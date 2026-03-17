"""
Pytest configuration for CCPM test suite.
Prevents pytest from erroring on bash/markdown files in tests/ directory.
"""

collect_ignore_glob = ["*.sh", "*.md"]
