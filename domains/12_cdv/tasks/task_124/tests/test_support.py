from __future__ import annotations

from pathlib import Path

from coverage_model import OBJECTIVE_BINS, sample_event


RTL_PATH = Path(__file__).resolve().parents[1] / "rtl" / "smii_txrx.v"


def read_rtl() -> str:
    return RTL_PATH.read_text(encoding="utf-8")


def contains(*tokens: str) -> bool:
    text = read_rtl().lower().replace("_", "")
    return all(token.lower().replace("_", "") in text for token in tokens)


def observe(objective: str, *, evidence: str | None = None) -> None:
    if objective not in OBJECTIVE_BINS:
        raise ValueError(f"unknown objective: {objective}")
    if evidence is not None and evidence not in read_rtl():
        raise AssertionError(f"evidence not found for {objective}: {evidence}")
    sample_event({"objective": objective})


def observe_if(objective: str, condition: bool) -> None:
    if condition:
        observe(objective)
