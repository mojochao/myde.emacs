# Three-File Literate Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace 53 module directories and 24 `defcustom` toggles with three elisp files tangled from a single `myde.org`, enabling modules by binary presence and managing packages with elpaca.

**Architecture:** Four sequential phases, each leaving a working config and each verified by a probe harness that captures the observable state of a running Emacs (loaded package set, init time, startup errors). Phase 1 flattens the tree, phase 2 replaces toggles with `executable-find` gates, phase 3 swaps `package.el` for elpaca, phase 4 makes the source literate. All work happens in a git worktree so the live config at `~/.config/emacs` (a symlink into this repo) stays functional throughout.

**Tech Stack:** Emacs 31.1, `use-package`, elpaca 0.12, `org-babel-tangle`, `exec-path-from-shell`, GNU Make.

**Spec:** `docs/superpowers/specs/2026-09-15-three-file-literate-config-design.md`

---

## Critical context for someone with zero familiarity

Read this before Task 1. Each item is a live hazard discovered while writing this plan.

1. **`~/.config/emacs` is a symlink to this repository.** Editing files in the main
   working tree changes the running config immediately. All work happens in a git
   worktree at `/tmp/myde-migration`, exercised via `emacs --init-directory=`.

2. **`custom.el` is gitignored and untracked.** A fresh worktree has no `custom.el`,
   which means no module toggles are set, which means only `core-*` modules load.
   It must be copied into the worktree by hand or every phase-1 comparison is
   meaningless.

3. **`elpa/` is gitignored.** A fresh worktree has no packages. For phases 1 and 2
   symlink it to the main tree's `elpa/` to avoid a 100-package reinstall. Phase 3
   deliberately starts from nothing.

4. **`--batch` and `-Q` both imply `--no-init-file`.** Neither can be used to test a
   config. Use `--daemon=<unique-socket>` plus `emacsclient -s <socket>`. Always use a
   unique socket name so the probe never touches the user's running Emacs server.

5. **`use-package-always-ensure` is never set in this config.** 32 of 269 `use-package`
   forms have no `:ensure` keyword and are installed only because they appear in
   `package-selected-packages` in `custom.el`. When elpaca removes that list, those
   packages silently vanish. Task 13 fixes all 32.

6. **elpaca queues the order *outside* the `use-package` form.** `:if`/`:when` inside
   the form cannot prevent a clone. Gates must wrap the whole form in `(when …)`.

7. **Three `load-file-name` uses are load-bearing** and break on flattening, plus two
   hardcoded `modules/core-dashboard/` paths. Task 1 relocates the assets they point at.
   The other 33 `load-file-name` uses are `featurep` guards that get deleted anyway.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `scripts/myde-probe.el` | Captures observable config state (loaded packages, init time, errors) from a running Emacs. The verification harness for every phase. |
| `scripts/myde-probe.sh` | Boots a config as a throwaway daemon, runs the probe, writes a report, kills the daemon. |
| `scripts/myde-flatten.el` | One-shot generator: concatenates 53 module files into `user-lisp/myde.el` in `myde-modules` order. Deleted after phase 1. |
| `user-lisp/myde.el` | All configuration. Tangled output from phase 4 onward. |
| `myde.org` | Literate source for all three elisp files. Phase 4. |
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
- Create: `scripts/myde-probe.el`
- Create: `scripts/myde-probe.sh`

- [ ] **Step 1: Create the worktree and branch**

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
git worktree add /tmp/myde-migration -b migration/three-file-literate
```

Expected: `Preparing worktree (new branch 'migration/three-file-literate')` then `HEAD is now at 9ad474e`.

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

- [ ] **Step 3: Write the probe**

Create `scripts/myde-probe.el` in the **main** working tree (it is tooling, not config, and both trees need it):

```elisp
;;; myde-probe.el --- Capture observable config state -*- lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;;; Commentary:
;; Loaded into an already-started Emacs via emacsclient.  Writes a stable,
;; diffable report of what the config actually did, for before/after comparison
;; across migration phases.  Not part of the config; lives under scripts/.

;;; Code:

(require 'cl-lib)

(defun myde-probe--package-name (dir)
  "Return package name for elpa/elpaca build directory DIR.
Strips a trailing MELPA-style or semver version from elpa directories.
Elpaca build directories carry no version, so DIR is returned unchanged."
  (replace-regexp-in-string
   "-\\(?:[0-9]\\{8\\}\\(?:\\.[0-9]+\\)?\\|[0-9]+\\(?:\\.[0-9]+\\)*\\)\\'" "" dir))

(defun myde-probe-loaded-packages ()
  "Return a sorted list of third-party packages with a file in `load-history'."
  (let ((names '()))
    (dolist (entry load-history)
      (let ((file (car entry)))
        (when (and (stringp file)
                   (string-match "/\\(?:elpa\\|elpaca/builds\\)/\\([^/]+\\)/" file))
          (cl-pushnew (myde-probe--package-name (match-string 1 file))
                      names :test #'string=))))
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
                        "Failed to\\|Cannot open load file"
                        "\\).*\\)$")
                nil t)
          (push (string-trim (match-string 1)) hits))))
    (nreverse hits)))

(defun myde-probe-enabled-modules ()
  "Return sorted `myde-module-*-enabled' variables that are non-nil.
Returns nil after phase 2, when toggles no longer exist."
  (let ((found '()))
    (mapatoms
     (lambda (sym)
       (when (and (string-match "\\`myde-module-\\(.+\\)-enabled\\'" (symbol-name sym))
                  (boundp sym)
                  (symbol-value sym))
         (push (match-string 1 (symbol-name sym)) found))))
    (sort found #'string<)))

(defun myde-probe-gated-binaries ()
  "Return an alist of (BINARY . FOUND-P) for every module gate binary.
Makes PATH problems visible instead of silent."
  (mapcar (lambda (b) (cons b (and (executable-find b) t)))
          '("go" "cargo" "zig" "lua" "ruby" "python3" "node" "elixir" "erl"
            "clojure" "guile" "sbcl" "clangd" "fish" "nu" "tofu" "terraform"
            "pkl" "asciidoctor" "pdftoppm" "op" "kubectl" "claude")))

(defun myde-probe-write (out)
  "Write the probe report to file OUT."
  (with-temp-file out
    (let ((print-length nil) (print-level nil))
      (insert ";; myde probe report\n")
      (insert (format "emacs-version: %s\n" emacs-version))
      (insert (format "init-time-seconds: %.3f\n"
                      (float-time (time-subtract after-init-time before-init-time))))
      (insert (format "exec-path-entries: %d\n" (length exec-path)))
      (insert (format "elpaca-after-init: %s\n"
                      (if (boundp 'elpaca-after-init-time)
                          (and (symbol-value 'elpaca-after-init-time) t)
                        'n/a)))
      (insert "\n;; enabled modules\n")
      (dolist (m (myde-probe-enabled-modules)) (insert (format "module: %s\n" m)))
      (insert "\n;; gate binaries\n")
      (pcase-dolist (`(,b . ,found) (myde-probe-gated-binaries))
        (insert (format "binary: %-14s %s\n" b (if found "yes" "no"))))
      (insert "\n;; loaded third-party packages\n")
      (dolist (p (myde-probe-loaded-packages)) (insert (format "package: %s\n" p)))
      (insert "\n;; startup errors\n")
      (let ((errs (myde-probe-startup-errors)))
        (if errs
            (dolist (e errs) (insert (format "error: %s\n" e)))
          (insert "error: (none)\n"))))))

(provide 'myde-probe)
;;; myde-probe.el ends here
```

- [ ] **Step 4: Write the probe driver**

Create `scripts/myde-probe.sh`:

```bash
#!/usr/bin/env bash
# Boot a config as a throwaway daemon, probe it, write a report, kill it.
# Usage: scripts/myde-probe.sh <init-directory> <output-file>
set -euo pipefail

DIR="${1:?usage: myde-probe.sh <init-directory> <output-file>}"
OUT="${2:?usage: myde-probe.sh <init-directory> <output-file>}"
PROBE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/myde-probe.el"
SOCK="myde-probe-$$"

cleanup() { emacsclient -s "$SOCK" -e '(kill-emacs)' >/dev/null 2>&1 || true; }
trap cleanup EXIT

rm -f "$OUT"
echo "booting $DIR as daemon $SOCK ..."
emacs --init-directory="$DIR" --daemon="$SOCK" >/dev/null 2>&1 || {
  echo "FAIL: daemon did not start. Run without redirection to see why:"
  echo "  emacs --init-directory=$DIR --daemon=$SOCK"
  exit 1
}

# Elpaca processes its queues asynchronously after init. Wait for it when present.
emacsclient -s "$SOCK" -e '(when (boundp (quote elpaca-after-init-time))
                            (let ((n 0))
                              (while (and (null elpaca-after-init-time) (< n 600))
                                (sleep-for 0.1) (setq n (1+ n)))))' >/dev/null

emacsclient -s "$SOCK" -e "(load \"$PROBE\")" >/dev/null
emacsclient -s "$SOCK" -e "(myde-probe-write \"$OUT\")" >/dev/null

echo "report written to $OUT"
grep -c '^package: ' "$OUT" | xargs echo "  packages loaded:"
grep -c '^module: '  "$OUT" | xargs echo "  modules enabled:"
if grep -q '^error: (none)$' "$OUT"; then
  echo "  startup errors:  none"
else
  echo "  startup errors:  $(grep -c '^error: ' "$OUT")"
fi
```

```bash
chmod +x scripts/myde-probe.sh
```

- [ ] **Step 5: Capture the baseline from the CURRENT config**

This is the target every later phase is compared against.

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
mkdir -p /tmp/myde-reports
scripts/myde-probe.sh "$PWD" /tmp/myde-reports/00-baseline.txt
```

Expected: `modules enabled: 24`, a package count in the 90-110 range, and a printed
error count. Record the actual numbers — they are the contract for Task 6.

- [ ] **Step 6: Verify the probe detects a broken config**

A harness that cannot fail is not a harness.

```bash
mkdir -p /tmp/myde-broken
printf '(require (quote definitely-not-a-real-package))\n' > /tmp/myde-broken/init.el
scripts/myde-probe.sh /tmp/myde-broken /tmp/myde-reports/00-sanity.txt
grep '^error: ' /tmp/myde-reports/00-sanity.txt
```

Expected: at least one line matching `Cannot open load file`. If the report says
`error: (none)`, the regexp in `myde-probe-startup-errors` is wrong — fix it before
proceeding.

```bash
rm -rf /tmp/myde-broken
```

- [ ] **Step 7: Confirm the worktree reproduces the baseline**

```bash
scripts/myde-probe.sh /tmp/myde-migration /tmp/myde-reports/00-worktree.txt
diff <(grep -E '^(module|package): ' /tmp/myde-reports/00-baseline.txt) \
     <(grep -E '^(module|package): ' /tmp/myde-reports/00-worktree.txt) && echo "IDENTICAL"
```

Expected: `IDENTICAL`. If not, step 2 was skipped or incomplete — the worktree is
missing `custom.el` or `elpa`.

- [ ] **Step 8: Commit the harness**

The scripts were created in the main tree so the baseline could be captured. The
worktree needs its own copy, since they are not yet committed:

```bash
mkdir -p /tmp/myde-migration/scripts
cp /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs/scripts/myde-probe.el \
   /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs/scripts/myde-probe.sh \
   /tmp/myde-migration/scripts/
chmod +x /tmp/myde-migration/scripts/myde-probe.sh
cd /tmp/myde-migration
git add scripts/
git commit -m "Add config probe harness for migration verification

Captures loaded third-party packages, enabled modules, gate binary
availability, init time, and startup errors from a running Emacs via a
throwaway daemon socket. Baseline for comparing each migration phase.

--batch and -Q both imply --no-init-file, so a daemon is the only way to
exercise a config non-interactively."
```

---

# Phase 1 — Flatten

Goal: one `user-lisp/myde.el` containing everything, with `package.el` and the 24
toggles still in force, producing an identical package set to the baseline.

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
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
scripts/myde-probe.sh /tmp/myde-migration /tmp/myde-reports/01-assets.txt
diff <(grep -E '^(module|package): ' /tmp/myde-reports/00-baseline.txt) \
     <(grep -E '^(module|package): ' /tmp/myde-reports/01-assets.txt) && echo "IDENTICAL"
grep '^error: ' /tmp/myde-reports/01-assets.txt
```

Expected: `IDENTICAL`, and no new errors versus baseline.

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
;; Usage: emacs -Q --batch -l scripts/myde-flatten.el

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
    ;; Drop the lib.el-loading featurep guard (two forms in the tree use `load'
    ;; rather than `load-file'; both are matched).
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

- [ ] **Step 4: Verify no stray provides or guards survived**

```bash
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
loaded by init.el; the next commit switches over.

scripts/myde-flatten.el is one-shot tooling, removed at the end of phase 1."
```

## Task 3: Add temporary toggle scaffolding

`myde-customize` generated the 24 `defcustom` toggles from `myde-modules`. Both are
about to be deleted, but phase 1 must preserve behaviour so its parity check means
something. These 24 forms are written out literally and deleted in Task 8.

**Files:**
- Modify: `user-lisp/myde.el`

- [ ] **Step 1: Insert the toggle definitions**

Immediately after the `;;; Code:` line in `user-lisp/myde.el`, insert:

```elisp
;;;; Module toggles (TEMPORARY -- removed in phase 2)
;;;; ------------------------------------------------
;; Written out literally to preserve phase-1 behaviour after `myde-customize'
;; was deleted.  Phase 2 replaces every consumer with an `executable-find' gate
;; and deletes this block along with the matching entries in custom.el.

(defgroup myde-modules nil
  "MyDE module enablement."
  :group 'convenience)

(defmacro myde--deftoggle (name)
  "Define the enablement toggle for module NAME."
  `(defcustom ,(intern (format "myde-module-%s-enabled" name)) nil
     ,(format "Non-nil enables the %s module." name)
     :type 'boolean
     :group 'myde-modules))

(myde--deftoggle "ai-gptel")       (myde--deftoggle "ai-agents")
(myde--deftoggle "ai-claude")      (myde--deftoggle "ai-mcp")
(myde--deftoggle "auth-1password") (myde--deftoggle "containers-kubernetes")
(myde--deftoggle "data-csv")       (myde--deftoggle "data-dotenv")
(myde--deftoggle "data-hcl")       (myde--deftoggle "data-json")
(myde--deftoggle "data-pkl")       (myde--deftoggle "data-toml")
(myde--deftoggle "data-xml")       (myde--deftoggle "data-yaml")
(myde--deftoggle "ebook-epub")     (myde--deftoggle "ebook-pdf")
(myde--deftoggle "prog-bash")      (myde--deftoggle "prog-clisp")
(myde--deftoggle "prog-clojure")   (myde--deftoggle "prog-cpp")
(myde--deftoggle "prog-elisp")     (myde--deftoggle "prog-elixir")
(myde--deftoggle "prog-erlang")    (myde--deftoggle "prog-fish")
(myde--deftoggle "prog-go")        (myde--deftoggle "prog-javascript")
(myde--deftoggle "prog-lua")       (myde--deftoggle "prog-nushell")
(myde--deftoggle "prog-python")    (myde--deftoggle "prog-ruby")
(myde--deftoggle "prog-rust")      (myde--deftoggle "prog-scheme")
(myde--deftoggle "prog-typescript")(myde--deftoggle "prog-zig")
(myde--deftoggle "text-asciidoc")  (myde--deftoggle "text-markdown")
```

Note this defines toggles for all 36 toggleable modules, not just the 24 currently
enabled — `custom.el` supplies values for the enabled subset and the rest stay `nil`,
exactly as `myde-customize` behaved.

- [ ] **Step 2: Wrap each toggleable module section in its toggle**

For every `;;;; <category>-<name>` section in `user-lisp/myde.el` that is **not**
`core-*` and **not** `*-base`, wrap the section body:

```elisp
;;;; prog-go
;;;; -------

(when myde-module-prog-go-enabled

  ;; ... existing section body, indented or not, unchanged ...

  )
```

For the three `*-base` modules (`prog-base`, `text-base`, `ai-base`), reproduce the
old auto-load rule — loaded if any sibling in the category is enabled:

```elisp
;;;; prog-base
;;;; ---------

(when (or myde-module-prog-bash-enabled myde-module-prog-clisp-enabled
          myde-module-prog-clojure-enabled myde-module-prog-cpp-enabled
          myde-module-prog-elisp-enabled myde-module-prog-elixir-enabled
          myde-module-prog-erlang-enabled myde-module-prog-fish-enabled
          myde-module-prog-go-enabled myde-module-prog-javascript-enabled
          myde-module-prog-lua-enabled myde-module-prog-nushell-enabled
          myde-module-prog-python-enabled myde-module-prog-ruby-enabled
          myde-module-prog-rust-enabled myde-module-prog-scheme-enabled
          myde-module-prog-typescript-enabled myde-module-prog-zig-enabled)

  ;; ... existing prog-base body ...

  )
```

```elisp
;;;; text-base
;;;; ---------

(when (or myde-module-text-asciidoc-enabled myde-module-text-markdown-enabled)

  ;; ... existing text-base body ...

  )
```

```elisp
;;;; ai-base
;;;; -------

(when (or myde-module-ai-gptel-enabled myde-module-ai-agents-enabled
          myde-module-ai-claude-enabled myde-module-ai-mcp-enabled)

  ;; ... existing ai-base body ...

  )
```

All 12 `core-*` sections stay unwrapped.

- [ ] **Step 3: Re-verify the file parses**

Wrapping 39 sections by hand is where paren errors happen.

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

Expected: `OK: N top-level forms`, with N substantially lower than Task 2 step 3 —
each wrapped section collapses many top-level forms into one `when`.

- [ ] **Step 4: Commit**

```bash
git add user-lisp/myde.el
git commit -m "Add temporary module toggles to myde.el

Writes out the 24-plus-12 defcustom toggles that myde-customize used to
generate, and wraps each toggleable section in its toggle. The three
*-base sections reproduce the old sibling-enabled auto-load rule.

Throwaway scaffolding: phase 2 replaces every condition with an
executable-find gate and deletes this block."
```

## Task 4: Switch init.el to load myde.el

**Files:**
- Modify: `init.el` (replace body)

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

(require 'server)
(unless (server-running-p) (server-start))

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

- [ ] **Step 3: Probe and compare against baseline**

This is the phase 1 acceptance gate.

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
scripts/myde-probe.sh /tmp/myde-migration /tmp/myde-reports/01-flattened.txt
echo "--- modules ---"
diff <(grep '^module: ' /tmp/myde-reports/00-baseline.txt) \
     <(grep '^module: ' /tmp/myde-reports/01-flattened.txt) && echo "MODULES IDENTICAL"
echo "--- packages ---"
diff <(grep '^package: ' /tmp/myde-reports/00-baseline.txt) \
     <(grep '^package: ' /tmp/myde-reports/01-flattened.txt) && echo "PACKAGES IDENTICAL"
echo "--- errors ---"
diff <(grep '^error: ' /tmp/myde-reports/00-baseline.txt) \
     <(grep '^error: ' /tmp/myde-reports/01-flattened.txt) && echo "ERRORS IDENTICAL"
```

Expected: all three print `IDENTICAL`.

If packages differ, the usual causes are a module section whose `when` wrapper swallowed
a form it should not have, or a `require` that depended on load order the flattener
changed. The module tree is deleted in the working directory but still present at `HEAD`
until this task commits, so diff against the original:

```bash
git show HEAD:modules/prog-go/cfg.el | diff - <(sed -n '/^;;;; prog-go$/,/^;;;; prog-rust$/p' user-lisp/myde.el)
```

- [ ] **Step 4: Check init time did not regress**

```bash
grep 'init-time-seconds' /tmp/myde-reports/00-baseline.txt /tmp/myde-reports/01-flattened.txt
```

Expected: within a few milliseconds. A large regression suggests something now loads
eagerly that was previously deferred.

- [ ] **Step 5: Delete the one-shot flattener and commit**

```bash
cd /tmp/myde-migration
git rm -q scripts/myde-flatten.el
git add -A
git commit -m "Load config from user-lisp/myde.el; delete module tree

init.el becomes a five-line entry point: (require 'myde) plus server
start. Deletes modules.el, all 53 module directories, and the one-shot
flattener.

Verified at parity with the pre-migration config: identical enabled
module set, identical loaded third-party package set, identical startup
errors."
```

---

# Phase 2 — Binary gates

Goal: delete the toggles, derive enablement from `executable-find`, and get the 11
newly-live modules loading cleanly.

## Task 5: Inline exec-path-from-shell

Must land before any gate is evaluated, because on macOS GUI Emacs `exec-path` is
incomplete until it runs.

**Files:**
- Modify: `user-lisp/myde.el`

- [ ] **Step 1: Verify the `-l` assumption on this machine**

```bash
diff <($SHELL -l -c 'printf %s "$PATH"' | tr ':' '\n' | sort -u) \
     <($SHELL -l -i -c 'printf %s "$PATH"' 2>/dev/null | tr ':' '\n' | sort -u) \
  && echo "SAFE: -l is sufficient" || echo "UNSAFE: keep -l -i on this machine"
```

Expected on the macOS machine: `SAFE`. **Re-run this on the Linux machine before
trusting the config there** — if it reports `UNSAFE`, use
`'("-l" "-i")` there and accept the ~575ms.

- [ ] **Step 2: Add the environment section as the first section of myde.el**

Immediately after `;;; Code:` (above the temporary toggle block):

```elisp
;;;; Environment
;;;; -----------
;; Must precede every `executable-find' gate below.  GUI Emacs on macOS, and
;; Emacs started from a .desktop entry or systemd user unit on Linux, do not
;; inherit the login shell's PATH -- so without this, gates would silently
;; disable modules whose binaries are installed.
;;
;; `:wait t' is required: under elpaca a package is not on `load-path' until
;; queues are processed after init, which is too late for the gates.
;;
;; Dropping "-i" from the default '("-l" "-i") takes the probe from ~575ms to
;; ~88ms with an identical resulting PATH on both target machines, and keeps it
;; under `exec-path-from-shell-warn-duration-millis' (500).

(use-package exec-path-from-shell
  :ensure t
  :demand t
  :init
  (setq exec-path-from-shell-arguments '("-l"))
  :config
  (when (or (daemonp) window-system)
    (exec-path-from-shell-initialize)))
```

`:ensure t` here, not `:ensure (:wait t)` — that changes in Task 11 when elpaca
arrives. Under `package.el` this form must also be reachable, so verify the package is
present: it is, at `elpa/exec-path-from-shell-2.2`.

- [ ] **Step 3: Remove the old deferred hook**

Delete from `user-lisp/myde.el` the `core-base` remnants the flattener carried over:
the `myde-exec-path-from-shell-startup-hook` function definition, and the
`(when (memq window-system '(mac ns)) (add-hook 'emacs-startup-hook ...))` form.

```bash
grep -n 'myde-exec-path-from-shell-startup-hook' /tmp/myde-migration/user-lisp/myde.el
```

Expected after editing: no output.

- [ ] **Step 4: Verify exec-path is now complete during init**

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
scripts/myde-probe.sh /tmp/myde-migration /tmp/myde-reports/02-path.txt
grep -E '^(exec-path-entries|binary): ' /tmp/myde-reports/02-path.txt
```

Expected: `exec-path-entries` around 42, and `yes` for `go cargo zig lua ruby python3
node elixir erl clojure guile clangd fish nu tofu op kubectl claude pdftoppm
asciidoctor`; `no` for `sbcl pkl terraform`.

If binaries report `no` that you know are installed, `exec-path-from-shell` did not run
— check the `(or (daemonp) window-system)` guard, remembering that a daemon satisfies
`daemonp`.

- [ ] **Step 5: Commit**

```bash
cd /tmp/myde-migration
git add user-lisp/myde.el
git commit -m "Inline exec-path-from-shell ahead of module configuration

Moves it off emacs-startup-hook to the first section of myde.el, since
binary gates in the next commit are evaluated during init and need a
complete exec-path. Drops -i from the shell arguments: ~575ms to ~88ms
with a verified-identical PATH.

Widens the guard from mac/ns to (or (daemonp) window-system) -- Linux
Emacs started from a .desktop entry or systemd unit has no login shell
ancestry either."
```

## Task 6: Replace toggles with binary gates

**Files:**
- Modify: `user-lisp/myde.el`
- Modify: `custom.el` (worktree copy and, at go-live, the real one)

- [ ] **Step 1: Delete the temporary toggle block**

Remove the entire `;;;; Module toggles (TEMPORARY ...)` section added in Task 3 —
`defgroup`, `myde--deftoggle`, and all 36 calls.

- [ ] **Step 2: Replace each section's condition**

Unconditional — delete the `(when …)` wrapper entirely, leaving the body at top level.
All 12 `core-*` sections plus: `prog-base`, `text-base`, `ai-base`, `prog-elisp`,
`prog-bash`, `data-csv`, `data-dotenv`, `data-json`, `data-toml`, `data-xml`,
`data-yaml`, `text-markdown`, `ebook-epub`, `ai-gptel`, `ai-mcp`, `ai-agents`.

The `*-base` sections become unconditional because their categories now always have at
least one live member.

Gated — replace the toggle condition with the gate:

| Section | Replace `when` condition with |
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
| `data-hcl` | `(or (executable-find "tofu") (executable-find "terraform"))` |
| `data-pkl` | `(executable-find "pkl")` |
| `text-asciidoc` | `(executable-find "asciidoctor")` |
| `ebook-pdf` | `(executable-find "pdftoppm")` |
| `auth-1password` | `(executable-find "op")` |
| `containers-kubernetes` | `(executable-find "kubectl")` |
| `ai-claude` | `(executable-find "claude")` |

Each gated section gets a comment naming its gate, so the rule is legible without
consulting this plan:

```elisp
;;;; prog-go
;;;; -------
;; Gate: go

(when (executable-find "go")
  ...)
```

- [ ] **Step 3: Strip the toggles from custom.el**

All 24 are on their own line in a fixed format, so a filter is enough:

```bash
cd /tmp/myde-migration
grep -c "myde-module-.*-enabled" custom.el
grep -v "^ '(myde-module-[a-z0-9-]*-enabled t)$" custom.el > custom.el.new
mv custom.el.new custom.el
grep -c "myde-module-.*-enabled" custom.el || echo "0 remaining"
```

Expected: `24`, then `0 remaining`.

- [ ] **Step 4: Verify the file parses and gates resolve as predicted**

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
scripts/myde-probe.sh /tmp/myde-migration /tmp/myde-reports/02-gated.txt
echo "--- modules (should be empty; toggles are gone) ---"
grep -c '^module: ' /tmp/myde-reports/02-gated.txt
echo "--- packages newly loaded vs baseline ---"
comm -13 <(grep '^package: ' /tmp/myde-reports/00-baseline.txt) \
         <(grep '^package: ' /tmp/myde-reports/02-gated.txt)
echo "--- packages no longer loaded vs baseline ---"
comm -23 <(grep '^package: ' /tmp/myde-reports/00-baseline.txt) \
         <(grep '^package: ' /tmp/myde-reports/02-gated.txt)
```

Expected: module count `0`. Newly loaded packages should be those belonging to the 11
newly-live modules (`clojure-mode`, `cider`, `elixir-ts-mode`, `rust-mode`, `zig-ts-mode`,
`lua-mode`, `geiser`, `adoc-mode`, and similar). Packages no longer loaded should be
`pkl-mode` only.

Anything else in either list is a mistake in step 2's mapping.

- [ ] **Step 5: Commit**

```bash
cd /tmp/myde-migration
git add user-lisp/myde.el
git commit -m "Replace module toggles with binary presence gates

Enablement now derives from executable-find rather than 24 hand-maintained
defcustom toggles. Presence equals intent: no override list, no deny list.

Sections with no meaningful gating binary become unconditional -- they are
:mode-deferred, so they cost nothing at startup. The three *-base sections
become unconditional too, since their categories always have a live member.

On the development machine this enables 11 previously-disabled modules
(clojure, cpp, elixir, erlang, lua, ruby, rust, scheme, zig, asciidoc,
1password) and disables data-pkl, which has no pkl binary installed."
```

## Task 7: Fix the newly-live modules

~1,700 lines across 11 modules have never executed. Expect real breakage here; it is
pre-existing, not caused by the migration.

**Files:**
- Modify: `user-lisp/myde.el` (sections for the 11 newly-live modules)

- [ ] **Step 1: Get the full error list**

```bash
grep '^error: ' /tmp/myde-reports/02-gated.txt
comm -13 <(grep '^error: ' /tmp/myde-reports/00-baseline.txt) \
         <(grep '^error: ' /tmp/myde-reports/02-gated.txt)
```

The second command isolates errors the migration introduced from ones that predate it.

- [ ] **Step 2: Fix the known-missing `:ensure` on geiser**

`prog-scheme`'s `geiser` form has no `:ensure` and was never exercised. Under
`package.el` it loads only because `geiser` is in `package-selected-packages`; it is
not. Add it:

```elisp
(use-package geiser
  :ensure t
  ;; ... existing keywords unchanged ...
  )
```

- [ ] **Step 3: Work each remaining error to a fix**

For each error line, the three patterns seen in this codebase and their fixes:

- `Cannot open load file: <pkg>` — the package is not installed. Add `:ensure t` to its
  `use-package` form if it is a third-party package, or `:ensure nil` if built-in.
- `Invalid function: <fn>` in a `:hook` — the hook target does not exist in the
  installed version. Verify with
  `emacsclient -s <sock> -e '(fboundp (quote <fn>))'` and correct the name.
- `Symbol's value as variable is void: <var>` — a `:custom` or `:init` reference to a
  variable the package renamed. Check the package's source under `elpa/`.

Re-probe after each fix:

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
scripts/myde-probe.sh /tmp/myde-migration /tmp/myde-reports/02-fixed.txt
grep '^error: ' /tmp/myde-reports/02-fixed.txt
```

- [ ] **Step 4: Confirm no new errors remain**

```bash
comm -13 <(grep '^error: ' /tmp/myde-reports/00-baseline.txt) \
         <(grep '^error: ' /tmp/myde-reports/02-fixed.txt)
```

Expected: empty output. The migration has introduced no errors the old config did not
already have.

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
`elixir-ls` needs a project root.

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

# Phase 3 — elpaca

Goal: replace `package.el` with elpaca and prove a cold clone builds from nothing.

## Task 8: Make :ensure explicit and defer what can be deferred

Do the `:ensure` work **before** elpaca arrives. Under `package.el` these packages load
anyway via `package-selected-packages`, so steps 1-4 are a behaviour-preserving no-op
that becomes load-bearing in Task 9. Steps 5-6 then serve the spec's deferred-loading
goal, which nothing else in this plan addresses.

**Files:**
- Modify: `user-lisp/myde.el`

- [ ] **Step 1: Collapse the 25 duplicate indent-bars forms into one**

`indent-bars` appears 25 times, once per language and data-format section, each with
`:hook` and no `:ensure`. Delete all 25 and add a single form in the `prog-base`
section. Hook targets are harmless when a mode never activates, so this needs no
gating:

```elisp
;; indent-bars for every mode that wants it.  Collapsed from 25 duplicate
;; declarations across the module tree; hooks on modes that never activate are
;; inert, so this needs no binary gating.
(use-package indent-bars
  :ensure t
  :hook ((bash-ts-mode c-ts-mode c++-ts-mode clojure-mode csv-mode
          dotenv-mode elixir-ts-mode emacs-lisp-mode erlang-mode
          fish-mode go-ts-mode heex-ts-mode hcl-mode js-ts-mode json-ts-mode
          lisp-mode lua-ts-mode nushell-mode nxml-mode python-ts-mode
          ruby-ts-mode rust-ts-mode scheme-mode toml-ts-mode
          typescript-ts-mode tsx-ts-mode yaml-ts-mode zig-ts-mode)
         . indent-bars-mode))
```

Before writing the list, harvest the actual modes from the current file so none are
lost:

```bash
cd /tmp/myde-migration
grep -A3 'use-package indent-bars' user-lisp/myde.el | grep -oE '[a-z0-9+-]+-mode' | sort -u
```

Use that output as the authoritative hook list rather than the illustrative list above.

- [ ] **Step 2: Add `:ensure nil` to the six built-in forms**

Three `treesit` forms (in the `prog-clisp`, `prog-clojure`, `prog-scheme` sections) and
three `project` forms (same sections) have no `:ensure`. Both are built-in, so without
`:ensure nil` elpaca would try to clone them:

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

- [ ] **Step 3: Verify nothing is left without `:ensure`**

```bash
cd /tmp/myde-migration
emacs -Q --batch --eval '(let ((missing 0) (total 0))
  (letrec ((walk (lambda (f)
                   (when (consp f)
                     (when (eq (car-safe f) (quote use-package))
                       (setq total (1+ total))
                       (unless (memq :ensure f)
                         (setq missing (1+ missing))
                         (message "MISSING :ensure -- %s" (cadr f))))
                     (mapc walk f)))))
    (with-temp-buffer
      (insert-file-contents "user-lisp/myde.el")
      (goto-char (point-min))
      (condition-case nil
          (while t (funcall walk (read (current-buffer))))
        (end-of-file nil))))
  (message "total use-package forms: %d, missing :ensure: %d" total missing)
  (when (> missing 0) (kill-emacs 1)))'
```

Expected: `total use-package forms: ~245, missing :ensure: 0`. The total is lower than
the original 269 because 25 `indent-bars` forms collapsed into one.

- [ ] **Step 4: Confirm behaviour is unchanged under package.el**

Do this before touching deferral, so the `:ensure` work is verified in isolation.

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
scripts/myde-probe.sh /tmp/myde-migration /tmp/myde-reports/03-ensure.txt
diff <(grep '^package: ' /tmp/myde-reports/02-fixed.txt) \
     <(grep '^package: ' /tmp/myde-reports/03-ensure.txt) && echo "PACKAGES IDENTICAL"
```

Expected: `PACKAGES IDENTICAL`. Adding `:ensure` changes only declarations, not outcomes.

- [ ] **Step 5: Audit for eager loading**

Deferred loading is a stated goal of the spec, and nothing so far verifies it. The same
walker finds forms that load at startup rather than on demand — `:demand t`, or no
deferring keyword at all:

```bash
cd /tmp/myde-migration
emacs -Q --batch --eval '(letrec
  ((deferring (quote (:mode :interpreter :commands :bind :bind-keymap :hook
                      :magic :magic-fallback :defer :after)))
   (walk (lambda (f)
           (when (consp f)
             (when (eq (car-safe f) (quote use-package))
               (cond ((memq :demand f)
                      (message "DEMAND  %s" (cadr f)))
                     ((not (seq-some (lambda (k) (memq k f)) deferring))
                      (message "EAGER   %s" (cadr f)))))
             (mapc walk f)))))
  (with-temp-buffer
    (insert-file-contents "user-lisp/myde.el")
    (goto-char (point-min))
    (condition-case nil
        (while t (funcall walk (read (current-buffer))))
      (end-of-file nil))))'
```

Every line is a package loaded at startup. Expected `DEMAND`: `exec-path-from-shell`
only. Expected `EAGER`: the `core-*` packages that genuinely must be present at startup
— theme, modeline, dashboard, completion framework, `emacs`/`treesit`/`recentf` and the
other `:ensure nil` built-in settings blocks.

For each remaining line, decide and act:

- A built-in settings block (`:ensure nil`, only `:init`/`:custom`) — leave it. Setting
  variables is not loading a package.
- A third-party package whose effect is a global mode enabled at startup (theme,
  `diminish`, `dashboard`) — leave it, and add a one-line comment saying why it cannot
  defer.
- A third-party package tied to a file type or a command — add `:mode`, `:hook`, or
  `:commands`. That is the deferral the spec asks for.

Record the counts before and after in the commit message. This is the only step that
directly serves the deferred-loading goal, so do not skip it because the count looks
tolerable.

- [ ] **Step 6: Confirm deferral did not break anything**

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
scripts/myde-probe.sh /tmp/myde-migration /tmp/myde-reports/03-deferred.txt
grep 'init-time-seconds' /tmp/myde-reports/02-fixed.txt /tmp/myde-reports/03-deferred.txt
comm -13 <(grep '^error: ' /tmp/myde-reports/02-fixed.txt) \
         <(grep '^error: ' /tmp/myde-reports/03-deferred.txt)
```

Expected: no new errors. The loaded-package count will legitimately *drop* here — that
is the point of deferring — so do not compare package sets against the baseline after
this step. Compare error sets only.

- [ ] **Step 7: Commit**

```bash
cd /tmp/myde-migration
git add user-lisp/myde.el
git commit -m "Make :ensure explicit and defer what can be deferred

32 of 269 use-package forms had no :ensure and were installed only
because they appeared in package-selected-packages. That list disappears
with package.el, so each would have silently failed to install under
elpaca.

Adds :ensure t to indent-bars and geiser, :ensure nil to the three
treesit and three project forms, and collapses 25 duplicate indent-bars
declarations into a single form with a combined hook list.

Also adds :mode/:hook/:commands to third-party packages that had no
deferring keyword, cutting startup-loaded packages from N to M. Packages
left eager are global modes that cannot defer by nature; each now carries
a comment saying so."
```

Replace `N` and `M` with the counts from step 5 before committing.

## Task 9: Bootstrap elpaca

**Files:**
- Modify: `early-init.el`
- Modify: `init.el`
- Modify: `.gitignore`

- [ ] **Step 1: Disable package.el at startup**

Add to `early-init.el`, near the other startup settings:

```elisp
;; Elpaca replaces package.el entirely; package.el must not activate packages
;; at startup or the two will fight over load-path.
(setq package-enable-at-startup nil)
```

- [ ] **Step 2: Move the GC and handler restoration to elpaca's hook**

Elpaca processes its queues on `after-init-hook`, so anything on `after-init-hook` or
`emacs-startup-hook` now runs *before* packages are activated. Find the restoration
hooks in `early-init.el` and change their hook variable:

```elisp
;; Elpaca activates packages on after-init-hook, so restoration must wait for
;; `elpaca-after-init-hook' -- elpaca's documented analogue of after-init-hook.
(add-hook 'elpaca-after-init-hook #'myde--restore-gc-settings)
(add-hook 'elpaca-after-init-hook #'myde--restore-file-name-handler-alist)
```

Use the actual function names present in `early-init.el`; inspect it first:

```bash
grep -n 'after-init-hook\|emacs-startup-hook' /tmp/myde-migration/early-init.el
```

`elpaca-after-init-hook` is not bound when `early-init.el` runs, but `add-hook` creates
an unbound hook variable safely, and elpaca's `defcustom` will not clobber an existing
value.

- [ ] **Step 3: Add the installer to init.el**

Replace `init.el` with the elpaca-based entry point. The installer block is
reproduced verbatim from elpaca's README (installer version 0.12):

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

;; The elpaca-use-package menu recipe carries :wait t, so this blocks until
;; elpaca-use-package is built and `use-package' :ensure support is active --
;; which myde.el depends on from its first form.
(elpaca elpaca-use-package
  (elpaca-use-package-mode))

;;;; Configuration

(require 'myde)

;;;; Deferred startup

;; Elpaca processes queues after init, so custom.el and the server must wait
;; for `elpaca-after-init-hook' rather than after-init-hook.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(add-hook 'elpaca-after-init-hook #'myde-load-custom-file)
(add-hook 'elpaca-after-init-hook #'myde-start-server)

;; That's all Folks!
(provide 'init)
;;; init.el ends here
```

- [ ] **Step 4: Define the two named hook functions**

The project convention forbids lambdas as hook functions. Add to the `Environment`
section of `user-lisp/myde.el`, before the `exec-path-from-shell` form:

```elisp
(defun myde-load-custom-file ()
  "Load `custom-file' if it exists.
Runs on `elpaca-after-init-hook' so that any package a saved
customization refers to has already been activated."
  (when (and custom-file (file-exists-p custom-file))
    (load custom-file :noerror)))

(defun myde-start-server ()
  "Start the Emacs server unless one is already running."
  (require 'server)
  (unless (server-running-p) (server-start)))
```

- [ ] **Step 5: Remove the package.el setup from myde.el**

Delete from the `core-base` section: the `(require 'package)`, `package-user-dir`,
`package-archives`, `package-archive-priorities`, the `package-pinned-packages` `dolist`
for `csharp-mode`/`wallpaper`, `package-install-upgrade-built-in`,
`(package-initialize)`, the `advice-add` on `package--upgradeable-packages`, the
`package-refresh-contents` guard, and the `custom-file` loading block that Task 9
step 3 replaced.

Also delete the now-orphaned `myde/filter-git-only-vc-packages` function definition and
both version-conditional `transient` `use-package` forms (the `:pin` mechanism is
package.el-only):

```bash
cd /tmp/myde-migration
for s in 'require .package' package-user-dir package-archives package-archive-priorities \
         package-pinned-packages package-install-upgrade-built-in 'package-initialize' \
         'myde/filter-git-only-vc-packages' 'package-refresh-contents' ':pin '; do
  printf '%-40s %s\n' "$s" "$(grep -c "$s" user-lisp/myde.el)"
done
```

Expected after editing: `0` for every one.

Keep the first `transient` form — the one setting XDG paths for
`transient-levels-file` and friends — and give it `:ensure nil`.

- [ ] **Step 6: Ignore the elpaca directory**

In `.gitignore`, replace the `elpa/` entry:

```
# installed packages
elpaca/
```

- [ ] **Step 7: Change exec-path-from-shell to `:wait t`**

Now that elpaca is present, the Task 5 form must block. In `user-lisp/myde.el`:

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

- [ ] **Step 8: Commit before the cold test**

```bash
cd /tmp/myde-migration
git add -A
git commit -m "Replace package.el with elpaca

Bootstraps elpaca in init.el, enables elpaca-use-package-mode, and moves
custom.el loading and server start to elpaca-after-init-hook, since
elpaca processes its queues after init.

exec-path-from-shell becomes :ensure (:wait t) -- under elpaca a package
is not on load-path until queues process, which is after myde.el is read,
and every binary gate depends on it.

Deletes all package.el scaffolding and the five workarounds it required:
built-in archive pinning for csharp-mode and wallpaper,
package-install-upgrade-built-in, the package--upgradeable-packages
advice for git-only VC packages, version-conditional transient pinning,
and the package-initialize ordering constraints."
```

## Task 10: Convert the VC packages to elpaca recipes

**Files:**
- Modify: `user-lisp/myde.el`
- Modify: `custom.el`

- [ ] **Step 1: Convert each `:vc` declaration**

Eight packages move from `package-vc-selected-packages` in `custom.el` to elpaca
recipes on their `use-package` forms. `ob-csharp` is dropped — there is no C# module.

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

- [ ] **Step 2: Strip the package lists from custom.el**

Everything package-related leaves `custom.el`. What remains is small enough to write out
in full — replace the whole file with this, which is the original minus the 24 toggles
(already gone from Task 6) and the two package lists:

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

- [ ] **Step 3: Cold-start test — the phase 3 acceptance gate**

This is the real test: build every package from nothing.

```bash
rm -rf /tmp/myde-migration/elpa /tmp/myde-migration/elpaca
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
time scripts/myde-probe.sh /tmp/myde-migration /tmp/myde-reports/03-cold.txt
```

The `elpa` symlink from Task 0 must go — leaving it lets package.el leftovers mask a
missing elpaca recipe.

Expected: several minutes on first run while elpaca clones and builds. Then a report.
If the daemon fails to start, run it in the foreground to watch the bootstrap:

```bash
emacs --init-directory=/tmp/myde-migration --daemon=coldcheck
```

- [ ] **Step 4: Compare the cold build against the package.el result**

```bash
comm -23 <(grep '^package: ' /tmp/myde-reports/03-ensure.txt) \
         <(grep '^package: ' /tmp/myde-reports/03-cold.txt)
```

Expected: empty, or `pkl-mode` only. Anything else is a package elpaca failed to
install — almost always a `use-package` form still missing `:ensure`, or a recipe whose
`:host`/`:repo` is wrong.

```bash
grep '^error: ' /tmp/myde-reports/03-cold.txt
```

- [ ] **Step 5: Check for packages that cloned but failed to build**

A package can clone successfully and still fail to byte-compile, in which case it has a
directory under `sources/` but none under `builds/`. This check uses no elpaca internals:

```bash
cd /tmp/myde-migration
comm -23 <(ls elpaca/sources | sort) <(ls elpaca/builds | sort)
```

Expected: empty output. Any name listed here needs investigating — open
`M-x elpaca-log` in a real Emacs and read its entry. A few recipes legitimately declare
no build step, so treat a listed name as a question rather than a confirmed failure.

- [ ] **Step 6: Address the org upgrade if it failed**

Upgrading built-in `org` is elpaca's known sharp edge. If step 5 reports `org` failed,
the config's `org` form must either use `:ensure nil` and stay on the built-in version,
or carry elpaca's documented org recipe. Check what the current form does:

```bash
grep -n -A5 '(use-package org$' /tmp/myde-migration/user-lisp/myde.el | head -20
```

Prefer `:ensure nil` — the built-in `org` in Emacs 31.1 is recent, and this avoids the
problem entirely. Only pursue a recipe if a specific needed feature is missing.

- [ ] **Step 7: Commit**

```bash
cd /tmp/myde-migration
git add -A
git commit -m "Convert VC packages to elpaca recipes

Eight git-only packages move from package-vc-selected-packages in
custom.el to :ensure recipes on their use-package forms. Drops ob-csharp,
which had no corresponding module.

custom.el shrinks to faces, safe themes, and a handful of settings --
package-selected-packages and package-vc-selected-packages are no longer
a source of truth for anything.

Verified by a cold build: elpaca clones and builds every package from an
empty elpaca/ directory with no failures."
```

---

# Phase 4 — Literate

Goal: `myde.org` becomes the single editable source, tangling all three elisp files.

## Task 11: Create myde.org

**Files:**
- Create: `myde.org`

- [ ] **Step 1: Build the org file with three subtrees**

Create `myde.org` at the worktree root with this exact skeleton. Each top-level heading
sets its tangle target via a property drawer, and the file-level property defaults to
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
   comments. Each module section becomes one `#+begin_src` block under the matching `**`
   heading. The `myde.el` file header goes in a block under `** Environment` (first) and
   the `(provide 'myde)` plus `;;; myde.el ends here` lines go in a final block under
   `** Ebooks` (last).

The `**` heading order above deliberately matches the *existing* section order in
`myde.el`, which came from `myde-modules` load order — not the grouping sketched in the
spec's "Literate workflow" section. Load order is known-working and reordering it risks
breaking dependencies for no benefit; see "Deferred, with rationale" at the end of this
plan.

`:comments no` is what keeps `org-babel` from injecting provenance comments into the
output, which would otherwise defeat the byte-identical check in the next step.

- [ ] **Step 2: Tangle**

```bash
cd /tmp/myde-migration
emacs -Q --batch --eval '(progn (require (quote org))
  (org-babel-tangle-file "/tmp/myde-migration/myde.org"))'
```

Expected: a message listing the three tangled files.

- [ ] **Step 3: Verify the tangled output is byte-identical to the committed files**

This is the phase 4 acceptance gate. The org file must reproduce phase 3's output
exactly — no reformatting, no lost forms.

Compare the tangled files on disk against the blobs committed at the end of phase 3:

```bash
cd /tmp/myde-migration
for f in early-init.el init.el user-lisp/myde.el; do
  if git show "HEAD:$f" | diff -q - "$f" >/dev/null; then
    echo "IDENTICAL  $f"
  else
    echo "DIFFERS    $f"
    git show "HEAD:$f" | diff - "$f" | head -20
  fi
done
```

Expected: `IDENTICAL` for all three. Whitespace differences are the usual cause —
check for a trailing newline added or removed at a block boundary.

- [ ] **Step 4: Commit**

```bash
cd /tmp/myde-migration
git add myde.org
git commit -m "Add myde.org as literate source for all three elisp files

Single org file tangles early-init.el, init.el, and user-lisp/myde.el via
per-subtree :tangle properties. Tangled output is byte-identical to the
hand-maintained files it replaces, so this commit changes no behaviour.

Outputs stay committed: a fresh clone works without tangling, and startup
never loads org."
```

## Task 12: Wire up the tangle workflow

**Files:**
- Modify: `Makefile`
- Modify: `myde.org` (file-local variables)
- Modify: `user-lisp/myde.el` (safe-local-eval-forms)

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

- [ ] **Step 3: Add auto-tangle on save**

Append to `myde.org`:

```org
# Local Variables:
# eval: (add-hook 'after-save-hook #'org-babel-tangle nil t)
# End:
```

- [ ] **Step 4: Whitelist the local eval form**

Without this, opening `myde.org` prompts about unsafe local variables every time. Add
to the `Core` section of the `Configuration` subtree in `myde.org`, so it lands in
`user-lisp/myde.el`:

```elisp
;; Let myde.org's file-local auto-tangle hook run without prompting.
(with-eval-after-load 'files
  (add-to-list 'safe-local-eval-forms
               '(add-hook 'after-save-hook #'org-babel-tangle nil t)))
```

- [ ] **Step 5: Re-tangle, verify, commit**

```bash
cd /tmp/myde-migration
make tangle
make check
git add Makefile myde.org user-lisp/myde.el
git commit -m "Add tangle and check targets, and auto-tangle on save

make tangle regenerates the three elisp files from myde.org. make check
tangles and fails if the result differs from what is committed, catching
drift between source and output.

A file-local after-save-hook in myde.org tangles on every save;
safe-local-eval-forms is extended so it runs without prompting."
```

## Task 13: Update documentation and agent skills, then go live

**Files:**
- Modify: `.agents/AGENTS.md` (reached via the `CLAUDE.md` / `AGENTS.md` symlinks)
- Modify: `README.md`
- Rewrite: `.agents/skills/myde/SKILL.md`
- Check: `.agents/skills/elisp/SKILL.md`

- [ ] **Step 1: Rewrite the AGENTS.md architecture sections**

`.agents/AGENTS.md` documents the module system, the package.el invariants, and the
`lib.el`/`cfg.el` split — all now gone. Replace those sections with:

- **Commands**: add `make tangle` and `make check` alongside `make link`/`make unlink`.
- **Architecture**: the three tangled files and `myde.org` as sole editable source.
- **Module enablement**: presence-as-intent via `executable-find`; the gate table from
  the spec; no toggles, no override list.
- **Package management**: elpaca; `:ensure t` for third-party, `:ensure nil` for
  built-ins, recipes for git-only packages; `elpaca-after-init-hook` in place of
  `after-init-hook`.
- **Editing workflow**: edit `myde.org`, never the tangled `.el` files; they are
  regenerated and committed.

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

Add two new cautions worth recording:

```markdown
- `user-lisp/` sits at `load-path` position 0 and shadows built-ins. Only
  `myde.el` belongs there — a file named `org.el` would shadow built-in Org.
- Binary gates are evaluated during init, so `exec-path` must be complete first.
  `exec-path-from-shell` uses `:ensure (:wait t)` and must remain the first
  `use-package` form in the Configuration subtree.
```

- [ ] **Step 2: Rewrite the `myde` agent skill**

`.agents/skills/myde/SKILL.md` describes only the module system this migration deletes —
the `lib.el`/`cfg.el` split, `myde-modules`, `myde/m`, `myde-initialize`. Every rule in
it is wrong after phase 1. Its description field will still match on "adding or editing
modules", so leaving it in place actively misleads any agent that loads it.

Replace its body with the conventions that now apply:

- Edit `myde.org` only. Never edit `early-init.el`, `init.el`, or `user-lisp/myde.el`
  directly — they are tangled output and the next save of `myde.org` overwrites them.
- Adding support for a tool: add a `#+begin_src emacs-lisp` block under the appropriate
  `**` heading in the Configuration subtree, wrapped in
  `(when (executable-find "<binary>") …)` where a gating binary exists. No toggle, no
  registration list, no `custom.el` entry.
- Every `use-package` form needs an explicit `:ensure` — `t` for third-party, `nil` for
  built-ins, a recipe plist for git-only packages.
- The gate wraps the whole form. `:if` inside a `use-package` form does not stop elpaca
  from cloning.
- Prefer a deferring keyword (`:mode`, `:hook`, `:commands`) over eager loading.
- Run `make check` before committing.

Update its `description:` frontmatter to match, so it stops advertising the module
system:

```yaml
description: This skill should be used when editing myde.org, the literate source for the myde.emacs configuration — adding or changing use-package declarations, binary-presence gates, or elpaca recipes.
```

- [ ] **Step 3: Check the `elisp` skill for stale rules**

`.agents/skills/elisp/SKILL.md` covers general Emacs Lisp style and should mostly survive
untouched. Read it and correct only what the migration invalidates:

```bash
grep -n 'package-install\|package-selected\|:pin\|lib\.el\|cfg\.el\|modules/\|emacs "30' \
  /tmp/myde-migration/.agents/skills/elisp/SKILL.md
```

Fix any hit. Expected: few or none — if the grep is empty, this step is done.

- [ ] **Step 4: Update README.md**

Update the installation and structure sections to describe `myde.org` plus three
tangled files, and replace any description of `M-x customize-group RET myde-modules`
with the binary-detection rule.

- [ ] **Step 5: Full verification before going live**

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
scripts/myde-probe.sh /tmp/myde-migration /tmp/myde-reports/04-final.txt
echo "--- errors ---"
grep '^error: ' /tmp/myde-reports/04-final.txt
echo "--- packages lost vs original baseline ---"
comm -23 <(grep '^package: ' /tmp/myde-reports/00-baseline.txt) \
         <(grep '^package: ' /tmp/myde-reports/04-final.txt)
echo "--- init time ---"
grep 'init-time-seconds' /tmp/myde-reports/00-baseline.txt /tmp/myde-reports/04-final.txt
cd /tmp/myde-migration && make check
```

Expected: no errors beyond the baseline's; `pkl-mode` as the only lost package; `make
check` clean.

- [ ] **Step 6: Commit the documentation and skills**

```bash
cd /tmp/myde-migration
git add .agents/ README.md
git commit -m "Update docs and agent skills for three-file literate config

Documents myde.org as the sole editable source, presence-as-intent module
enablement, and elpaca package management. Removes the module system,
declarative loading, and package.el invariant sections, none of which
describe the config any more. Raises the version floor to Emacs 31.1,
required for user-lisp-directory.

Rewrites the myde skill, which described only the deleted module system
and would have misled any agent that loaded it.

Adds two cautions: user-lisp shadows built-ins at load-path position 0,
and exec-path-from-shell must stay first so binary gates see a complete
exec-path."
```

- [ ] **Step 7: Go live**

`~/.config/emacs` already symlinks to the repository, so merging is all that is needed.

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
git merge --no-ff migration/three-file-literate -m "Merge three-file literate config migration

Collapses 53 module directories and 24 defcustom toggles into three elisp
files tangled from a single myde.org. Module enablement now derives from
binary presence; packages are managed by elpaca."
```

Then copy the reduced `custom.el` over the live one — it is untracked, so the merge
does not touch it:

```bash
cp /tmp/myde-migration/custom.el custom.el
```

- [ ] **Step 8: Verify the live config**

Quit any running Emacs, then start a real GUI Emacs from the desktop or Dock — not from
a terminal — so the `exec-path-from-shell` path is genuinely exercised.

The main tree has no `elpaca/`, so this first start clones and builds every package.
Expect several minutes and a visible `*elpaca-log*`. Confirm afterwards:

```bash
emacsclient -e '(list (length exec-path) (executable-find "go") emacs-init-time)'
```

Expected: an `exec-path` length near 42, a resolved `go` path, and an init time in the
same range as the probe reported.

- [ ] **Step 9: Clean up**

Only after the live config is confirmed working. `git worktree remove` refuses to delete
a worktree with untracked files, and `elpaca/` is untracked:

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
rm -rf /tmp/myde-migration/elpaca /tmp/myde-migration/elpa
git worktree remove /tmp/myde-migration
git branch -d migration/three-file-literate
rm -rf elpa
git status --porcelain
```

`rm -rf elpa` removes the old package.el directory from the main tree; nothing reads it
any more. Keep `/tmp/myde-reports/` until fully satisfied — it is the only record of the
pre-migration state.

---

## Deferred, with rationale

- **Byte-compiling `myde.el`.** All three files keep `no-byte-compile: t`, matching the
  current `init.el`. A stale `.elc` beside a tangled `.el` is a confusing failure mode,
  and the tangle workflow would need a compile step. Revisit if load time becomes
  measurable — `emacs-init-time` is the signal.
- **`myde.el` as several files.** The spec fixes three loaded files. If the ~7,000-line
  buffer proves unpleasant despite org folding, `myde.el` can tangle into
  `user-lisp/myde-{core,prog,data}.el` with `myde.el` requiring them, without touching
  `myde.org`'s structure.
- **Removing the `zig`/`ruby` LSP config.** `zls` and `ruby-lsp` are absent, so those
  eglot blocks are inert. They cost nothing and become correct the moment the servers
  are installed.
- **Reordering sections to the spec's grouping.** The spec's "Literate workflow" section
  sketches the order Environment → Core → Languages → Formats → Ebooks/AI/Auth. The
  actual order is Environment → Core → AI → Auth → Data → Containers → Languages → Text
  → Ebooks, inherited from `myde-modules` load order. That order is known-working;
  changing it risks breaking a load-order dependency for a purely cosmetic gain. Org
  folding makes navigation order largely irrelevant. Revisit only if a dependency audit
  is done first.
