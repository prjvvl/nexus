"""Nexus entrypoint.

Initializes state storage, reconciles services to their declared
desired_state, runs any on-start jobs, starts the job scheduler, and serves
the API and dashboard.
"""
import socket
import sys

import uvicorn

from nexus.api import app
from nexus.config import HOST, PORT
from nexus.lifecycle import run_on_start_jobs, start_services
from nexus.maintenance import schedule_maintenance
from nexus.manifest import load_manifest, validate_manifest
from nexus.scheduler import schedule_jobs
from nexus.state import init_db


def _already_running() -> bool:
    """True if something is already listening on HOST:PORT - checked by
    trying to bind it ourselves, the same thing uvicorn does later, just
    before any startup side effect runs instead of after. Without this, a
    second instance (a wrapper script restarting after a crash, an
    auto-start racing a manual launch, running main.py twice by accident)
    would run every service's start script and every on_start job in full
    before failing to bind the port at the very end - so on a restart loop,
    those side effects fire again on every retry, not just once.

    Deliberately no SO_REUSEADDR before this bind: on Windows that option
    lets a bind succeed even though another process is already listening,
    which would silently defeat the whole check on exactly the platform
    this matters most on."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        try:
            sock.bind((HOST, PORT))
        except OSError:
            return True
    return False


def main() -> None:
    if _already_running():
        print(f"Nexus already running on {HOST}:{PORT} - exiting without restarting services/jobs.")
        sys.exit(0)
    init_db()
    validate_manifest(*load_manifest())
    start_services()
    run_on_start_jobs()
    schedule_jobs()
    schedule_maintenance()
    uvicorn.run(app, host=HOST, port=PORT)


if __name__ == "__main__":
    main()
