#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
upload_ios.py — Upload IPA lên App Store Connect (TestFlight)
Sử dụng App Store Connect API Key (.p8) qua `xcrun altool`.

Usage: python3 scripts/upload_ios.py <version_name>

Yêu cầu:
  - File API Key: ios_api_key/AuthKey_<KEY_ID>.p8
  - File config:  ios_api_key/api_key_config.json
      {"key_id": "YOUR_KEY_ID", "issuer_id": "YOUR_ISSUER_ID"}
  - Xcode (xcrun) đã cài đặt.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
API_KEY_DIR = PROJECT_ROOT / "ios_api_key"
API_KEY_CONFIG = API_KEY_DIR / "api_key_config.json"
IPA_DIR = PROJECT_ROOT / "build/ios/ipa"


def load_api_key():
    if not API_KEY_CONFIG.exists():
        print(f"❌ Thiếu file cấu hình: {API_KEY_CONFIG}", flush=True)
        sys.exit(1)

    config = json.loads(API_KEY_CONFIG.read_text())
    key_id = config.get("key_id", "")
    issuer_id = config.get("issuer_id", "")
    if not key_id or not issuer_id:
        print("❌ key_id hoặc issuer_id bị thiếu trong api_key_config.json", flush=True)
        sys.exit(1)

    p8_file = API_KEY_DIR / f"AuthKey_{key_id}.p8"
    if not p8_file.exists():
        print(f"❌ Thiếu file API Key: {p8_file}", flush=True)
        sys.exit(1)

    return key_id, issuer_id


def resolve_ipa() -> Path:
    ipas = sorted(IPA_DIR.glob("*.ipa"))
    if not ipas:
        print(f"❌ Không tìm thấy file IPA trong: {IPA_DIR}", flush=True)
        sys.exit(1)
    return ipas[0]


def upload_ipa(version_name: str) -> None:
    ipa_path = resolve_ipa()
    key_id, issuer_id = load_api_key()

    print(f"🚀 [iOS Upload] Bắt đầu: {ipa_path.name} | Ver: {version_name}", flush=True)
    print(f"🔑 [iOS Upload] Sử dụng API Key: {key_id}", flush=True)

    env = os.environ.copy()
    env["API_PRIVATE_KEYS_DIR"] = str(API_KEY_DIR)

    cmd = [
        "xcrun", "altool",
        "--upload-app",
        "--type", "ios",
        "--file", str(ipa_path),
        "--apiKey", key_id,
        "--apiIssuer", issuer_id,
    ]

    print("⏳ [iOS Upload] Đang đẩy file lên App Store Connect...", flush=True)
    result = subprocess.run(cmd, env=env)

    if result.returncode != 0:
        print(f"❌ [iOS Upload] Lỗi (exit code: {result.returncode})", flush=True)
        sys.exit(result.returncode)

    print(f"🎉 [iOS Upload] Thành công! File: {ipa_path.name}", flush=True)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/upload_ios.py <version_name>")
        sys.exit(1)
    upload_ipa(sys.argv[1])
