"""HTTP API and dashboard for Nexus."""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import UI_DIST
from .logs import get_service_output
from .manifest import find_entry, load_manifest, set_desired_state
from .runner import run_script
from .scheduler import scheduler
from .state import clear_backoff, get_current_states

app = FastAPI(title="Nexus")
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)


@app.get("/api/services")
def api_services():
    services, _ = load_manifest()
    states = get_current_states("service")
    return [{**svc, **states.get(svc["name"], {"status": "unknown"})} for svc in services]


@app.get("/api/jobs")
def api_jobs():
    _, jobs = load_manifest()
    states = get_current_states("job")
    result = []
    for job in jobs:
        info = {**job, **states.get(job["name"], {})}
        sched_job = scheduler.get_job(job["name"])
        info["next_run_at"] = (
            sched_job.next_run_time.isoformat()
            if sched_job and sched_job.next_run_time
            else None
        )
        result.append(info)
    return result


@app.post("/api/services/{name}/start")
def api_start(name: str):
    entry = find_entry(name, "service")
    if not entry:
        raise HTTPException(404, "service not found")
    code, output = run_script(entry, "service", "start")
    clear_backoff(name)  # manual action resets any auto-restart backoff state
    return {"exit_code": code, "output": output[-2000:]}


@app.post("/api/services/{name}/stop")
def api_stop(name: str):
    entry = find_entry(name, "service")
    if not entry:
        raise HTTPException(404, "service not found")
    if "stop_script" not in entry:
        raise HTTPException(400, "no stop_script configured for this service")
    code, output = run_script(entry, "service", "stop", script_key="stop_script")
    clear_backoff(name)
    return {"exit_code": code, "output": output[-2000:]}


@app.post("/api/services/{name}/restart")
def api_restart(name: str):
    entry = find_entry(name, "service")
    if not entry:
        raise HTTPException(404, "service not found")
    if "stop_script" not in entry:
        raise HTTPException(400, "no stop_script configured for this service")
    stop_code, stop_output = run_script(entry, "service", "stop", script_key="stop_script")
    if stop_code != 0:
        raise HTTPException(500, f"stop failed (exit {stop_code}): {stop_output[-500:]}")
    code, output = run_script(entry, "service", "start")
    clear_backoff(name)
    return {"exit_code": code, "output": output[-2000:]}


@app.post("/api/services/{name}/autostart")
def api_set_autostart(name: str, enabled: bool):
    entry = find_entry(name, "service")
    if not entry:
        raise HTTPException(404, "service not found")
    desired_state = "running" if enabled else "stopped"
    if not set_desired_state(name, desired_state):
        raise HTTPException(500, "failed to update manifest.yaml")
    return {"desired_state": desired_state}


@app.post("/api/jobs/{name}/run")
def api_run_job(name: str):
    entry = find_entry(name, "job")
    if not entry:
        raise HTTPException(404, "job not found")
    code, output = run_script(entry, "job", "run")
    return {"exit_code": code, "output": output[-2000:]}


@app.get("/api/output/{name}")
def api_output(name: str, lines: int = 200):
    entry = find_entry(name, "service")
    if not entry:
        raise HTTPException(404, "service not found")
    code, output = get_service_output(entry, lines)
    if code is None:
        raise HTTPException(400, output)
    return {"exit_code": code, "output": output}


if UI_DIST.exists():
    app.mount("/", StaticFiles(directory=str(UI_DIST), html=True), name="ui")
