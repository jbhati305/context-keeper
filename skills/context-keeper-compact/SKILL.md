---
name: context-keeper:compact
description: Prune stale, verbose, or resolved entries from context-keeper memory files. Keeps files concise without losing critical information. Failed attempts are never deleted — only compressed. Use when any context file exceeds 80 lines, or when the user explicitly asks to compact context.
---

# context-keeper:compact

You are compacting the context-keeper working memory to remove stale and verbose content.

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

## Step 3 — Compact DECISIONS.md

Rules:
- Remove any entry marked `[RESOLVED]` whose date is 8 or more days ago, unless another open entry explicitly depends on it.
- Keep all `[OPEN]` entries.
- Do not shorten or rewrite kept entries.

Rewrite the file with only the surviving entries.

## Step 4 — Compact FAILED_ATTEMPTS.md

**Never delete a failed attempt entry.** Only compress verbose ones.

For each entry:
- If the entry is concise (4 fields, each one sentence): leave it unchanged.
- If the entry has verbose narrative, multi-paragraph explanations, or long command output: compress it to the 4 essential fields, each no longer than one sentence.
- The **Do not retry unless** field must be preserved verbatim, never paraphrased.

Rewrite the file with compressed entries.

## Step 5 — Compact CHANGED_FILES.md

Rules:
- Remove any entry for a file that has since been deleted or renamed (verify with `git status --short` or file existence check).
- If a file has only had minor cosmetic changes (formatting, comments, whitespace) and is not mentioned in `NEXT_STEPS.md` or `CURRENT_TASK.md`: collapse it into a single group entry at the bottom titled `## Minor edits` with a comma-separated list of filenames.
- Keep all entries for files that are actively relevant to the current task.

## Step 6 — Compact NEXT_STEPS.md

Rules:
- Remove any item from **Immediate** or **Upcoming** that is clearly completed (cross-reference with `CHANGED_FILES.md` and git status).
- Move any item from **Blocked** to **Upcoming** if the blocker appears to be resolved.
- Do not invent new steps.

Rewrite the file with the cleaned-up lists.

## Step 7 — Update CURRENT_TASK.md

Only update the **Status** field if it needs changing (e.g., from `active` to `paused` or `blocked`). Do not modify any other section.

## Step 8 — Report

Tell the user:
- How many lines were removed from each file.
- Which failed attempt entries were compressed (not deleted).
- Whether any files still exceed 80 lines after compaction.

