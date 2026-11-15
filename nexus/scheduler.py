"""Cron-based execution for manifest jobs, backed by APScheduler."""
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

from .manifest import load_manifest
from .runner import run_script

scheduler = BackgroundScheduler()


def schedule_jobs() -> None:
    """Registers a cron trigger for every job that has a `schedule` - a job
    without one (on_start-only, or purely manual via Run now/the API) simply
    isn't given one here; nothing else needs to run it on a recurring basis."""
    _, jobs = load_manifest()
    for job in jobs:
        if "schedule" not in job:
            continue
        scheduler.add_job(
            run_script,
            CronTrigger.from_crontab(job["schedule"]),
            args=[job, "job", "run"],
            id=job["name"],
            replace_existing=True,
        )
    scheduler.start()
