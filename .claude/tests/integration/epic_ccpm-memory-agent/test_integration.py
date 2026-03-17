"""Phase B integration tests for epic ccpm-memory-agent.

Tests module boundaries and data flow across components.
No mocking of core functionality.
"""

import json
import sqlite3
import sys
import time
from pathlib import Path

import pytest
from aiohttp import web
from aiohttp.test_utils import TestClient, TestServer

sys.path.insert(0, str(Path(__file__).parents[3] / "memory-agent"))

from agent import (
    DB_SCHEMA,
    DEFAULT_CONFIG,
    handle_ingest,
    handle_query,
    handle_consolidate,
    handle_status,
    migrate_schema,
    store_memory,
    store_insight,
    infer_metadata,
    _extract_entity_types,
    _calibrate_importance,
    is_duplicate,
)

import asyncio


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _fresh_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:", check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.executescript(DB_SCHEMA)
    conn.commit()
    migrate_schema(conn)
    return conn


def _make_app(conn, config=None) -> web.Application:
    cfg = dict(DEFAULT_CONFIG)
    if config:
        cfg.update(config)
    app = web.Application()
    app["db"] = conn
    app["config"] = cfg
    app["start_time"] = time.time()
    app.router.add_get("/status", handle_status)
    app.router.add_post("/ingest", handle_ingest)
    app.router.add_get("/query", handle_query)
    app.router.add_post("/consolidate", handle_consolidate)
    return app


def run_async(coro):
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


# ---------------------------------------------------------------------------
# Integration: IngestAgent → Schema (entity storage)
# ---------------------------------------------------------------------------

class TestIngestToSchema:
    """Verify data flows correctly from ingest API to schema storage."""

    def test_metadata_stored_in_extended_columns(self):
        """POST /ingest with CCPM metadata → stored in extended schema columns."""
        conn = _fresh_conn()

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                resp = await client.post("/ingest", json={
                    "text": "Decision: Use WAL mode for SQLite concurrency.",
                    "source": "handoff",
                    "task_id": "#130",
                    "epic": "ccpm-memory-agent",
                    "task_type": "FEATURE",
                })
                assert resp.status == 202
                data = await resp.json()
                mem_id = data["id"]

                # Verify in DB
                row = conn.execute(
                    "SELECT task_id, epic, task_type FROM memories WHERE id=?",
                    (mem_id,)
                ).fetchone()
                assert row is not None
                assert row["task_id"] == "#130"
                assert row["epic"] == "ccpm-memory-agent"
                assert row["task_type"] == "FEATURE"

        run_async(_run())

    def test_importance_override_applied(self):
        """importance_override overwrites LLM-calculated importance."""
        conn = _fresh_conn()

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                resp = await client.post("/ingest", json={
                    "text": "Minor documentation update",
                    "source": "manual",
                    "importance_override": 0.95,
                })
                assert resp.status == 202
                data = await resp.json()
                row = conn.execute(
                    "SELECT importance FROM memories WHERE id=?",
                    (data["id"],)
                ).fetchone()
                assert row["importance"] == 0.95

        run_async(_run())

    def test_entity_types_column_populated(self):
        """entity_types JSON array is stored in DB after extraction."""
        conn = _fresh_conn()
        # Directly test store_memory with entity_types
        mem_id = store_memory(
            conn, text="Test decision about architecture",
            summary="Architecture decision", entities=[{"name": "test", "type": "decision"}],
            topics=["arch"], importance=0.9, source="test",
            entity_types=json.dumps(["decision"]),
        )
        row = conn.execute(
            "SELECT entity_types FROM memories WHERE id=?", (mem_id,)
        ).fetchone()
        assert row is not None
        types = json.loads(row["entity_types"])
        assert "decision" in types


# ---------------------------------------------------------------------------
# Integration: Schema → Query API (filtering)
# ---------------------------------------------------------------------------

class TestSchemaToQuery:
    """Verify query API correctly uses schema columns for filtering."""

    def test_epic_filter_uses_db_column(self):
        """?epic=X filters using the epic column in DB."""
        conn = _fresh_conn()
        store_memory(conn, text="Memory in epic A", summary="A", entities=[],
                     topics=[], importance=0.7, source="test", epic="epic-a",
                     entity_types="[]")
        store_memory(conn, text="Memory in epic B", summary="B", entities=[],
                     topics=[], importance=0.7, source="test", epic="epic-b",
                     entity_types="[]")

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                resp = await client.get("/query?epic=epic-a")
                data = await resp.json()
                assert len(data["memories"]) == 1
                assert data["memories"][0]["epic"] == "epic-a"

        run_async(_run())

    def test_combined_type_and_epic_filter(self):
        """?type=decision&epic=X applies both filters."""
        conn = _fresh_conn()
        store_memory(conn, text="Decision in A", summary="DA", entities=[],
                     topics=[], importance=0.9, source="test", epic="epic-a",
                     entity_types=json.dumps(["decision"]))
        store_memory(conn, text="Pattern in A", summary="PA", entities=[],
                     topics=[], importance=0.7, source="test", epic="epic-a",
                     entity_types=json.dumps(["pattern"]))
        store_memory(conn, text="Decision in B", summary="DB", entities=[],
                     topics=[], importance=0.9, source="test", epic="epic-b",
                     entity_types=json.dumps(["decision"]))

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                resp = await client.get("/query?type=decision&epic=epic-a")
                data = await resp.json()
                assert len(data["memories"]) == 1
                assert "Decision in A" in data["memories"][0]["text"]

        run_async(_run())

    def test_limit_parameter_caps_results(self):
        """?limit=2 returns at most 2 memories."""
        conn = _fresh_conn()
        for i in range(5):
            store_memory(conn, text=f"Memory {i}", summary=f"M{i}", entities=[],
                         topics=[], importance=0.5 + i * 0.1, source="test",
                         entity_types="[]")

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                resp = await client.get("/query?limit=2")
                data = await resp.json()
                assert len(data["memories"]) == 2

        run_async(_run())


# ---------------------------------------------------------------------------
# Integration: ConsolidateAgent → Query API (insights in response)
# ---------------------------------------------------------------------------

class TestConsolidateToQuery:
    """Verify insights stored by consolidation appear in query responses."""

    def test_insights_appear_in_query_response(self):
        """Stored insights are returned in /query response."""
        conn = _fresh_conn()
        mem_id = store_memory(conn, text="Test memory", summary="Test",
                              entities=[], topics=[], importance=0.7,
                              source="test", entity_types="[]")
        store_insight(conn, {
            "type": "decision_regression",
            "severity": "high",
            "description": "Task reversed earlier decision",
            "memory_ids": [mem_id],
            "recommended_action": "Review decision",
            "confidence": 0.85,
        })

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                resp = await client.get("/query?q=test")
                data = await resp.json()
                assert len(data["insights"]) >= 1
                ins = data["insights"][0]
                assert ins["type"] == "decision_regression"
                assert ins["confidence"] == 0.85
                assert ins["severity"] == "high"

        run_async(_run())

    def test_low_confidence_insights_filtered(self):
        """Insights below confidence threshold excluded from response."""
        conn = _fresh_conn()
        store_memory(conn, text="Placeholder", summary="P", entities=[],
                     topics=[], importance=0.5, source="test", entity_types="[]")
        store_insight(conn, {
            "type": "complexity_signal",
            "severity": "low",
            "description": "Low confidence signal",
            "memory_ids": [1],
            "confidence": 0.3,
        })
        store_insight(conn, {
            "type": "architecture_drift",
            "severity": "high",
            "description": "High confidence drift",
            "memory_ids": [1],
            "confidence": 0.9,
        })

        async def _run():
            app = _make_app(conn, {"consolidation_confidence_threshold": 0.7})
            async with TestClient(TestServer(app)) as client:
                resp = await client.get("/query?q=placeholder")
                data = await resp.json()
                # Only the high-confidence insight should appear
                assert len(data["insights"]) == 1
                assert data["insights"][0]["type"] == "architecture_drift"

        run_async(_run())


# ---------------------------------------------------------------------------
# Integration: File Watcher → IngestAgent (source tagging)
# ---------------------------------------------------------------------------

class TestWatcherSourceTagging:
    """Verify file path → source metadata inference (FR-11)."""

    def test_handoff_path_tagged(self):
        meta = infer_metadata(".claude/context/handoffs/latest.md")
        assert meta["source"] == "handoff"
        assert meta["importance"] == 0.90
        assert meta["epic"] is None

    def test_prd_path_tagged(self):
        meta = infer_metadata(".claude/prds/feature-x.md")
        assert meta["source"] == "prd"
        assert meta["importance"] == 0.95

    def test_epic_path_extracts_name(self):
        meta = infer_metadata(".claude/epics/ccpm-memory-agent/131.md")
        assert meta["source"] == "epic"
        assert meta["epic"] == "ccpm-memory-agent"
        assert meta["importance"] == 0.85

    def test_context_path_tagged(self):
        meta = infer_metadata(".claude/context/sessions/debug.md")
        assert meta["source"] == "context"
        assert meta["importance"] == 0.70

    def test_rules_path_tagged(self):
        meta = infer_metadata(".claude/rules/git-workflows.md")
        assert meta["source"] == "rule"
        assert meta["importance"] == 0.60

    def test_unknown_path_defaults(self):
        meta = infer_metadata("random/file.md")
        assert meta["source"] == "file"
        assert meta["importance"] == 0.5


# ---------------------------------------------------------------------------
# Integration: Schema migration idempotency
# ---------------------------------------------------------------------------

class TestSchemaMigration:
    """Verify schema migration is idempotent and additive."""

    def test_migration_idempotent(self):
        """Running migrate_schema twice doesn't error."""
        conn = _fresh_conn()
        migrate_schema(conn)  # already called in _fresh_conn, call again
        # Should not raise
        row = conn.execute("PRAGMA table_info(memories)").fetchall()
        col_names = [r[1] for r in row]
        assert "task_id" in col_names
        assert "epic" in col_names
        assert "task_type" in col_names
        assert "entity_types" in col_names

    def test_insights_table_exists(self):
        """Insights table created by migration."""
        conn = _fresh_conn()
        row = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='insights'"
        ).fetchone()
        assert row is not None

    def test_indexes_created(self):
        """CCPM-specific indexes exist."""
        conn = _fresh_conn()
        indexes = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='index'"
        ).fetchall()
        idx_names = [r[0] for r in indexes]
        assert "idx_entity_types" in idx_names
        assert "idx_epic" in idx_names
        assert "idx_task_id" in idx_names


# ---------------------------------------------------------------------------
# Integration: Dedup logic across components
# ---------------------------------------------------------------------------

class TestDedupIntegration:
    """Verify dedup works across ingest API and DB layer."""

    def test_is_duplicate_function(self):
        """is_duplicate correctly detects matching source_path + source_mtime."""
        conn = _fresh_conn()
        store_memory(conn, text="File content", summary="S", entities=[],
                     topics=[], importance=0.5, source="watcher",
                     source_path="/tmp/test.md", source_mtime=1710000000.0,
                     entity_types="[]")

        assert is_duplicate(conn, "/tmp/test.md", 1710000000.0) is True
        assert is_duplicate(conn, "/tmp/test.md", 1710001000.0) is False
        assert is_duplicate(conn, "/tmp/other.md", 1710000000.0) is False


# ---------------------------------------------------------------------------
# Integration: Importance calibration
# ---------------------------------------------------------------------------

class TestImportanceCalibration:
    """Verify importance scoring for software development artifacts."""

    def test_architectural_decision_high(self):
        score = _calibrate_importance("architectural decision about DB", 0.5)
        assert score >= 0.9

    def test_bug_fix_medium(self):
        score = _calibrate_importance("bug fix for auth module", 0.5)
        assert score >= 0.7

    def test_documentation_low(self):
        score = _calibrate_importance("documentation update for readme", 0.8)
        assert score <= 0.5

    def test_llm_score_not_reduced_for_high(self):
        """Calibration only increases, never decreases, for high signals."""
        score = _calibrate_importance("architectural migration plan", 0.95)
        assert score >= 0.95


# ---------------------------------------------------------------------------
# Integration: Entity type extraction
# ---------------------------------------------------------------------------

class TestEntityTypeExtraction:
    """Verify _extract_entity_types filters and deduplicates correctly."""

    def test_valid_types_extracted(self):
        entities = [
            {"name": "test", "type": "decision"},
            {"name": "test2", "type": "pattern"},
        ]
        result = _extract_entity_types(entities)
        assert result == ["decision", "pattern"]

    def test_invalid_types_filtered(self):
        entities = [
            {"name": "test", "type": "decision"},
            {"name": "test2", "type": "invalid_type"},
        ]
        result = _extract_entity_types(entities)
        assert result == ["decision"]

    def test_duplicates_removed(self):
        entities = [
            {"name": "a", "type": "decision"},
            {"name": "b", "type": "decision"},
        ]
        result = _extract_entity_types(entities)
        assert result == ["decision"]

    def test_non_dict_entities_skipped(self):
        entities = ["string_entity", {"name": "test", "type": "bug"}]
        result = _extract_entity_types(entities)
        assert result == ["bug"]
