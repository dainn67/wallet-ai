"""E2E tests: QA agent prompt template structure validation (NFR-1)."""
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
PROMPT_FILE = os.path.join(PROJECT_ROOT, "prompts", "qa-agent-prompt.md")


def _read_prompt():
    with open(PROMPT_FILE, "r") as f:
        return f.read()


def test_prompt_file_exists():
    """Prompt template must exist at prompts/qa-agent-prompt.md."""
    assert os.path.isfile(PROMPT_FILE), f"Prompt file not found: {PROMPT_FILE}"


def test_prompt_has_epic_name_placeholder():
    """Prompt must contain {epic_name} placeholder."""
    content = _read_prompt()
    assert "{epic_name}" in content, "Prompt missing {epic_name} placeholder"


def test_prompt_has_ac_text_placeholder():
    """Prompt must contain {ac_text} placeholder."""
    content = _read_prompt()
    assert "{ac_text}" in content, "Prompt missing {ac_text} placeholder"


def test_prompt_has_diff_output_placeholder():
    """Prompt must contain {diff_output} placeholder."""
    content = _read_prompt()
    assert "{diff_output}" in content, "Prompt missing {diff_output} placeholder"


def test_prompt_specifies_json_output():
    """Prompt must specify JSON output format."""
    content = _read_prompt()
    assert "json" in content.lower() or "JSON" in content, "Prompt does not specify JSON output format"
    # Check for required JSON fields in the output spec
    for field in ("status", "health_score", "scenarios_generated", "scenarios_passed", "scenarios_failed"):
        assert field in content, f"Prompt JSON output spec missing field: {field}"


def test_prompt_includes_auto_prefix_strategy():
    """Prompt must include _auto_ prefix copy strategy."""
    content = _read_prompt()
    assert "_auto_" in content, "Prompt missing _auto_ prefix copy strategy"


def test_prompt_includes_cleanup_instruction():
    """Prompt must include cleanup instruction for _auto_ files."""
    content = _read_prompt()
    assert "rm -f" in content or "cleanup" in content.lower() or "clean up" in content.lower(), \
        "Prompt missing cleanup instruction for _auto_ files"
    # More specifically check for _auto_ cleanup
    assert "_auto_" in content, "Prompt missing _auto_ file cleanup step"
