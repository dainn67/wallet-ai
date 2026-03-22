"""Pytest fixtures for qa-agent-skill-integration E2E tests."""
import os
import pytest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))


@pytest.fixture
def project_root():
    """Return the absolute path to the project root."""
    return PROJECT_ROOT
