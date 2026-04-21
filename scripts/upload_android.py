#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
upload_android.py — Upload AAB lên Google Play (internal track)
Usage: python3 scripts/upload_android.py <version_name>
"""

import sys
from pathlib import Path

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

PACKAGE_NAME = "com.leslie.wallyai"
TRACK = "internal"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SERVICE_ACCOUNT_FILE = PROJECT_ROOT / "service_account.json"
AAB_PATH = PROJECT_ROOT / "build/app/outputs/bundle/release/app-release.aab"


def upload_aab(version_name: str) -> None:
    print(f"🚀 [Upload] Bắt đầu: {PACKAGE_NAME} | Ver: {version_name}", flush=True)

    if not SERVICE_ACCOUNT_FILE.exists():
        print(f"❌ Thiếu file key: {SERVICE_ACCOUNT_FILE}", flush=True)
        sys.exit(1)
    if not AAB_PATH.exists():
        print(f"❌ Không tìm thấy file AAB: {AAB_PATH}", flush=True)
        sys.exit(1)

    credentials = service_account.Credentials.from_service_account_file(
        str(SERVICE_ACCOUNT_FILE), scopes=SCOPES
    )
    service = build("androidpublisher", "v3", credentials=credentials)

    edit_id = service.edits().insert(body={}, packageName=PACKAGE_NAME).execute()["id"]

    print("⏳ [Upload] Đang đẩy file lên Google...", flush=True)
    media = MediaFileUpload(str(AAB_PATH), mimetype="application/octet-stream", resumable=True)
    bundle = service.edits().bundles().upload(
        editId=edit_id, packageName=PACKAGE_NAME, media_body=media
    ).execute()
    version_code = bundle["versionCode"]

    release_name = f"{version_code} ({version_name})"
    service.edits().tracks().update(
        editId=edit_id,
        packageName=PACKAGE_NAME,
        track=TRACK,
        body={"releases": [{"name": release_name, "versionCodes": [str(version_code)], "status": "completed"}]},
    ).execute()

    service.edits().commit(editId=edit_id, packageName=PACKAGE_NAME).execute()
    print(f"🎉 [Upload] Thành công! App: {PACKAGE_NAME} | Code: {version_code}", flush=True)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/upload_android.py <version_name>")
        sys.exit(1)
    upload_aab(sys.argv[1])
