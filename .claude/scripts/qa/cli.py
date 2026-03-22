#!/usr/bin/env python3
"""cli.py — Programmatic QA pipeline entry point.

Usage:
    python3 scripts/qa/cli.py run --non-interactive [--timeout N] [--scenario NAME]

Exit codes:
    0  All scenarios passed
    1  One or more scenarios failed
    2  Timeout
    3  Configuration error (missing API key, shell wrappers not found, etc.)
"""

from __future__ import annotations

import argparse
import datetime
import json
import os
import sys
from pathlib import Path


def _make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="cli.py",
        description="Programmatic QA pipeline for iOS semantic testing",
    )
    sub = parser.add_subparsers(dest="command")

    run_cmd = sub.add_parser("run", help="Execute QA pipeline")
    run_cmd.add_argument(
        "--non-interactive",
        action="store_true",
        help="Required flag for programmatic/CI mode",
    )
    run_cmd.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Timeout in seconds (default: 300)",
    )
    run_cmd.add_argument(
        "--scenario",
        metavar="NAME",
        default=None,
        help="Filter to specific scenario by name",
    )
    return parser


def _check_api_key() -> None:
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("❌ ANTHROPIC_API_KEY required for programmatic mode", file=sys.stderr)
        sys.exit(3)


def _check_shell_wrappers() -> None:
    wrappers = [
        "scripts/qa/axe-wrapper.sh",
        "scripts/qa/simctl-wrapper.sh",
        "scripts/qa/evidence-capture.sh",
    ]
    missing = [w for w in wrappers if not Path(w).exists()]
    if missing:
        print(
            f"❌ Shell wrappers not installed: {', '.join(missing)}",
            file=sys.stderr,
        )
        sys.exit(3)


def _compute_health_score(scenarios: list[dict], config: dict) -> dict:
    """Compute health score using category weights from config."""
    weights: dict[str, float] = config.get(
        "category_weights",
        {"ui_layout": 25, "navigation_flow": 25, "data_display": 25, "accessibility": 25},
    )

    category_totals: dict[str, int] = {}
    category_passing: dict[str, int] = {}

    for scenario in scenarios:
        categories = scenario.get("categories", [])
        if not categories:
            categories = ["ui_layout"]  # default bucket

        steps = scenario.get("executed_steps", [])
        for step in steps:
            verdict = step.get("verdict", {})
            is_pass = verdict.get("result") == "PASS"
            for cat in categories:
                category_totals[cat] = category_totals.get(cat, 0) + 1
                if is_pass:
                    category_passing[cat] = category_passing.get(cat, 0) + 1

    active_cats = [c for c in category_totals if category_totals[c] > 0]
    if not active_cats:
        return {"health_score": 100, "category_scores": {}}

    active_weight_sum = sum(weights.get(c, 0) for c in active_cats)
    if active_weight_sum == 0:
        active_weight_sum = len(active_cats)  # equal weight fallback

    health = 0.0
    category_scores: dict[str, float] = {}
    for cat in active_cats:
        total = category_totals[cat]
        passing = category_passing.get(cat, 0)
        cat_score = (passing / total) * 100 if total else 0.0
        category_scores[cat] = round(cat_score, 1)
        w = weights.get(cat, 0)
        health += cat_score * (w / active_weight_sum)

    return {"health_score": round(health), "category_scores": category_scores}


def _write_json_report(run_id: str, payload: dict) -> Path:
    """Write JSON report to .claude/qa/reports/{run_id}.json."""
    reports_dir = Path(".claude/qa/reports")
    reports_dir.mkdir(parents=True, exist_ok=True)
    report_path = reports_dir / f"{run_id}.json"
    report_path.write_text(json.dumps(payload, indent=2, default=str))
    return report_path


def _write_markdown_report(run_id: str, payload: dict) -> Path:
    """Write markdown report to .claude/qa/reports/{run_id}.md."""
    reports_dir = Path(".claude/qa/reports")
    reports_dir.mkdir(parents=True, exist_ok=True)
    report_path = reports_dir / f"{run_id}.md"

    health = payload.get("health_score", 0)
    scenarios = payload.get("scenarios", [])
    total_steps = sum(len(s.get("executed_steps", [])) for s in scenarios)
    pass_steps = sum(
        1
        for s in scenarios
        for st in s.get("executed_steps", [])
        if (st.get("verdict") or {}).get("result") == "PASS"
    )
    timestamp = payload.get("timestamp", "")
    duration = payload.get("duration_s", 0)

    lines: list[str] = [
        f"# QA Report: {run_id}",
        f"**Health Score: {health}/100** | {pass_steps}/{total_steps} steps passed",
        f"Generated: {timestamp} | Duration: {duration}s",
        "---",
        "",
        "## Per-Scenario Results",
    ]

    for scenario in scenarios:
        steps = scenario.get("executed_steps", [])
        scenario_pass = all(
            (st.get("verdict") or {}).get("result") == "PASS" for st in steps
        ) if steps else False
        label = "PASS" if scenario_pass else "FAIL"
        lines.append(f"### {scenario.get('name', '?')} — {label}")
        lines.append("")
        lines.append("| Step | Action | Result | Confidence | Details |")
        lines.append("|------|--------|--------|------------|---------|")
        for i, step in enumerate(steps, 1):
            verdict = step.get("verdict") or {}
            result = verdict.get("result", "UNCERTAIN")
            conf = verdict.get("confidence", 0)
            reason = verdict.get("reasoning", "")[:80]
            action_desc = step.get("raw_text", "")[:50]
            lines.append(f"| {i} | {action_desc} | {result} | {conf}% | {reason} |")
        lines.append("")

    lines += [
        "## Recommendations",
        "Review failed/uncertain steps above and address UI issues identified.",
        "",
    ]

    report_path.write_text("\n".join(lines))
    return report_path


def cmd_run(args: argparse.Namespace) -> None:
    if not args.non_interactive:
        print(
            "❌ --non-interactive flag required for programmatic mode",
            file=sys.stderr,
        )
        sys.exit(3)

    _check_api_key()
    _check_shell_wrappers()

    # Import here so missing deps give clear ConfigError (exit 3)
    try:
        from scripts.qa.runner import QARunner  # type: ignore[import]
        from scripts.qa.evaluator import SemanticEvaluator, ConfigError  # type: ignore[import]
    except ImportError:
        # Fall back to relative import when run directly from repo root
        sys.path.insert(0, str(Path(__file__).parent.parent.parent))
        from scripts.qa.runner import QARunner  # type: ignore[import]
        from scripts.qa.evaluator import SemanticEvaluator, ConfigError  # type: ignore[import]

    try:
        evaluator = SemanticEvaluator()
    except Exception as exc:  # ConfigError or ImportError
        print(f"❌ {exc}", file=sys.stderr)
        sys.exit(3)

    config_path = "config/qa.json"
    runner = QARunner(config_path=config_path)

    import json as _json

    config: dict = {}
    if Path(config_path).exists():
        config = _json.loads(Path(config_path).read_text())

    start_ts = datetime.datetime.utcnow()
    runner_result = runner.run(
        scenario_filter=args.scenario,
        timeout=args.timeout,
    )
    end_ts = datetime.datetime.utcnow()
    duration = int((end_ts - start_ts).total_seconds())

    if runner_result.get("timeout"):
        # Write partial report then exit 2
        run_id = runner_result.get("run_id", start_ts.strftime("%Y%m%d-%H%M%S"))
        payload = {
            "run_id": run_id,
            "timestamp": start_ts.isoformat() + "Z",
            "duration_s": duration,
            "timeout": True,
            "health_score": 0,
            "scenarios": runner_result.get("scenarios", []),
        }
        json_path = _write_json_report(run_id, payload)
        _write_markdown_report(run_id, payload)
        print(f"⚠️  QA run timed out after {args.timeout}s. Partial report: {json_path}")
        sys.exit(2)

    scenarios = runner_result.get("scenarios", [])
    run_id = runner_result.get("run_id", start_ts.strftime("%Y%m%d-%H%M%S"))

    # Evaluate each step
    all_steps_for_eval: list[dict] = []
    for scenario in scenarios:
        for step in scenario.get("executed_steps", []):
            evidence = step.get("evidence", {})
            tree_path = evidence.get("tree_path")
            screenshot_path = evidence.get("screenshot_path")

            tree: dict = {}
            if tree_path and Path(tree_path).exists():
                try:
                    tree = _json.loads(Path(tree_path).read_text())
                except Exception:
                    tree = {}

            all_steps_for_eval.append(
                {
                    "accessibility_tree": tree,
                    "screenshot_path": screenshot_path,
                    "assertion": step.get("assertion", step.get("raw_text", "")),
                    "_scenario": scenario,
                    "_step": step,
                }
            )

    verdicts = evaluator.evaluate_batch(all_steps_for_eval)

    # Attach verdicts back to steps
    for eval_item, verdict in zip(all_steps_for_eval, verdicts):
        eval_item["_step"]["verdict"] = verdict

    # Compute health score
    score_data = _compute_health_score(scenarios, config)
    health = score_data["health_score"]

    # Count totals
    total_steps = sum(len(s.get("executed_steps", [])) for s in scenarios)
    pass_steps = sum(
        1
        for s in scenarios
        for st in s.get("executed_steps", [])
        if (st.get("verdict") or {}).get("result") == "PASS"
    )

    # Write reports
    payload = {
        "run_id": run_id,
        "timestamp": start_ts.isoformat() + "Z",
        "duration_s": duration,
        "timeout": False,
        "health_score": health,
        "category_scores": score_data["category_scores"],
        "scenarios": scenarios,
        "summary": {
            "total_steps": total_steps,
            "passed": pass_steps,
            "failed": total_steps - pass_steps,
        },
    }
    json_path = _write_json_report(run_id, payload)
    _write_markdown_report(run_id, payload)

    # Print summary
    print(f"✅ QA run complete: {run_id}")
    print(f"   Health Score: {health}/100")
    print(f"   Passed: {pass_steps}/{total_steps} steps")
    print(f"   Report: {json_path}")
    print(f"   Duration: {duration}s")

    # Exit code
    threshold = config.get("health_score_threshold", 70)
    if pass_steps == total_steps or health >= threshold:
        sys.exit(0)
    else:
        sys.exit(1)


def main() -> None:
    parser = _make_parser()
    args = parser.parse_args()

    if args.command == "run":
        cmd_run(args)
    else:
        parser.print_help()
        sys.exit(3)


if __name__ == "__main__":
    main()
