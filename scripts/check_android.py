#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_android.py — Xem bản build mới nhất trên mọi track của Google Play
Usage: python3 scripts/check_android.py
"""

import sys
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build

PACKAGE_NAME = "com.leslie.wallyai"
TRACKS = ["internal", "alpha", "beta", "production"]
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SERVICE_ACCOUNT_FILE = PROJECT_ROOT / "service_account.json"


def check_tracks() -> None:
    print(f"🔎 [Check] {PACKAGE_NAME}", flush=True)

    if not SERVICE_ACCOUNT_FILE.exists():
        print(f"❌ Thiếu file key: {SERVICE_ACCOUNT_FILE}", flush=True)
        sys.exit(1)

    credentials = service_account.Credentials.from_service_account_file(
        str(SERVICE_ACCOUNT_FILE), scopes=SCOPES
    )
    service = build("androidpublisher", "v3", credentials=credentials)

    edit_id = service.edits().insert(body={}, packageName=PACKAGE_NAME).execute()["id"]

    print(f"{'Track':<12} {'Version':<20} {'Code':<8} {'Status':<12}", flush=True)
    print("-" * 52, flush=True)

    for track in TRACKS:
        try:
            result = service.edits().tracks().get(
                editId=edit_id, packageName=PACKAGE_NAME, track=track
            ).execute()
        except Exception as e:
            print(f"{track:<12} (lỗi: {e})", flush=True)
            continue

        releases = result.get("releases", [])
        if not releases:
            print(f"{track:<12} (chưa có release)", flush=True)
            continue

        # Latest release = first in the list (Google returns newest first)
        latest = max(releases, key=lambda r: int((r.get("versionCodes") or ["0"])[0]))
        version_codes = latest.get("versionCodes") or []
        code = version_codes[0] if version_codes else "-"
        name = latest.get("name", "-")
        status = latest.get("status", "-")
        fraction = latest.get("userFraction")
        if status == "inProgress" and fraction is not None:
            status = f"rollout {int(fraction * 100)}%"

        print(f"{track:<12} {name:<20} {code:<8} {status:<12}", flush=True)

    service.edits().delete(editId=edit_id, packageName=PACKAGE_NAME).execute()


if __name__ == "__main__":
    check_tracks()
