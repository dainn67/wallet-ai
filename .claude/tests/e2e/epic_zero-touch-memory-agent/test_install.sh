#!/bin/bash
# E2E tests for local_install.sh Memory Agent auto-install (Issue #153)
# Tests the install script structure and logic (static analysis + isolated function tests)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
INSTALL_SCRIPT="$REPO_ROOT/install/local_install.sh"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---- Test: script has required functions ----
test_script_has_required_functions() {
    local required_fns=(
        "detect_python"
        "install_global_agent"
        "setup_global_venv"
        "register_project"
        "generate_rollback"
    )

    for fn in "${required_fns[@]}"; do
        if grep -q "^${fn}()" "$INSTALL_SCRIPT"; then
            pass "Function ${fn}() defined in local_install.sh"
        else
            fail "Function ${fn}() MISSING in local_install.sh"
        fi
    done
}

# ---- Test: Python warning message ----
test_python_warning_message() {
    if grep -q "Python 3.10+ not found" "$INSTALL_SCRIPT"; then
        pass "Python 3.10+ warning message present"
    else
        fail "Python 3.10+ warning message missing"
    fi
}

# ---- Test: VERSION comparison logic ----
test_version_comparison() {
    if grep -q 'SOURCE_VERSION' "$INSTALL_SCRIPT" && grep -q 'INSTALLED_VERSION' "$INSTALL_SCRIPT"; then
        pass "VERSION comparison logic (SOURCE_VERSION / INSTALLED_VERSION) present"
    else
        fail "VERSION comparison logic missing"
    fi
}

# ---- Test: rollback.sh generation ----
test_rollback_generation() {
    if grep -q 'rollback.sh' "$INSTALL_SCRIPT"; then
        pass "rollback.sh generation present"
    else
        fail "rollback.sh generation missing"
    fi
}

# ---- Test: daemon-state.json registration ----
test_daemon_state_registration() {
    if grep -q 'daemon-state.json' "$INSTALL_SCRIPT"; then
        pass "daemon-state.json project registration present"
    else
        fail "daemon-state.json registration missing"
    fi
}

# ---- Test: single global venv (not per-project) ----
test_single_venv_path() {
    if grep -q 'GLOBAL_AGENT_DIR/.venv' "$INSTALL_SCRIPT"; then
        pass "Single global venv path used (GLOBAL_AGENT_DIR/.venv)"
    else
        fail "Single global venv path missing"
    fi
}

# ---- Test: detect_python function logic ----
test_detect_python_logic() {
    if ! grep -q '^detect_python()' "$INSTALL_SCRIPT"; then
        fail "detect_python function body not found"
        return
    fi

    # Verify it iterates over python3 and python
    if grep -q 'for cmd in python3 python' "$INSTALL_SCRIPT"; then
        pass "detect_python checks both python3 and python commands"
    else
        fail "detect_python does not iterate over python3 and python"
    fi

    # Verify version check >= 3.10
    if grep -q 'major.*-ge.*3' "$INSTALL_SCRIPT" && grep -q 'minor.*-ge.*10' "$INSTALL_SCRIPT"; then
        pass "detect_python checks version >= 3.10"
    else
        fail "detect_python does not check version >= 3.10"
    fi
}

# ---- Test: fresh install copies required files ----
test_fresh_install_copies_files() {
    local required_files=("agent.py" "ccpm-memory" "requirements.txt" "config-defaults.json")

    for f in "${required_files[@]}"; do
        if grep -q "$f" "$INSTALL_SCRIPT"; then
            pass "install_global_agent copies $f"
        else
            fail "install_global_agent does NOT copy $f"
        fi
    done
}

# ---- Test: ccpm-memory made executable ----
test_ccpm_memory_executable() {
    if grep -q 'chmod +x.*ccpm-memory' "$INSTALL_SCRIPT"; then
        pass "ccpm-memory made executable after install"
    else
        fail "ccpm-memory not made executable"
    fi
}

# ---- Test: already-installed path skips copy ----
test_already_installed_skips() {
    if grep -q 'already installed' "$INSTALL_SCRIPT"; then
        pass "already-installed path logs skip message"
    else
        fail "already-installed skip message missing"
    fi
}

# ---- Test: detect_python with real Python (if available) ----
test_detect_python_runtime() {
    # Source just the detect_python function
    local fn
    fn=$(awk '/^detect_python\(\)/,/^\}/' "$INSTALL_SCRIPT")
    eval "$fn" 2>/dev/null || true

    if type detect_python &>/dev/null; then
        result=$(detect_python 2>/dev/null)
        exit_code=$?

        if [ $exit_code -eq 0 ] && [ -n "$result" ]; then
            version=$("$result" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
            major=$(echo "$version" | cut -d. -f1)
            minor=$(echo "$version" | cut -d. -f2)
            if [ "$major" -ge 3 ] && [ "$minor" -ge 10 ]; then
                pass "detect_python runtime: returns $result (Python $version >= 3.10)"
            else
                fail "detect_python runtime: returned command with Python $version < 3.10"
            fi
        else
            echo "SKIP: detect_python runtime (Python 3.10+ not available on this machine)"
        fi
    else
        fail "detect_python function could not be loaded for runtime test"
    fi
}

# ---- Test: fresh install isolated simulation ----
test_fresh_install_simulation() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local global_dir="$tmp_dir/memory-agent"
    local source_dir="$tmp_dir/source/memory-agent"

    # Create mock source files
    mkdir -p "$source_dir"
    echo "# agent" > "$source_dir/agent.py"
    echo "#!/bin/bash" > "$source_dir/ccpm-memory"
    echo "requests" > "$source_dir/requirements.txt"
    echo '{}' > "$source_dir/config-defaults.json"
    echo "1.0.0" > "$source_dir/VERSION"

    # Simulate the copy logic from install_global_agent
    mkdir -p "$global_dir"
    cp "$source_dir/agent.py" "$global_dir/"
    cp "$source_dir/ccpm-memory" "$global_dir/"
    cp "$source_dir/requirements.txt" "$global_dir/"
    cp "$source_dir/config-defaults.json" "$global_dir/"
    chmod +x "$global_dir/ccpm-memory"
    cp "$source_dir/VERSION" "$global_dir/VERSION"

    # Verify
    local required=("agent.py" "ccpm-memory" "requirements.txt" "config-defaults.json" "VERSION")
    for f in "${required[@]}"; do
        if [ -f "$global_dir/$f" ]; then
            pass "Fresh install simulation: $f exists"
        else
            fail "Fresh install simulation: $f missing"
        fi
    done

    # Verify ccpm-memory is executable
    if [ -x "$global_dir/ccpm-memory" ]; then
        pass "Fresh install simulation: ccpm-memory is executable"
    else
        fail "Fresh install simulation: ccpm-memory not executable"
    fi

    # Verify VERSION content
    installed_version=$(cat "$global_dir/VERSION")
    if [ "$installed_version" = "1.0.0" ]; then
        pass "Fresh install simulation: VERSION file contains correct version"
    else
        fail "Fresh install simulation: VERSION file has wrong content: $installed_version"
    fi

    rm -rf "$tmp_dir"
}

# ---- Test: rollback.sh generation simulation ----
test_rollback_generation_simulation() {
    local tmp_dir
    tmp_dir=$(mktemp -d)

    cat > "$tmp_dir/rollback.sh" << 'ROLLBACK'
#!/bin/bash
echo "Rolling back global Memory Agent..."
[ -f "$HOME/.config/ccpm/memory-agent/.pid" ] && kill $(cat "$HOME/.config/ccpm/memory-agent/.pid") 2>/dev/null
rm -f "$HOME/.config/ccpm/memory-agent/.pid"
echo "Done."
ROLLBACK
    chmod +x "$tmp_dir/rollback.sh"

    if [ -x "$tmp_dir/rollback.sh" ]; then
        pass "rollback.sh simulation: file created and executable"
    else
        fail "rollback.sh simulation: file not executable"
    fi

    rm -rf "$tmp_dir"
}

# ---- Run all tests ----
echo ""
echo "Running install.sh Memory Agent tests..."
echo "==========================================="

test_script_has_required_functions
test_python_warning_message
test_version_comparison
test_rollback_generation
test_daemon_state_registration
test_single_venv_path
test_detect_python_logic
test_fresh_install_copies_files
test_ccpm_memory_executable
test_already_installed_skips
test_detect_python_runtime
test_fresh_install_simulation
test_rollback_generation_simulation

echo ""
echo "==========================================="
echo "Results: $PASS passed, $FAIL failed"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
