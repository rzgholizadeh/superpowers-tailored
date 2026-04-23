#!/usr/bin/env bash
set -euo pipefail

# Location of this script — used to find the Dockerfile for auto-build
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: sandbox.sh <path-to-plan.md>"
  echo ""
  echo "Required env vars:"
  echo "  ANTHROPIC_API_KEY"
  echo "  GITHUB_TOKEN"
  exit 1
}

[ $# -eq 1 ] || usage
[ -f "$1" ] || { echo "Error: plan file not found: $1"; exit 1; }
[ -n "${ANTHROPIC_API_KEY:-}" ] || { echo "Error: ANTHROPIC_API_KEY not set"; exit 1; }
[ -n "${GITHUB_TOKEN:-}" ] || { echo "Error: GITHUB_TOKEN not set"; exit 1; }

PLAN_FILE="$(realpath "$1")"

# Parse plan header
REPO_URL=$(grep "^\*\*Repo:" "$PLAN_FILE" | awk '{print $2}')
BASE_BRANCH=$(grep "^\*\*Base Branch:" "$PLAN_FILE" | awk '{print $3}')
FEATURE_BRANCH=$(grep "^\*\*Feature Branch:" "$PLAN_FILE" | awk '{print $3}')
TOPIC=$(basename "$PLAN_FILE" .md)

[ -n "$REPO_URL" ]       || { echo "Error: **Repo:** field missing from plan header"; exit 1; }
[ -n "$BASE_BRANCH" ]    || { echo "Error: **Base Branch:** field missing from plan header"; exit 1; }
[ -n "$FEATURE_BRANCH" ] || { echo "Error: **Feature Branch:** field missing from plan header"; exit 1; }

# Derive plan path relative to its repo root
PLAN_REPO_ROOT=$(git -C "$(dirname "$PLAN_FILE")" rev-parse --show-toplevel 2>/dev/null \
  || { echo "Error: plan file is not inside a git repo"; exit 1; })
PLAN_PATH="${PLAN_FILE#"$PLAN_REPO_ROOT"/}"

# Auto-build Docker image if not present (Dockerfile lives next to this script)
if ! docker image inspect claude-sandbox:latest &>/dev/null; then
  echo "Building claude-sandbox Docker image (first run)..."
  docker build -t claude-sandbox:latest "${SCRIPT_DIR}"
fi

# Create log file
LOG_DIR="$HOME/.claude/sandbox-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y%m%dT%H%M%S)-$TOPIC.log"
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

echo "Starting sandbox"
echo "  Plan:    $TOPIC"
echo "  Repo:    $REPO_URL"
echo "  Branch:  $FEATURE_BRANCH"
echo "  Log:     $LOG_FILE"
echo ""
echo "Tail logs with:"
echo "  tail -f $LOG_FILE"
echo ""

# Run container
docker run --rm \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -e GITHUB_TOKEN="$GITHUB_TOKEN" \
  -e REPO_URL="$REPO_URL" \
  -e BASE_BRANCH="$BASE_BRANCH" \
  -e FEATURE_BRANCH="$FEATURE_BRANCH" \
  -e PLAN_PATH="$PLAN_PATH" \
  -v "$LOG_FILE":/logs/session.log \
  claude-sandbox:latest

# Extract results from log
COST=$(grep -oP 'Total cost: \$\K[\d.]+' "$LOG_FILE" 2>/dev/null | tail -1 || echo "unknown")
PR_URL=$(grep -oP 'SANDBOX_PR_URL=\K\S+' "$LOG_FILE" 2>/dev/null | tail -1 || echo "unknown")

# Append to cost ledger
LEDGER="$HOME/.claude/sandbox-costs.csv"
if [ ! -f "$LEDGER" ]; then
  echo "timestamp,plan,repo,feature_branch,cost_usd,pr_url" > "$LEDGER"
fi
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),$TOPIC,$REPO_URL,$FEATURE_BRANCH,$COST,$PR_URL" >> "$LEDGER"

echo ""
echo "DONE: $PR_URL | Cost: \$$COST"
