"""SQLite-backed run history, current status, and restart bookkeeping."""
import sqlite3
from datetime import datetime, timezone

from .config import STATE_DB_PATH


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(STATE_DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def _ensure_column(conn: sqlite3.Connection, table: str, column: str, ddl: str) -> None:
    existing = {row["name"] for row in conn.execute(f"PRAGMA table_info({table})")}
    if column not in existing:
        conn.execute(f"ALTER TABLE {table} ADD COLUMN {ddl}")


def _ensure_composite_key(conn: sqlite3.Connection) -> None:
    """Migrates `current_state` from a single-column `name` primary key to a
    composite `(name, kind)` key: a service and a job sharing the same name
    used to collide into one row, each stomping the other's status. No-ops
    once already migrated (fresh installs get the composite key from the
    CREATE TABLE above and skip this)."""
    info = list(conn.execute("PRAGMA table_info(current_state)"))
    pk_cols = {row["name"] for row in info if row["pk"] > 0}
    if pk_cols == {"name", "kind"}:
        return
    # Rebuild with whatever columns already exist (base schema or one that's
    # already picked up the backoff columns below) - only the key changes.
    col_defs = []
    for row in info:
        notnull = " NOT NULL" if row["notnull"] else ""
        default = f" DEFAULT {row['dflt_value']}" if row["dflt_value"] is not None else ""
        col_defs.append(f"{row['name']} {row['type'] or 'TEXT'}{notnull}{default}")
    col_list = ", ".join(row["name"] for row in info)
    conn.executescript(
        f"""
        ALTER TABLE current_state RENAME TO current_state_old;
        CREATE TABLE current_state (
            {', '.join(col_defs)},
            PRIMARY KEY (name, kind)
        );
        INSERT INTO current_state ({col_list}) SELECT {col_list} FROM current_state_old;
        DROP TABLE current_state_old;
        """
    )


def init_db() -> None:
    conn = get_db()
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS runs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            action TEXT NOT NULL,
            started_at TEXT NOT NULL,
            finished_at TEXT,
            exit_code INTEGER,
            output TEXT
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS current_state (
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            status TEXT NOT NULL,
            last_action TEXT,
            last_run_at TEXT,
            PRIMARY KEY (name, kind)
        )
        """
    )
    _ensure_composite_key(conn)
    # Restart-backoff bookkeeping, added after the initial schema - applied as a
    # migration so existing deployments keep their run history.
    _ensure_column(conn, "current_state", "fail_count", "fail_count INTEGER DEFAULT 0")
    _ensure_column(conn, "current_state", "next_retry_at", "next_retry_at TEXT")
    _ensure_column(conn, "current_state", "alive_since", "alive_since TEXT")
    conn.commit()
    conn.close()


def record_run_start(name: str, kind: str, action: str) -> int:
    conn = get_db()
    cur = conn.execute(
        "INSERT INTO runs (name, kind, action, started_at) VALUES (?, ?, ?, ?)",
        (name, kind, action, now_iso()),
    )
    conn.commit()
    run_id = cur.lastrowid
    conn.close()
    return run_id


def record_run_finish(run_id: int, exit_code: int, output: str) -> None:
    conn = get_db()
    conn.execute(
        "UPDATE runs SET finished_at = ?, exit_code = ?, output = ? WHERE id = ?",
        (now_iso(), exit_code, output[-4000:], run_id),
    )
    conn.commit()
    conn.close()


def upsert_current_state(name: str, kind: str, status: str, action: str) -> None:
    conn = get_db()
    conn.execute(
        """
        INSERT INTO current_state (name, kind, status, last_action, last_run_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(name, kind) DO UPDATE SET
            status = excluded.status,
            last_action = excluded.last_action,
            last_run_at = excluded.last_run_at
        """,
        (name, kind, status, action, now_iso()),
    )
    conn.commit()
    conn.close()


def get_current_states(kind: str) -> dict:
    conn = get_db()
    rows = conn.execute(
        "SELECT * FROM current_state WHERE kind = ?", (kind,)
    ).fetchall()
    conn.close()
    return {row["name"]: dict(row) for row in rows}


# ------------------------------------------------------- restart backoff --
# Backoff is a service-only concept (jobs don't crash-restart), so these
# always scope to kind='service' - otherwise a job sharing a service's name
# could match the wrong row.

def get_backoff(name: str) -> dict:
    conn = get_db()
    row = conn.execute(
        "SELECT fail_count, next_retry_at, alive_since FROM current_state WHERE name = ? AND kind = 'service'",
        (name,),
    ).fetchone()
    conn.close()
    if not row:
        return {"fail_count": 0, "next_retry_at": None, "alive_since": None}
    return dict(row)


_UNSET = object()


def set_backoff(name: str, *, fail_count=_UNSET, next_retry_at=_UNSET, alive_since=_UNSET) -> None:
    """Updates only the backoff fields explicitly passed (each may be set to None
    on purpose, e.g. to clear next_retry_at, so a sentinel marks "not passed")."""
    conn = get_db()
    fields, values = [], []
    if fail_count is not _UNSET:
        fields.append("fail_count = ?")
        values.append(fail_count)
    if next_retry_at is not _UNSET:
        fields.append("next_retry_at = ?")
        values.append(next_retry_at)
    if alive_since is not _UNSET:
        fields.append("alive_since = ?")
        values.append(alive_since)
    if fields:
        values.append(name)
        conn.execute(
            f"UPDATE current_state SET {', '.join(fields)} WHERE name = ? AND kind = 'service'", values
        )
        conn.commit()
    conn.close()


def clear_backoff(name: str) -> None:
    conn = get_db()
    conn.execute(
        "UPDATE current_state SET fail_count = 0, next_retry_at = NULL, alive_since = NULL "
        "WHERE name = ? AND kind = 'service'",
        (name,),
    )
    conn.commit()
    conn.close()


# --------------------------------------------------------------- pruning --

def prune_old_runs(keep_per_name: int = 200) -> int:
    """Keeps only the most recent `keep_per_name` run records per name. Returns rows deleted."""
    conn = get_db()
    cur = conn.execute(
        """
        DELETE FROM runs
        WHERE id IN (
            SELECT id FROM (
                SELECT id, ROW_NUMBER() OVER (
                    PARTITION BY name ORDER BY id DESC
                ) AS rn
                FROM runs
            )
            WHERE rn > ?
        )
        """,
        (keep_per_name,),
    )
    conn.commit()
    deleted = cur.rowcount
    conn.close()
    return deleted
