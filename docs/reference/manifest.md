# Manifest reference

`manifest.yaml` lives at the repo root, is gitignored (it's per-machine
config), and has two top-level keys: `services` and `jobs`. Copy
`manifest.example.yaml` to get started — see [Getting started](../getting-started.md).

Edited by hand, or round-tripped by Nexus itself (the Autostart toggle) via
`ruamel.yaml` in round-trip mode, which preserves your comments and
formatting.

## Services

| Field | Type | Required | Default | Meaning |
|---|---|---|---|---|
| `name` | string | Yes | — | Unique across all services and jobs. |
| `script` | path | Yes | — | Run on Start. See [Scripts](../guides/scripts.md). |
| `stop_script` | path | No | — | Run on Stop/Restart. Without it, Stop/Restart are disabled in the UI. |
| `status_script` | path | No | — | Checked every 30s by the reconciler. Without it, the service is never auto-restarted or marked `crashed`/`error` — Nexus just trusts the last action it took. |
| `logs_script` | path | No | — | Backs the dashboard's Logs panel and `/api/output/{name}`. |
| `args` | list of string | No | `[]` | Passed to every script for this service, in order, before any script-specific extra args (e.g. `logs_script`'s line count). |
| `desired_state` | `running` \| `stopped` | No | `running` | What the reconciler holds this service to, and what a fresh boot starts it into. Edited by the Autostart toggle; see [Concepts](../concepts.md). |
| `timeout` | integer (seconds) | No | `600` | Timeout for `script`/`stop_script` runs. `status_script` and `logs_script` always get 15s regardless of this. |
| `max_restarts` | integer | No | `5` | Consecutive failed restarts before the reconciler gives up and marks the service `error`. |
| `restart_base_delay` | integer (seconds) | No | `10` | Delay before the first restart attempt. |
| `restart_max_delay` | integer (seconds) | No | `300` | Cap on the exponential backoff delay. |
| `restart_reset_after` | integer (seconds) | No | `600` | How long a service must stay continuously alive before its failure count resets to 0. |

## Jobs

| Field | Type | Required | Default | Meaning |
|---|---|---|---|---|
| `name` | string | Yes | — | Unique across all services and jobs. |
| `script` | path | Yes | — | Run on its schedule, or on demand via Run now / `/api/jobs/{name}/run`. |
| `schedule` | cron string | Yes | — | Standard 5-field crontab syntax (`APScheduler`'s `CronTrigger.from_crontab`). |
| `args` | list of string | No | `[]` | Passed to the script. |
| `timeout` | integer (seconds) | No | `600` | Timeout for the run. |

Jobs have no `max_restarts`/backoff fields — a failed job run is just
recorded as `error` in its current state; it isn't retried, and runs again
on its normal schedule regardless of whether the last run failed.

All script paths are relative to the repository root, and every script
runs with that directory as its working directory — see
[Scripts](../guides/scripts.md).
