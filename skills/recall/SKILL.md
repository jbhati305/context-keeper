name: context-keeper:recall
description: Read the repo's context-keeper memory and resume work. Surfaces current task, open decisions, failed attempts, and next steps before continuing. Use at the start of any session where context-keeper has been initialized, or when the user asks to continue previous work.
---

# context-keeper:recall

You are resuming work using structured session memory.

## Step 1 — Check context exists

Check whether `.claude/context/CURRENT_TASK.md` exists.

If it does not exist: tell the user "No context found. Run `context-keeper:init` first to initialize working memory for this repo." Then stop.

## Step 2 — Read all context files

Read:
- `.claude/context/CURRENT_TASK.md`
- `.claude/context/DECISIONS.md`
- `.claude/context/FAILED_ATTEMPTS.md`
- `.claude/context/CHANGED_FILES.md`
- `.claude/context/NEXT_STEPS.md`

## Step 3 — Output a structured summary

Present the context in this order:

**Current Task**
State the goal and status from `CURRENT_TASK.md`.

**Relevant Files**
List files from `CHANGED_FILES.md` that are relevant to the current goal.

**Open Decisions**
List only `[OPEN]` entries from `DECISIONS.md`. Skip resolved ones.

**⚠️ Failed Attempts — Read Before Acting**
List every entry from `FAILED_ATTEMPTS.md`. For each one, show:
- What was tried
- Why it failed
- Do not retry unless: [condition]

This section is prominent for a reason. Do not attempt any approach listed here unless its stated retry condition is met.

**Next Steps**
Show the Immediate section from `NEXT_STEPS.md`.

## Step 4 — Continue the task

Proceed with the work. Use the context summary to guide your actions. Do not retry any failed approach unless its retry condition is met.
