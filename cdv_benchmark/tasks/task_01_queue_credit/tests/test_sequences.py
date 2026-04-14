from test_support import configure_limit, expect_snapshot, step


async def run_sequences(dut):
    await configure_limit(dut, 4)

    snapshot = await step(dut, push=1)
    expect_snapshot(snapshot, count=1, empty=0, full=0)

    snapshot = await step(dut, push=1)
    expect_snapshot(snapshot, count=2, empty=0, full=0)

    snapshot = await step(dut, pop=1)
    expect_snapshot(snapshot, count=1, empty=0, full=0)

    snapshot = await step(dut, flush=1)
    expect_snapshot(snapshot, count=0, empty=1, full=0)
