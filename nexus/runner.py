"""Executes a manifest entry's script and records the outcome in state.db."""
from .config import BASE_DIR
from .shell import run_bash
from .state import record_run_finish, record_run_start, upsert_current_state


def run_script(entry: dict, kind: str, action: str, script_key: str = "script"):
    name = entry["name"]
    script_path = BASE_DIR / entry[script_key]
    args = entry.get("args", [])

    run_id = record_run_start(name, kind, action)
    upsert_current_state(name, kind, "pending", action)
    code, output = run_bash(script_path, args, entry.get("timeout", 600))
    record_run_finish(run_id, code, output)

    if code != 0:
        status = "error"
    elif action == "stop":
        status = "stopped"
    else:
        status = "running" if kind == "service" else "idle"
    upsert_current_state(name, kind, status, action)
    return code, output
