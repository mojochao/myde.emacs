#!/usr/bin/env bash
# Claude Code hook: keep myde.org and the elisp tangled from it in step.
#
#   guard   PreToolUse  Edit|Write  -- deny edits to the tangled elisp
#   tangle  PostToolUse Edit|Write  -- re-tangle after myde.org is edited
#
# Reads the hook payload on stdin, writes hook JSON on stdout.  Both modes are
# silent no-ops for any other file, so they cost nothing outside this repo.
# The repo is identified by a myde.org sitting where the file's root should be,
# not by a hard-coded path, so the ~/.config/emacs symlink and the clone both
# resolve the same way.
set -euo pipefail

mode=${1:?usage: claude-tangle-hook.sh guard|tangle}
file=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')
[ -n "$file" ] || exit 0

case "$file" in
  */myde.org)                kind=source;  root=${file%/*}    ;;
  */early-init.el|*/init.el) kind=tangled; root=${file%/*}    ;;
  */user-lisp/myde.el)       kind=tangled; root=${file%/*/*}  ;;
  *)                         exit 0 ;;
esac
[ -f "$root/myde.org" ] || exit 0

case "$mode:$kind" in
  guard:tangled)
    jq -nc --arg f "$file" '{hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ($f + " is tangled from myde.org and any edit here is overwritten by the next tangle. Edit the matching src block in myde.org instead -- the PostToolUse hook re-tangles it for you.")}}'
    ;;
  tangle:source)
    # Reported either way: a tangle that fails silently is the drift this hook exists to prevent.
    if out=$(cd "$root" && mise run tangle 2>&1); then
      jq -nc '{systemMessage: "Re-tangled myde.org -> early-init.el, init.el, user-lisp/myde.el"}'
    else
      jq -nc --arg o "$out" '{systemMessage: ("mise run tangle FAILED: " + $o)}'
    fi
    ;;
esac
exit 0
