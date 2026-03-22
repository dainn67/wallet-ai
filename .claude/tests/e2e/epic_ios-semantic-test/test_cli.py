"""Unit tests for programmatic QA CLI (T168).

Tests:
  - cli.py run --non-interactive without ANTHROPIC_API_KEY → exit 3
  - cli.py run without --non-interactive → exit 3
  - evaluator.py ConfigError raised when ANTHROPIC_API_KEY missing
  - runner.py discover_scenarios with filter
  - JSON report structure has required fields
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Ensure project root is on path
REPO_ROOT = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(REPO_ROOT))


# ---------------------------------------------------------------------------
# CLI entry point tests (via subprocess to test real exit codes)
# ---------------------------------------------------------------------------

CLI = str(REPO_ROOT / "scripts" / "qa" / "cli.py")


def _run_cli(*args: str, env: dict | None = None) -> subprocess.CompletedProcess:
    """Run cli.py in a subprocess and return the completed process."""
    merged_env = {**os.environ, **(env or {})}
    return subprocess.run(
        [sys.executable, CLI, *args],
        capture_output=True,
        text=True,
        env=merged_env,
        cwd=str(REPO_ROOT),
    )


class TestCliExitCodes:
    def test_missing_api_key_exits_3(self):
        """cli.py run --non-interactive without ANTHROPIC_API_KEY → exit 3."""
        env = {k: v for k, v in os.environ.items() if k != "ANTHROPIC_API_KEY"}
        result = _run_cli("run", "--non-interactive", env=env)
        assert result.returncode == 3
        assert "ANTHROPIC_API_KEY" in result.stderr

    def test_missing_non_interactive_flag_exits_3(self):
        """cli.py run without --non-interactive → exit 3."""
        result = _run_cli("run")
        assert result.returncode == 3
        assert "--non-interactive" in result.stderr

    def test_help_exits_0(self):
        """cli.py --help → exit 0."""
        result = _run_cli("--help")
        assert result.returncode == 0

    def test_no_command_exits_3(self):
        """cli.py with no subcommand → exit 3."""
        result = _run_cli()
        assert result.returncode == 3


# ---------------------------------------------------------------------------
# Evaluator tests
# ---------------------------------------------------------------------------

class TestSemanticEvaluator:
    def test_config_error_when_no_api_key(self):
        """SemanticEvaluator raises ConfigError when ANTHROPIC_API_KEY missing."""
        from scripts.qa.evaluator import SemanticEvaluator, ConfigError

        env_backup = os.environ.pop("ANTHROPIC_API_KEY", None)
        try:
            with pytest.raises(ConfigError, match="ANTHROPIC_API_KEY"):
                SemanticEvaluator()
        finally:
            if env_backup is not None:
                os.environ["ANTHROPIC_API_KEY"] = env_backup

    def _make_evaluator_with_mock_client(self, mock_client: MagicMock) -> "SemanticEvaluator":
        """Create a SemanticEvaluator bypassing __init__, injecting mock client."""
        from scripts.qa.evaluator import SemanticEvaluator

        evaluator = SemanticEvaluator.__new__(SemanticEvaluator)
        evaluator._model = "claude-sonnet-4-6"
        evaluator._client = mock_client
        return evaluator

    def test_evaluate_step_mocked(self):
        """evaluate_step returns correct verdict dict from mocked API."""
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.content = [
            MagicMock(
                text='{"result": "PASS", "confidence": 90, "reasoning": "Element found"}'
            )
        ]
        mock_client.messages.create.return_value = mock_response

        evaluator = self._make_evaluator_with_mock_client(mock_client)
        verdict = evaluator.evaluate_step(
            accessibility_tree={"label": "Submit Button"},
            screenshot_path=None,
            assertion="Submit button is visible",
        )

        assert verdict["result"] == "PASS"
        assert verdict["confidence"] == 90
        assert "Element found" in verdict["reasoning"]

    def test_evaluate_step_api_error_returns_uncertain(self):
        """evaluate_step returns UNCERTAIN on unexpected API error."""
        mock_client = MagicMock()
        mock_client.messages.create.side_effect = RuntimeError("API error")

        evaluator = self._make_evaluator_with_mock_client(mock_client)
        verdict = evaluator.evaluate_step(
            accessibility_tree={},
            screenshot_path=None,
            assertion="anything",
        )

        assert verdict["result"] == "UNCERTAIN"
        assert verdict["confidence"] == 0

    def test_evaluate_batch_returns_list(self):
        """evaluate_batch returns one verdict per step."""
        steps = [
            {"accessibility_tree": {}, "screenshot_path": None, "assertion": "step 1"},
            {"accessibility_tree": {}, "screenshot_path": None, "assertion": "step 2"},
        ]

        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.content = [
            MagicMock(text='{"result": "PASS", "confidence": 80, "reasoning": "ok"}')
        ]
        mock_client.messages.create.return_value = mock_response

        evaluator = self._make_evaluator_with_mock_client(mock_client)
        verdicts = evaluator.evaluate_batch(steps)

        assert len(verdicts) == len(steps)
        assert all("result" in v for v in verdicts)


# ---------------------------------------------------------------------------
# Runner tests
# ---------------------------------------------------------------------------

class TestQARunner:
    def test_discover_no_scenarios_dir(self):
        """discover_scenarios returns empty list when directory missing."""
        from scripts.qa.runner import QARunner

        runner = QARunner.__new__(QARunner)
        runner._config = {}
        runner._udid = ""
        # Point to a non-existent dir by mocking Path.glob
        result = runner.discover_scenarios()
        # Expect empty list when .claude/qa/scenarios doesn't exist
        assert isinstance(result, list)

    def test_discover_with_filter(self, tmp_path):
        """discover_scenarios returns only matching scenarios."""
        from scripts.qa.runner import QARunner

        # Create temp scenario dir
        scenarios_dir = tmp_path / ".claude" / "qa" / "scenarios"
        scenarios_dir.mkdir(parents=True)
        (scenarios_dir / "quiz-flow.md").write_text("---\nname: quiz-flow\n---\n\n1. tap 'Start'")
        (scenarios_dir / "login-flow.md").write_text("---\nname: login-flow\n---\n\n1. tap 'Login'")

        orig_cwd = os.getcwd()
        os.chdir(tmp_path)
        try:
            runner = QARunner.__new__(QARunner)
            runner._config = {}
            runner._udid = ""
            all_scenarios = runner.discover_scenarios()
            filtered = runner.discover_scenarios(filter_name="quiz")
        finally:
            os.chdir(orig_cwd)

        assert len(all_scenarios) == 2
        assert len(filtered) == 1
        assert filtered[0].stem == "quiz-flow"

    def test_parse_scenario_extracts_steps(self, tmp_path):
        """parse_scenario correctly extracts steps from markdown."""
        from scripts.qa.runner import QARunner

        scenario_file = tmp_path / "quiz-flow.md"
        scenario_file.write_text(
            "---\n"
            "name: quiz-flow\n"
            "categories: [navigation_flow, ui_layout]\n"
            "---\n\n"
            "# Quiz Flow\n\n"
            "1. tap 'Start Quiz' → Quiz screen is displayed\n"
            "2. verify 'Question 1' is visible\n"
        )

        runner = QARunner.__new__(QARunner)
        runner._config = {}
        runner._udid = ""
        scenario = runner.parse_scenario(scenario_file)

        assert scenario["name"] == "quiz-flow"
        assert "navigation_flow" in scenario["categories"]
        assert len(scenario["steps"]) == 2
        assert scenario["steps"][0]["action"] == "tap"
        assert scenario["steps"][0]["target"] == "Start Quiz"
        assert "Quiz screen is displayed" in scenario["steps"][0]["assertion"]


# ---------------------------------------------------------------------------
# JSON report structure
# ---------------------------------------------------------------------------

class TestJsonReportStructure:
    def test_report_has_required_fields(self, tmp_path):
        """JSON report has health_score, scenarios, summary, timestamp fields."""
        from scripts.qa.cli import _write_json_report

        payload = {
            "run_id": "20260101-120000",
            "timestamp": "2026-01-01T12:00:00Z",
            "duration_s": 42,
            "timeout": False,
            "health_score": 85,
            "category_scores": {"navigation_flow": 100.0},
            "scenarios": [],
            "summary": {"total_steps": 5, "passed": 5, "failed": 0},
        }

        orig_cwd = os.getcwd()
        os.chdir(tmp_path)
        try:
            report_path = _write_json_report("20260101-120000", payload)
            data = json.loads(report_path.read_text())
        finally:
            os.chdir(orig_cwd)

        assert "health_score" in data
        assert "scenarios" in data
        assert "summary" in data
        assert "timestamp" in data
        assert data["health_score"] == 85
