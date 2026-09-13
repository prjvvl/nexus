"""Shared helper for invoking a manifest script via bash."""
import subprocess

from .config import BASE_DIR


def run_bash(script_path, args, timeout):
    """Runs `bash <script_path> <args...>` with BASE_DIR as cwd. Returns
    (returncode, combined_output); a launch failure or timeout is folded into
    (-1, str(exception)) rather than raising, so callers never need to catch
    subprocess errors themselves."""
    try:
        result = subprocess.run(
            ["bash", str(script_path), *args],
            cwd=BASE_DIR,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        return result.returncode, (result.stdout or "") + (result.stderr or "")
    except Exception as exc:  # noqa: BLE001 - surface any failure as a failed run
        return -1, str(exc)
