# Getting started

This walks through `manifest.yaml` using the demo service and job that ship
with Nexus (seeded into `manifest.yaml` on first install), so you can see
the whole lifecycle — start, crash-restart, schedule, dashboard — before
wiring in anything of your own.

## The demo

`manifest.example.yaml` defines one service and one job:

```yaml
services:
  - name: nexus-demo
    script: scripts/defaults/run-compose.sh
    stop_script: scripts/defaults/stop-compose.sh
    status_script: scripts/defaults/status-compose.sh
    logs_script: scripts/defaults/logs-compose.sh
    args: ["examples/demo-app"]
    desired_state: stopped

jobs:
  - name: nexus-demo-job
    script: examples/demo-job/run.sh
    schedule: "*/2 * * * *"
```

`nexus-demo` is an nginx container (`examples/demo-app/docker-compose.yml`)
started with `docker compose up -d`. `nexus-demo-job` appends a timestamped
line to a log file every two minutes.

## Try it

Open the dashboard at `http://<your machine>:8787`.

1. **Start the demo service.** It's `desired_state: stopped` by default, so
   the card shows a Start button. Click it — within a couple of seconds the
   status badge goes to `running`, and `http://<your machine>:8091` serves
   the demo page.
2. **Kill it from outside Nexus**: `docker stop nexus-demo`. Within 30
   seconds the reconciler notices (via `status_script`) and restarts it —
   watch the status badge go `crashed` → `running` again, with no click from
   you.
3. **Flip Autostart.** The toggle next to the service edits `desired_state`
   in `manifest.yaml` directly — turn it on, then check the file: it now
   says `desired_state: running`. That's what Nexus brings the service back
   to on its own next boot; Start/Stop in the dashboard are separate,
   one-off actions that don't change it.
4. **Open Logs.** Only services with a `logs_script` get a Logs button —
   this one tails the container's output.
5. **Run the job now** from the "Scheduled jobs" card instead of waiting
   for its cron schedule, then check `examples/demo-job/output.log`.

## Wire in a real service

Add an entry to `manifest.yaml` (not `manifest.example.yaml` — that one's
just the template). At minimum:

```yaml
services:
  - name: my-app
    script: scripts/defaults/run-compose.sh
    args: ["/path/to/my-app"]       # a directory with a docker-compose.yml
    desired_state: running
```

`stop_script`, `status_script`, and `logs_script` are optional — add them
when you want stop/restart, crash auto-restart, and a log viewer for this
service. See [Scripts](guides/scripts.md) for the script contract and the
defaults that ship for compose and plain containers, and
[Manifest reference](reference/manifest.md) for every field.

Nexus doesn't hot-reload the manifest yet — restart the service
(`sudo systemctl restart nexus.service`) after editing it.
