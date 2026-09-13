"""Loads and edits manifest.yaml (services + jobs).

Uses ruamel.yaml's round-trip mode so that toggling a field (e.g. autostart)
from the API preserves the file's comments and formatting instead of
clobbering them, since manifest.yaml is meant to be hand-edited too.

A fresh YAML() instance is created per call rather than shared at module
level: ruamel's YAML object is not thread-safe, and load_manifest() is
called concurrently from FastAPI's request threadpool and the reconciler's
background thread. Sharing one instance let concurrent calls corrupt each
other's internal parser buffer, producing an intermittent IndexError.
"""
import os
import tempfile

from ruamel.yaml import YAML

from .config import MANIFEST_PATH


def _make_yaml() -> YAML:
    y = YAML()
    y.preserve_quotes = True
    y.indent(mapping=2, sequence=4, offset=2)
    return y


def load_manifest() -> tuple[list, list]:
    with open(MANIFEST_PATH) as f:
        data = _make_yaml().load(f) or {}
    return data.get("services") or [], data.get("jobs") or []


def validate_manifest(services: list, jobs: list) -> None:
    """Fails fast with a clear message on a malformed manifest.yaml, instead of
    letting a missing field surface as a raw KeyError from deep inside startup
    scheduling - and rejects a name reused across a service and a job, since
    Nexus's state storage assumes names are unique regardless of kind."""
    seen: dict[str, str] = {}
    for kind, entries, required in (
        ("service", services, ("name", "script")),
        ("job", jobs, ("name", "script", "schedule")),
    ):
        for i, entry in enumerate(entries):
            missing = [f for f in required if f not in entry]
            if missing:
                raise SystemExit(
                    f"manifest.yaml: {kind} #{i + 1} is missing required field(s) {missing}: {entry}"
                )
            name = entry["name"]
            if name in seen:
                raise SystemExit(
                    f"manifest.yaml: name {name!r} is used by both a {seen[name]} and a {kind} "
                    "- names must be unique across services and jobs"
                )
            seen[name] = kind


def find_entry(name: str, kind: str):
    services, jobs = load_manifest()
    for entry in (services if kind == "service" else jobs):
        if entry["name"] == name:
            return entry
    return None


def _write_atomic(data) -> None:
    """Writes via a temp file + rename so concurrent readers (the reconciler's
    background thread, other requests) never observe a partially-written file."""
    fd, tmp_path = tempfile.mkstemp(dir=MANIFEST_PATH.parent, prefix=".manifest-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            _make_yaml().dump(data, f)
        os.replace(tmp_path, MANIFEST_PATH)
    except Exception:
        os.unlink(tmp_path)
        raise


def set_desired_state(name: str, desired_state: str) -> bool:
    """Persists an autostart on/off toggle by editing manifest.yaml in place."""
    with open(MANIFEST_PATH) as f:
        data = _make_yaml().load(f) or {}
    for svc in data.get("services") or []:
        if svc.get("name") == name:
            svc["desired_state"] = desired_state
            _write_atomic(data)
            return True
    return False
