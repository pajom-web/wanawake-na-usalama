#!/usr/bin/env python
"""Compatibility entry point for the single shared backend."""
import os
import sys
from pathlib import Path


SHARED_BACKEND = Path(__file__).resolve().parents[2] / "project6" / "backend"


def main() -> None:
    if not (SHARED_BACKEND / "manage.py").is_file():
        raise RuntimeError(f"Shared backend not found at {SHARED_BACKEND}")
    sys.path.insert(0, str(SHARED_BACKEND))
    os.environ["DJANGO_SETTINGS_MODULE"] = "safety_mobility.settings"
    from django.core.management import execute_from_command_line

    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
