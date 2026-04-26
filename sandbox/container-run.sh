#!/usr/bin/env bash
set -euo pipefail

# Required env vars (passed by sandbox.sh)
: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY is required}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"
: "${REPO_URL:?REPO_URL is required}"
: "${BASE_BRANCH:?BASE_BRANCH is required}"
: "${FEATURE_BRANCH:?FEATURE_BRANCH is required}"
: "${PLAN_PATH:?PLAN_PATH is required}"

LOG=/logs/session.log

log() { echo "[container] $*" | tee -a "$LOG"; }

log "Starting sandbox container"
log "Repo: $REPO_URL"
log "Branch: $FEATURE_BRANCH"
log "Plan: $PLAN_PATH"

# Configure git identity (GITHUB_TOKEN env var is sufficient for gh CLI auth)
git config --global user.email "rzgholizadeh@gmail.com"
git config --global user.name "rzgholizadeh"
git config --global url."https://x-access-token:${GITHUB_TOKEN}@github.com/".insteadOf "https://github.com/"

# Clone repo
log "Cloning $REPO_URL..."
git clone "$REPO_URL" /workspace
cd /workspace

# Checkout feature branch (created and pushed by writing-plans)
git checkout "$FEATURE_BRANCH"
log "On branch $FEATURE_BRANCH"

# Run Claude: read README, install deps, execute plan
log "Starting Claude Code..."
CLAUDE_CODE_SYNC_PLUGIN_INSTALL=1 claude --dangerously-skip-permissions \
  -p "Read the README first. Install any missing OS-level or project-level dependencies. Then use superpowers:subagent-driven-development on $PLAN_PATH. IMPORTANT: Do NOT run integration tests — only unit tests. Do NOT invoke superpowers:finishing-a-development-branch — the container script handles pushing and PR creation." \
  2>&1 | tee -a "$LOG"

# Push feature branch
log "Pushing branch $FEATURE_BRANCH..."
git push -u origin "$FEATURE_BRANCH"

# Create PR
log "Creating pull request..."
PLAN_TITLE=$(head -1 "$PLAN_PATH" | sed 's/^# //')
PR_URL=$(gh pr create \
  --base "$BASE_BRANCH" \
  --head "$FEATURE_BRANCH" \
  --title "$PLAN_TITLE" \
  --body "Implemented by Claude sandbox agent.

Plan: \`$PLAN_PATH\`
Feature branch: \`$FEATURE_BRANCH\`" \
  2>&1 | grep "https://")

log "DONE: PR created at $PR_URL"
echo "SANDBOX_PR_URL=$PR_URL" >> "$LOG"
