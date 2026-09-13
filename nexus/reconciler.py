"""Periodically verifies each running service against its desired_state and
restarts crashed ones with exponential backoff, capped at max_restarts."""
from datetime import datetime, timedelta, timezone

from .config import BASE_DIR
from .manifest import load_manifest
from .runner import run_script
from .shell import run_bash
from .state import get_backoff, set_backoff, upsert_current_state

DEFAULT_BASE_DELAY = 10   # seconds before the first retry
DEFAULT_MAX_DELAY = 300   # cap on backoff delay
DEFAULT_MAX_RESTARTS = 5  # give up and surface as "error" after this many
DEFAULT_RESET_AFTER = 600  # seconds of continuous liveness before fail_count resets

RECONCILE_INTERVAL_SECONDS = 30


def _check_alive(entry: dict):
    """True/False if status_script is configured, else None (unverifiable)."""
    if "status_script" not in entry:
        return None
    script_path = BASE_DIR / entry["status_script"]
    code, _ = run_bash(script_path, entry.get("args", []), timeout=15)
    return code == 0


def _parse(ts: str):
    return datetime.fromisoformat(ts) if ts else None


def reconcile_once() -> None:
    services, _ = load_manifest()
    now = datetime.now(timezone.utc)

    for svc in services:
        if svc.get("desired_state", "running") != "running":
            continue

        alive = _check_alive(svc)
        if alive is None:
            continue  # no status_script - nothing to verify, trust last known state

        name = svc["name"]
        backoff = get_backoff(name)
        reset_after = svc.get("restart_reset_after", DEFAULT_RESET_AFTER)

        if alive:
            alive_since = _parse(backoff["alive_since"]) or now
            if backoff["fail_count"] and (now - alive_since).total_seconds() >= reset_after:
                set_backoff(name, fail_count=0, next_retry_at=None, alive_since=alive_since.isoformat())
            elif not backoff["alive_since"]:
                set_backoff(name, alive_since=now.isoformat())
            upsert_current_state(name, "service", "running", "reconcile")
            continue

        # Not alive but should be.
        set_backoff(name, alive_since=None)
        max_restarts = svc.get("max_restarts", DEFAULT_MAX_RESTARTS)

        if backoff["fail_count"] >= max_restarts:
            upsert_current_state(name, "service", "error", "reconcile")
            continue

        next_retry_at = _parse(backoff["next_retry_at"])
        if next_retry_at and now < next_retry_at:
            upsert_current_state(name, "service", "crashed", "reconcile")
            continue  # still inside the backoff window

        run_script(svc, "service", "start")
        fail_count = backoff["fail_count"] + 1
        base_delay = svc.get("restart_base_delay", DEFAULT_BASE_DELAY)
        max_delay = svc.get("restart_max_delay", DEFAULT_MAX_DELAY)
        delay = min(base_delay * (2 ** (fail_count - 1)), max_delay)
        set_backoff(
            name,
            fail_count=fail_count,
            next_retry_at=(now + timedelta(seconds=delay)).isoformat(),
        )
