#!/bin/bash
# simctl Wrapper — normalizes xcrun simctl output to standardized JSON API
# AD-3: Shell Wrapper Convention as Adapter Interface
# Usage: source this file and call the functions
# Requires: xcrun simctl (Xcode Command Line Tools)
set -euo pipefail

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# _simctl_json_response <success: true|false> <error: string|null> <data: json|null>
_simctl_json_response() {
  local success="$1"
  local error="$2"
  local data="$3"

  if [ "$error" = "null" ]; then
    printf '{"success":%s,"error":null,"data":%s}\n' "$success" "$data"
  else
    local escaped_error
    escaped_error=$(printf '%s' "$error" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')
    printf '{"success":%s,"error":"%s","data":%s}\n' "$success" "$escaped_error" "$data"
  fi
}

# _check_simctl — verifies xcrun simctl is available
_check_simctl() {
  if ! command -v xcrun &>/dev/null; then
    _simctl_json_response false "xcrun not found. Install Xcode Command Line Tools: xcode-select --install" null
    return 1
  fi
  if ! xcrun simctl help &>/dev/null 2>&1; then
    _simctl_json_response false "xcrun simctl unavailable. Verify Xcode installation." null
    return 1
  fi
  return 0
}

# _build_device_json <udid> <name> <state> <os_version>
# Outputs a single device JSON object.
_build_device_json() {
  local udid="$1"
  local name="$2"
  local state="$3"
  local os_version="$4"
  # Escape values for JSON safety
  name=$(printf '%s' "$name" | sed 's/"/\\"/g')
  os_version=$(printf '%s' "$os_version" | sed 's/"/\\"/g')
  printf '{"udid":"%s","name":"%s","state":"%s","os_version":"%s"}' \
    "$udid" "$name" "$state" "$os_version"
}

# ---------------------------------------------------------------------------
# Public wrapper functions
# ---------------------------------------------------------------------------

# simctl_list_booted
# Lists all booted simulators as a JSON array.
# Returns: {"success": true, "data": [{"udid": "...", "name": "...", "state": "Booted", "os_version": "..."}]}
simctl_list_booted() {
  _check_simctl || return 0

  local raw_json exit_code
  raw_json=$(xcrun simctl list devices booted -j 2>&1) && exit_code=0 || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    _simctl_json_response false "$raw_json" null
    return 0
  fi

  # Parse JSON: extract devices across all runtime keys where state=="Booted"
  local devices_json py_exit
  devices_json=$(printf '%s' "$raw_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
devices = []
for runtime_key, device_list in data.get('devices', {}).items():
    for dev in device_list:
        if dev.get('state') == 'Booted':
            os_version = runtime_key.replace('com.apple.CoreSimulator.SimRuntime.', '').replace('-', ' ').replace('iOS ', 'iOS ')
            devices.append({
                'udid': dev.get('udid', ''),
                'name': dev.get('name', ''),
                'state': dev.get('state', ''),
                'os_version': os_version
            })
print(json.dumps(devices))
" 2>&1)
  py_exit=$?

  if [ "$py_exit" -ne 0 ]; then
    _simctl_json_response false "Failed to parse simctl JSON output: $devices_json" null
    return 0
  fi

  printf '{"success":true,"error":null,"data":%s}\n' "$devices_json"
}

# simctl_boot <device_id>
# Boots the specified simulator by UDID.
# Returns: {"success": true, "data": {"udid": "..."}}
simctl_boot() {
  local device_id="${1:-}"

  _check_simctl || return 0

  if [ -z "$device_id" ]; then
    _simctl_json_response false "device_id argument is required" null
    return 0
  fi

  local raw_output exit_code
  raw_output=$(xcrun simctl boot "$device_id" 2>&1) && exit_code=0 || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    # "already booted" is not a real error
    if printf '%s' "$raw_output" | grep -qi "already booted"; then
      _simctl_json_response true null "{\"udid\":\"$device_id\",\"status\":\"already_booted\"}"
      return 0
    fi
    _simctl_json_response false "$raw_output" null
    return 0
  fi

  _simctl_json_response true null "{\"udid\":\"$device_id\",\"status\":\"booted\"}"
}

# simctl_auto_detect
# Finds a booted simulator. If none is booted, locates the most recent available
# device and boots it. Returns the device info.
# Returns: {"success": true, "data": {"udid": "...", "name": "...", "state": "Booted", "os_version": "..."}}
simctl_auto_detect() {
  _check_simctl || return 0

  # Step 1: Check for already-booted simulators
  local booted_json exit_code
  booted_json=$(xcrun simctl list devices booted -j 2>&1) && exit_code=0 || exit_code=$?

  if [ $exit_code -eq 0 ]; then
    local first_booted
    first_booted=$(printf '%s' "$booted_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for runtime_key, device_list in data.get('devices', {}).items():
    for dev in device_list:
        if dev.get('state') == 'Booted':
            os_version = runtime_key.replace('com.apple.CoreSimulator.SimRuntime.', '').replace('-', ' ')
            print(json.dumps({'udid': dev['udid'], 'name': dev['name'], 'state': 'Booted', 'os_version': os_version}))
            sys.exit(0)
" 2>/dev/null)

    if [ -n "$first_booted" ]; then
      printf '{"success":true,"error":null,"data":%s}\n' "$first_booted"
      return 0
    fi
  fi

  # Step 2: No booted device — find most recent available device and boot it
  local all_json
  all_json=$(xcrun simctl list devices available -j 2>&1) && exit_code=0 || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    _simctl_json_response false "Could not list available simulators: $all_json" null
    return 0
  fi

  local best_device
  best_device=$(printf '%s' "$all_json" | python3 -c "
import sys, json, re
data = json.load(sys.stdin)
best = None
best_version = (0, 0)
for runtime_key, device_list in data.get('devices', {}).items():
    # Extract version number from runtime key (e.g. iOS-18-4 -> (18, 4))
    m = re.search(r'iOS-(\d+)-(\d+)', runtime_key)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    os_label = 'iOS {}.{}'.format(m.group(1), m.group(2))
    for dev in device_list:
        if dev.get('isAvailable', False) and dev.get('state') != 'Booted':
            if version > best_version:
                best_version = version
                best = {'udid': dev['udid'], 'name': dev['name'], 'state': dev['state'], 'os_version': os_label}
if best:
    print(json.dumps(best))
" 2>/dev/null)

  if [ -z "$best_device" ]; then
    _simctl_json_response false "No available iOS simulators found. Open Xcode and create a simulator." null
    return 0
  fi

  local udid
  udid=$(printf '%s' "$best_device" | python3 -c "import sys,json; print(json.load(sys.stdin)['udid'])")

  # Boot the selected device
  xcrun simctl boot "$udid" 2>&1 || true  # "already booted" error is acceptable

  # Return device info with Booted state
  local final_device
  final_device=$(printf '%s' "$best_device" | python3 -c "
import sys, json
d = json.load(sys.stdin)
d['state'] = 'Booted'
print(json.dumps(d))
")

  printf '{"success":true,"error":null,"data":%s}\n' "$final_device"
}

# simctl_check_app <bundle_id> [udid]
# Verifies the app is running on the booted simulator.
# Returns: {"success": true, "data": {"bundle_id": "...", "running": true|false, "pid": N|null}}
simctl_check_app() {
  local bundle_id="${1:-}"
  local udid="${2:-}"

  _check_simctl || return 0

  if [ -z "$bundle_id" ]; then
    _simctl_json_response false "bundle_id argument is required" null
    return 0
  fi

  if [ -z "$udid" ]; then
    # Try to find a booted simulator
    udid=$(xcrun simctl list devices booted 2>/dev/null \
      | grep -E '^\s+.+\(.+\) \(Booted\)' \
      | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/' \
      | head -1)
    if [ -z "$udid" ]; then
      _simctl_json_response false "No booted simulator found. Run simctl_auto_detect first." null
      return 0
    fi
  fi

  # Use simctl get_app_container to check if app is installed/running
  local exit_code
  xcrun simctl get_app_container "$udid" "$bundle_id" >/dev/null 2>&1 && exit_code=0 || exit_code=$?

  if [ $exit_code -ne 0 ]; then
    # App not installed or not found
    _simctl_json_response true null "{\"bundle_id\":\"$bundle_id\",\"running\":false,\"pid\":null}"
    return 0
  fi

  # Check if process is actually running via simctl spawn ps
  local pid
  pid=$(xcrun simctl spawn "$udid" pgrep -f "$bundle_id" 2>/dev/null | head -1 || echo "")

  if [ -n "$pid" ]; then
    _simctl_json_response true null "{\"bundle_id\":\"$bundle_id\",\"running\":true,\"pid\":$pid}"
  else
    _simctl_json_response true null "{\"bundle_id\":\"$bundle_id\",\"running\":false,\"pid\":null}"
  fi
}
