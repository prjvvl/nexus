from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
MANIFEST_PATH = BASE_DIR / "manifest.yaml"
STATE_DB_PATH = BASE_DIR / "state.db"
UI_DIST = BASE_DIR / "ui" / "dist"

HOST = "0.0.0.0"
PORT = 8787
