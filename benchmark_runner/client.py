from __future__ import annotations

from dataclasses import dataclass
import logging
import os
from typing import Any, Iterable

from dotenv import load_dotenv
from openai import OpenAI


DEFAULT_SYSTEM_PROMPT = (
    "You are an expert RTL engineer. Follow the user's instructions exactly and "
    "return only the requested code or structured data."
)
LOGGER = logging.getLogger(__name__)
LOG_FORMAT = "%(asctime)s %(levelname)s %(name)s: %(message)s"


@dataclass(frozen=True)
class LLMConfig:
    model: str
    api_key: str | None = None
    base_url: str | None = None
    system_prompt: str = DEFAULT_SYSTEM_PROMPT
    temperature: float = 0.0
    max_output_tokens: int | None = None
def _first_env_with_name(names: Iterable[str]) -> tuple[str | None, str | None]:
    for name in names:
        value = os.environ.get(name)
        if value:
            return value, name
    return None, None


def _configure_module_logging() -> None:
    level_name = (
        os.environ.get("BENCH_LLM_LOG_LEVEL")
        or os.environ.get("LLM_LOG_LEVEL")
        or ""
    ).strip()
    if not level_name:
        return

    level = getattr(logging, level_name.upper(), None)
    if not isinstance(level, int):
        logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
        LOGGER.warning(
            "Invalid log level %r in BENCH_LLM_LOG_LEVEL/LLM_LOG_LEVEL. Falling back to INFO.",
            level_name,
        )
        return

    logging.basicConfig(level=level, format=LOG_FORMAT)


def _message_stats(messages: list[dict[str, str]]) -> list[dict[str, Any]]:
    stats = []
    for index, message in enumerate(messages, start=1):
        content = message.get("content", "")
        if not isinstance(content, str):
            content = str(content)
        stats.append(
            {
                "index": index,
                "role": message.get("role", "unknown"),
                "chars": len(content),
                "lines": content.count("\n") + (1 if content else 0),
            }
        )
    return stats


def _usage_to_dict(response: Any) -> dict[str, Any]:
    usage = getattr(response, "usage", None)
    if usage is None:
        return {}

    if hasattr(usage, "model_dump"):
        payload = usage.model_dump(mode="json")
        return payload if isinstance(payload, dict) else {}

    if isinstance(usage, dict):
        return usage

    payload = {}
    for key in ("prompt_tokens", "completion_tokens", "total_tokens"):
        value = getattr(usage, key, None)
        if value is not None:
            payload[key] = value
    return payload


def _content_part_to_text(part: Any) -> str:
    if isinstance(part, str):
        return part

    if isinstance(part, dict):
        if isinstance(part.get("text"), str):
            return part["text"]
        if part.get("type") == "text" and isinstance(part.get("text"), str):
            return part["text"]
        if isinstance(part.get("content"), str):
            return part["content"]
        return ""

    if hasattr(part, "text") and isinstance(part.text, str):
        return part.text

    if hasattr(part, "content") and isinstance(part.content, str):
        return part.content

    return ""


def extract_response_text(response: Any) -> str:
    choices = getattr(response, "choices", None) or []
    if not choices:
        return ""

    first_choice = choices[0]
    message = getattr(first_choice, "message", None)
    if message is None:
        return ""

    content = getattr(message, "content", "")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = [_content_part_to_text(part) for part in content]
        return "".join(part for part in parts if part)
    return _content_part_to_text(content)


def response_to_dict(response: Any) -> dict[str, Any]:
    if hasattr(response, "model_dump"):
        return response.model_dump(mode="json")
    if hasattr(response, "dict"):
        return response.dict()
    return {"repr": repr(response)}


class OpenAICompatibleLLM:
    def __init__(self, config: LLMConfig):
        _configure_module_logging()
        load_dotenv()

        api_key = config.api_key
        api_key_source = "constructor"
        if not api_key:
            api_key, api_key_source = _first_env_with_name(
                [
                    "BENCH_LLM_API_KEY",
                    "LLM_API_KEY",
                    "OPENAI_API_KEY",
                    "GROQ_API_KEY",
                ]
            )
        if not api_key:
            raise ValueError(
                "No API key configured. Use --api-key or set one of "
                "BENCH_LLM_API_KEY, LLM_API_KEY, OPENAI_API_KEY, or GROQ_API_KEY."
            )

        base_url = config.base_url
        base_url_source = "constructor"
        if not base_url:
            base_url, base_url_source = _first_env_with_name(
                [
                    "BENCH_LLM_BASE_URL",
                    "LLM_BASE_URL",
                    "OPENAI_BASE_URL",
                ]
            )

        self.config = config
        self.client = OpenAI(api_key=api_key, base_url=base_url)
        self.base_url = base_url

        LOGGER.info(
            "Initialized OpenAI-compatible client for model=%s base_url=%s api_key_source=%s base_url_source=%s",
            self.config.model,
            self.base_url or "default",
            api_key_source,
            base_url_source if self.base_url else "sdk_default",
        )

    def chat(
        self,
        messages: list[dict[str, str]],
        *,
        temperature: float | None = None,
        max_output_tokens: int | None = None,
    ) -> dict[str, Any]:
        request: dict[str, Any] = {
            "model": self.config.model,
            "messages": messages,
            "temperature": self.config.temperature if temperature is None else temperature,
        }

        effective_max_tokens = (
            self.config.max_output_tokens
            if max_output_tokens is None
            else max_output_tokens
        )
        if effective_max_tokens is not None:
            request["max_tokens"] = effective_max_tokens

        LOGGER.info(
            "Sending chat completion request model=%s message_count=%d temperature=%s max_tokens=%s",
            request["model"],
            len(messages),
            request["temperature"],
            request.get("max_tokens"),
        )
        LOGGER.debug("Request message stats: %s", _message_stats(messages))

        try:
            response = self.client.chat.completions.create(**request)
        except Exception:
            LOGGER.exception(
                "Chat completion request failed model=%s base_url=%s",
                request["model"],
                self.base_url or "default",
            )
            raise

        text = extract_response_text(response)
        choices = getattr(response, "choices", None) or []
        finish_reason = None
        if choices:
            finish_reason = getattr(choices[0], "finish_reason", None)

        LOGGER.info(
            "Received chat completion response model=%s response_id=%s finish_reason=%s output_chars=%d",
            request["model"],
            getattr(response, "id", None),
            finish_reason,
            len(text),
        )

        usage_payload = _usage_to_dict(response)
        if usage_payload:
            LOGGER.debug("Response token usage: %s", usage_payload)

        return {
            "text": text,
            "response": response_to_dict(response),
            "request": request,
        }
