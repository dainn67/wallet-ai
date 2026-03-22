#!/bin/bash
# Detect test framework and output configuration
# Usage: bash .claude/scripts/testing/detect-framework.sh

detected=""
test_cmd=""
test_dir=""
config_file=""
test_count=0

# Flutter/Dart
if [ -z "$detected" ] && [ -f "pubspec.yaml" ]; then
  detected="flutter"
  test_cmd="fvm flutter test"
  test_dir="test"
  config_file="pubspec.yaml"
  test_count=$(find . -name "*_test.dart" 2>/dev/null | wc -l | tr -d ' ')
fi

# JavaScript/Node.js
if [ -f "package.json" ]; then
  if grep -qE '"jest"' package.json 2>/dev/null || [ -f "jest.config.js" ] || [ -f "jest.config.ts" ]; then
    detected="jest"
    test_cmd="npx jest --verbose"
    test_dir="__tests__"
    config_file=$(ls jest.config.* 2>/dev/null | head -1)
    test_count=$(find . -path "*/node_modules" -prune -o \( -name "*.test.js" -o -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.js" -o -name "*.spec.ts" \) -print 2>/dev/null | wc -l | tr -d ' ')
  elif grep -qE '"mocha"' package.json 2>/dev/null || [ -f ".mocharc.js" ] || [ -f ".mocharc.yml" ]; then
    detected="mocha"
    test_cmd="npx mocha --recursive"
    test_dir="test"
    config_file=$(ls .mocharc.* 2>/dev/null | head -1)
    test_count=$(find . -path "*/node_modules" -prune -o \( -name "*.test.js" -o -name "*.spec.js" \) -print 2>/dev/null | wc -l | tr -d ' ')
  elif grep -qE '"vitest"' package.json 2>/dev/null; then
    detected="vitest"
    test_cmd="npx vitest run"
    test_dir="src"
    config_file="vitest.config.ts"
    test_count=$(find . -path "*/node_modules" -prune -o \( -name "*.test.ts" -o -name "*.spec.ts" \) -print 2>/dev/null | wc -l | tr -d ' ')
  fi
fi

# Python
if [ -z "$detected" ]; then
  if [ -f "pytest.ini" ] || [ -f "conftest.py" ] || [ -f "pyproject.toml" ] && grep -q "pytest" pyproject.toml 2>/dev/null; then
    detected="pytest"
    test_cmd="pytest -v --tb=short"
    test_dir="tests"
    config_file=$(ls pytest.ini pyproject.toml setup.cfg 2>/dev/null | head -1)
    test_count=$(find . -name "test_*.py" -o -name "*_test.py" 2>/dev/null | wc -l | tr -d ' ')
  elif find . -name "test_*.py" 2>/dev/null | head -1 | grep -q .; then
    detected="unittest"
    test_cmd="python3 -m pytest -v"
    test_dir="tests"
    test_count=$(find . -name "test_*.py" 2>/dev/null | wc -l | tr -d ' ')
  fi
fi

# Go
if [ -z "$detected" ] && [ -f "go.mod" ]; then
  detected="go"
  test_cmd="go test -v ./..."
  test_dir="."
  config_file="go.mod"
  test_count=$(find . -name "*_test.go" 2>/dev/null | wc -l | tr -d ' ')
fi

# Rust
if [ -z "$detected" ] && [ -f "Cargo.toml" ]; then
  detected="cargo"
  test_cmd="cargo test -- --nocapture"
  test_dir="tests"
  config_file="Cargo.toml"
  test_count=$(find . -name "*.rs" -exec grep -l "#\[cfg(test)\]" {} \; 2>/dev/null | wc -l | tr -d ' ')
fi

# PHP
if [ -z "$detected" ]; then
  if [ -f "phpunit.xml" ] || [ -f "phpunit.xml.dist" ]; then
    detected="phpunit"
    test_cmd="./vendor/bin/phpunit --verbose"
    test_dir="tests"
    config_file=$(ls phpunit.xml phpunit.xml.dist 2>/dev/null | head -1)
    test_count=$(find . -name "*Test.php" 2>/dev/null | wc -l | tr -d ' ')
  fi
fi

# Java/Kotlin
if [ -z "$detected" ]; then
  if [ -f "pom.xml" ]; then
    detected="maven"
    test_cmd="mvn test"
    test_dir="src/test/java"
    config_file="pom.xml"
    test_count=$(find . -path "*/src/test/*" \( -name "*Test.java" -o -name "*Test.kt" \) 2>/dev/null | wc -l | tr -d ' ')
  elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
    detected="gradle"
    test_cmd="./gradlew test"
    test_dir="src/test"
    config_file=$(ls build.gradle build.gradle.kts 2>/dev/null | head -1)
    test_count=$(find . -path "*/src/test/*" \( -name "*Test.java" -o -name "*Test.kt" \) 2>/dev/null | wc -l | tr -d ' ')
  fi
fi

# Ruby
if [ -z "$detected" ]; then
  if [ -f ".rspec" ] || [ -f "spec/spec_helper.rb" ]; then
    detected="rspec"
    test_cmd="bundle exec rspec --format documentation"
    test_dir="spec"
    config_file=".rspec"
    test_count=$(find . -name "*_spec.rb" 2>/dev/null | wc -l | tr -d ' ')
  fi
fi

# Swift
if [ -z "$detected" ] && [ -f "Package.swift" ]; then
  detected="swift"
  test_cmd="swift test --verbose"
  test_dir="Tests"
  config_file="Package.swift"
  test_count=$(find . -name "*Test.swift" -o -name "*Tests.swift" 2>/dev/null | wc -l | tr -d ' ')
fi

# C/C++
if [ -z "$detected" ] && [ -f "CMakeLists.txt" ]; then
  detected="cmake"
  test_cmd="ctest --verbose --output-on-failure"
  test_dir="build"
  config_file="CMakeLists.txt"
  test_count=$(find . -name "*test.cpp" -o -name "*test.c" -o -name "test_*.cpp" 2>/dev/null | wc -l | tr -d ' ')
fi

# .NET
if [ -z "$detected" ] && find . -name "*.csproj" -exec grep -l "IsTestProject" {} \; 2>/dev/null | head -1 | grep -q .; then
  detected="dotnet"
  test_cmd="dotnet test --verbosity normal"
  test_dir="."
  config_file=$(find . -name "*.sln" 2>/dev/null | head -1)
  test_count=$(find . -name "*Test.cs" -o -name "*Tests.cs" 2>/dev/null | wc -l | tr -d ' ')
fi

# Output
if [ -z "$detected" ]; then
  echo "framework: none"
  echo "test_count: 0"
  exit 1
fi

echo "framework: $detected"
echo "test_command: $test_cmd"
echo "test_directory: $test_dir"
echo "config_file: $config_file"
echo "test_count: $test_count"
