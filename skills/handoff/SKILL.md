---
name: context-keeper:handoff
description: Generate a clean, human-readable handoff note from context-keeper memory. Creates .claude/context/HANDOFF.md summarizing current goal, completed work, decisions, failed attempts, changed files, and next steps. Safe to paste into a PR description, Slack message, or a new Claude Code session.
---

# context-keeper:handoff

You are generating a clean handoff document from context-keeper working memory.

## Step 1 — Check context exists

Check whether `.claude/context/CURRENT_TASK.md` exists.

If it does not exist: tell the user "No context found. Run `context-keeper:init` first." Then stop.

## Step 2 — Read all context files

Read:
- `.claude/context/CURRENT_TASK.md`
- `.claude/context/DECISIONS.md`
- `.claude/context/FAILED_ATTEMPTS.md`
- `.claude/context/CHANGED_FILES.md`
- `.claude/context/NEXT_STEPS.md`

## Step 3 — Generate HANDOFF.md

Create or overwrite `.claude/context/HANDOFF.md` with this structure:

```
# Handoff — [Goal from CURRENT_TASK.md]
Generated: YYYY-MM-DD

## Current Goal
[Copy Goal section from CURRENT_TASK.md]

## Scope
[Copy Scope section from CURRENT_TASK.md]

## Completed This Session
[Summarize what was actually done based on CHANGED_FILES.md — which files changed and why]

## Key Decisions
[List all OPEN decisions from DECISIONS.md. List RESOLVED decisions only if they affect future work.]

## ⚠️ Failed Attempts — Do Not Retry
[List every entry from FAILED_ATTEMPTS.md with its Do-not-retry-unless condition]

## Files Changed
[List all entries from CHANGED_FILES.md as a flat bullet list: path — reason]

## Next Steps
[Copy the Immediate and Upcoming sections from NEXT_STEPS.md verbatim]
```

Use today's date for the Generated field. If any section has no content, write "None." rather than leaving it blank.

## Step 4 — Display to user

Show the generated `HANDOFF.md` content in the chat so the user can review it.

Then say: "Saved to `.claude/context/HANDOFF.md`. Safe to paste into a PR description, Slack message, or a new Claude session."

## Step 5 — Warn about secrets

Scan the generated HANDOFF.md for patterns resembling API keys, tokens, or passwords. If found: warn the user and remove or redact those values before saving.

---

After writing, verify:
```bash
head -5 /home/afs/Projects/context-keeper/skills/handoff/SKILL.md
```

Then commit (no Co-Authored-By lines):
```bash
git -C /home/afs/Projects/context-keeper add skills/handoff/SKILL.md
git -C /home/afs/Projects/context-keeper commit -m "feat: add context-keeper:handoff skill"
```

Report: **DONE** or **BLOCKED: [reason]**
