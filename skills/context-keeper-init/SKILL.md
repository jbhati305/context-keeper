---
name: context-keeper:init
description: Initialize context-keeper working memory in the current repo. Creates .claude/context/ with five structured markdown files for tracking the current task, decisions, failed attempts, changed files, and next steps. Also sets up automatic hooks so context is injected at session start and before compaction. Run once per repo before using any other context-keeper skill.
---

# context-keeper:init

You are initializing context-keeper working memory for this repository.

## Step 1 — Check for existing context

Check if `.claude/context/` already exists in the current working directory.

If it exists:
- Tell the user: "`.claude/context/` already exists. Reinitializing will overwrite existing context. Continue? (yes/no)"
- If they say no, stop here.

## Step 2 — Create the context directory

Create `.claude/context/` if it does not exist.

## Step 3 — Write the five context files

Create each file with exactly this content:

### `.claude/context/CURRENT_TASK.md`

```
# Current Task

## Goal
<!-- One sentence: what are we trying to accomplish -->

## Scope
<!-- What is explicitly in/out of scope for this task -->

## Project Context
<!-- Brief repo overview: stack, main dirs, key conventions -->

## Status
active
```

### `.claude/context/DECISIONS.md`

```
# Decisions

<!-- Format per entry:
## [OPEN|RESOLVED] Decision title
- **Decision:** what was decided
- **Reason:** why
- **Date:** YYYY-MM-DD
-->
```

### `.claude/context/FAILED_ATTEMPTS.md`

```
# Failed Attempts

<!-- Format per entry:
## Attempt: short description
- **What:** what was tried
- **Result:** what happened
- **Why it failed:** root cause
- **Do not retry unless:** condition that would change the outcome
-->
```

### `.claude/context/CHANGED_FILES.md`

```
# Changed Files

<!-- Format per entry:
## path/to/file.ext
- **Why:** reason for change
- **What changed:** brief summary
- **Last updated:** YYYY-MM-DD
-->
```

### `.claude/context/NEXT_STEPS.md`

```
# Next Steps

## Immediate (do next)
<!-- Ordered list of the very next actions -->

## Upcoming (after immediate)
<!-- Queued work, not yet started -->

## Blocked
<!-- Items waiting on something external -->
```

## Step 4 — Set up automatic hooks

Create `.claude/hooks/` directory, write the hook script, and wire it into `.claude/settings.json`.

**Create `.claude/hooks/ck-inject.sh`** with this exact content:

```bash
#!/usr/bin/env bash
# context-keeper: auto-inject context files into Claude sessions
EVENT="${1:-SessionStart}"

# Stop hook: remind to update context after real work (commits in last 2h)
if [ "$EVENT" = "Stop" ]; then
    if git log --since="2 hours ago" --oneline 2>/dev/null | grep -q .; then
        jq -n '{"systemMessage": "context-keeper: ask me to run context-keeper:update to save session context."}'
    fi
    exit 0
fi

CTX=".claude/context"
[ -d "$CTX" ] || exit 0

CONTENT=""
for f in "$CTX"/*.md; do
    [ -f "$f" ] || continue
    CONTENT="${CONTENT}--- $(basename "$f") ---
$(cat "$f")

"
done

[ -z "$CONTENT" ] && exit 0

if [ "$EVENT" = "PreCompact" ]; then
    jq -n --arg content "$CONTENT" \
        '{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":("IMPORTANT: Invoke context-keeper:compact before compacting this conversation to update and prune context files.\n\nCurrent context files:\n\n"+$content)}}'
else
    jq -n --arg content "$CONTENT" \
        '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":("context-keeper context:\n\n"+$content)}}'
fi
```

After writing the file, make it executable:
```bash
chmod +x .claude/hooks/ck-inject.sh
```

**Create or update `.claude/settings.json`:**

If `.claude/settings.json` already exists, read it first and merge only the `hooks` section into the existing content, preserving all other settings (permissions, env, model, etc.). If it does not exist, create it with:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "timeout": 10,
            "command": "bash .claude/hooks/ck-inject.sh SessionStart 2>/dev/null || true"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "timeout": 10,
            "command": "bash .claude/hooks/ck-inject.sh PreCompact 2>/dev/null || true"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "timeout": 5,
            "command": "bash .claude/hooks/ck-inject.sh Stop 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

**What these hooks do:**
- `SessionStart` — at the start of every Claude session in this repo, reads all `.claude/context/*.md` files and injects their content as additional context automatically. No manual recall needed.
- `PreCompact` — before Claude compacts a long conversation, injects the current context files and a reminder to run `context-keeper:compact` first so context is updated before it disappears.
- `Stop` — after Claude finishes responding, checks if any commits were made in the last 2 hours. If yes, shows a UI message prompting you to ask Claude to run `context-keeper:update`.

## Step 5 — Scan the repo

Inspect the following (read only what exists, skip what doesn't):
- `README.md`
- Package manager files: `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pom.xml`
- Top-level directory listing
- Any `tests/`, `test/`, or `spec/` directories
- Main entrypoints (e.g., `main.py`, `index.ts`, `src/main.rs`, `cmd/`)

Write a concise 3–5 sentence summary into the **Project Context** section of `.claude/context/CURRENT_TASK.md`. Cover: language/stack, main directory layout, testing approach (if visible), key conventions (if visible).

## Step 6 — Ask for the current task

Say: "Context initialized. What is the current task or goal for this session?"

Write their answer into the **Goal** section of `.claude/context/CURRENT_TASK.md`.

## Step 7 — Warn about secrets

Say: "⚠️ Security reminder: never store API keys, tokens, passwords, or connection strings in `.claude/context/` files. If you plan to commit this directory, treat it like any other source file."
