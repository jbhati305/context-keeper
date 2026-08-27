---
name: context-keeper:init
description: Initialize context-keeper working memory in the current repo. Creates .claude/context/ with five structured markdown files for tracking the current task, decisions, failed attempts, changed files, and next steps. Also sets up automatic hooks so context is injected at session start, before compaction, and updated automatically on a 2-hour cadence. Run once per repo before using any other context-keeper skill.
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

# Stop hook: on a real 2-hour cadence, force an automatic context-keeper
# update instead of just reminding the user. A state file (outside the
# tracked context/ dir, so it never shows up as a commit-worthy diff) records
# when the last auto-update fired, so this only forces a stop-block once per
# 2-hour window rather than on every single Stop event while the window
# holds.
if [ "$EVENT" = "Stop" ]; then
    CTX=".claude/context"
    if [ -d "$CTX" ]; then
        STATE_FILE=".claude/state/last-auto-update"
        NOW=$(date +%s)
        LAST=0
        [ -f "$STATE_FILE" ] && LAST=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
        ELAPSED=$((NOW - LAST))
        if [ "$ELAPSED" -ge 7200 ]; then
            mkdir -p "$(dirname "$STATE_FILE")"
            echo "$NOW" > "$STATE_FILE"
            jq -n '{"decision":"block","reason":"context-keeper: 2+ hours have passed since the last automatic context update. Autonomously invoke the context-keeper:update skill now (do not ask the user first) to capture recent changes, decisions, and failed attempts into .claude/context/*.md. Once done, continue normally."}'
            exit 0
        fi
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

If this is the first time `.claude/settings.json` is created in this repo, also add `.claude/state/` to `.gitignore` (the auto-update cadence tracker is local-only, not meaningful history to commit) unless `.claude/` is already broadly ignored there.

**What these hooks do:**
- `SessionStart` — at the start of every Claude session in this repo, reads all `.claude/context/*.md` files and injects their content as additional context automatically. No manual recall needed.
- `PreCompact` — before Claude compacts a long conversation, injects the current context files and a reminder to run `context-keeper:compact` first so context is updated before it disappears.
- `Stop` — after Claude finishes responding, checks whether 2+ hours have passed since the last automatic update (tracked in `.claude/state/last-auto-update`, not `.claude/context/`, so this never generates noisy commits to the tracked context files). If so, it returns `{"decision":"block","reason":"..."}`, which prevents the turn from ending and feeds the reason back to Claude as an instruction — Claude then runs `context-keeper:update` itself, autonomously, without the user needing to ask.

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
