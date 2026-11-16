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
# <repo> is the main repository's folder name, so git worktrees share one context.
set -u

START="${CLAUDE_PROJECT_DIR:-$PWD}"

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
        echo "${home%/}/$name/context"
    else
        echo "$top/.claude/context"
    fi
}

EVENT="${1:-SessionStart}"
CTX=$(ck_dir)

if [ "$EVENT" = "dir" ]; then
    echo "$CTX"
    exit 0
fi

[ -d "$CTX" ] || exit 0

# Stop: on a 2-hour cadence, ask Claude to run context-keeper:update. The state
# file sits next to the context folder, never inside it.
if [ "$EVENT" = "Stop" ]; then
    STATE_FILE="$(dirname "$CTX")/state/last-auto-update"
    NOW=$(date +%s)
    LAST=0
    [ -f "$STATE_FILE" ] && LAST=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    if [ $((NOW - LAST)) -ge 7200 ]; then
        mkdir -p "$(dirname "$STATE_FILE")"
        echo "$NOW" > "$STATE_FILE"
        jq -n --arg ctx "$CTX" '{"decision":"block","reason":("context-keeper: 2+ hours have passed since the last automatic context update. Autonomously invoke the context-keeper:update skill now (do not ask the user first) to capture recent changes, decisions, and failed attempts into " + $ctx + "/*.md. Once done, continue normally.")}'
    fi
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
