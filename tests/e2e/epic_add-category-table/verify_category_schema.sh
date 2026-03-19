#!/bin/bash
set -e
echo "Running smoke tests for add-category-table..."

# Note: In a real CI environment, we would use sqlite3 command on the actual db file.
# For this smoke test, we verify that the code contains the expected schema changes.

grep -q "CREATE TABLE Category" lib/repositories/record_repository.dart || (echo "❌ Category table definition missing"; exit 1)
grep -q "category_id" lib/models/record.dart || (echo "❌ category_id in Record model missing"; exit 1)
grep -q "LEFT JOIN Category" lib/repositories/record_repository.dart || (echo "❌ SQL JOIN missing in repository"; exit 1)

echo "Running repository unit tests..."
fvm flutter test test/repositories/record_repository_test.dart

echo "✅ All category smoke tests passed!"
