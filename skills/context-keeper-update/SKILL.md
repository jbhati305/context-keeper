---
name: context-keeper:update
description: Update context-keeper working memory after completing meaningful work. Upserts changed files, decisions, and failed attempts. Rewrites next steps. Suggests compact if files grow long. Also use this skill when you detect a natural stopping point in work (tests passing, bug fixed, feature complete) — offer to update context once at that moment.
---

# context-keeper:update

You are updating the context-keeper working memory after meaningful work.

## Suggest-at-breakpoints rule

When you detect any of these signals during normal work — without being explicitly asked:
- All tests pass after a fix
- A bug is resolved
- A feature is complete
- A git commit was just made

Say once: "Good stopping point — want me to update context-keeper?" Do not repeat this offer until the next natural breakpoint.

---

## Step 1 — Check context exists

Check whether `.claude/context/CURRENT_TASK.md` exists.

If it does not exist: tell the user "No context found. Run `context-keeper:init` first." Then stop.

## Step 2 — Check what changed

Run:
```
git status --short
```

Use this output to identify which files have been modified, added, or deleted since the last commit.

## Step 3 — Upsert CHANGED_FILES.md

For each file shown in `git status --short`:

1. Open `.claude/context/CHANGED_FILES.md`.
2. Search for a `##` heading matching the file path.
3. If found: rewrite that block with updated reason, summary, and today's date.
4. If not found: append a new block at the end.

Format:
```
## path/to/file.ext
- **Why:** [reason for this change]
- **What changed:** [one sentence summary]
- **Last updated:** YYYY-MM-DD
```

Use today's date. If you are unsure why a file changed, ask the user.

## Step 4 — Update DECISIONS.md

Ask the user: "Were any architectural or implementation decisions made during this work?"

If yes:
1. Open `.claude/context/DECISIONS.md`.
2. For each decision: search for an existing `##` heading matching it.
3. If found: update that block.
4. If not found: append a new `[OPEN]` entry.

Format:
```
## [OPEN] Decision title
- **Decision:** what was decided
- **Reason:** why
- **Date:** YYYY-MM-DD
```

If no decisions were made, skip this step.

## Step 5 — Update FAILED_ATTEMPTS.md

Ask the user: "Did anything fail that we should remember to avoid next time?"

If yes:
1. Open `.claude/context/FAILED_ATTEMPTS.md`.
2. For each failure: search for an existing `##` heading matching it.
3. If found: update that block.
4. If not found: append a new entry.

Format:
```
## Attempt: short description
- **What:** what was tried
- **Result:** what happened
- **Why it failed:** root cause
- **Do not retry unless:** condition that would change the outcome
```

If nothing failed, skip this step.

## Step 6 — Rewrite NEXT_STEPS.md

Replace the entire contents of `.claude/context/NEXT_STEPS.md` with a fresh assessment of current state:

```
# Next Steps

## Immediate (do next)
[list the very next 1–3 actions needed]

## Upcoming (after immediate)
[list queued work not yet started]

## Blocked
[list anything waiting on an external dependency — or leave empty]
```

This is a full replace, not an append. Base it on what you know about the current state of the work.

## Step 7 — Check line counts and warn about secrets

For each context file, check its line count:
```
wc -l .claude/context/*.md
```

If any file exceeds 80 lines: say "`.claude/context/[filename]` is getting long. Run `context-keeper:compact` to clean it up." Say this once per update, for the longest offending file only.

Also scan the content you just wrote for patterns resembling API keys, tokens, or passwords (long alphanumeric strings, strings matching `sk-...`, `Bearer ...`, `password=...`). If found: warn the user and do not write those values into context files.

