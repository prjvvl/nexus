"""Cron-based execution for manifest jobs, backed by APScheduler."""
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

from .manifest import load_manifest
from .runner import run_script

scheduler = BackgroundScheduler()


def schedule_jobs() -> None:
    _, jobs = load_manifest()
    for job in jobs:
        scheduler.add_job(
            run_script,
            CronTrigger.from_crontab(job["schedule"]),
            args=[job, "job", "run"],
            id=job["name"],
            replace_existing=True,
        )
    scheduler.start()
