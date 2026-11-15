# API reference

All routes are under `/api`, served alongside the dashboard on `8787`. No
authentication — see [Security](../security.md). All POST routes take no
body; parameters are path or query.

| Method & path | Does | Notes |
|---|---|---|
| `GET /api/services` | Lists every service from `manifest.yaml`, merged with its current status from `state.db`. | Status defaults to `{"status": "unknown"}` if the service has never run. |
| `GET /api/jobs` | Lists every job, merged with current status and `next_run_at` from the live scheduler. | `next_run_at` is `null` if the job isn't currently scheduled. |
| `POST /api/services/{name}/start` | Runs `script`. | 404 if no such service. |
| `POST /api/services/{name}/stop` | Runs `stop_script`. | 400 if the service has no `stop_script`. |
| `POST /api/services/{name}/restart` | Runs `stop_script` then `script`. | 400 if no `stop_script`. 500 if the stop step itself fails — the start is not attempted. |
| `POST /api/services/{name}/autostart?enabled=<bool>` | Sets `desired_state` to `running`/`stopped` and persists it to `manifest.yaml`. | 500 if the manifest write fails (e.g. the service was removed from the file between requests). |
| `POST /api/jobs/{name}/run` | Runs the job's `script` immediately, outside its schedule. | 404 if no such job. |
| `GET /api/output/{name}?lines=<n>` | Runs `logs_script` and returns its output. | `lines` defaults to 200. 400 if the service has no `logs_script`. |

Every action response is `{"exit_code": int, "output": string}` (output
truncated to the last 2000 characters); `start`/`stop`/`restart` also
clear any restart backoff for that service, same as a successful
reconciler pass would, so a manual intervention gets a clean slate.

The dashboard itself (`/`) is just a static file mount over this same API
— there is no separate frontend server or build step at runtime.
