#!/usr/bin/env bash
# context-keeper: find a repo's context directory, and feed it to Claude sessions.
#
#   ck.sh dir                          print the context directory for the current repo
#   ck.sh SessionStart|PreCompact|Stop hook entry points (see the init skill)
#
# Where context lives, first match wins:
#   1. $CONTEXT_KEEPER_HOME/<repo>/context
#   2. <home>/<repo>/context, when a folder ABOVE the repo holds a file named
#      .context-keeper-home whose first line is <home> (absolute, ~/..., or relative
#      to that file). This is "home mode": nothing is ever written inside the repo.
#   3. <repo>/.claude/context, the original repo-local layout.
#
# The hook events act only in home mode (1 or 2). A repo-local repo has its own hooks
# from init, so acting here too would inject its context twice.
#
# <repo> is the main repository's folder name, so git worktrees share one context.
set -u

START="${CLAUDE_PROJECT_DIR:-$PWD}"

# Sets CTX (the context directory) and MODE ("home" or "local").
ck_dir() {
    local top common name home="" d line
    top=$(git -C "$START" rev-parse --show-toplevel 2>/dev/null) || top="$START"
    common=$(cd "$START" 2>/dev/null && cd "$(git rev-parse --git-common-dir 2>/dev/null)" 2>/dev/null && pwd)
    if [ -n "$common" ] && [ "$(basename "$common")" = ".git" ]; then
        name=$(basename "$(dirname "$common")")
    else
        name=$(basename "$top")
    fi

    if [ -n "${CONTEXT_KEEPER_HOME:-}" ]; then
        home="$CONTEXT_KEEPER_HOME"
    else
        d=$(dirname "$top")
        while :; do
            if [ -f "$d/.context-keeper-home" ]; then
                line=$(head -n1 "$d/.context-keeper-home" | tr -d '\r')
                case "$line" in
                    "~/"*) home="$HOME/${line#\~/}" ;;
                    /*) home="$line" ;;
                    "") home="" ;;
                    *) home="$d/$line" ;;
                esac
                break
            fi
            [ "$d" = "/" ] && break
            d=$(dirname "$d")
        done
    fi

    if [ -n "$home" ]; then
        CTX="${home%/}/$name/context"; MODE=home
    else
        CTX="$top/.claude/context"; MODE=local
    fi
}

EVENT="${1:-SessionStart}"
ck_dir

if [ "$EVENT" = "dir" ]; then
    echo "$CTX"
    exit 0
fi

[ "$MODE" = "home" ] || exit 0
[ -d "$CTX" ] || exit 0

# Stop: update on progress, not on a timer. Right after a new commit (or branch
# switch); otherwise at most hourly while there are uncommitted changes; never when
# nothing changed. The state file sits next to the context folder, never inside it,
# and holds "<time of last update> <HEAD then> <working-tree signature then>".
if [ "$EVENT" = "Stop" ]; then
    REPO=$(git -C "$START" rev-parse --show-toplevel 2>/dev/null) || exit 0
    STATE_FILE="$(dirname "$CTX")/state/last-auto-update"
    NOW=$(date +%s)
    HEAD_NOW=$(git -C "$REPO" rev-parse HEAD 2>/dev/null || echo none)
    TREE_NOW=$({ git -C "$REPO" status --porcelain; git -C "$REPO" diff HEAD --shortstat; } 2>/dev/null | sha1sum | cut -c1-12)
    LAST=0 HEAD_LAST="" TREE_LAST=""
    [ -f "$STATE_FILE" ] && read -r LAST HEAD_LAST TREE_LAST < "$STATE_FILE"
    case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac
    save_state() { mkdir -p "$(dirname "$STATE_FILE")"; echo "$NOW $HEAD_NOW $TREE_NOW" > "$STATE_FILE"; }

    # First run, or a state file from the old timer format: start tracking quietly.
    if [ -z "$HEAD_LAST" ]; then save_state; exit 0; fi

    WHY=""
    if [ "$HEAD_NOW" != "$HEAD_LAST" ]; then
        WHY="a new commit (or branch switch) since the last context update"
    elif [ "$TREE_NOW" != "$TREE_LAST" ] && [ $((NOW - LAST)) -ge 3600 ]; then
        WHY="uncommitted changes, and an hour since the last context update"
    fi
    [ -z "$WHY" ] && exit 0
    save_state
    jq -n --arg ctx "$CTX" --arg why "$WHY" '{"decision":"block","reason":("context-keeper: " + $why + ". Invoke the context-keeper:update skill now, autonomously: do not ask the user anything; take decisions and failed attempts from this conversation and skip those steps when there are none. Context files are in " + $ctx + ". Then continue normally.")}'
    exit 0
fi

CONTENT=""
for f in "$CTX"/*.md; do
    [ -f "$f" ] || continue
    [ "$(basename "$f")" = "HANDOFF.md" ] && continue
    CONTENT="${CONTENT}--- $(basename "$f") ---
$(cat "$f")

"
done
[ -z "$CONTENT" ] && exit 0

if [ "$EVENT" = "PreCompact" ]; then
    jq -n --arg content "$CONTENT" --arg ctx "$CTX" \
        '{"hookSpecificOutput":{"hookEventName":"PreCompact","additionalContext":("IMPORTANT: Invoke context-keeper:compact before compacting this conversation to update and prune context files (they live in " + $ctx + ").\n\nCurrent context files:\n\n" + $content)}}'
else
    jq -n --arg content "$CONTENT" --arg ctx "$CTX" \
        '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":("context-keeper context (files in " + $ctx + "):\n\n" + $content)}}'
fi
