# Troubleshooting

## A service is stuck in `error`

After `max_restarts` consecutive failed restarts (default 5), the
reconciler gives up and leaves the service in `error` until someone acts —
it does not retry on its own and nothing notifies you. Check what's
actually wrong (`journalctl -u nexus.service`, or run the `status_script`
by hand), fix it, then click Start or Restart in the dashboard — that
clears the backoff and the reconciler starts tracking it fresh.

## A service shows `error` but is actually running fine

Its `status_script` is checking the wrong thing — most commonly, something
*other* than Nexus already started the real process (a separate systemd
unit, a leftover container from before Nexus managed it), so
`status_script` can't find what it's looking for, Nexus's own `start`
"succeeds" into nothing changing, and it crash-loops to `error` against a
service that was never actually down. Make sure nothing but Nexus is
managing that service, and that `status_script`'s check matches what
`script` actually starts.

## Stop/Restart/the toggle are disabled

Stop and Restart need `stop_script`. A service defined with only `script`
(no `stop_script`) is start-only on purpose — Nexus has no safe way to stop
it, so the UI disables the buttons and shows why in a tooltip, rather than
pretending they'd work.

## No Logs button on a service

It has no `logs_script` configured. Add one — see
[Scripts](guides/scripts.md) for the contract — or use one of the shipped
`scripts/defaults/logs-*.sh`.

## Startup fails with a manifest error

`validate_manifest` runs before anything else starts, and exits with a
clear message rather than letting a typo surface as a raw `KeyError`
later. The two things it checks: every service/job has its required fields
(`name`+`script`, jobs also need `schedule`), and no name is reused across
a service and a job. Fix `manifest.yaml` and restart.

## A manifest edit (a new service, a new job) didn't take effect

Nexus reads `manifest.yaml` fresh on most operations, but new/removed
services and jobs are only picked up at startup — restart the service:
`sudo systemctl restart nexus.service`. (Toggling an existing service's
`desired_state` — the Autostart switch — doesn't need a restart; the
reconciler picks that up on its next 30-second pass.)

## The dashboard shows "failed to reach Nexus"

The API didn't respond to `/api/services` or `/api/jobs`. Check the
process is actually up: `systemctl status nexus.service`,
`journalctl -u nexus.service -n 50`.

## Where to look for more detail

`journalctl -u nexus.service` has everything Nexus itself logs (uvicorn
access logs, startup messages). Per-run output lives in `state.db`'s `runs`
table (capped at the last 4000 characters per run, pruned to 200 runs per
name) if you need history beyond what a live log tail shows.
