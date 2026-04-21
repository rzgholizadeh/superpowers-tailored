---
description: Run a plan file in the isolated Docker sandbox container. Invoke when the user wants to execute an implementation plan in the sandbox.
---

The user wants to run a plan in the sandbox container.

1. Get the plan file path from the user's message
2. Locate the sandbox script: it lives at `sandbox/sandbox.sh` inside the plugin root. The plugin root is the parent of the `commands/` directory where this file lives. Determine it from the base directory context available in the session.
3. Run: `bash "<plugin-root>/sandbox/sandbox.sh" <plan-file-path>`
4. Show the user the log file path so they can monitor with `tail -f`
