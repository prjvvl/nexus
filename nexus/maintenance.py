"""Background upkeep: periodic reconciliation and run-history pruning."""
from apscheduler.triggers.interval import IntervalTrigger

from .reconciler import RECONCILE_INTERVAL_SECONDS, reconcile_once
from .scheduler import scheduler
from .state import prune_old_runs

PRUNE_INTERVAL_HOURS = 24
KEEP_RUNS_PER_NAME = 200


def schedule_maintenance() -> None:
    scheduler.add_job(
        reconcile_once,
        IntervalTrigger(seconds=RECONCILE_INTERVAL_SECONDS),
        id="__reconcile__",
        replace_existing=True,
        max_instances=1,
    )
    scheduler.add_job(
        prune_old_runs,
        IntervalTrigger(hours=PRUNE_INTERVAL_HOURS),
        args=[KEEP_RUNS_PER_NAME],
        id="__prune_runs__",
        replace_existing=True,
    )
