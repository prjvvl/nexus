"""Fetches the tail of a running service's own output (not the run-history log)."""
from .config import BASE_DIR
from .shell import run_bash


def get_service_output(entry: dict, lines: int = 200):
    script_key = "logs_script"
    if script_key not in entry:
        return None, "no logs_script configured for this service"

    script_path = BASE_DIR / entry[script_key]
    args = [*entry.get("args", []), str(lines)]
    return run_bash(script_path, args, timeout=15)
