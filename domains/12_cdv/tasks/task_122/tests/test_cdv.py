from __future__ import annotations

import os
from pathlib import Path
import sys
import traceback
import xml.etree.ElementTree as ET

from coverage_model import export_coverage
from test_sequences import run_sequences


def write_results(path: str | None, failures: int) -> None:
    if not path:
        return
    testsuite = ET.Element("testsuite", tests="1", failures=str(failures), errors="0")
    if failures:
        testcase = ET.SubElement(testsuite, "testcase", name="close_coverage_loop")
        ET.SubElement(testcase, "failure", message="analysis sequence failed")
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(testsuite).write(path, encoding="utf-8", xml_declaration=True)


def main() -> int:
    failures = 0
    try:
        run_sequences()
    except Exception:
        failures = 1
        traceback.print_exc()
    finally:
        coverage_path = os.environ.get("CDV_COVERAGE_FILE")
        if coverage_path:
            export_coverage(coverage_path)
        write_results(os.environ.get("COCOTB_RESULTS_FILE"), failures)
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
