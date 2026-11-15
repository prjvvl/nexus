"""Startup reconciliation: brings services to their declared desired_state,
and fires any job that runs once per boot rather than on a recurring
schedule."""
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


def run_on_start_jobs() -> None:
    """Runs every job with `trigger: on_start` once, synchronously, before
    Nexus starts serving - the same timing start_services() gets, so an
    on-start job can assume whatever a `desired_state: running` service just
    started is already up."""
    _, jobs = load_manifest()
    for job in jobs:
        if job.get("trigger") == "on_start":
            run_script(job, "job", "run")
