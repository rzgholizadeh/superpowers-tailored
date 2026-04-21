#!/usr/bin/env bash
set -euo pipefail

FIXTURE="$(dirname "$0")/fixtures/test-plan.md"
SANDBOX="$(dirname "$0")/../sandbox/sandbox.sh"

# Source only the parsing functions from sandbox.sh (not the full script)
# We test by calling parse_plan directly
parse_plan() {
  local plan_file="$1"
  REPO_URL=$(grep "^\*\*Repo:" "$plan_file" | awk '{print $2}')
  BASE_BRANCH=$(grep "^\*\*Base Branch:" "$plan_file" | awk '{print $3}')
  FEATURE_BRANCH=$(grep "^\*\*Feature Branch:" "$plan_file" | awk '{print $3}')
  TOPIC=$(basename "$plan_file" .md)
}

pass=0
fail=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    fail=$((fail + 1))
  fi
}

echo "=== sandbox header parsing ==="
parse_plan "$FIXTURE"

check "REPO_URL"       "https://github.com/testuser/testrepo.git" "$REPO_URL"
check "BASE_BRANCH"    "main"                                       "$BASE_BRANCH"
check "FEATURE_BRANCH" "feat/2026-04-20-test-feature"               "$FEATURE_BRANCH"
check "TOPIC"          "test-plan"                                   "$TOPIC"

echo ""
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
