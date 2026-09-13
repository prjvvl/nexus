"""Startup reconciliation: brings services to their declared desired_state."""
from .manifest import load_manifest
from .runner import run_script
from .state import upsert_current_state


def start_services() -> None:
    services, _ = load_manifest()
    for svc in services:
        if svc.get("desired_state", "running") == "running":
            run_script(svc, "service", "start")
        else:
            upsert_current_state(svc["name"], "service", "stopped", "none")
