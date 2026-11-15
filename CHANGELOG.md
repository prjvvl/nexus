# Changelog

## v0.0.1

First tagged version, after a deliberate git history reset to ship one
clean, reviewed commit.

- Manifest-driven services (`script`/`stop_script`/`status_script`/`logs_script`,
  `desired_state`, restart backoff) and cron jobs, read from `manifest.yaml`.
- Reconciler: restarts crashed services (those with a `status_script`) with
  exponential backoff, capped by `max_restarts`.
- Dashboard (React + Tailwind) and REST API (FastAPI): service/job status,
  start/stop/restart, autostart toggle, run-job-now, a log viewer.
- SQLite-backed run history and current-state tracking, keyed on `(name, kind)`.
- `install.sh`: installs dependencies, builds the UI, and sets up `nexus.service`
  (systemd) for the current user.
- Known, accepted tradeoffs: no auth, CORS open, single machine only — see
  [docs/security.md](docs/security.md).
