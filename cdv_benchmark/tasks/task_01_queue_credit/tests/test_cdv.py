import os

import cocotb

from coverage_model import export_coverage
from test_sequences import run_sequences
from test_support import initialize_dut


@cocotb.test()
async def close_coverage_loop(dut):
    coverage_path = os.environ.get("CDV_COVERAGE_FILE")
    try:
        await initialize_dut(dut)
        await run_sequences(dut)
    finally:
        if coverage_path:
            export_coverage(coverage_path)
