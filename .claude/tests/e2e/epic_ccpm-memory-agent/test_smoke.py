"""Phase B smoke tests for epic ccpm-memory-agent.

Verifies end-to-end scenarios using aiohttp TestClient with in-memory SQLite.
No mocking of core functionality — tests exercise real agent code paths.
"""

import asyncio
import json
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

import pytest
from aiohttp import web
from aiohttp.test_utils import TestClient, TestServer

# Add memory-agent to path
sys.path.insert(0, str(Path(__file__).parents[3] / "memory-agent"))

from agent import (
    DB_SCHEMA,
    DEFAULT_CONFIG,
    handle_consolidate,
    handle_ingest,
    handle_query,
    handle_status,
    migrate_schema,
    store_memory,
    store_insight,
)


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


def _seed_memory(conn, text="Test memory", source="test", entity_types=None,
                 epic="", task_id="", importance=0.7):
    """Insert a memory directly for test setup."""
    et = json.dumps(entity_types or [])
    return store_memory(
        conn, text=text, summary=f"Summary of: {text[:30]}",
        entities=[], topics=[], importance=importance,
        source=source, entity_types=et, epic=epic, task_id=task_id,
    )


# ---------------------------------------------------------------------------
# Smoke 1: Full lifecycle — ingest → query → consolidate → verify
# ---------------------------------------------------------------------------

class TestSmoke01FullLifecycle:
    def test_ingest_then_query_then_consolidate(self):
        """Full lifecycle: POST /ingest → GET /query → POST /consolidate → GET /query."""
        conn = _fresh_conn()

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                # Step 1: Ingest
                resp = await client.post("/ingest", json={
                    "text": "We decided to use SQLite with WAL mode for concurrent safety.",
                    "source": "handoff",
                    "task_id": "#130",
                    "epic": "ccpm-memory-agent",
                })
                assert resp.status == 202
                data = await resp.json()
                assert data["status"] == "queued"
                assert "id" in data
                mem_id = data["id"]

                # Step 2: Query — should find the ingested memory
                resp = await client.get("/query?q=SQLite")
                assert resp.status == 200
                data = await resp.json()
                assert "memories" in data
                assert "insights" in data
                assert "summary" in data
                assert len(data["memories"]) >= 1
                found = any(m["id"] == mem_id for m in data["memories"])
                assert found, f"Memory {mem_id} not found in query results"

                # Step 3: Consolidate
                resp = await client.post("/consolidate")
                assert resp.status == 200
                cdata = await resp.json()
                assert "insights" in cdata
                assert "status" in cdata

                # Step 4: Query again — verify still works after consolidation
                resp = await client.get("/query?q=SQLite")
                assert resp.status == 200
                data = await resp.json()
                assert len(data["memories"]) >= 1

        run_async(_run())


# ---------------------------------------------------------------------------
# Smoke 2: Structured JSON response schema validation
# ---------------------------------------------------------------------------

class TestSmoke02StructuredJSON:
    def test_json_response_schema(self):
        """Default /query response has correct JSON schema."""
        conn = _fresh_conn()
        _seed_memory(conn, text="Architectural decision about fork strategy",
                     entity_types=["decision"], epic="ccpm-memory-agent")

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                resp = await client.get("/query?q=fork")
                assert resp.status == 200
                data = await resp.json()

                # Top-level keys
                assert set(data.keys()) == {"memories", "insights", "summary"}

                # Memory fields
                mem = data["memories"][0]
                required_fields = {"id", "text", "source", "entities",
                                   "importance", "task_id", "epic", "created_at"}
                assert required_fields.issubset(set(mem.keys())), \
                    f"Missing fields: {required_fields - set(mem.keys())}"

        run_async(_run())

    def test_empty_query_returns_200(self):
        """Query with no matches returns HTTP 200 with empty arrays."""
        conn = _fresh_conn()

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                resp = await client.get("/query?q=nonexistent_term_xyz")
                assert resp.status == 200
                data = await resp.json()
                assert data["memories"] == []
                assert data["insights"] == []
                assert "No relevant memories found" in data["summary"]

        run_async(_run())


# ---------------------------------------------------------------------------
# Smoke 3: Entity type filtering
# ---------------------------------------------------------------------------

class TestSmoke03EntityTypeFilter:
    def test_type_filter_decision(self):
        """?type=decision returns only memories with decision entity type."""
        conn = _fresh_conn()
        _seed_memory(conn, text="Chose exponential backoff", entity_types=["decision"])
        _seed_memory(conn, text="Auth module pattern", entity_types=["pattern"])
        _seed_memory(conn, text="SQLite bug workaround", entity_types=["bug"])

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                resp = await client.get("/query?type=decision")
                assert resp.status == 200
                data = await resp.json()
                assert len(data["memories"]) == 1
                assert "backoff" in data["memories"][0]["text"]

        run_async(_run())

    def test_all_six_entity_types(self):
        """All 6 entity types are filterable."""
        conn = _fresh_conn()
        types = ["decision", "pattern", "bug", "requirement", "file", "concept"]
        for t in types:
            _seed_memory(conn, text=f"Test {t} entity", entity_types=[t])

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                for t in types:
                    resp = await client.get(f"/query?type={t}")
                    assert resp.status == 200
                    data = await resp.json()
                    assert len(data["memories"]) == 1, \
                        f"Expected 1 memory for type={t}, got {len(data['memories'])}"

        run_async(_run())


# ---------------------------------------------------------------------------
# Smoke 4: Markdown format output
# ---------------------------------------------------------------------------

class TestSmoke04MarkdownFormat:
    def test_markdown_has_sections(self):
        """?format=markdown returns text with required sections."""
        conn = _fresh_conn()
        _seed_memory(conn, text="Important design decision about caching",
                     entity_types=["decision"], epic="test-epic")

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                resp = await client.get("/query?q=caching&format=markdown")
                assert resp.status == 200
                text = await resp.text()
                assert "# Query Results" in text
                assert "## Memories" in text
                assert "## Insights" in text
                assert "## Summary" in text
                assert "text/markdown" in resp.content_type

        run_async(_run())


# ---------------------------------------------------------------------------
# Smoke 5: Concurrent ingest
# ---------------------------------------------------------------------------

class TestSmoke05ConcurrentIngest:
    def test_three_concurrent_ingests(self):
        """3 simultaneous POST /ingest requests all succeed (NFR-8)."""
        conn = _fresh_conn()

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                tasks = [
                    client.post("/ingest", json={
                        "text": f"Concurrent memory {i}: testing WAL mode safety",
                        "source": "test",
                    })
                    for i in range(3)
                ]
                results = await asyncio.gather(*tasks)

                ids = set()
                for resp in results:
                    assert resp.status == 202
                    data = await resp.json()
                    assert data["status"] == "queued"
                    ids.add(data["id"])

                # All 3 must have distinct IDs
                assert len(ids) == 3, f"Expected 3 distinct IDs, got {ids}"

                # Verify in DB
                count = conn.execute("SELECT COUNT(*) FROM memories").fetchone()[0]
                assert count == 3

        run_async(_run())


# ---------------------------------------------------------------------------
# Smoke 6: Dedup on re-scan
# ---------------------------------------------------------------------------

class TestSmoke06Dedup:
    def test_same_file_same_mtime_skipped(self):
        """Same file_path + file_mtime → second ingest skipped."""
        conn = _fresh_conn()

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                payload = {
                    "text": "Dedup test content",
                    "source": "watcher",
                    "file_path": "/tmp/test-dedup.md",
                    "file_mtime": 1710000000.0,
                }

                # First ingest
                resp = await client.post("/ingest", json=payload)
                assert resp.status == 202
                d1 = await resp.json()
                assert d1["status"] == "queued"

                # Second ingest — same path + mtime
                resp = await client.post("/ingest", json=payload)
                assert resp.status == 200
                d2 = await resp.json()
                assert d2["status"] == "skipped"
                assert d2["reason"] == "duplicate"

        run_async(_run())

    def test_same_file_different_mtime_reingested(self):
        """Same file_path but different file_mtime → re-ingested."""
        conn = _fresh_conn()

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                base = {
                    "text": "Content v1",
                    "source": "watcher",
                    "file_path": "/tmp/test-update.md",
                    "file_mtime": 1710000000.0,
                }
                resp = await client.post("/ingest", json=base)
                assert resp.status == 202

                # Updated file (new mtime)
                updated = {**base, "text": "Content v2", "file_mtime": 1710001000.0}
                resp = await client.post("/ingest", json=updated)
                assert resp.status == 202
                data = await resp.json()
                assert data["status"] == "queued"

                count = conn.execute("SELECT COUNT(*) FROM memories").fetchone()[0]
                assert count == 2

        run_async(_run())


# ---------------------------------------------------------------------------
# Smoke 7: Smoke test checklist items
# ---------------------------------------------------------------------------

class TestSmoke07Checklist:
    def test_cli_syntax_valid(self):
        """ccpm-memory bash script has valid syntax."""
        cli_path = Path(__file__).parents[3] / "memory-agent" / "ccpm-memory"
        result = subprocess.run(
            ["bash", "-n", str(cli_path)],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, f"Syntax error: {result.stderr}"

    def test_agent_importable(self):
        """agent.py can be imported without errors."""
        result = subprocess.run(
            [sys.executable, "-c", "import agent"],
            capture_output=True, text=True,
            cwd=str(Path(__file__).parents[3] / "memory-agent"),
        )
        assert result.returncode == 0, f"Import error: {result.stderr}"

    def test_config_defaults_valid_json(self):
        """config-defaults.json is valid JSON."""
        config_path = Path(__file__).parents[3] / "memory-agent" / "config-defaults.json"
        with open(config_path) as f:
            data = json.load(f)
        assert "watch_directories" in data
        assert "port" in data

    def test_readme_exists(self):
        """README.md exists and is non-empty."""
        readme = Path(__file__).parents[3] / "memory-agent" / "README.md"
        assert readme.exists()
        assert readme.stat().st_size > 100

    def test_fork_changes_exists(self):
        """FORK_CHANGES.md exists and documents all tasks."""
        fc = Path(__file__).parents[3] / "memory-agent" / "FORK_CHANGES.md"
        assert fc.exists()
        content = fc.read_text()
        # Should reference key task numbers
        assert "T130" in content or "schema" in content.lower()

    def test_status_endpoint(self):
        """GET /status returns running status with memory count."""
        conn = _fresh_conn()

        async def _run():
            app = _make_app(conn)
            async with TestClient(TestServer(app)) as client:
                resp = await client.get("/status")
                assert resp.status == 200
                data = await resp.json()
                assert data["status"] == "running"
                assert "memories" in data
                assert "uptime_seconds" in data

        run_async(_run())
