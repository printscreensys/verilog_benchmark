import subprocess
from pathlib import Path

def test():
    python_bin = ".venv/bin/python"
    failed = []

    for task_dir in sorted(Path("domains").glob("*/task_*")):
        if not (task_dir / "ref.v").exists():
            continue
        if not (task_dir / "tb.v").exists():
            continue

        cmd = [python_bin, "-m", "eval", str(task_dir / "ref.v"), "--task-dir", str(task_dir)]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        ok = proc.returncode == 0 and '"benchmark_pass": true' in proc.stdout
        print(f"{task_dir.name}: {'PASS' if ok else 'FAIL'}")
        if not ok:
            failed.append(task_dir.as_posix())

    print(f"FAILED {len(failed)}")

if __name__ == "__main__":
    test()