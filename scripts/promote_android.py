#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
promote_android.py — Đẩy một build từ track internal lên production
Usage: python3 scripts/promote_android.py <version_code> [rollout_fraction]
  version_code      : số build cần promote (vd: 22)
  rollout_fraction  : tỉ lệ staged rollout 0.0–1.0 (mặc định 1.0 = completed)
"""

import sys
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build

PACKAGE_NAME = "com.leslie.wallyai"
SOURCE_TRACK = "internal"
TARGET_TRACK = "production"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SERVICE_ACCOUNT_FILE = PROJECT_ROOT / "service_account.json"


def promote(version_code: str, rollout: float) -> None:
    print(
        f"🚀 [Promote] {PACKAGE_NAME} | Code: {version_code} "
        f"| {SOURCE_TRACK} → {TARGET_TRACK} | rollout: {int(rollout * 100)}%",
        flush=True,
    )

    if not SERVICE_ACCOUNT_FILE.exists():
        print(f"❌ Thiếu file key: {SERVICE_ACCOUNT_FILE}", flush=True)
        sys.exit(1)
    if not 0 < rollout <= 1:
        print("❌ rollout_fraction phải nằm trong khoảng (0, 1]", flush=True)
        sys.exit(1)

    credentials = service_account.Credentials.from_service_account_file(
        str(SERVICE_ACCOUNT_FILE), scopes=SCOPES
    )
    service = build("androidpublisher", "v3", credentials=credentials)

    edit_id = service.edits().insert(body={}, packageName=PACKAGE_NAME).execute()["id"]

    source = service.edits().tracks().get(
        editId=edit_id, packageName=PACKAGE_NAME, track=SOURCE_TRACK
    ).execute()

    match = next(
        (r for r in source.get("releases", []) if version_code in (r.get("versionCodes") or [])),
        None,
    )
    if not match:
        print(f"❌ Không tìm thấy version code {version_code} trên track {SOURCE_TRACK}", flush=True)
        sys.exit(1)

    release_name = match.get("name", version_code)
    release = {
        "name": release_name,
        "versionCodes": [version_code],
        "releaseNotes": match.get("releaseNotes", []),
    }
    if rollout >= 1:
        release["status"] = "completed"
    else:
        release["status"] = "inProgress"
        release["userFraction"] = rollout

    service.edits().tracks().update(
        editId=edit_id,
        packageName=PACKAGE_NAME,
        track=TARGET_TRACK,
        body={"releases": [release]},
    ).execute()

    service.edits().commit(editId=edit_id, packageName=PACKAGE_NAME).execute()
    print(
        f"🎉 [Promote] Thành công! {release_name} đã lên {TARGET_TRACK} "
        f"({'completed' if rollout >= 1 else f'rollout {int(rollout * 100)}%'})",
        flush=True,
    )


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/promote_android.py <version_code> [rollout_fraction]")
        sys.exit(1)
    code = sys.argv[1]
    frac = float(sys.argv[2]) if len(sys.argv) >= 3 else 1.0
    promote(code, frac)
