#!/usr/bin/env bash
# Boot a config as an isolated throwaway daemon, probe it, write a report,
# kill it.
# Usage: scripts/myde-probe.sh <init-directory> <output-file>
#
# Isolation:
#   - unique socket name, so the user's running Emacs server is never touched
#   - PATH reduced to /usr/bin:/bin, so binary gates only pass if
#     exec-path-from-shell ran during init (git and the login shell live there
#     on macOS and Linux; everything else must be recovered from the shell)
#   - private XDG_STATE_HOME, so the daemon's exit cannot overwrite the live
#     session's recentf, savehist, and bookmarks
#   - MISE_TRUSTED_CONFIG_PATHS, because the private XDG_STATE_HOME hides
#     mise's trust store, and global-mise-mode's trust prompt reads stdin in a
#     frameless daemon and aborts elpaca-after-init-hook
#   - stdin from /dev/null and a deadline on init, so any other startup
#     prompt fails the probe instead of hanging it (see the boot below)
set -euo pipefail

DIR="${1:?usage: myde-probe.sh <init-directory> <output-file>}"
OUT="${2:?usage: myde-probe.sh <init-directory> <output-file>}"
PROBE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/myde-probe.el"
EMACS="$(command -v emacs)"
SOCK="myde-probe-$$"
STATE="$(mktemp -d "${TMPDIR:-/tmp}/myde-probe-state.XXXXXX")"
LOG="$STATE/daemon.log"

cleanup() {
  emacsclient -s "$SOCK" -e '(kill-emacs)' >/dev/null 2>&1 || true
  # A daemon still in init has no server to take kill-emacs.  On macOS it is
  # also a re-exec'd child of the process started below.  Both carry the
  # unique socket name in their arguments.
  pkill -f -- "${SOCK}( |\$)" 2>/dev/null || true
  rm -rf "$STATE"
}
trap cleanup EXIT

rm -f "$OUT"
echo "booting $DIR as daemon $SOCK ..."
env PATH=/usr/bin:/bin XDG_STATE_HOME="$STATE" MISE_TRUSTED_CONFIG_PATHS="$(cd "$DIR" && pwd)" \
  "$EMACS" --init-directory="$DIR" --daemon="$SOCK" </dev/null >"$LOG" 2>&1 &
BOOT=$!

# `emacs --daemon' returns once init finishes, and elpaca's async builds are
# waited for after that.  A startup prompt can keep init from finishing: its
# read of the empty stdin usually signals end-of-file, but a second prompt
# during elpaca's error report has been seen to spin at 100% CPU instead.
# Emacs prints each prompt before reading, so the log's tail names what asked.
deadline=$((SECONDS + 300))
while kill -0 "$BOOT" 2>/dev/null; do
  if [ "$SECONDS" -gt "$deadline" ]; then
    echo "FAIL: daemon still in init after 5 minutes. Its output ends with:"
    tail -n 5 "$LOG" | sed 's/^/  /'
    exit 1
  fi
  sleep 1
done
wait "$BOOT" || {
  echo "FAIL: daemon did not start. Its output ends with:"
  tail -n 20 "$LOG" | sed 's/^/  /'
  exit 1
}

# Elpaca processes its queues asynchronously after init.  A cold build takes
# minutes, so poll from the shell with a generous deadline rather than
# nesting a wait inside the server process.
deadline=$((SECONDS + 1800))
while [ "$(emacsclient -s "$SOCK" -e '(and (boundp (quote elpaca-after-init-time)) (null elpaca-after-init-time))')" = "t" ]; do
  if [ "$SECONDS" -gt "$deadline" ]; then
    echo "FAIL: elpaca still processing after 30 minutes"
    exit 1
  fi
  sleep 2
done

emacsclient -s "$SOCK" -e "(load \"$PROBE\")" >/dev/null
emacsclient -s "$SOCK" -e "(myde-probe-write \"$OUT\")" >/dev/null

echo "report written to $OUT"
grep -E '^(init-file-had-error|init-time-seconds|elpaca-init-time-seconds):' "$OUT" | sed 's/^/  /'
echo "  declared packages: $(grep -c '^declared: ' "$OUT" || true)"
echo "  loaded packages:   $(grep -c '^loaded: ' "$OUT" || true)"
echo "  modes off:         $(grep -c '^mode: .* off$' "$OUT" || true)"
if grep -q '^error: (none)$' "$OUT"; then
  echo "  startup errors:    none"
else
  echo "  startup errors:    $(grep -c '^error: ' "$OUT")"
fi
