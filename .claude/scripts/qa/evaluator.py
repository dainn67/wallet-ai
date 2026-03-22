"""SemanticEvaluator — Anthropic SDK evaluation for programmatic QA mode.

AD-2: This is the ONLY component that makes Anthropic API calls.
Requires: ANTHROPIC_API_KEY environment variable.
"""

from __future__ import annotations

import base64
import json
import os
import time
from pathlib import Path
from typing import Any


class ConfigError(Exception):
    """Raised for configuration problems (missing API key, etc.)."""


class SemanticEvaluator:
    """Evaluates UI assertions using Claude via Anthropic SDK."""

    def __init__(self, model: str = "claude-sonnet-4-6") -> None:
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise ConfigError("ANTHROPIC_API_KEY required for programmatic mode")

        try:
            import anthropic  # type: ignore[import]
        except ImportError as e:
            raise ConfigError(
                "anthropic package not installed. Run: pip install anthropic"
            ) from e

        self._client = anthropic.Anthropic(api_key=api_key)
        self._model = model

    def evaluate_step(
        self,
        accessibility_tree: dict,
        screenshot_path: str | None,
        assertion: str,
    ) -> dict:
        """Evaluate a single UI assertion.

        Args:
            accessibility_tree: Parsed AXe describe-ui JSON.
            screenshot_path: Path to screenshot PNG, or None.
            assertion: Human-readable assertion text to verify.

        Returns:
            {"result": "PASS"|"FAIL"|"UNCERTAIN", "confidence": 0-100, "reasoning": "..."}
        """
        content: list[Any] = []

        # Build the text prompt
        prompt = (
            f"You are evaluating an iOS app's UI state.\n\n"
            f"Assertion to verify: {assertion}\n\n"
            f"Accessibility tree:\n{json.dumps(accessibility_tree, indent=2)}\n\n"
            f"Based on the accessibility tree"
        )

        if screenshot_path and Path(screenshot_path).exists():
            try:
                img_data = Path(screenshot_path).read_bytes()
                img_b64 = base64.b64encode(img_data).decode("utf-8")
                content.append(
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": "image/png",
                            "data": img_b64,
                        },
                    }
                )
                prompt += " and screenshot"
            except OSError:
                pass  # screenshot unreadable — continue without it

        prompt += (
            ", determine if the assertion holds.\n\n"
            "Respond with a JSON object only (no markdown):\n"
            '{"result": "PASS"|"FAIL"|"UNCERTAIN", "confidence": 0-100, "reasoning": "brief explanation"}'
        )
        content.append({"type": "text", "text": prompt})

        try:
            response = self._client.messages.create(
                model=self._model,
                max_tokens=256,
                messages=[{"role": "user", "content": content}],
            )
            raw = response.content[0].text.strip()
            # Strip markdown code fences if present
            if raw.startswith("```"):
                raw = raw.split("```")[1]
                if raw.startswith("json"):
                    raw = raw[4:]
            verdict = json.loads(raw)
            return {
                "result": verdict.get("result", "UNCERTAIN"),
                "confidence": int(verdict.get("confidence", 0)),
                "reasoning": verdict.get("reasoning", ""),
            }
        except TimeoutError:
            return {
                "result": "UNCERTAIN",
                "confidence": 0,
                "reasoning": "API timeout",
            }
        except Exception as exc:  # noqa: BLE001
            return {
                "result": "UNCERTAIN",
                "confidence": 0,
                "reasoning": f"Evaluation error: {exc}",
            }

    def evaluate_batch(self, steps: list[dict]) -> list[dict]:
        """Evaluate a list of steps sequentially.

        Each step dict must contain:
            accessibility_tree: dict
            screenshot_path: str | None
            assertion: str

        Returns list of verdict dicts in the same order.
        """
        verdicts: list[dict] = []
        for step in steps:
            verdict = self.evaluate_step(
                accessibility_tree=step.get("accessibility_tree", {}),
                screenshot_path=step.get("screenshot_path"),
                assertion=step.get("assertion", ""),
            )
            verdicts.append(verdict)
            # Small courtesy delay to avoid thundering-herd on the API
            time.sleep(0.1)
        return verdicts
