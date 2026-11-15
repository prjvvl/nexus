"""Nexus entrypoint.

Initializes state storage, reconciles services to their declared
desired_state, runs any on-start jobs, starts the job scheduler, and serves
the API and dashboard.
"""
import uvicorn

from nexus.api import app
from nexus.config import HOST, PORT
from nexus.lifecycle import run_on_start_jobs, start_services
from nexus.maintenance import schedule_maintenance
from nexus.manifest import load_manifest, validate_manifest
from nexus.scheduler import schedule_jobs
from nexus.state import init_db


def main() -> None:
    init_db()
    validate_manifest(*load_manifest())
    start_services()
    run_on_start_jobs()
    schedule_jobs()
    schedule_maintenance()
    uvicorn.run(app, host=HOST, port=PORT)


if __name__ == "__main__":
    main()
