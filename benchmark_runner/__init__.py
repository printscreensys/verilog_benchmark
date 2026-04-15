__all__ = [
    "BenchmarkRunner",
    "LLMConfig",
    "OpenAICompatibleLLM",
    "RunOptions",
    "run_task",
]


def __getattr__(name):
    if name in {"LLMConfig", "OpenAICompatibleLLM"}:
        from .client import LLMConfig, OpenAICompatibleLLM

        return {
            "LLMConfig": LLMConfig,
            "OpenAICompatibleLLM": OpenAICompatibleLLM,
        }[name]

    if name in {"BenchmarkRunner", "RunOptions", "run_task"}:
        from .runner import BenchmarkRunner, RunOptions, run_task

        return {
            "BenchmarkRunner": BenchmarkRunner,
            "RunOptions": RunOptions,
            "run_task": run_task,
        }[name]

    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
