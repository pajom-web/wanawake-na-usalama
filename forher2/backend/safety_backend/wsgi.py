"""Compatibility WSGI entry point for the single shared backend."""

import sys
from pathlib import Path

SHARED_BACKEND = Path(__file__).resolve().parents[3] / "project6" / "backend"
if not (SHARED_BACKEND / "safety_mobility" / "wsgi.py").is_file():
    raise RuntimeError(f"Shared backend not found at {SHARED_BACKEND}")
sys.path.insert(0, str(SHARED_BACKEND))

from safety_mobility.wsgi import application  # noqa: E402,F401
