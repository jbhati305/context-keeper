---
name: context-keeper:init
description: Initialize context-keeper working memory in the current repo. Creates .claude/context/ with five structured markdown files for tracking the current task, decisions, failed attempts, changed files, and next steps. Run once per repo before using any other context-keeper skill.
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

## Step 4 — Scan the repo

Inspect the following (read only what exists, skip what doesn't):
- `README.md`
- Package manager files: `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `go.mod`, `pom.xml`
- Top-level directory listing
- Any `tests/`, `test/`, or `spec/` directories
- Main entrypoints (e.g., `main.py`, `index.ts`, `src/main.rs`, `cmd/`)

Write a concise 3–5 sentence summary into the **Project Context** section of `.claude/context/CURRENT_TASK.md`. Cover: language/stack, main directory layout, testing approach (if visible), key conventions (if visible).

## Step 5 — Ask for the current task

Say: "Context initialized. What is the current task or goal for this session?"

Write their answer into the **Goal** section of `.claude/context/CURRENT_TASK.md`.

## Step 6 — Warn about secrets

Say: "⚠️ Security reminder: never store API keys, tokens, passwords, or connection strings in `.claude/context/` files. If you plan to commit this directory, treat it like any other source file."
