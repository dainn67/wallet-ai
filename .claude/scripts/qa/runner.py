"""QARunner — orchestrates shell wrappers for programmatic QA pipeline.

Discovers and parses scenarios, sets up the iOS simulator, and executes
steps via the shell wrappers (axe-wrapper.sh, simctl-wrapper.sh,
evidence-capture.sh). Returns raw results for evaluation by SemanticEvaluator.
"""

from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import threading
from pathlib import Path
from typing import Any


class QARunner:
    """Runs QA scenarios by orchestrating shell wrappers."""

    def __init__(self, config_path: str = "config/qa.json") -> None:
        cfg_file = Path(config_path)
        if cfg_file.exists():
            self._config: dict = json.loads(cfg_file.read_text())
        else:
            self._config = {
                "enabled": True,
                "default_timeout": 300,
                "health_score_threshold": 70,
                "category_weights": {
                    "ui_layout": 25,
                    "navigation_flow": 25,
                    "data_display": 25,
                    "accessibility": 25,
                },
                "evidence_retention_runs": 10,
                "model": "claude-sonnet-4-6",
            }
        self._udid: str = ""

    # ------------------------------------------------------------------
    # Discovery
    # ------------------------------------------------------------------

    def discover_scenarios(self, filter_name: str | None = None) -> list[Path]:
        """Return all .md scenario files, optionally filtered by name."""
        scenario_dir = Path(".claude/qa/scenarios")
        if not scenario_dir.exists():
            return []
        paths = sorted(scenario_dir.glob("*.md"))
        if filter_name:
            paths = [p for p in paths if filter_name in p.stem]
        return paths

    # ------------------------------------------------------------------
    # Parsing
    # ------------------------------------------------------------------

    def parse_scenario(self, path: Path) -> dict:
        """Parse frontmatter + numbered steps from a scenario file.

        Returns:
            {name, screens, priority, categories, steps: [{action, target, assertion, raw_text}]}
        """
        text = path.read_text()
        # Extract frontmatter
        frontmatter: dict[str, Any] = {}
        fm_match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
        if fm_match:
            for line in fm_match.group(1).splitlines():
                if ":" in line:
                    k, _, v = line.partition(":")
                    raw_v = v.strip()
                    # Simple YAML list parsing: [a, b, c]
                    if raw_v.startswith("[") and raw_v.endswith("]"):
                        items = [i.strip().strip('"\'') for i in raw_v[1:-1].split(",")]
                        frontmatter[k.strip()] = [i for i in items if i]
                    else:
                        frontmatter[k.strip()] = raw_v

        # Parse numbered steps (lines starting with a digit and dot/period)
        steps: list[dict] = []
        for line in text.splitlines():
            m = re.match(r"^\d+\.\s+(.+)", line)
            if not m:
                continue
            raw = m.group(1).strip()
            if " → " in raw:
                action_part, _, assertion_part = raw.partition(" → ")
            else:
                action_part = raw
                assertion_part = raw

            action_type = _detect_action(action_part)
            target = _extract_quoted(action_part)

            steps.append(
                {
                    "action": action_type,
                    "target": target,
                    "assertion": assertion_part,
                    "raw_text": raw,
                }
            )

        return {
            "name": frontmatter.get("name", path.stem),
            "screens": frontmatter.get("screens", []),
            "priority": frontmatter.get("priority", "P2"),
            "categories": frontmatter.get("categories", []),
            "steps": steps,
            "path": str(path),
        }

    # ------------------------------------------------------------------
    # Simulator setup
    # ------------------------------------------------------------------

    def setup_simulator(self) -> dict:
        """Auto-detect booted simulator via simctl-wrapper.sh.

        Returns parsed JSON response from simctl_auto_detect.
        """
        result = _bash("source scripts/qa/simctl-wrapper.sh && simctl_auto_detect")
        if result.get("success"):
            self._udid = (result.get("data") or {}).get("udid", "")
        return result

    # ------------------------------------------------------------------
    # Step execution
    # ------------------------------------------------------------------

    def execute_step(self, run_id: str, step_n: int, step: dict) -> dict:
        """Execute one scenario step and collect evidence.

        Returns:
            {"action_result": {...}, "evidence": {"tree_path": ..., "screenshot_path": ...}}
        """
        action = step["action"]
        target = step.get("target", "")
        udid = self._udid

        action_result: dict
        if action == "launch":
            # No shell action — app already running
            action_result = {"success": True, "data": None, "error": None}
        elif action == "tap":
            cmd = (
                f"source scripts/qa/axe-wrapper.sh && "
                f"axe_tap '{target}' '{udid}'"
            )
            action_result = _bash(cmd)
        elif action == "type":
            cmd = (
                f"source scripts/qa/axe-wrapper.sh && "
                f"axe_type '{target}' '{udid}'"
            )
            action_result = _bash(cmd)
        elif action == "swipe":
            cmd = (
                f"source scripts/qa/axe-wrapper.sh && "
                f"axe_swipe '{target}' '{udid}'"
            )
            action_result = _bash(cmd)
        else:  # verify or unknown — capture state only
            action_result = {"success": True, "data": None, "error": None}

        # Collect evidence
        evidence = self._capture_evidence(run_id, step_n, action, target, udid)
        return {"action_result": action_result, "evidence": evidence}

    def _capture_evidence(
        self, run_id: str, step_n: int, action: str, target: str, udid: str
    ) -> dict:
        """Call evidence-capture.sh to gather screenshot + accessibility tree.

        Returns paths to captured files.
        """
        evidence_dir = Path(f".claude/qa/evidence/{run_id}/step-{step_n:03d}")
        evidence_dir.mkdir(parents=True, exist_ok=True)

        if action in ("tap", "type", "swipe"):
            cmd = (
                f"source scripts/qa/evidence-capture.sh && "
                f"capture_before_after '{run_id}' '{step_n}' '{action}' '{target}' '{udid}'"
            )
            result = _bash(cmd)
            data = result.get("data") or {}
            return {
                "tree_path": str(evidence_dir / "after-accessibility-tree.json"),
                "screenshot_path": str(evidence_dir / "after-screenshot.png"),
                "raw": data,
            }
        else:
            cmd = (
                f"source scripts/qa/evidence-capture.sh && "
                f"capture_step_evidence '{run_id}' '{step_n}' 'axe' '{udid}'"
            )
            result = _bash(cmd)
            data = result.get("data") or {}
            return {
                "tree_path": str(evidence_dir / "accessibility-tree.json"),
                "screenshot_path": str(evidence_dir / "screenshot.png"),
                "raw": data,
            }

    # ------------------------------------------------------------------
    # Main run
    # ------------------------------------------------------------------

    def run(
        self,
        scenario_filter: str | None = None,
        timeout: int = 300,
    ) -> dict:
        """Discover → Parse → Setup → Execute all scenarios.

        Returns:
            {
                "scenarios": [{...scenario with executed steps...}],
                "timeout": bool,
                "error": str | None,
            }
        """
        result: dict = {"scenarios": [], "timeout": False, "error": None}
        timed_out = threading.Event()

        def _on_timeout() -> None:
            timed_out.set()

        timer = threading.Timer(timeout, _on_timeout)
        timer.start()

        try:
            # Discover
            paths = self.discover_scenarios(scenario_filter)
            if not paths:
                return result

            # Parse
            scenarios: list[dict] = []
            for path in paths:
                try:
                    s = self.parse_scenario(path)
                    scenarios.append(s)
                except Exception as exc:  # noqa: BLE001
                    scenarios.append(
                        {
                            "name": path.stem,
                            "error": f"Parse error: {exc}",
                            "steps": [],
                            "categories": [],
                        }
                    )

            # Setup simulator (best-effort)
            sim_result = self.setup_simulator()
            if not sim_result.get("success"):
                result["error"] = (
                    f"Simulator not available: {sim_result.get('error', 'unknown')}"
                )
                # Still return parsed scenarios so evaluator can mark as UNCERTAIN

            # Execute steps
            import datetime

            run_id = datetime.datetime.utcnow().strftime("%Y%m%d-%H%M%S")

            for scenario in scenarios:
                if timed_out.is_set():
                    result["timeout"] = True
                    break
                executed_steps: list[dict] = []
                for i, step in enumerate(scenario.get("steps", []), start=1):
                    if timed_out.is_set():
                        result["timeout"] = True
                        break
                    try:
                        step_result = self.execute_step(run_id, i, step)
                    except Exception as exc:  # noqa: BLE001
                        step_result = {
                            "action_result": {
                                "success": False,
                                "error": str(exc),
                                "data": None,
                            },
                            "evidence": {
                                "tree_path": None,
                                "screenshot_path": None,
                            },
                        }
                    executed_steps.append({**step, **step_result})

                scenario["executed_steps"] = executed_steps

            result["scenarios"] = scenarios
            result["run_id"] = run_id
        finally:
            timer.cancel()

        return result


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _bash(cmd: str, timeout: int = 30) -> dict:
    """Run a bash command and parse its JSON stdout."""
    try:
        proc = subprocess.run(
            ["bash", "-c", cmd],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        stdout = proc.stdout.strip()
        if stdout:
            return json.loads(stdout)
        return {"success": False, "error": proc.stderr.strip() or "no output", "data": None}
    except subprocess.TimeoutExpired:
        return {"success": False, "error": f"Command timed out after {timeout}s", "data": None}
    except json.JSONDecodeError as exc:
        return {"success": False, "error": f"JSON parse error: {exc}", "data": None}
    except Exception as exc:  # noqa: BLE001
        return {"success": False, "error": str(exc), "data": None}


def _detect_action(action_part: str) -> str:
    """Detect action type from a step's action text."""
    lower = action_part.lower()
    if any(kw in lower for kw in ("mở", "launch", "open")):
        return "launch"
    if any(kw in lower for kw in ("chọn", "select", "tap", "nhấn")):
        return "tap"
    if any(kw in lower for kw in ("vuốt", "swipe")):
        return "swipe"
    if "type" in lower:
        return "type"
    if any(kw in lower for kw in ("kiểm tra", "verify", "check")):
        return "verify"
    return "verify"


def _extract_quoted(text: str) -> str:
    """Extract first single-quoted string from text."""
    m = re.search(r"'([^']+)'", text)
    return m.group(1) if m else text
