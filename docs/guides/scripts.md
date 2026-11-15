# Scripts

Nexus doesn't know how to start anything itself — every action runs a bash
script you point it at. This keeps Docker, compose, and plain processes on
one interface, and means you can wire in literally anything that can be
scripted.

## The contract

Every script is invoked as:

```sh
bash <script> <args...> [extra args]
```

with the manifest entry's `args` list passed first, `cwd` set to the repo
root (`nexus/config.py`'s `BASE_DIR`), and a timeout (`entry["timeout"]`,
default 600s for start/stop/run scripts; status and logs scripts always get
15s). A script that exceeds its timeout, or fails to launch at all, is
treated as exit code `-1` with the exception text as output — callers never
need to handle a launch failure specially.

| Key | Called by | Exit code meaning | Required? |
|---|---|---|---|
| `script` | Start (service), Run (job) | 0 = started/succeeded | Yes |
| `stop_script` | Stop, and Restart's stop half | 0 = stopped | No — without it, Stop/Restart are disabled in the UI |
| `status_script` | The reconciler, every 30s | 0 = alive, non-zero = not alive | No — without it, the service is never auto-restarted |
| `logs_script` | The dashboard's Logs panel | stdout/stderr = log output | No — without it, there's no Logs button |

`logs_script` additionally gets a line-count appended as its last argument
(from `?lines=` on `/api/output/{name}`, default 200) — write it to honor
that if you want "tail -n".

## The defaults

`scripts/defaults/` ships four pairs, for the two kinds of thing this
project runs things as:

- **`run-compose.sh` / `stop-compose.sh` / `status-compose.sh` /
  `logs-compose.sh`** — a service defined by a `docker-compose.yml`.
  `args: ["<app_dir>"]`. Start does `docker compose up -d`; status checks
  `docker compose ps --status running`.
- **`run-container.sh` / `stop-container.sh` / `status-container.sh` /
  `logs-container.sh`** — a single existing container by name.
  `args: ["<container_name>"]`.

Point `script`/`stop_script`/etc. at these, or write your own — a
`status_script` just needs to exit 0 or not; it can be a one-line `curl` for
an HTTP health check, a `pgrep`, anything.

## Writing your own

A few things that bite:

- **`set -euo pipefail`** at the top — a script that doesn't propagate
  failure as a non-zero exit silently looks "running" to Nexus even when it
  isn't.
- **cwd is the Nexus repo root**, not the script's own directory and not
  your app's directory — `cd` explicitly if your script needs to run
  somewhere else (every shipped default does this via its `args`).
- **stdout and stderr are combined** into one `output` string Nexus
  records — don't rely on them being separable later.
- A `status_script` is on a tight 15s budget on every reconcile pass (every
  30s) — don't make it do anything slow.
