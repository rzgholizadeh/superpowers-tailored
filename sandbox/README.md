# Claude Sandbox

Runs Claude Code implementation sessions in an isolated Docker container — full tool autonomy, no permission prompts, no blast radius on the host OS.

The sandbox scripts live in this plugin and are available at `${CLAUDE_PLUGIN_ROOT}/sandbox/` — no manual install needed. The Docker image is built automatically on first run.

## Prerequisites

- Docker running locally
- `ANTHROPIC_API_KEY` set in your shell (Anthropic API key)
- `GITHUB_TOKEN` set in your shell (fine-grained token: repo contents read/write + pull requests write)

## Usage

**From inside a Claude Code session:**
```
/sandbox docs/plans/2026-04-20-my-feature.md
```

**From a terminal (multi-repo, parallel):**
```bash
bash "${CLAUDE_PLUGIN_ROOT}/sandbox/sandbox.sh" backend/docs/plans/2026-04-20-auth.md &
bash "${CLAUDE_PLUGIN_ROOT}/sandbox/sandbox.sh" frontend/docs/plans/2026-04-20-auth-ui.md &
wait
```

The Docker image builds automatically on first run. To force a rebuild after a plugin update:
```bash
docker rmi claude-sandbox:latest
```

## Watch logs

```bash
tail -f ~/.claude/sandbox-logs/<timestamp>-<topic>.log
```

## Review costs

```bash
cat ~/.claude/sandbox-costs.csv

# Sum all costs
awk -F',' 'NR>1 {sum += $5} END {print "Total: $" sum}' ~/.claude/sandbox-costs.csv
```

## How it works

1. `sandbox.sh` auto-builds the Docker image if not present (Dockerfile is next to it in the plugin)
2. Parses the plan header (Repo, Base Branch, Feature Branch)
3. Starts a container with only `ANTHROPIC_API_KEY`, `GITHUB_TOKEN`, and a write-only log file
4. Container clones the repo, creates the feature branch, reads README, installs deps, runs `executing-plans`
5. Container creates a PR and exits
6. `sandbox.sh` appends a cost record to `~/.claude/sandbox-costs.csv`

## Plan header requirements

Added automatically by `writing-plans` skill:

```
**Repo:** https://github.com/user/repo.git
**Base Branch:** main
**Feature Branch:** feat/YYYY-MM-DD-topic
```
