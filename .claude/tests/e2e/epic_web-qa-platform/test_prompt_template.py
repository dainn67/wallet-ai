"""Tests for web QA agent prompt template (Issue #209)."""

import os
import unittest

PROMPT_PATH = os.path.join(
    os.path.dirname(__file__), "..", "..", "..", "prompts", "web-qa-agent-prompt.md"
)


class TestWebQAPromptTemplate(unittest.TestCase):
    """Verify prompts/web-qa-agent-prompt.md exists and has required content."""

    @classmethod
    def setUpClass(cls):
        cls.prompt_path = os.path.normpath(PROMPT_PATH)
        assert os.path.isfile(cls.prompt_path), (
            f"Prompt file not found: {cls.prompt_path}"
        )
        with open(cls.prompt_path, "r") as f:
            cls.content = f.read()

    def test_file_exists(self):
        """Prompt template file must exist."""
        self.assertTrue(os.path.isfile(self.prompt_path))

    def test_has_input_section(self):
        """Prompt must have an Input section with template variables."""
        self.assertIn("## Input", self.content)
        self.assertIn("{epic_name}", self.content)
        self.assertIn("{ac_text}", self.content)
        self.assertIn("{diff_output}", self.content)

    def test_has_workflow_section(self):
        """Prompt must have a Workflow section."""
        self.assertIn("## Workflow", self.content)

    def test_has_output_section(self):
        """Prompt must have an Output section."""
        self.assertIn("## Output", self.content)

    def test_references_ccpm_browse(self):
        """Prompt must reference ccpm-browse commands (not AXe/simctl)."""
        self.assertIn("ccpm-browse", self.content)
        self.assertNotIn("simctl", self.content)
        self.assertNotIn("axe-wrapper", self.content)

    def test_references_detect_web(self):
        """Prompt must reference detect-web.sh."""
        self.assertIn("detect-web.sh", self.content)

    def test_references_detect_server(self):
        """Prompt must reference detect-server.sh."""
        self.assertIn("detect-server.sh", self.content)

    def test_references_health_score(self):
        """Prompt must reference health-score.sh."""
        self.assertIn("health-score.sh", self.content)

    def test_references_evidence_capture(self):
        """Prompt must reference screenshot evidence paths."""
        self.assertIn("evidence", self.content)
        self.assertIn("screenshot", self.content.lower())
        self.assertIn(".claude/qa/evidence/", self.content)

    def test_references_framework_checks(self):
        """Prompt must include framework-specific checks."""
        self.assertIn("Next.js", self.content)
        self.assertIn("Nuxt", self.content)
        self.assertIn("hydration", self.content.lower())

    def test_has_skip_handling(self):
        """Prompt must handle skip cases (no server, no AC)."""
        self.assertIn("SKIP", self.content)
        self.assertIn("skip_reason", self.content)

    def test_has_report_format(self):
        """Prompt must define report output format."""
        self.assertIn("Health Score", self.content)
        self.assertIn("Scenario Results", self.content)


if __name__ == "__main__":
    unittest.main()
