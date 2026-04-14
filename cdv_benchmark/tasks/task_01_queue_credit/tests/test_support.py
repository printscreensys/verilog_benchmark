from __future__ import annotations

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, NextTimeStep, ReadOnly, RisingEdge

from coverage_model import sample_event


__all__ = [
    "configure_limit",
    "expect_snapshot",
    "initialize_dut",
    "step",
]


def _limit_code(limit: int) -> int:
    if limit < 1 or limit > 4:
        raise ValueError("limit must be in the range 1..4")
    return limit - 1


def _limit_value(cfg_limit: int) -> int:
    return int(cfg_limit) + 1


def _scenario_name(pre_count: int, limit: int, push: int, pop: int, flush: int) -> str | None:
    if flush:
        return "flush_empty" if pre_count == 0 else "flush_nonempty"
    if push and not pop:
        if pre_count == 0:
            return "push_into_empty"
        if pre_count == limit:
            return "push_into_full_overflow"
        return "push_into_mid"
    if pop and not push:
        if pre_count == 0:
            return "pop_from_empty_underflow"
        if pre_count == limit:
            return "pop_from_full"
        return "pop_from_mid"
    if push and pop:
        if pre_count == 0:
            return "push_pop_on_empty"
        if pre_count == limit:
            return "push_pop_on_full"
        return "push_pop_on_mid"
    return None


def _sample_transition(event: dict[str, int | str]) -> None:
    sample_event(
        {
            "scenario": event["scenario"],
            "limit": event["limit"],
        }
    )


async def initialize_dut(dut, period_ns: int = 10) -> None:
    cocotb.start_soon(Clock(dut.clk, period_ns, units="ns").start())
    dut.push.value = 0
    dut.pop.value = 0
    dut.flush.value = 0
    dut.cfg_limit.value = _limit_code(4)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await ReadOnly()
    await NextTimeStep()


async def configure_limit(dut, limit: int) -> None:
    dut.cfg_limit.value = _limit_code(limit)
    await NextTimeStep()


async def step(dut, *, push: int = 0, pop: int = 0, flush: int = 0) -> dict[str, int | str | None]:
    pre_count = int(dut.count.value)
    limit = _limit_value(int(dut.cfg_limit.value))

    dut.push.value = int(push)
    dut.pop.value = int(pop)
    dut.flush.value = int(flush)

    await RisingEdge(dut.clk)
    await ReadOnly()

    snapshot = {
        "pre_count": pre_count,
        "post_count": int(dut.count.value),
        "limit": limit,
        "push": int(push),
        "pop": int(pop),
        "flush": int(flush),
        "full": int(dut.full.value),
        "empty": int(dut.empty.value),
        "overflow_pulse": int(dut.overflow_pulse.value),
        "underflow_pulse": int(dut.underflow_pulse.value),
        "scenario": _scenario_name(pre_count, limit, int(push), int(pop), int(flush)),
    }

    if snapshot["scenario"] is not None:
        _sample_transition(snapshot)

    await NextTimeStep()
    dut.push.value = 0
    dut.pop.value = 0
    dut.flush.value = 0
    return snapshot


def expect_snapshot(
    snapshot: dict[str, int | str | None],
    *,
    count: int | None = None,
    full: int | None = None,
    empty: int | None = None,
    overflow_pulse: int | None = None,
    underflow_pulse: int | None = None,
) -> None:
    expected = {
        "post_count": count,
        "full": full,
        "empty": empty,
        "overflow_pulse": overflow_pulse,
        "underflow_pulse": underflow_pulse,
    }
    for key, value in expected.items():
        if value is None:
            continue
        actual = snapshot[key]
        assert actual == value, f"{key} expected {value} but saw {actual}: {snapshot}"
