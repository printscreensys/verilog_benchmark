from __future__ import annotations

from dataclasses import dataclass
import os
from typing import Any, Iterable

from dotenv import load_dotenv
from openai import OpenAI


DEFAULT_SYSTEM_PROMPT = (
    "You are an expert RTL engineer. Follow the user's instructions exactly and "
    "return only the requested code or structured data."
)


@dataclass(frozen=True)
class LLMConfig:
    model: str
    api_key: str | None = None
    base_url: str | None = None
    system_prompt: str = DEFAULT_SYSTEM_PROMPT
    temperature: float = 0.0
    max_output_tokens: int | None = None


def _first_env(names: Iterable[str]) -> str | None:
    for name in names:
        value = os.environ.get(name)
        if value:
            return value
    return None


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
        load_dotenv()

        api_key = config.api_key or _first_env(
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

        base_url = config.base_url or _first_env(
            [
                "BENCH_LLM_BASE_URL",
                "LLM_BASE_URL",
                "OPENAI_BASE_URL",
            ]
        )

        self.config = config
        self.client = OpenAI(api_key=api_key, base_url=base_url)

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

        response = self.client.chat.completions.create(**request)
        return {
            "text": extract_response_text(response),
            "response": response_to_dict(response),
            "request": request,
        }

