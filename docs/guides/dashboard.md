# The dashboard

The dashboard is a static page served by Nexus itself at `/` — no separate
process, no build step at runtime. It polls `/api/services` and `/api/jobs`
every 5 seconds.

## Top bar

Three tiles: total services, how many are `running`, and how many services
or jobs are in `error`. An error or a failed action shows as a dismissible
banner in the header.

## Services

Each service card shows:

- **Status badge** — `running`, `stopped`, `pending`, `crashed`, `error`,
  or `unknown` (unknown means it was never recorded in `state.db` — a job
  before its first run, typically).
- **Autostart toggle** — edits `desired_state` in `manifest.yaml` (see
  [Concepts](../concepts.md)).
- **Logs** — only shown if the service has a `logs_script`. Toggles a panel
  tailing the service's own output.
- **Restart** and **Start/Stop** — disabled, with an explanatory tooltip,
  when the service has no `stop_script`: Nexus can start it but has no safe
  way to stop it, so it doesn't offer to.
- A failed-restart note (`N failed restarts · retrying around HH:MM:SS`)
  appears once the reconciler has had to restart the service at least once.

## Scheduled jobs

Each job card shows its cron schedule, when it last ran, when it's next
due, and a **Run now** button that runs it immediately without disturbing
its schedule.

## What it doesn't show

No resource/CPU/memory charts — removed deliberately; this is a control
surface, not a monitoring dashboard. No run history list in the UI yet,
though every run is in `state.db` (`runs` table) if you need to look it up
directly.
