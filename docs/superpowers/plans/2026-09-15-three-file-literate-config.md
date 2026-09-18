# Three-File Literate Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Build commands here are historical.** The `Makefile` was replaced on
> 2026-09-18 by mise tasks and hk hooks, so read every `make <target>` below
> as `mise run <target>`, and the `Makefile` edits as edits to `mise.toml`.

**Goal:** Replace 53 module directories and 24 `defcustom` toggles with three elisp files tangled from a single `myde.org`, enabling modules by binary presence and managing packages with elpaca.

**Architecture:** Three sequential phases, each leaving a working config and each verified by a probe harness that captures the observable state of a running Emacs: the set of declared `use-package` forms, the global modes turned on at startup, init time, and startup errors. Phase 1 flattens the tree and replaces toggles with `executable-find` gates in one pass, phase 2 swaps `package.el` for elpaca, phase 3 makes the source literate. All work happens in a git worktree so the live config at `~/.config/emacs` (a symlink into this repo) stays functional throughout.

**Tech Stack:** Emacs 31.1, `use-package`, elpaca 0.12, `org-babel-tangle`, `exec-path-from-shell`, GNU Make.

**Spec:** `docs/superpowers/specs/2026-09-15-three-file-literate-config-design.md`

**Revision:** 2026-09-15, after adversarial review. The toggle-preserving phase is gone, the probe measures declared packages rather than loaded ones, and phase 2 gained the startup-hook rewrite. See the spec's "Why there is no toggle-preserving phase" and "Probe isolation".

---

## Critical context for someone with zero familiarity

Read this before Task 0. Each item is a live hazard discovered while writing or reviewing this plan.

1. **`~/.config/emacs` is a symlink to this repository.** Editing files in the main
   working tree changes the running config immediately. All work happens in a git
   worktree at `/tmp/myde-migration`, exercised via `emacs --init-directory=`.

2. **`custom.el` is gitignored and untracked.** A fresh worktree has no `custom.el`,
   which means no module toggles are set, which means only `core-*` modules load.
   It must be copied into the worktree by hand or the baseline is meaningless.

3. **`elpa/` is gitignored.** A fresh worktree has no packages. For phase 1 symlink it
   to the main tree's `elpa/` to avoid a 100-package reinstall. Phase 2 deliberately
   starts from nothing.

4. **`--batch` and `-Q` both imply `--no-init-file`.** Neither can be used to test a
   config. Use `--daemon=<unique-socket>` plus `emacsclient -s <socket>`. Always use a
   unique socket name so the probe never touches the user's running Emacs server.

5. **A probe daemon inherits the terminal's PATH and shares the live session's XDG
   state.** The driver script strips PATH to `/usr/bin:/bin` so gates only pass if
   `exec-path-from-shell` ran, and points `XDG_STATE_HOME` at a scratch directory so
   the daemon's exit cannot overwrite the live recentf/savehist/bookmarks.

6. **`load-history` misses deferred packages.** Most language and data modules are
   `:mode`- or `:hook`-deferred and never load at startup, so a comparison on loaded
   packages is blind to gating. The probe's primary metric is the set of *declared*
   packages from `use-package-statistics`, which needs
   `use-package-compute-statistics t` set in `early-init.el` before the config loads.

7. **A third-party `use-package` placed before `package-initialize` fails**, even
   when the package is installed under `elpa/`. Under `package.el` (phase 1) the
   `exec-path-from-shell` form must come *after* the core-base section, which is
   where `package-initialize` lives. That position is kept under elpaca too.

8. **elpaca queues the order *outside* the `use-package` form.** `:if`/`:when` inside
   the form cannot prevent a clone. Gates must wrap the whole form in `(when …)`.

9. **elpaca runs `use-package` bodies after `after-init-hook` has fired.** Fourteen
   forms use `:hook (after-init . <global-mode>)`, one uses `(emacs-startup . …)`,
   and dashboard installs its own startup hooks. All of them silently do nothing
   under elpaca until rewritten to `elpaca-after-init`. Task 7 does this; the probe's
   startup-mode list catches any that are missed.

10. **`elpaca-use-package` has no ensure-by-default variable of its own.** The
    standard `use-package-always-ensure t` is the knob. It turns the 26 third-party
    forms without `:ensure` into `:ensure t` — and would also try to clone the 6
    built-in forms without `:ensure` (3 `treesit`, 3 `project`). Task 6 gives those
    `:ensure nil` first.

11. **Three `load-file-name` uses are load-bearing** and break on flattening, plus two
    hardcoded `modules/core-dashboard/` paths. Task 1 relocates the assets they point
    at. The other 33 `load-file-name` uses are `featurep` guards that get deleted.

12. **`server-name` is still `"server"` while `init.el` runs under `--daemon=NAME`.**
    An unguarded `(server-start)` in `init.el` grabs the user's default socket. The
    new `init.el` skips server start when `(daemonp)`; startup.el starts the daemon's
    own server afterwards.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `scripts/myde-probe.el` | Captures observable config state (declared packages, startup modes, loaded packages, init time, errors) from a running Emacs. The verification harness for every phase. |
| `scripts/myde-probe.sh` | Boots a config as an isolated throwaway daemon, waits for elpaca, runs the probe, writes a report, kills the daemon. |
| `scripts/myde-flatten.el` | One-shot generator: concatenates 53 module files into `user-lisp/myde.el` in `myde-modules` order. Deleted at the end of phase 1. |
| `user-lisp/myde.el` | All configuration. Tangled output from phase 3 onward. |
| `myde.org` | Literate source for all three elisp files. Phase 3. |
| `snippets/go/`, `snippets/elixir/` | Relocated flat yasnippet dirs. |
| `etc/myde-banner.png`, `etc/myde-banner.txt`, `etc/preview/mermaid-init.js` | Relocated assets. |

**Modified:** `early-init.el`, `init.el`, `custom.el`, `Makefile`, `.gitignore`,
`.agents/AGENTS.md`, `.agents/skills/myde/SKILL.md`, `README.md`

Note on paths: `CLAUDE.md` and `AGENTS.md` are both symlinks to `.agents/AGENTS.md`, and
`.claude/skills` is a symlink to `.agents/skills`. Always edit and `git add` the
`.agents/` paths.

**Deleted:** `modules/` (53 dirs, 106 `.el` files, 8 stale `.elc`), `modules.el`

---

## Task 0: Worktree and baseline harness

This is the test-first task. Nothing may be migrated until a baseline exists.

**Files:**
- Modify: `early-init.el` (one line)
- Create: `scripts/myde-probe.el`
- Create: `scripts/myde-probe.sh`

- [ ] **Step 1: Create the worktree and branch**

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
git worktree add /tmp/myde-migration -b migration/three-file-literate
```

Expected: `Preparing worktree (new branch 'migration/three-file-literate')` followed by
`HEAD is now at <current main HEAD>`.

- [ ] **Step 2: Wire the untracked and ignored files into the worktree**

Without this the worktree loads only `core-*` modules and every comparison is void.

```bash
MAIN=/Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
cp "$MAIN/custom.el" /tmp/myde-migration/custom.el
ln -s "$MAIN/elpa" /tmp/myde-migration/elpa
ls -l /tmp/myde-migration/custom.el /tmp/myde-migration/elpa
```

Expected: a regular file ~3.6K and a symlink to the main tree's `elpa`.

The `.gitignore` entry `elpa/` has a trailing slash, so it matches directories only —
and git treats a symlink as a file. Without excluding it, `git add -A` in later tasks
would commit the symlink:

```bash
cd /tmp/myde-migration
echo 'elpa' >> "$(git rev-parse --git-path info/exclude)"
git status --porcelain
```

Expected: empty output. Anything listed here will be swept up by a later `git add -A`.

- [ ] **Step 3: Enable use-package statistics**

The probe's primary metric is the set of declared `use-package` forms, read from
`use-package-statistics`. That table is only populated when
`use-package-compute-statistics` is non-nil *before* any `use-package` form is
evaluated, so it belongs in `early-init.el`. It also powers `M-x use-package-report`,
which the follow-up deferral audit uses.

In `/tmp/myde-migration/early-init.el`, immediately after the existing
`use-package-verbose` / `use-package-minimum-reported-time` `setq` (around line 79),
add:

```elisp
;; Record every evaluated use-package form.  Read by scripts/myde-probe.el to
;; compare declared package sets across migration phases, and by
;; M-x use-package-report afterwards.  Cheap enough to leave on permanently.
(setq use-package-compute-statistics t)
```

- [ ] **Step 4: Write the probe**

Create `/tmp/myde-migration/scripts/myde-probe.el`:

```elisp
;;; myde-probe.el --- Capture observable config state -*- lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;;; Commentary:
;; Loaded into an already-started Emacs via emacsclient.  Writes a stable,
;; diffable report of what the config actually did, for before/after comparison
;; across migration phases.  Not part of the config; lives under scripts/.
;;
;; The primary metric is the set of *declared* packages: every `use-package'
;; form that was evaluated, read from `use-package-statistics'.  It is
;; gate-sensitive (a form inside a false `when' is never expanded) and it
;; includes deferred packages, which `load-history' does not.  It requires
;; `use-package-compute-statistics' to be t before the config loads.

;;; Code:

(defconst myde-probe-gate-binaries
  '("go" "cargo" "zig" "lua" "ruby" "python3" "node" "elixir" "erl" "clojure"
    "guile" "sbcl" "clangd" "fish" "nu" "pdftoppm" "op" "kubectl" "claude")
  "Binaries that gate a module section in myde.el.
Keep in sync with the gate table in the spec.")

(defconst myde-probe-startup-modes
  '(buffer-guardian-mode vertico-mode marginalia-mode global-corfu-mode
    editorconfig-mode global-treesit-auto-mode global-flycheck-mode
    global-mise-mode global-diff-hl-mode which-key-mode spacious-padding-mode
    yas-global-mode whole-line-or-region-global-mode)
  "Global modes the config enables from startup hooks.
Under elpaca a `:hook (after-init . fn)' never fires, so these are the
canaries for that failure.  Dashboard is not listed; it is verified in the GUI.")

(defun myde-probe-declared-packages ()
  "Return sorted names of every `use-package' form that was evaluated."
  (let ((names '()))
    (when (boundp 'use-package-statistics)
      (maphash (lambda (k _v) (push (symbol-name k) names))
               use-package-statistics))
    (sort names #'string<)))

(defun myde-probe--package-name (dir)
  "Return package name for elpa/elpaca build directory DIR.
Strips a trailing MELPA-style or semver version from elpa directories.
Elpaca build directories carry no version, so DIR is returned unchanged."
  (replace-regexp-in-string
   "-\\(?:[0-9]\\{8\\}\\(?:\\.[0-9]+\\)?\\|[0-9]+\\(?:\\.[0-9]+\\)*\\)\\'" "" dir))

(defun myde-probe-loaded-packages ()
  "Return a sorted list of third-party packages with a file in `load-history'.
Secondary metric: only packages actually loaded at startup appear here."
  (let ((names '()))
    (dolist (entry load-history)
      (let ((file (car entry)))
        (when (and (stringp file)
                   (string-match "/\\(?:elpa\\|elpaca/builds\\)/\\([^/]+\\)/" file))
          (let ((name (myde-probe--package-name (match-string 1 file))))
            (unless (member name names) (push name names))))))
    (sort names #'string<)))

(defun myde-probe-startup-errors ()
  "Return startup error lines found in the *Messages* buffer."
  (let ((hits '()))
    (with-current-buffer (messages-buffer)
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward
                (concat "^\\(.*\\(?:"
                        "Invalid function\\|Symbol's value as variable is void\\|"
                        "Symbol's function definition is void\\|"
                        "error in process\\|Wrong type argument\\|"
                        "Wrong number of arguments\\|"
                        "use-package.*Error\\|Package.*is unavailable\\|"
                        "Failed to\\|Cannot open load file\\|Cannot load"
                        "\\).*\\)$")
                nil t)
          (push (string-trim (match-string 1)) hits))))
    (nreverse hits)))

(defun myde-probe-enabled-modules ()
  "Return sorted `myde-module-*-enabled' variables that are non-nil.
Only meaningful for the baseline; empty once the toggles are gone."
  (let ((found '()))
    (mapatoms
     (lambda (sym)
       (when (and (string-match "\\`myde-module-\\(.+\\)-enabled\\'" (symbol-name sym))
                  (boundp sym)
                  (symbol-value sym))
         (push (match-string 1 (symbol-name sym)) found))))
    (sort found #'string<)))

(defun myde-probe--seconds-since-start (time)
  "Format TIME as seconds since `before-init-time', or n/a if TIME is nil."
  (if time
      (format "%.3f" (float-time (time-subtract time before-init-time)))
    "n/a"))

(defun myde-probe-write (out)
  "Write the probe report to file OUT."
  (with-temp-file out
    (insert ";; myde probe report\n")
    (insert (format "emacs-version: %s\n" emacs-version))
    (insert (format "init-file-had-error: %s\n" init-file-had-error))
    (insert (format "init-time-seconds: %s\n"
                    (myde-probe--seconds-since-start after-init-time)))
    (insert (format "elpaca-init-time-seconds: %s\n"
                    (myde-probe--seconds-since-start
                     (bound-and-true-p elpaca-after-init-time))))
    (insert (format "exec-path-entries: %d\n" (length exec-path)))
    (insert "\n;; enabled modules (toggles; empty once they are gone)\n")
    (dolist (m (myde-probe-enabled-modules)) (insert (format "module: %s\n" m)))
    (insert "\n;; gate binaries\n")
    (dolist (b myde-probe-gate-binaries)
      (insert (format "binary: %-10s %s\n" b (if (executable-find b) "yes" "no"))))
    (insert "\n;; startup modes\n")
    (dolist (m myde-probe-startup-modes)
      (insert (format "mode: %-34s %s\n" m
                      (if (and (boundp m) (symbol-value m)) "on" "off"))))
    (insert "\n;; declared packages (every evaluated use-package form)\n")
    (dolist (p (myde-probe-declared-packages)) (insert (format "declared: %s\n" p)))
    (insert "\n;; loaded third-party packages (load-history)\n")
    (dolist (p (myde-probe-loaded-packages)) (insert (format "loaded: %s\n" p)))
    (insert "\n;; startup errors\n")
    (let ((errs (myde-probe-startup-errors)))
      (if errs
          (dolist (e errs) (insert (format "error: %s\n" e)))
        (insert "error: (none)\n")))))

(provide 'myde-probe)
;;; myde-probe.el ends here
```

- [ ] **Step 5: Write the probe driver**

Create `/tmp/myde-migration/scripts/myde-probe.sh`:

```bash
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
set -euo pipefail

DIR="${1:?usage: myde-probe.sh <init-directory> <output-file>}"
OUT="${2:?usage: myde-probe.sh <init-directory> <output-file>}"
PROBE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/myde-probe.el"
EMACS="$(command -v emacs)"
SOCK="myde-probe-$$"
STATE="$(mktemp -d "${TMPDIR:-/tmp}/myde-probe-state.XXXXXX")"

cleanup() {
  emacsclient -s "$SOCK" -e '(kill-emacs)' >/dev/null 2>&1 || true
  rm -rf "$STATE"
}
trap cleanup EXIT

rm -f "$OUT"
echo "booting $DIR as daemon $SOCK ..."
env PATH=/usr/bin:/bin XDG_STATE_HOME="$STATE" \
  "$EMACS" --init-directory="$DIR" --daemon="$SOCK" >/dev/null 2>&1 || {
  echo "FAIL: daemon did not start. Run without redirection to see why:"
  echo "  env PATH=/usr/bin:/bin XDG_STATE_HOME=/tmp/x $EMACS --init-directory=$DIR --daemon=$SOCK"
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
```

```bash
chmod +x /tmp/myde-migration/scripts/myde-probe.sh
```

- [ ] **Step 6: Capture the baseline**

The worktree at this point *is* the current config plus the statistics line. This
report is the contract every later phase is compared against.

```bash
mkdir -p /tmp/myde-reports
cd /tmp/myde-migration
scripts/myde-probe.sh "$PWD" /tmp/myde-reports/00-baseline.txt
grep -c '^module: ' /tmp/myde-reports/00-baseline.txt
grep '^binary: ' /tmp/myde-reports/00-baseline.txt | grep -c yes
grep '^mode: ' /tmp/myde-reports/00-baseline.txt
```

Expected: `init-file-had-error: nil`; `24` modules; declared packages somewhere in the
150-200 range (every `use-package` form in the 24 enabled modules plus core, including
built-ins like `emacs` and `treesit`); a printed error count.

Expected `yes` count: **0**. The current config only runs `exec-path-from-shell` when
`window-system` is `mac`/`ns`, which a daemon is not, and the driver stripped PATH.
This is correct for the baseline and is exactly what phase 1 changes.

Expected modes: most `on`. Record which are `off` in the baseline — some may
legitimately be off in a frameless daemon — because later phases are compared against
this list, not against "all on".

- [ ] **Step 7: Record the predicted additions**

Phase 1 turns on 11 modules. The packages they declare are knowable now, from the
module tree, and become the expected delta in Task 4:

```bash
cd /tmp/myde-migration
for m in prog-clojure prog-cpp prog-elixir prog-erlang prog-lua prog-ruby \
         prog-rust prog-scheme prog-zig text-asciidoc auth-1password; do
  cat modules/$m/lib.el modules/$m/cfg.el 2>/dev/null
done | grep -oE '\(use-package [^ )]+' | awk '{print $2}' | sort -u \
  > /tmp/myde-reports/00-expected-new.txt
wc -l < /tmp/myde-reports/00-expected-new.txt
cat /tmp/myde-reports/00-expected-new.txt
```

Expected: a few dozen names. Eyeball the list for anything that is not a package
name (a `grep` hit inside a comment, say) and remove it by hand.

- [ ] **Step 8: Verify the probe detects a broken config**

A harness that cannot fail is not a harness.

```bash
mkdir -p /tmp/myde-broken
printf '(require (quote definitely-not-a-real-package))\n' > /tmp/myde-broken/init.el
/tmp/myde-migration/scripts/myde-probe.sh /tmp/myde-broken /tmp/myde-reports/00-sanity.txt
grep -E '^(init-file-had-error|error): ' /tmp/myde-reports/00-sanity.txt
rm -rf /tmp/myde-broken
```

Expected: `init-file-had-error: t` and at least one `error:` line mentioning
`Cannot open load file`. If `init-file-had-error` is `t` but no `error:` line
appears, the `*Messages*` regexp is too narrow; widen it, but the flag alone is
already sufficient to fail a phase.

- [ ] **Step 9: Commit the harness**

```bash
cd /tmp/myde-migration
git add early-init.el scripts/
git commit -m "Add config probe harness for migration verification

Captures declared use-package forms (via use-package-statistics),
startup-enabled global modes, gate binary availability, loaded
third-party packages, init time, and startup errors from a running Emacs
via an isolated throwaway daemon. Baseline for comparing each migration
phase.

The daemon runs with PATH=/usr/bin:/bin so binary gates only pass when
exec-path-from-shell ran, and with a private XDG_STATE_HOME so exiting
cannot clobber the live session's state files.

Enables use-package-compute-statistics in early-init.el, which the probe
depends on and which powers M-x use-package-report.

--batch and -Q both imply --no-init-file, so a daemon is the only way to
exercise a config non-interactively."
```

---

# Phase 1 — Flatten and gate

Goal: one `user-lisp/myde.el` containing everything, enablement derived from
`executable-find`, `package.el` still in force, declared package set equal to the
baseline plus exactly the packages of the 11 newly-live modules.

## Task 1: Relocate module assets

Five references break when `modules/` is deleted. Fix them before flattening.

**Files:**
- Move: `modules/prog-go/snippets/*` → `snippets/go/`
- Move: `modules/prog-elixir/snippets/*` → `snippets/elixir/`
- Move: `modules/core-dashboard/myde-banner.{png,txt}` → `etc/`
- Move: `modules/text-markdown/preview/mermaid-init.js` → `etc/preview/`
- Modify: `modules/core-dashboard/lib.el:23-29`
- Modify: `modules/prog-go/cfg.el:130-132`
- Modify: `modules/prog-elixir/cfg.el:280-282`
- Modify: `modules/text-markdown/lib.el:33-35`

- [ ] **Step 1: Move the asset files**

```bash
cd /tmp/myde-migration
mkdir -p snippets/go snippets/elixir etc/preview
git mv modules/prog-go/snippets/* snippets/go/
git mv modules/prog-elixir/snippets/* snippets/elixir/
git mv modules/core-dashboard/myde-banner.png etc/myde-banner.png
git mv modules/core-dashboard/myde-banner.txt etc/myde-banner.txt
git mv modules/text-markdown/preview/mermaid-init.js etc/preview/mermaid-init.js
ls snippets/go | wc -l && ls snippets/elixir | wc -l
```

Expected: `17` then `7`.

- [ ] **Step 2: Repoint the dashboard banner paths**

In `modules/core-dashboard/lib.el`, replace lines 23-29:

```elisp
(defvar myde-banner-image-file
  (expand-file-name "etc/myde-banner.png" user-emacs-directory)
  "Path to the dashboard banner image file.")

(defvar myde-banner-text-file
  (expand-file-name "etc/myde-banner.txt" user-emacs-directory)
  "Path to the dashboard banner text fallback file.")
```

- [ ] **Step 3: Repoint the Go snippets registration**

In `modules/prog-go/cfg.el`, replace the `myde-register-snippets` call at lines 130-132:

```elisp
(myde-register-snippets
 (expand-file-name "snippets/go" user-emacs-directory)
 'go-ts-mode)
```

- [ ] **Step 4: Repoint the Elixir snippets registration**

In `modules/prog-elixir/cfg.el`, replace the `myde-register-snippets` call at lines 280-282:

```elisp
(myde-register-snippets
 (expand-file-name "snippets/elixir" user-emacs-directory)
 'elixir-ts-mode)
```

- [ ] **Step 5: Repoint the markdown preview asset directory**

In `modules/text-markdown/lib.el`, replace lines 33-35. The `defconst` no longer needs
`load-file-name` at all:

```elisp
(defconst myde-text-markdown-dir
  (expand-file-name "etc/" user-emacs-directory)
  "Directory containing text-markdown module assets.")
```

The call site in `modules/text-markdown/cfg.el:96` passes `"preview/mermaid-init.js"`,
which resolves correctly against `etc/` after the move in step 1. Leave it unchanged.

- [ ] **Step 6: Verify no regression**

```bash
cd /tmp/myde-migration
scripts/myde-probe.sh "$PWD" /tmp/myde-reports/01-assets.txt
diff <(grep -E '^(module|declared|mode): ' /tmp/myde-reports/00-baseline.txt) \
     <(grep -E '^(module|declared|mode): ' /tmp/myde-reports/01-assets.txt) && echo "IDENTICAL"
comm -13 <(grep '^error: ' /tmp/myde-reports/00-baseline.txt | sort) \
         <(grep '^error: ' /tmp/myde-reports/01-assets.txt | sort)
```

Expected: `IDENTICAL`, and the `comm` prints nothing (no new errors).

- [ ] **Step 7: Verify the banner and snippets actually resolve**

The probe does not cover file existence. Check directly:

```bash
emacs --init-directory=/tmp/myde-migration --daemon=assetcheck >/dev/null 2>&1
emacsclient -s assetcheck -e '(list (file-exists-p myde-banner-image-file)
                                    (file-exists-p myde-banner-text-file)
                                    (file-exists-p (expand-file-name "preview/mermaid-init.js" myde-text-markdown-dir))
                                    (file-directory-p (expand-file-name "snippets/go" user-emacs-directory)))'
emacsclient -s assetcheck -e '(kill-emacs)'
```

Expected: `(t t t t)`. Any `nil` means a path in steps 2-5 is wrong.

- [ ] **Step 8: Commit**

```bash
cd /tmp/myde-migration
git add -A
git commit -m "Move module assets out of modules/ tree

Snippets to snippets/{go,elixir}/, dashboard banner and markdown preview
asset to etc/. Repoints the three load-file-name-relative lookups and the
two hardcoded modules/core-dashboard/ paths at user-emacs-directory, so
they survive the flattening in the next commit."
```

## Task 2: Generate the flattened myde.el

**Files:**
- Create: `scripts/myde-flatten.el`
- Create: `user-lisp/myde.el` (generated)

- [ ] **Step 1: Write the generator**

Create `scripts/myde-flatten.el`. It reads module order from `init.el` so the generated
file cannot drift from the declared load order:

```elisp
;;; myde-flatten.el --- One-shot module flattener -*- lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;;; Commentary:
;; Concatenates modules/<name>/{lib,cfg}.el into user-lisp/myde.el in the order
;; declared by `myde-modules' in init.el.  Strips per-file headers, `featurep'
;; guards, and `provide' forms.  Run once during phase 1 of the migration, then
;; deleted -- myde.el becomes the source of truth (and later, myde.org does).
;;
;; Usage: MYDE_ROOT=<repo> emacs -Q --batch -l scripts/myde-flatten.el

;;; Code:

(require 'subr-x)

(defconst myde-flatten-root
  (or (getenv "MYDE_ROOT") default-directory))

(defun myde-flatten--module-names ()
  "Return module names in declared order by parsing `myde-modules' in init.el."
  (let ((names '()))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "init.el" myde-flatten-root))
      (goto-char (point-min))
      (while (re-search-forward "(myde/m +\"\\([^\"]+\\)\"" nil t)
        (push (match-string 1) names)))
    (nreverse names)))

(defun myde-flatten--body (file)
  "Return the meaningful body of FILE: no header, no guard, no provide."
  (with-temp-buffer
    (insert-file-contents file)
    ;; Drop everything through the ";;; Code:" marker.
    (goto-char (point-min))
    (when (re-search-forward "^;;; Code:[ \t]*\n" nil t)
      (delete-region (point-min) (point)))
    ;; Drop the trailing provide form and the "ends here" line.
    (goto-char (point-min))
    (when (re-search-forward "^(provide '[^)]+)" nil t)
      (delete-region (match-beginning 0) (point-max)))
    ;; Drop the lib.el-loading featurep guard (one form in the tree uses `load'
    ;; rather than `load-file'; both are matched).  Every guard in the tree is
    ;; two lines; verified before writing this.
    (goto-char (point-min))
    (while (re-search-forward "^(unless (featurep '[^)]+)\n[ \t]*(load\\(?:-file\\)? .*\n" nil t)
      (replace-match ""))
    (string-trim (buffer-string))))

(defun myde-flatten-run ()
  "Generate user-lisp/myde.el from the module tree."
  (let* ((names (myde-flatten--module-names))
         (out (expand-file-name "user-lisp/myde.el" myde-flatten-root)))
    (make-directory (file-name-directory out) t)
    (with-temp-file out
      (insert ";;; myde.el --- MyDE configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-\n\n")
      (insert ";; Copyright (C) 2020-2026  Allen Gooch\n\n")
      (insert ";; Author:   Allen Gooch <allen.gooch@gmail.com>\n")
      (insert ";; URL:      https://github.com/mojochao/myde.emacs\n")
      (insert ";; Keywords: convenience, configuration\n")
      (insert ";; Package-Requires: ((emacs \"31.1\"))\n\n")
      (insert ";; This file is not part of GNU Emacs.\n\n")
      (insert ";; Released under the MIT License; see the LICENSE file at the repository\n")
      (insert ";; root for the full text.\n\n")
      (insert ";;; Commentary:\n;;\n;; The whole of MyDE.  Loaded from init.el via (require 'myde).\n\n")
      (insert ";;; Code:\n\n")
      (dolist (name names)
        (let* ((dir (expand-file-name (concat "modules/" name) myde-flatten-root))
               (lib (expand-file-name "lib.el" dir))
               (cfg (expand-file-name "cfg.el" dir)))
          (insert (format "\n;;;; %s\n;;;; %s\n\n"
                          name (make-string (max 8 (length name)) ?-)))
          (when (file-exists-p lib)
            (insert (myde-flatten--body lib) "\n\n"))
          (when (file-exists-p cfg)
            (insert (myde-flatten--body cfg) "\n\n"))))
      (insert "\n(provide 'myde)\n;;; myde.el ends here\n"))
    (message "wrote %s" out)))

(myde-flatten-run)
;;; myde-flatten.el ends here
```

- [ ] **Step 2: Run it**

```bash
cd /tmp/myde-migration
MYDE_ROOT=/tmp/myde-migration emacs -Q --batch -l scripts/myde-flatten.el
wc -l user-lisp/myde.el
```

Expected: `wrote /tmp/myde-migration/user-lisp/myde.el` and a line count between
7,500 and 8,300.

- [ ] **Step 3: Verify it reads as valid elisp**

Catches unbalanced parens from a bad strip before anything tries to load it.

```bash
emacs -Q --batch --eval '(with-temp-buffer
  (insert-file-contents "/tmp/myde-migration/user-lisp/myde.el")
  (goto-char (point-min))
  (let ((n 0))
    (condition-case e
        (while t (read (current-buffer)) (setq n (1+ n)))
      (end-of-file (message "OK: %d top-level forms" n))
      (error (message "PARSE FAIL after %d forms: %S" n e) (kill-emacs 1)))))'
```

Expected: `OK: N top-level forms` with N in the 400-600 range. A `PARSE FAIL` means
`myde-flatten--body` mangled a file — inspect the form count to locate roughly where.

- [ ] **Step 4: Verify no stray provides, guards, or load-file-name uses survived**

```bash
cd /tmp/myde-migration
grep -n "provide 'myde-" user-lisp/myde.el || echo "no stray provides"
grep -n 'featurep .myde-' user-lisp/myde.el || echo "no stray guards"
grep -n 'load-file-name' user-lisp/myde.el || echo "no load-file-name uses"
```

Expected: all three print their "no ..." message. Any hit is a generator bug —
`load-file-name` in particular would resolve to `user-lisp/` and silently misbehave.

- [ ] **Step 5: Commit the generated file**

```bash
git add scripts/myde-flatten.el user-lisp/myde.el
git commit -m "Generate flattened user-lisp/myde.el from module tree

Concatenates all 53 modules' lib.el and cfg.el in myde-modules order,
stripping per-file headers, featurep guards, and provide forms. Not yet
loaded by init.el; the next commits gate it and switch over.

scripts/myde-flatten.el is one-shot tooling, removed at the end of phase 1."
```

## Task 3: Environment section and binary gates

One wrapping pass. Each toggleable section either becomes unconditional (its `when`
is simply never written) or gets wrapped in its `executable-find` gate.

**Files:**
- Modify: `user-lisp/myde.el`

- [ ] **Step 1: Verify the `-l` assumption on this machine**

```bash
diff <($SHELL -l -c 'printf %s "$PATH"' | tr ':' '\n' | sort -u) \
     <($SHELL -l -i -c 'printf %s "$PATH"' 2>/dev/null | tr ':' '\n' | sort -u) \
  && echo "SAFE: -l is sufficient" || echo "UNSAFE: keep -l -i on this machine"
```

Expected on the macOS machine: `SAFE`. **Re-run this on the Linux machine before
trusting the config there** — if it reports `UNSAFE`, use `'("-l" "-i")` there and
accept the ~575ms.

- [ ] **Step 2: Remove the old deferred exec-path-from-shell hook**

In `user-lisp/myde.el`, within the `;;;; core-base` section, delete the
`myde-exec-path-from-shell-startup-hook` function definition (carried over from
`core-base/lib.el:38-49`) and the block carried over from `core-base/cfg.el:108-115`:

```elisp
;; Environment variables from shell initialization
;; NOTE: ...
(when (memq window-system '(mac ns))
  (add-hook 'emacs-startup-hook #'myde-exec-path-from-shell-startup-hook 90))
```

```bash
grep -n 'exec-path-from-shell' /tmp/myde-migration/user-lisp/myde.el
```

Expected after editing: only the comment line from the core-base commentary, if the
flattener kept it; no code.

- [ ] **Step 3: Insert the Environment section after core-base**

Find the `;;;; core-ui` section header — the first header after the core-base
section — and insert this immediately before it:

```elisp
;;;; Environment
;;;; -----------
;; Must precede every `executable-find' gate below.  GUI Emacs on macOS, and
;; Emacs started from a .desktop entry or systemd user unit on Linux, do not
;; inherit the login shell's PATH -- so without this, gates would silently
;; disable modules whose binaries are installed.
;;
;; Sits after core-base rather than first in the file: under package.el a
;; third-party package cannot be required before `package-initialize', which
;; core-base runs.  The position is harmless under elpaca and is kept fixed.
;;
;; Dropping "-i" from the default '("-l" "-i") takes the probe from ~575ms to
;; ~88ms with an identical resulting PATH, and keeps it under
;; `exec-path-from-shell-warn-duration-millis' (500).

(use-package exec-path-from-shell
  :ensure t
  :demand t
  :init
  (setq exec-path-from-shell-arguments '("-l"))
  :config
  (when (or (daemonp) window-system)
    (exec-path-from-shell-initialize)))
```

`:ensure t` here, not `:ensure (:wait t)` — that changes in Task 7 when elpaca
arrives.

- [ ] **Step 4: Wrap the gated sections**

For each section below, wrap the whole section body — every form between its `;;;;`
header and the next section's header — in a `when`, and add a `;; Gate:` comment so
the rule is legible without consulting this plan:

```elisp
;;;; prog-go
;;;; -------
;; Gate: go

(when (executable-find "go")

  ;; ... existing section body, indented or not, unchanged ...

  )
```

| Section | `when` condition |
|---|---|
| `prog-go` | `(executable-find "go")` |
| `prog-rust` | `(executable-find "cargo")` |
| `prog-zig` | `(executable-find "zig")` |
| `prog-lua` | `(executable-find "lua")` |
| `prog-ruby` | `(executable-find "ruby")` |
| `prog-python` | `(executable-find "python3")` |
| `prog-javascript` | `(executable-find "node")` |
| `prog-typescript` | `(executable-find "node")` |
| `prog-elixir` | `(executable-find "elixir")` |
| `prog-erlang` | `(executable-find "erl")` |
| `prog-clojure` | `(executable-find "clojure")` |
| `prog-scheme` | `(executable-find "guile")` |
| `prog-clisp` | `(executable-find "sbcl")` |
| `prog-cpp` | `(executable-find "clangd")` |
| `prog-fish` | `(executable-find "fish")` |
| `prog-nushell` | `(executable-find "nu")` |
| `ebook-pdf` | `(executable-find "pdftoppm")` |
| `auth-1password` | `(executable-find "op")` |
| `containers-kubernetes` | `(executable-find "kubectl")` |
| `ai-claude` | `(executable-find "claude")` |

Twenty sections. Everything else stays at top level, unwrapped: all 12 `core-*`
sections, `prog-base`, `text-base`, `ai-base`, `prog-elisp`, `prog-bash`, every
`data-*` section (including `data-hcl` and `data-pkl`), `text-asciidoc`,
`text-markdown`, `ebook-epub`, `ai-gptel`, `ai-mcp`, `ai-agents`. These are editing
modes that need no toolchain and are `:mode`-deferred, so they cost nothing.

- [ ] **Step 5: Re-verify the file parses**

Wrapping 20 sections by hand is where paren errors happen.

```bash
emacs -Q --batch --eval '(with-temp-buffer
  (insert-file-contents "/tmp/myde-migration/user-lisp/myde.el")
  (goto-char (point-min))
  (let ((n 0))
    (condition-case e
        (while t (read (current-buffer)) (setq n (1+ n)))
      (end-of-file (message "OK: %d top-level forms" n))
      (error (message "PARSE FAIL after %d forms: %S" n e) (kill-emacs 1)))))'
grep -c '^;; Gate: ' /tmp/myde-migration/user-lisp/myde.el
```

Expected: `OK: N top-level forms`, with N lower than Task 2 step 3 (each wrapped
section collapses many forms into one `when`), and `20` gate comments.

- [ ] **Step 6: Commit**

```bash
cd /tmp/myde-migration
git add user-lisp/myde.el
git commit -m "Gate module sections on binary presence; inline exec-path-from-shell

Wraps 20 sections in (when (executable-find ...)) gates. Presence equals
intent: no override list, no deny list, no defcustom. Sections that are
editing modes with no toolchain dependency stay unconditional; they are
:mode-deferred and cost nothing.

exec-path-from-shell moves off emacs-startup-hook to a section right after
core-base, since gates are evaluated during init and need a complete
exec-path. Drops -i from the shell arguments (~575ms to ~88ms, identical
PATH) and widens the guard from mac/ns to (or (daemonp) window-system) --
Linux Emacs started from a .desktop entry or systemd unit has no login
shell ancestry either.

Not yet loaded by init.el; the next commit switches over."
```

## Task 4: Switch init.el, delete the module tree, verify against baseline

**Files:**
- Modify: `init.el` (replace body)
- Modify: `custom.el` (worktree copy; the live one at go-live)
- Delete: `modules.el`, `modules/`

- [ ] **Step 1: Replace init.el**

The module machinery goes; `package.el` setup stays inside `myde.el` for now, where
the flattener put it (from `core-base/cfg.el`).

```elisp
;;; init.el --- Loaded after early-init.el -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration
;; Package-Requires: ((emacs "31.1"))

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;
;; Entry point for MyDE -- *MY* Development Environment.
;;
;; All configuration lives in user-lisp/myde.el, which Emacs 31 places on
;; `load-path' automatically via `user-lisp-directory'.

;;; Code:

(require 'myde)

;; A daemon starts its own server from startup.el after init; only GUI and
;; TTY sessions need one here.  (`server-name' is still "server" at this
;; point even under --daemon=NAME, so an unguarded start would grab the
;; user's default socket.)
(unless (daemonp)
  (require 'server)
  (unless (server-running-p) (server-start)))

;; That's all Folks!
(provide 'init)
;;; init.el ends here
```

- [ ] **Step 2: Remove the old module machinery**

```bash
cd /tmp/myde-migration
git rm -q modules.el
git rm -r -q modules/
ls modules.el modules 2>&1 | head -2
```

Expected: `No such file or directory` for both.

- [ ] **Step 3: Strip the toggles from the worktree custom.el**

The 24 `defcustom`s no longer exist, but `custom-set-variables` would still set the
bare symbols, and the probe's `module:` count would lie. All 24 are on their own line
in a fixed format:

```bash
cd /tmp/myde-migration
grep -c "myde-module-.*-enabled" custom.el
grep -v "^ '(myde-module-[a-z0-9-]*-enabled t)$" custom.el > custom.el.new
mv custom.el.new custom.el
grep -c "myde-module-.*-enabled" custom.el || echo "0 remaining"
```

Expected: `24`, then `0 remaining`. `package-selected-packages` stays for now;
`package.el` still needs it.

- [ ] **Step 4: Probe and compare against baseline**

This is the phase 1 acceptance gate.

```bash
cd /tmp/myde-migration
scripts/myde-probe.sh "$PWD" /tmp/myde-reports/01-gated.txt
R=/tmp/myde-reports
decl() { grep '^declared: ' "$1" | sed 's/^declared: //'; }

echo "--- init ---"
grep -E '^(init-file-had-error|exec-path-entries):' $R/01-gated.txt
echo "--- modules (must be 0) ---"
grep -c '^module: ' $R/01-gated.txt || true
echo "--- gate binaries ---"
grep '^binary: ' $R/01-gated.txt
echo "--- declared: lost vs baseline (must be empty) ---"
comm -23 <(decl $R/00-baseline.txt) <(decl $R/01-gated.txt)
echo "--- declared: gained vs predicted ---"
diff <(comm -13 <(decl $R/00-baseline.txt) <(decl $R/01-gated.txt)) \
     <(comm -13 <(decl $R/00-baseline.txt) $R/00-expected-new.txt) && echo "GAINED = PREDICTED"
echo "--- startup modes ---"
diff <(grep '^mode: ' $R/00-baseline.txt) <(grep '^mode: ' $R/01-gated.txt) && echo "MODES IDENTICAL"
echo "--- new errors ---"
comm -13 <(grep '^error: ' $R/00-baseline.txt | sort) <(grep '^error: ' $R/01-gated.txt | sort)
```

Expected:

- `init-file-had-error: nil`; `exec-path-entries` around 42 (was ~8 in the baseline).
- `0` modules.
- `binary:` `yes` for `go cargo zig lua ruby python3 node elixir erl clojure guile
  clangd fish nu pdftoppm op kubectl claude`; `no` for `sbcl`. If binaries you know
  are installed report `no`, `exec-path-from-shell` did not run — check the
  `(or (daemonp) window-system)` guard, remembering a daemon satisfies `daemonp`.
- Nothing lost. `GAINED = PREDICTED`.
- `MODES IDENTICAL`.
- New errors: expect some. They come from the 11 modules that have never run; Task 5
  works them off. Anything mentioning a module that was *already* enabled is a
  flattening mistake — fix it now.

If `GAINED = PREDICTED` fails, `diff` shows the discrepancy. A package predicted but
not gained means its section's `when` swallowed a form or its gate is false. A package
gained but not predicted means a section that should be unconditional got wrapped, or
the Task 0 step 7 list missed a form.

- [ ] **Step 5: Check init time did not regress**

```bash
grep 'init-time-seconds' /tmp/myde-reports/00-baseline.txt /tmp/myde-reports/01-gated.txt
```

Expected: within tens of milliseconds, allowing for ~88ms of `exec-path-from-shell`
that now runs during init instead of after it. A large regression suggests something
in a newly-live module loads eagerly.

- [ ] **Step 6: Delete the one-shot flattener and commit**

```bash
cd /tmp/myde-migration
git rm -q scripts/myde-flatten.el
git add -A
git commit -m "Load config from user-lisp/myde.el; delete module tree

init.el becomes a short entry point: (require 'myde) plus server start
for non-daemon sessions. Deletes modules.el, all 53 module directories,
and the one-shot flattener.

Verified against the pre-migration baseline: no declared package lost;
the packages gained are exactly those declared by the 11 modules that
binary gating switches on (clojure, cpp, elixir, erlang, lua, ruby, rust,
scheme, zig, asciidoc, 1password); startup-enabled modes identical."
```

## Task 5: Fix the newly-live modules

~1,700 lines across 11 modules have never executed. Expect real breakage here; it is
pre-existing, not caused by the migration.

**Files:**
- Modify: `user-lisp/myde.el` (sections for the 11 newly-live modules)

- [ ] **Step 1: Get the new error list**

```bash
comm -13 <(grep '^error: ' /tmp/myde-reports/00-baseline.txt | sort) \
         <(grep '^error: ' /tmp/myde-reports/01-gated.txt | sort)
```

- [ ] **Step 2: Fix the known-missing `:ensure` on geiser**

`prog-scheme`'s `geiser` form has no `:ensure` and was never exercised. Under
`package.el` it loads only if `geiser` is in `package-selected-packages`; it is not.
Add it:

```elisp
(use-package geiser
  :ensure t
  ;; ... existing keywords unchanged ...
  )
```

- [ ] **Step 3: Work each remaining error to a fix**

For each error line, the three patterns seen in this codebase and their fixes:

- `Cannot open load file: <pkg>` / `Cannot load <pkg>` — the package is not installed.
  Add `:ensure t` to its `use-package` form if it is a third-party package, or
  `:ensure nil` if built-in.
- `Invalid function: <fn>` in a `:hook` — the hook target does not exist in the
  installed version. Verify with
  `emacsclient -s <sock> -e '(fboundp (quote <fn>))'` and correct the name.
- `Symbol's value as variable is void: <var>` — a `:custom` or `:init` reference to a
  variable the package renamed. Check the package's source under `elpa/`.

Re-probe after each fix:

```bash
cd /tmp/myde-migration
scripts/myde-probe.sh "$PWD" /tmp/myde-reports/01-fixed.txt
comm -13 <(grep '^error: ' /tmp/myde-reports/00-baseline.txt | sort) \
         <(grep '^error: ' /tmp/myde-reports/01-fixed.txt | sort)
```

- [ ] **Step 4: Confirm no new errors remain and nothing else moved**

```bash
R=/tmp/myde-reports
decl() { grep '^declared: ' "$1" | sed 's/^declared: //'; }
comm -13 <(grep '^error: ' $R/00-baseline.txt | sort) <(grep '^error: ' $R/01-fixed.txt | sort)
diff <(decl $R/01-gated.txt) <(decl $R/01-fixed.txt) && echo "DECLARED UNCHANGED"
diff <(grep '^mode: ' $R/00-baseline.txt) <(grep '^mode: ' $R/01-fixed.txt) && echo "MODES IDENTICAL"
```

Expected: empty `comm` output, `DECLARED UNCHANGED`, `MODES IDENTICAL`. Fixing a
module may legitimately add a declared package (a missing `use-package` for a
dependency); if so, note it in the commit message and accept the diff.

- [ ] **Step 5: Smoke-test one newly-live language interactively**

The probe covers startup, not editing. Confirm a gated module actually works:

```bash
emacs --init-directory=/tmp/myde-migration --daemon=smoke >/dev/null 2>&1
printf 'defmodule Foo do\n  def bar, do: :ok\nend\n' > /tmp/smoke.ex
emacsclient -s smoke -e '(with-current-buffer (find-file-noselect "/tmp/smoke.ex")
                          (list major-mode (bound-and-true-p eglot--managed-mode)))'
emacsclient -s smoke -e '(kill-emacs)'
rm -f /tmp/smoke.ex
```

Expected: `(elixir-ts-mode ...)`. The major mode is the assertion; eglot may be nil if
`elixir-ls` needs a project root. If the mode falls back to `fundamental-mode`, the
tree-sitter grammar is missing — that is a grammar installation matter, not a
migration defect; install it and re-check.

- [ ] **Step 6: Commit**

```bash
cd /tmp/myde-migration
git add user-lisp/myde.el
git commit -m "Fix modules that binary gating newly enabled

The 11 modules switched on by executable-find gating had never been
loaded, so their configuration was never exercised. Adds the missing
:ensure on geiser and corrects the errors surfaced by first execution.

Startup error set now matches the pre-migration config exactly."
```

---

# Phase 2 — elpaca

Goal: replace `package.el` with elpaca and prove a cold clone builds from nothing with
the same declared packages and the same startup modes as the end of phase 1.

## Task 6: Make built-ins explicit

`use-package-always-ensure t` (Task 7) turns every form without `:ensure` into
`:ensure t`. For the 26 third-party forms that is the point. For the 6 built-in forms
it would make elpaca try to clone `treesit` and `project`. Fix those first, while
`package.el` is still in charge and the change is a verifiable no-op.

**Files:**
- Modify: `user-lisp/myde.el`

- [ ] **Step 1: Add `:ensure nil` to the six built-in forms**

Three `treesit` forms (in the `prog-clisp`, `prog-clojure`, `prog-scheme` sections) and
three `project` forms (same sections) have no `:ensure`:

```elisp
(use-package treesit
  :ensure nil
  ;; ... existing keywords ...
  )
```

```elisp
(use-package project
  :ensure nil
  ;; ... existing keywords ...
  )
```

- [ ] **Step 2: Verify every form without `:ensure` is third-party**

The walker recurses on `car`/`cdr` rather than `mapc`, because `:hook (mode . fn)`
dotted pairs make `mapc` signal `wrong-type-argument`:

```bash
cd /tmp/myde-migration
cat > /tmp/myde-ensure-walk.el <<'EOF'
;;; -*- lexical-binding: t -*-
(letrec
  ((walk (lambda (f)
           (when (consp f)
             (when (and (eq (car-safe f) 'use-package) (not (memq :ensure f)))
               (message "MISSING :ensure -- %s" (cadr f)))
             (funcall walk (car f))
             (funcall walk (cdr f))))))
  (with-temp-buffer
    (insert-file-contents "user-lisp/myde.el")
    (goto-char (point-min))
    (condition-case nil
        (while t (funcall walk (read (current-buffer))))
      (end-of-file nil))))
EOF
emacs -Q --batch -l /tmp/myde-ensure-walk.el 2>&1 | sort | uniq -c
rm -f /tmp/myde-ensure-walk.el
```

Expected: exactly one line, `25 MISSING :ensure -- indent-bars`. Any other name is
either a built-in that needs `:ensure nil` or a third-party package that is fine
either way. Check `(package-built-in-p 'NAME)` for anything unfamiliar.

- [ ] **Step 3: Confirm behaviour is unchanged under package.el**

```bash
cd /tmp/myde-migration
scripts/myde-probe.sh "$PWD" /tmp/myde-reports/02-ensure.txt
R=/tmp/myde-reports
diff <(grep -E '^(declared|mode): ' $R/01-fixed.txt) <(grep -E '^(declared|mode): ' $R/02-ensure.txt) && echo "IDENTICAL"
comm -13 <(grep '^error: ' $R/01-fixed.txt | sort) <(grep '^error: ' $R/02-ensure.txt | sort)
```

Expected: `IDENTICAL`, no new errors.

- [ ] **Step 4: Commit**

```bash
cd /tmp/myde-migration
git add user-lisp/myde.el
git commit -m "Mark built-in treesit and project forms :ensure nil

The next commit sets use-package-always-ensure, which turns every
use-package form without :ensure into :ensure t. These six forms are
built-ins and must opt out or elpaca would try to clone them.

No behaviour change under package.el."
```

## Task 7: Bootstrap elpaca

Everything package.el-specific goes, elpaca comes in, startup hooks move to
`elpaca-after-init`, the eight git-only packages get recipes, and a cold build from an
empty `elpaca/` is the acceptance gate.

**Files:**
- Modify: `init.el`
- Modify: `user-lisp/myde.el`
- Modify: `custom.el`
- Modify: `.gitignore`

- [ ] **Step 1: Confirm early-init.el already disables package.el**

```bash
grep -n 'package-enable-at-startup' /tmp/myde-migration/early-init.el
```

Expected: one line, `(setq package-enable-at-startup nil)`. It is already there; do not
add a second. GC and `file-name-handler-alist` restoration stay on `emacs-startup-hook`
— see the spec's early-init section for why they must not move to elpaca's hook.

- [ ] **Step 2: Replace init.el with the elpaca entry point**

The installer block is reproduced verbatim from elpaca's README (installer version
0.12):

```elisp
;;; init.el --- Loaded after early-init.el -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration
;; Package-Requires: ((emacs "31.1"))

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;
;; Entry point for MyDE -- *MY* Development Environment.
;;
;; Bootstraps elpaca, enables its use-package support, then loads all
;; configuration from user-lisp/myde.el, which Emacs 31 places on `load-path'
;; automatically via `user-lisp-directory'.

;;; Code:

;;;; Elpaca bootstrap

(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-sources-directory (expand-file-name "sources/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1 :inherit ignore
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca-activate)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-sources-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil)) (load "./elpaca-autoloads"))))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;;;; Use-package support

;; Every use-package form is :ensure t unless it says :ensure nil.  Built-in
;; forms must say so; elpaca-use-package has no by-default knob of its own.
(setq use-package-always-ensure t)

;; The elpaca-use-package menu recipe carries :wait t, so this blocks until
;; elpaca-use-package is built and `use-package' :ensure support is active --
;; which myde.el depends on from its first form.
(elpaca elpaca-use-package
  (elpaca-use-package-mode))

;;;; Configuration

(require 'myde)

;; A daemon starts its own server from startup.el after init; only GUI and
;; TTY sessions need one here.
(unless (daemonp)
  (require 'server)
  (unless (server-running-p) (server-start)))

;; That's all Folks!
(provide 'init)
;;; init.el ends here
```

`custom-file` is already set in `early-init.el:159` and loaded by the core-base
section of `myde.el` during init; nothing left in it depends on a package, so it does
not need to wait for elpaca.

- [ ] **Step 3: Remove the package.el setup from myde.el**

Delete from the `core-base` section: the `(require 'package)`, `package-user-dir`,
`package-archives`, `package-archive-priorities`, the `package-pinned-packages`
`dolist` for `csharp-mode`/`wallpaper`, `package-install-upgrade-built-in`,
`(package-initialize)`, the `advice-add` on `package--upgradeable-packages`, and the
`package-refresh-contents` guard — everything from the "Package initialization" comment
through the refresh guard (`core-base/cfg.el:46-86` in the original). **Keep** the
`custom.el` loading `let*` that follows it.

Also delete the now-orphaned `myde/filter-git-only-vc-packages` function definition and
both version-conditional `transient` `use-package` forms (the `:pin` mechanism is
package.el-only). Keep the first `transient` form — the one setting XDG paths — which
already has `:ensure nil`.

```bash
cd /tmp/myde-migration
for s in "require 'package" package-user-dir package-archives package-archive-priorities \
         package-pinned-packages package-install-upgrade-built-in '(package-initialize)' \
         'myde/filter-git-only-vc-packages' 'package-refresh-contents' ':pin '; do
  printf '%-40s %s\n' "$s" "$(grep -c -- "$s" user-lisp/myde.el || true)"
done
grep -c '(use-package transient' user-lisp/myde.el
```

Expected after editing: `0` for every pattern, and `1` transient form.

- [ ] **Step 4: Change exec-path-from-shell to `:wait t`**

In the Environment section:

```elisp
(use-package exec-path-from-shell
  :ensure (:wait t)
  :demand t
  :init
  (setq exec-path-from-shell-arguments '("-l"))
  :config
  (when (or (daemonp) window-system)
    (exec-path-from-shell-initialize)))
```

Under elpaca a package is not on `load-path` until queues process after init, which is
after `myde.el` has been read. `:wait t` processes the queue immediately, so the gates
below see a complete `exec-path`.

- [ ] **Step 5: Move startup hooks to elpaca-after-init**

Under elpaca, a `use-package` body runs after the package is activated, which is
during or after `after-init-hook`. A `:hook (after-init . vertico-mode)` added at that
point never fires, and vertico is silently off. The current tree has 14 such forms:

`buffer-guardian-mode`, `dashboard-setup-startup-hook`, `vertico-mode`,
`marginalia-mode`, `global-corfu-mode`, `editorconfig-mode`,
`global-treesit-auto-mode`, `global-flycheck-mode`, `global-mise-mode`,
`global-diff-hl-mode`, `which-key-mode`, `spacious-padding-mode`, `yas-global-mode`,
`whole-line-or-region-global-mode`

plus `:hook (emacs-startup . myde/mcp-server-startup-hook)` in the `ai-mcp` section.

Rewrite all of them except dashboard mechanically:

```bash
cd /tmp/myde-migration
grep -c '(after-init \. \|(emacs-startup \. ' user-lisp/myde.el
sed -i.bak -e 's/(after-init \. /(elpaca-after-init . /g' \
           -e 's/(emacs-startup \. /(elpaca-after-init . /g' user-lisp/myde.el
rm user-lisp/myde.el.bak
grep -c '(elpaca-after-init \. ' user-lisp/myde.el
grep -n '(after-init \. \|(emacs-startup \. ' user-lisp/myde.el || echo "none left"
```

Expected: `15`, then `15`, then `none left`. (On Linux `sed -i` takes no suffix; drop
the `.bak`.)

Then rewrite dashboard by hand. Its `dashboard-setup-startup-hook` installs its own
`after-init`/`window-setup` hooks, which have also already fired, so the mechanical
rewrite is not enough. Replace `:hook (elpaca-after-init . dashboard-setup-startup-hook)`
in the `core-dashboard` section with the recipe from dashboard's README:

```elisp
  :config
  (add-hook 'elpaca-after-init-hook #'dashboard-insert-startupify-lists)
  (add-hook 'elpaca-after-init-hook #'dashboard-initialize)
  (dashboard-setup-startup-hook)
```

If the section already has a `:config`, merge into it. Verify both functions exist in
the installed dashboard after the cold build in step 8 (the project rule about hook
targets applies):
`emacsclient -s <sock> -e '(list (fboundp (quote dashboard-insert-startupify-lists)) (fboundp (quote dashboard-initialize)))'`.

Finally, `core-ui`'s top-level `(add-hook 'emacs-startup-hook #'myde/clear-echo-area)`
exists to erase startup messages. Under elpaca the messages arrive later; change it to
`elpaca-after-init-hook` so it still does its job.

- [ ] **Step 6: Convert the VC packages to elpaca recipes**

Eight packages move from `package-vc-selected-packages` in `custom.el` to recipes on
their `use-package` forms. `ob-csharp` is dropped — there is no C# module.

```elisp
(use-package mcp-server
  :ensure (:host github :repo "rhblind/emacs-mcp-server")
  ;; ... existing keywords ...
  )

(use-package claude-code-ide
  :ensure (:host github :repo "manzaltu/claude-code-ide.el")
  ;; ... existing keywords ...
  )

(use-package modusregel
  :ensure (:host codeberg :repo "jjba23/modusregel")
  ;; ... existing keywords ...
  )

(use-package inf-lua
  :ensure (:host github :repo "nverno/inf-lua")
  ;; ... existing keywords ...
  )

(use-package zig-ts-mode
  :ensure (:host github :repo "emacsmirror/zig-ts-mode")
  ;; ... existing keywords ...
  )

(use-package ob-zig
  :ensure (:host github :repo "jolby/ob-zig.el")
  ;; ... existing keywords ...
  )

(use-package nushell-ts-babel
  :ensure (:host github :repo "herbertjones/nushell-ts-babel")
  ;; ... existing keywords ...
  )

(use-package ob-erlang
  :ensure (:host github :repo "xfwduke/ob-erlang")
  ;; ... existing keywords ...
  )
```

Remove any `:vc` keyword those forms carried.

```bash
grep -n ':vc ' /tmp/myde-migration/user-lisp/myde.el || echo "no :vc left"
```

- [ ] **Step 7: Reduce custom.el and ignore the elpaca directory**

Everything package-related leaves `custom.el`. Replace the worktree copy with the
original minus the 24 toggles (already gone in Task 4) and the two package lists:

```elisp
;;; -*- lexical-binding: t -*-
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(column-number-mode t)
 '(custom-safe-themes
   '("68a0201c7bb9dba9c9b6fd6662d1f3daf8865860ba8fc56d0201be859da535fc"
     "b0cedf3c6d8fbbf65934e2045dddacff0a031992f2f389215adcb0ca741347c3"
     default))
 '(myde-projects-directory "/Users/edwin-gooch/devel/projects/")
 '(tool-bar-mode nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:family "JetBrainsMono Nerd Font Mono" :foundry "nil" :slant normal :weight regular :height 120 :width normal)))))
```

```bash
cd /tmp/myde-migration
grep -c 'package-selected-packages\|package-vc-selected-packages' custom.el || echo "0 remaining"
wc -l custom.el
```

Expected: `0 remaining` and `19`.

In `.gitignore`, replace the `elpa/` entry:

```
# installed packages
elpaca/
```

- [ ] **Step 8: Cold-start test — the phase 2 acceptance gate**

Build every package from nothing. The `elpa` symlink from Task 0 must go — leaving it
lets package.el leftovers mask a missing recipe. It is a symlink, so `rm` without a
trailing slash removes only the link:

```bash
rm -f /tmp/myde-migration/elpa
rm -rf /tmp/myde-migration/elpaca
cd /tmp/myde-migration
time scripts/myde-probe.sh "$PWD" /tmp/myde-reports/02-cold.txt
```

Expected: several minutes on first run while elpaca clones and builds; the driver
waits up to 30 minutes. Then a report. If the daemon fails to start, run it in the
foreground to watch the bootstrap:

```bash
env PATH=/usr/bin:/bin emacs --init-directory=/tmp/myde-migration --daemon=coldcheck
```

- [ ] **Step 9: Compare the cold build against the end of phase 1**

```bash
R=/tmp/myde-reports
decl() { grep '^declared: ' "$1" | sed 's/^declared: //'; }
echo "--- init ---"
grep -E '^(init-file-had-error|init-time-seconds|elpaca-init-time-seconds|exec-path-entries):' $R/02-cold.txt
echo "--- gate binaries ---"
grep '^binary: ' $R/02-cold.txt
echo "--- declared ---"
diff <(decl $R/02-ensure.txt) <(decl $R/02-cold.txt) && echo "DECLARED IDENTICAL"
echo "--- startup modes ---"
diff <(grep '^mode: ' $R/02-ensure.txt) <(grep '^mode: ' $R/02-cold.txt) && echo "MODES IDENTICAL"
echo "--- new errors ---"
comm -13 <(grep '^error: ' $R/02-ensure.txt | sort) <(grep '^error: ' $R/02-cold.txt | sort)
```

Expected: `init-file-had-error: nil`; `elpaca-init-time-seconds` is a real number, not
`n/a`; the same `binary:` yes/no pattern as Task 4; `DECLARED IDENTICAL`;
`MODES IDENTICAL`; no new errors.

A mode that is `on` in `02-ensure.txt` and `off` here is a startup hook step 5 missed.
A declared package missing here is a `use-package` form elpaca could not satisfy —
almost always a recipe whose `:host`/`:repo` is wrong, or a package that is on neither
MELPA nor GNU/NonGNU ELPA and needs a recipe.

- [ ] **Step 10: Check for packages that cloned but failed to build**

A package can clone successfully and still fail to byte-compile, in which case it has a
directory under `sources/` but none under `builds/`:

```bash
cd /tmp/myde-migration
comm -23 <(ls elpaca/sources | sort) <(ls elpaca/builds | sort)
```

Expected: empty output. Any name listed here needs investigating — open
`M-x elpaca-log` in a real Emacs and read its entry. A few recipes legitimately declare
no build step, so treat a listed name as a question rather than a confirmed failure.

- [ ] **Step 11: Warm-start check**

```bash
cd /tmp/myde-migration
scripts/myde-probe.sh "$PWD" /tmp/myde-reports/02-warm.txt
grep -E '^(init-time-seconds|elpaca-init-time-seconds):' /tmp/myde-reports/02-cold.txt /tmp/myde-reports/02-warm.txt
diff <(grep -E '^(declared|mode): ' /tmp/myde-reports/02-cold.txt) <(grep -E '^(declared|mode): ' /tmp/myde-reports/02-warm.txt) && echo "IDENTICAL"
```

Expected: warm `elpaca-init-time-seconds` well under a second; `IDENTICAL`.

- [ ] **Step 12: Commit**

```bash
cd /tmp/myde-migration
git add -A
git commit -m "Replace package.el with elpaca

Bootstraps elpaca in init.el, sets use-package-always-ensure, and enables
elpaca-use-package-mode. exec-path-from-shell becomes :ensure (:wait t)
so the binary gates that follow it see a complete exec-path during init.

Moves 15 startup hooks from after-init/emacs-startup to elpaca-after-init
and rewrites dashboard's startup per its README: under elpaca a
use-package body runs after those hooks have fired, so every one of those
global modes would otherwise stay silently off.

Converts eight git-only packages to elpaca recipes and drops ob-csharp,
which had no module. custom.el shrinks to faces, safe themes, and a
handful of settings.

Deletes all package.el scaffolding and the five workarounds it required:
built-in archive pinning for csharp-mode and wallpaper,
package-install-upgrade-built-in, the package--upgradeable-packages
advice for git-only VC packages, version-conditional transient pinning,
and the package-initialize ordering constraints.

Verified by a cold build from an empty elpaca/: declared package set and
startup-enabled modes identical to the package.el config; every clone has
a build."
```

---

# Phase 3 — Literate

Goal: `myde.org` becomes the single editable source, tangling all three elisp files.

## Task 8: Create myde.org

**Files:**
- Create: `myde.org`

- [ ] **Step 1: Build the org file with three subtrees**

Create `myde.org` at the worktree root with this skeleton. Each top-level heading sets
its tangle target via a property drawer, and the file-level property defaults to
`:tangle no` so a stray block cannot leak into an output file:

```org
#+title: MyDE — *MY* Development Environment
#+author: Allen Gooch
#+property: header-args:emacs-lisp :tangle no :results none :comments no

* Early Init
:PROPERTIES:
:header-args:emacs-lisp: :tangle early-init.el :mkdirp yes
:END:

Runs before ~init.el~, and before Emacs startup creates its directories.

* Bootstrap
:PROPERTIES:
:header-args:emacs-lisp: :tangle init.el :mkdirp yes
:END:

Bootstraps elpaca, enables its ~use-package~ support, then loads ~user-lisp/myde.el~.

* Configuration
:PROPERTIES:
:header-args:emacs-lisp: :tangle user-lisp/myde.el :mkdirp yes
:END:

** Core base
** Environment
** Core
** AI
** Auth
** Data formats
** Containers
** Languages
** Text formats
** Ebooks
```

Then fill it, moving content rather than rewriting it:

1. Under `* Early Init`, one `#+begin_src emacs-lisp` block containing the entire
   current `early-init.el`, byte for byte including its header and its
   `;;; early-init.el ends here` line.
2. Under `* Bootstrap`, one block containing the entire current `init.el`, likewise
   byte for byte.
3. Under `* Configuration`, split the current `user-lisp/myde.el` at its `;;;;` section
   comments. Each section becomes one `#+begin_src` block under the matching `**`
   heading. The `myde.el` file header goes in a block under `** Core base` (first),
   the Environment section under `** Environment`, and the `(provide 'myde)` plus
   `;;; myde.el ends here` lines go in a final block under `** Ebooks` (last).

The `**` heading order deliberately matches the *existing* section order in `myde.el`,
which came from `myde-modules` load order plus the Environment insertion. Load order
is known-working and reordering it risks breaking dependencies for no benefit.

`:comments no` keeps `org-babel` from injecting provenance comments into the output.
`org-babel`'s default `:padline yes` inserts a blank line before every block except
the first in a file, which is why the check in step 3 ignores blank lines.

- [ ] **Step 2: Tangle**

```bash
cd /tmp/myde-migration
emacs -Q --batch --eval '(progn (require (quote org))
  (org-babel-tangle-file "/tmp/myde-migration/myde.org"))'
```

Expected: a message listing the three tangled files.

- [ ] **Step 3: Verify the tangled output matches the committed files**

This is the phase 3 acceptance gate. The org file must reproduce phase 2's output with
no forms lost or changed. Blank-line differences from `:padline` are tolerated; they
carry no code:

```bash
cd /tmp/myde-migration
for f in early-init.el init.el user-lisp/myde.el; do
  if git show "HEAD:$f" | diff -B -q - "$f" >/dev/null; then
    echo "SAME       $f"
  else
    echo "DIFFERS    $f"
    git show "HEAD:$f" | diff -B - "$f" | head -20
  fi
done
head -1 early-init.el init.el user-lisp/myde.el | grep -c 'lexical-binding: t'
```

Expected: `SAME` for all three, and `3` — every output still has its
`lexical-binding` cookie on line 1, which `:padline` respects for the first block.

- [ ] **Step 4: Probe once more, then commit the org file and the tangled outputs**

```bash
cd /tmp/myde-migration
scripts/myde-probe.sh "$PWD" /tmp/myde-reports/03-tangled.txt
diff <(grep -E '^(declared|mode): ' /tmp/myde-reports/02-warm.txt) <(grep -E '^(declared|mode): ' /tmp/myde-reports/03-tangled.txt) && echo "IDENTICAL"
git add myde.org early-init.el init.el user-lisp/myde.el
git commit -m "Add myde.org as literate source for all three elisp files

Single org file tangles early-init.el, init.el, and user-lisp/myde.el via
per-subtree :tangle properties. Tangled output is identical to the
hand-maintained files it replaces except for blank lines, so this commit
changes no behaviour.

Outputs stay committed: a fresh clone works without tangling, and startup
never loads org."
```

## Task 9: Wire up the tangle workflow

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Add Make targets**

Append to `Makefile`, following its existing `##@` category and `##` description
conventions:

```make
##@ Literate config targets

.PHONY: tangle
tangle: ## Tangle myde.org into early-init.el, init.el, and user-lisp/myde.el
	@echo 'tangling myde.org'
	emacs -Q --batch --eval "(progn (require 'org) \
	  (org-babel-tangle-file \"$(ROOT_DIR)/myde.org\"))"

.PHONY: check
check: tangle ## Verify committed elisp matches myde.org
	@echo 'checking tangled output is up to date'
	@git diff --exit-code -- early-init.el init.el user-lisp/myde.el \
	  || { echo 'ERROR: tangled output differs from committed files.'; \
	       echo 'Run make tangle and commit the result.'; exit 1; }
	@echo 'tangled output is up to date'
```

- [ ] **Step 2: Verify both targets**

```bash
cd /tmp/myde-migration
make tangle
make check
```

Expected: `tangled output is up to date`.

Then confirm `check` actually fails when it should. Two traps here. The drift must be
introduced in `myde.org`, not in a tangled file — `check` runs `tangle` first, so an edit
to `user-lisp/myde.el` would be overwritten and the test would pass vacuously. And the
new block must sit under a heading whose property drawer sets a real target; a block
appended at top level inherits the file-level `:tangle no` and changes no output.
Appending a `**` heading puts it inside the final top-level subtree, `* Configuration`,
which tangles to `user-lisp/myde.el`:

```bash
cd /tmp/myde-migration
cp myde.org /tmp/myde.org.bak
printf '\n** Drift test\n#+begin_src emacs-lisp\n;; deliberate drift\n#+end_src\n' >> myde.org
make check; echo "exit: $?"
cp /tmp/myde.org.bak myde.org && rm /tmp/myde.org.bak
make tangle
git diff --exit-code -- early-init.el init.el user-lisp/myde.el && echo "restored"
```

Expected: the `ERROR: tangled output differs` message, a non-zero exit, then `restored`.
A passing `check` means the target is broken.

There is deliberately no auto-tangle on save. `make check` catches drift, and
re-tangling a 7,000-line file on every save is latency for no gain.

- [ ] **Step 3: Commit**

```bash
cd /tmp/myde-migration
git add Makefile
git commit -m "Add tangle and check targets

make tangle regenerates the three elisp files from myde.org. make check
tangles and fails if the result differs from what is committed, catching
drift between source and output."
```

## Task 10: Update documentation and agent skills, then go live

**Files:**
- Modify: `.agents/AGENTS.md` (reached via the `CLAUDE.md` / `AGENTS.md` symlinks)
- Modify: `README.md`
- Rewrite: `.agents/skills/myde/SKILL.md`
- Check: `.agents/skills/elisp/SKILL.md`

- [ ] **Step 1: Rewrite the AGENTS.md architecture sections**

`.agents/AGENTS.md` documents the module system, the package.el invariants, and the
`lib.el`/`cfg.el` split — all now gone. Replace those sections with:

- **Commands**: add `make tangle` and `make check` alongside `make link`/`make unlink`,
  and `scripts/myde-probe.sh <init-dir> <report>` for verifying a config change.
- **Architecture**: the three tangled files and `myde.org` as sole editable source.
- **Module enablement**: presence-as-intent via `executable-find`; the gate table from
  the spec; no toggles, no override list; editing modes with no toolchain dependency
  are unconditional.
- **Package management**: elpaca; `use-package-always-ensure t`, so third-party forms
  need nothing and **every built-in form must say `:ensure nil`**; recipes for
  git-only packages.
- **Startup hooks**: `:hook (elpaca-after-init . fn)`, never `after-init` or
  `emacs-startup` inside a `use-package` form — the body runs after those have fired.
- **Editing workflow**: edit `myde.org`, never the tangled `.el` files; run
  `make check` before committing.

Delete outright: the module-system section, the declarative-loading table, the
package-system-invariants section, the built-in-exclusion table, the
VC-package-upgrade-behavior section, the version-conditional-pinning section, and
"Adding a module".

Keep unchanged: XDG compliance, platform support, the copyright-header convention, the
named-hook-functions rule, and the keybinding prefixes.

Also update the version floor. `AGENTS.md` currently says "targeting **Emacs 30+**" and
the old `init.el` header said `((emacs "30.1"))`; this config now requires 31.1 for
`user-lisp-directory`. Change both to 31.1, and delete the `use-package constraints
(Emacs 30)` heading's version qualifier along with the two Emacs-30-specific bullets
about `use-package-ensure-function` and version-conditional pinning.

Add these cautions:

```markdown
- `user-lisp/` sits at `load-path` position 0 and shadows built-ins. Only
  `myde.el` belongs there — a file named `org.el` would shadow built-in Org.
- Binary gates are evaluated during init, so `exec-path` must be complete first.
  The `exec-path-from-shell` form uses `:ensure (:wait t)` and must stay in the
  Environment section, ahead of the first gated section.
- GC and `file-name-handler-alist` restoration stay on `emacs-startup-hook`, not
  `elpaca-after-init-hook`, so a failed elpaca bootstrap cannot leave a session
  with GC disabled and TRAMP broken.
```

- [ ] **Step 2: Rewrite the `myde` agent skill**

`.agents/skills/myde/SKILL.md` describes only the module system this migration deletes —
the `lib.el`/`cfg.el` split, `myde-modules`, `myde/m`, `myde-initialize`. Every rule in
it is wrong after phase 1. Its description field will still match on "adding or editing
modules", so leaving it in place actively misleads any agent that loads it.

Replace its body with the conventions that now apply:

- Edit `myde.org` only. Never edit `early-init.el`, `init.el`, or `user-lisp/myde.el`
  directly — they are tangled output; `make tangle` overwrites them.
- Adding support for a tool: add a `#+begin_src emacs-lisp` block under the appropriate
  `**` heading in the Configuration subtree, wrapped in
  `(when (executable-find "<binary>") …)` if the tool needs a toolchain to be useful.
  Editing modes stay unconditional. No toggle, no registration list, no `custom.el`
  entry.
- `use-package-always-ensure` is on: third-party forms need no `:ensure`; built-in
  forms **must** say `:ensure nil`; git-only packages take a recipe plist.
- The gate wraps the whole form. `:if` inside a `use-package` form does not stop elpaca
  from cloning.
- Startup hooks inside `use-package` forms use `elpaca-after-init`, never `after-init`
  or `emacs-startup`.
- Prefer a deferring keyword (`:mode`, `:hook`, `:commands`) over eager loading.
- Run `make check` before committing. Run `scripts/myde-probe.sh` to verify a change
  did not drop a declared package or turn off a startup mode.

Update its `description:` frontmatter to match, so it stops advertising the module
system:

```yaml
description: This skill should be used when editing myde.org, the literate source for the myde.emacs configuration — adding or changing use-package declarations, binary-presence gates, or elpaca recipes.
```

- [ ] **Step 3: Check the `elisp` skill for stale rules**

`.agents/skills/elisp/SKILL.md` covers general Emacs Lisp style and should mostly survive
untouched. Read it and correct only what the migration invalidates:

```bash
grep -n 'package-install\|package-selected\|:pin\|lib\.el\|cfg\.el\|modules/\|emacs "30\|after-init' \
  /tmp/myde-migration/.agents/skills/elisp/SKILL.md
```

Fix any hit. Expected: few or none — if the grep is empty, this step is done.

- [ ] **Step 4: Update README.md**

`README.md` lines 19-89 describe `modules/`, `myde-modules`, `myde-customize`, and
`M-x customize-group RET myde-modules`. Update the installation and structure sections
to describe `myde.org` plus three tangled files, and replace the customize instructions
with the binary-detection rule.

- [ ] **Step 5: Full verification before going live**

```bash
cd /tmp/myde-migration
scripts/myde-probe.sh "$PWD" /tmp/myde-reports/04-final.txt
R=/tmp/myde-reports
decl() { grep '^declared: ' "$1" | sed 's/^declared: //'; }
echo "--- init ---"
grep -E '^(init-file-had-error|init-time-seconds|elpaca-init-time-seconds):' $R/00-baseline.txt $R/04-final.txt
echo "--- declared lost vs original baseline (must be empty) ---"
comm -23 <(decl $R/00-baseline.txt) <(decl $R/04-final.txt)
echo "--- startup modes vs original baseline ---"
diff <(grep '^mode: ' $R/00-baseline.txt) <(grep '^mode: ' $R/04-final.txt) && echo "MODES IDENTICAL"
echo "--- new errors vs original baseline ---"
comm -13 <(grep '^error: ' $R/00-baseline.txt | sort) <(grep '^error: ' $R/04-final.txt | sort)
make check
```

Expected: nothing lost, `MODES IDENTICAL`, no new errors, `make check` clean. Compare
`elpaca-init-time-seconds` in the final report against `init-time-seconds` in the
baseline; that is the like-for-like startup number.

- [ ] **Step 6: Commit the documentation and skills**

```bash
cd /tmp/myde-migration
git add .agents/ README.md
git commit -m "Update docs and agent skills for three-file literate config

Documents myde.org as the sole editable source, presence-as-intent module
enablement, elpaca package management with use-package-always-ensure, and
the elpaca-after-init rule for startup hooks. Removes the module system,
declarative loading, and package.el invariant sections, none of which
describe the config any more. Raises the version floor to Emacs 31.1,
required for user-lisp-directory.

Rewrites the myde skill, which described only the deleted module system
and would have misled any agent that loaded it."
```

- [ ] **Step 7: Go live**

`~/.config/emacs` already symlinks to the repository, so merging is all that is needed.
Move the worktree's built `elpaca/` across first so the first live start does not
spend minutes rebuilding in a frozen GUI:

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
git merge --no-ff migration/three-file-literate -m "Merge three-file literate config migration

Collapses 53 module directories and 24 defcustom toggles into three elisp
files tangled from a single myde.org. Module enablement now derives from
binary presence; packages are managed by elpaca."
cp /tmp/myde-migration/custom.el custom.el
mv /tmp/myde-migration/elpaca ./elpaca
```

`custom.el` is untracked, so the merge does not touch it; the copy replaces the live
one with the reduced version.

- [ ] **Step 8: Verify the live config**

Quit any running Emacs. Note that this severs the `emacs` MCP server that agent
sessions use; reconnect after restart. Then start a real GUI Emacs from the desktop or
Dock — not from a terminal — so the `exec-path-from-shell` path is genuinely
exercised. With `elpaca/` moved across, startup should only activate, not build.

Confirm from a terminal:

```bash
emacsclient -e '(list (length exec-path) (executable-find "go") (bound-and-true-p vertico-mode) (get-buffer "*dashboard*"))'
```

Expected: an `exec-path` length near 42, a resolved `go` path, `t`, and a dashboard
buffer. The dashboard is the one startup item the probe could not check.

- [ ] **Step 9: Clean up**

Only after the live config is confirmed working. `git worktree remove` refuses to delete
a worktree with untracked files:

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
rm -f /tmp/myde-migration/elpa
git worktree remove --force /tmp/myde-migration
git branch -d migration/three-file-literate
rm -rf elpa
git status --porcelain
```

`rm -rf elpa` removes the old package.el directory from the main tree; nothing reads it
any more. Keep `/tmp/myde-reports/` until fully satisfied — it is the only record of the
pre-migration state.

---

## Follow-up work, outside this migration

Each of these changes behaviour and gets its own before/after probe comparison. None
is a precondition for the migration.

- **Deferral audit.** `M-x use-package-report` lists every form that loaded at startup
  (`use-package-compute-statistics` is on). For each third-party package tied to a
  file type or a command, add `:mode`, `:hook`, or `:commands`. Global modes (theme,
  modeline, dashboard, completion) legitimately stay eager. The probe's `loaded:` set
  is the before/after metric.
- **Collapse the 25 duplicate `indent-bars` forms** into one with a combined hook
  list. Harvest the mode list with
  `grep -A3 'use-package indent-bars' user-lisp/myde.el | grep -oE '[a-z0-9+-]+-mode' | sort -u`
  before writing it.
- **Linux `-l` verification** (Task 3 step 1) before the Linux machine adopts the
  config, and `emacs --version` there: `user-lisp-directory` needs 31.1.

## Deferred, with rationale

- **Byte-compiling `myde.el`.** All three files keep `no-byte-compile: t`, matching the
  current `init.el`. A stale `.elc` beside a tangled `.el` is a confusing failure mode,
  and the tangle workflow would need a compile step. Revisit if load time becomes
  measurable — `elpaca-init-time-seconds` in the probe is the signal.
- **`myde.el` as several files.** The spec fixes three loaded files. If the ~7,000-line
  buffer proves unpleasant despite org folding, `myde.el` can tangle into
  `user-lisp/myde-{core,prog,data}.el` with `myde.el` requiring them, without touching
  `myde.org`'s structure.
- **Removing the `zig`/`ruby` LSP config.** `zls` and `ruby-lsp` are absent, so those
  eglot blocks are inert. They cost nothing and become correct the moment the servers
  are installed.
- **Reordering sections.** The `**` headings follow `myde-modules` load order plus the
  Environment insertion. That order is known-working; changing it risks breaking a
  load-order dependency for a purely cosmetic gain. Revisit only after a dependency
  audit.
