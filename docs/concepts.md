# Concepts

## Services vs. jobs

A **service** is long-running — a container, a process — that should
generally be up. A **job** is a one-shot script, triggered by a cron
schedule, Nexus starting (`trigger: on_start`), a manual Run now/API call,
or any combination — unlike services, nothing about a job is required
except `name` and `script`. Services and jobs share one manifest and one
dashboard, but are tracked separately:
Nexus rejects a manifest that reuses a name across the two
(`nexus/manifest.py`'s `validate_manifest`), and state storage keys every
row on `(name, kind)` for the same reason.

## `desired_state` vs. imperative actions

Each service has a `desired_state`: `running` or `stopped`. This is what
the **reconciler** (see below) holds the service to, and what a fresh boot
starts it into — it's the only thing persisted back into `manifest.yaml`.

Start, Stop, and Restart in the dashboard (or API) are separate, one-off
actions. Clicking Stop on a `desired_state: running` service stops it right
now, but the reconciler will start it right back up on its next pass,
because the declared state didn't change. The **Autostart** toggle is the
one control that edits `desired_state` itself.

This split exists so you can take a service down for maintenance without
editing the manifest, while still trusting the manifest as the source of
truth for "what should be running after a reboot."

## Reconciliation and backoff

Every 30 seconds, the reconciler re-checks every service whose
`desired_state` is `running`:

- No `status_script` configured → nothing to check. Nexus trusts whatever
  it last told itself (started, stopped) and does nothing further. This is
  the right choice for a service you don't want monitored.
- `status_script` exits 0 → the service is alive. Status shows `running`.
- `status_script` exits non-zero → the service should be running but
  isn't. Nexus restarts it, with exponential backoff
  (`restart_base_delay`, doubling up to `restart_max_delay`) between
  attempts. After `max_restarts` consecutive failures it gives up and marks
  the service `error` — manually clicking Start or Restart resets the
  backoff and gives it a fresh set of attempts. If it stays healthy for
  `restart_reset_after` seconds, the failure count resets on its own.

## Run history and current state

Every start/stop/restart/job-run is recorded in `state.db` (SQLite): one
row per run in `runs` (with output, capped at the last 4000 characters), and
one row per `(name, kind)` in `current_state` holding the latest status,
last action, and backoff bookkeeping. `runs` is pruned to the most recent
200 rows per name, daily.

## What Nexus doesn't do (yet)

See [Security](security.md) for the no-auth, open-CORS tradeoff. Beyond
that: no manifest hot-reload (a restart is needed to add/remove
services/jobs — toggling `desired_state` doesn't need one), no multi-machine
support, no per-service user, no notifications on failure. These are
accepted gaps for a single-user, single-machine tool, not oversights.
