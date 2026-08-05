# Org Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the personal project management and PIM system specified in
[org-workflow-design.md](org-workflow-design.md) by rewriting `modules/core-org/`.

**Architecture:** One org file per code project in `~/org/projects/`, named after
the project directory under `~/devel/projects/`. A single `~/org/inbox.org`
capture sink. `org-agenda-files` is a list containing the inbox file and the
projects *directory*, which org expands natively — no discovery code. Roughly 40
lines of new elisp in `lib.el`, all of it project-name derivation and template
generation; everything else is built-in org variable configuration in `cfg.el`.

**Tech Stack:** Emacs 30.2, built-in org 9.7.11, built-in ERT for tests, denote
4.2.3 (unchanged, in `core-notes`). **No new packages.**

---

## Verified facts this plan depends on

Each was confirmed by batch-evaluating against this machine's Emacs 30.2. Do not
"simplify" away the code that handles them.

| # | Fact | Consequence |
|---|------|-------------|
| 1 | A **missing agenda file** triggers a blocking `Non-existent agenda file … [R]emove from list or [A]bort?` prompt | `inbox.org` must be created at load time or first startup hangs |
| 2 | A **missing agenda directory** is silently returned *as if it were a file* | `~/org/projects/` must exist or the agenda tries to parse a directory |
| 3 | An **existing directory** in `org-agenda-files` expands to its `.org` files, non-recursively | Flat one-file-per-project layout; no discovery function needed |
| 4 | A capture target `file` given as a **function symbol** is called; the function definition beats a same-named variable | `(file+headline myde-org-project-target "Tasks")` is valid |
| 5 | `org-tag-re` is `[[:alnum:]_@#%]+` — excludes `-` and `.` | `#+filetags:` values must be sanitized; **filenames need not be** |
| 6 | `%^G` completes tags across all agenda files; `%^g` only within the target file | Thought template uses `%^G` |
| 7 | `(project-name (project-current))` returns nil in the 2 non-VC project dirs, and reports an inner repo in `multi-tenancy/repos/` | Project identity uses path-prefix derivation, not `project.el` |
| 8 | `byte-compile-file` honors the `no-byte-compile: t` cookie — returns `no-byte-compile`, writes nothing, warns nothing | The compile check must strip the cookie into a scratch copy first |
| 9 | `%^G` omits its leading colon when the preceding char is already `:` | `:bookmark:%^G` yields `:bookmark:emacs:orgmode:`, not `:bookmark::emacs:` |
| 10 | Editing `Info.plist` invalidates the ad-hoc signature `osacompile` applies; `codesign -v` then fails | `make install-macos` must re-sign with `codesign --force --sign -` |
| 11 | `docs/org-protocol-setup.md` documents `template=u`, but only `b` exists | The documented bookmarklet is broken today and must be corrected |

## File structure

| File | Action | Responsibility |
|------|--------|----------------|
| `tests/core-org.el` | **Create** | ERT checks for name derivation, sanitization, template validity |
| `Makefile` | Modify | Add `test`, `install-macos`, and `uninstall-macos` targets |
| `modules/core-org/lib.el` | Rewrite | Directory/file variables, project-name derivation, template generation |
| `modules/core-org/cfg.el` | Modify | Agenda files/views, TODO keywords, capture templates, keybindings, archive, org-id |
| `docs/org-protocol-setup.md` | Modify | Correct the broken `template=u` bookmarklet and stale `bookmarks.org` references; replace the manual Automator instructions with `make install-macos` |
| `AGENTS.md` | Modify | Document the new make targets |

`tests/` is a new top-level directory. It is deliberately **not** inside
`modules/core-org/`, because `AGENTS.md` specifies that a module contains
exactly two files, `lib.el` and `cfg.el`.

## Sequencing constraint

`cfg.el` currently references `myde-org-tasks-file`,
`myde-org-bookmarks-file`, `myde-org-capture-project-line`,
`myde-org-capture-scheduled-line`, and `myde-org-capture-deadline-line`.
Deleting those from `lib.el` before `cfg.el` stops referencing them leaves the
config unloadable.

Therefore: **Tasks 1–4 are purely additive**, Task 5 switches `cfg.el` over, and
Task 6 deletes the now-unreferenced code. Every commit leaves a loadable config.

## Naming deviation from the spec

The spec named the interactive command `myde-org-project-file` and the capture
resolver `myde-org-project-capture-file`. This plan splits those
responsibilities more cleanly:

| Spec name | Plan name | Why |
|-----------|-----------|-----|
| `myde-org-project-file` (command) | `myde-org-visit-project` | A `-file` suffix should name a path, not an action |
| — | `myde-org-project-file` (pure) | Name → path, no side effects |
| `myde-org-project-capture-file` | `myde-org-project-target` | Used by both the command and capture; not capture-specific |

---

### Task 1: Test harness and tag sanitization

**Files:**
- Create: `tests/core-org.el`
- Modify: `Makefile` (append a new target section)
- Modify: `modules/core-org/lib.el` (add one function)

- [ ] **Step 1: Create the test file with a failing test**

Create `tests/core-org.el`:

```elisp
;;; core-org.el --- Tests for the core-org module -*- lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;;; Commentary:
;;; ERT checks for `core-org' project-name derivation and tag sanitization.
;;; Run with `make test'.

;;; Code:

(require 'ert)
(require 'org)

(defvar myde-test-root
  (expand-file-name
   ".." (file-name-directory (or load-file-name buffer-file-name)))
  "Repository root, derived from this file's location.")

(load (expand-file-name "modules/core-org/lib.el" myde-test-root))

(defun myde-test--tag-valid-p (tag)
  "Return non-nil when TAG matches `org-tag-re' in full."
  (and (string-match (concat "\\`" org-tag-re "\\'") tag) t))

(ert-deftest myde-org-sanitize-tag/produces-valid-org-tags ()
  "Characters outside `org-tag-re' become underscores."
  (should (equal (myde-org-sanitize-tag "scitech-idp") "scitech_idp"))
  (should (equal (myde-org-sanitize-tag "myde.emacs") "myde_emacs"))
  (should (equal (myde-org-sanitize-tag "already_ok9") "already_ok9"))
  (dolist (name '("scitech-idp" "myde.emacs" "hybrid-eks-poc" "a b/c"))
    (should (myde-test--tag-valid-p (myde-org-sanitize-tag name)))))

;;; core-org.el ends here
```

- [ ] **Step 2: Add the `test` target to the Makefile**

Append to `Makefile`, after the existing `uninstall-xdg` target:

```makefile
##@ Test targets

.PHONY: test
test: ## Run ERT tests in batch mode
	emacs -Q --batch -l $(ROOT_DIR)/tests/core-org.el \
	  -f ert-run-tests-batch-and-exit
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `make test`

Expected: FAIL. ERT reports `myde-org-sanitize-tag` is void, because the
function does not exist yet.

- [ ] **Step 4: Add `myde-org-sanitize-tag` to lib.el**

In `modules/core-org/lib.el`, insert after the existing directory `defvar`
block and before `myde-org-mode-disable-flycheck`:

```elisp
(defun myde-org-sanitize-tag (name)
  "Return NAME with every character invalid in an org tag replaced by `_'.
`org-tag-re' is \"[[:alnum:]_@#%]+\", which excludes `-' and `.'.  An
invalid `#+filetags:' value fails silently and breaks tag search, so
project names must be sanitized before use as tags."
  (replace-regexp-in-string "[^[:alnum:]_@#%]" "_" name))
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `make test`

Expected: `Ran 1 test, 1 results as expected, 0 unexpected`

- [ ] **Step 6: Commit**

```bash
git add tests/core-org.el Makefile modules/core-org/lib.el
git commit -m "Add ERT test harness and org tag sanitization

org-tag-re is [[:alnum:]_@#%]+, which excludes hyphens and dots. An invalid
#+filetags: value fails silently and breaks tag search, so project names must
be sanitized before use as tags."
```

---

### Task 2: Org tree variables and directory creation

**Files:**
- Modify: `modules/core-org/lib.el`
- Modify: `tests/core-org.el`

- [ ] **Step 1: Write the failing test**

Append to `tests/core-org.el`, before the trailing `;;; core-org.el ends here`:

```elisp
(ert-deftest myde-org-ensure-tree/creates-dirs-and-inbox ()
  "The org tree and inbox file are created when absent.
A missing agenda *directory* is silently returned by `org-agenda-files'
as though it were a file; a missing agenda *file* triggers a blocking
`[R]emove or [A]bort?' prompt at startup.  Both must exist."
  (let* ((tmp (make-temp-file "myde-org-test" :dir))
         (myde-org-directory (file-name-as-directory tmp))
         (myde-org-inbox-file (expand-file-name "inbox.org" myde-org-directory))
         (myde-org-projects-directory
          (file-name-as-directory (expand-file-name "projects" myde-org-directory)))
         (myde-org-archive-directory
          (file-name-as-directory (expand-file-name "archive" myde-org-directory))))
    (unwind-protect
        (progn
          (myde-org-ensure-tree)
          (should (file-directory-p myde-org-projects-directory))
          (should (file-directory-p myde-org-archive-directory))
          (should (file-exists-p myde-org-inbox-file))
          ;; Idempotent: a second call must not signal or truncate.
          (with-temp-file myde-org-inbox-file (insert "* keep me\n"))
          (myde-org-ensure-tree)
          (should (equal (with-temp-buffer
                           (insert-file-contents myde-org-inbox-file)
                           (buffer-string))
                         "* keep me\n")))
      (delete-directory tmp :recursive))))
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `make test`

Expected: FAIL — `myde-org-ensure-tree` is void.

- [ ] **Step 3: Replace the variable block in lib.el**

In `modules/core-org/lib.el`, replace everything from `(defvar
myde-org-directory` through the closing paren of `myde-find-org-agenda-files`
with this. Note `myde-org-notes-directory` keeps its exact current value —
`core-notes/lib.el` consumes it.

```elisp
;; Org mode directories and files
(defvar myde-org-directory "~/org/"
  "Root directory for all org documents.")

(defvar myde-org-inbox-file
  (expand-file-name "inbox.org" myde-org-directory)
  "Single capture sink for tasks, thoughts, and bookmarks.
Entries are refiled out of here into project files.")

(defvar myde-org-projects-directory
  (file-name-as-directory (expand-file-name "projects" myde-org-directory))
  "Directory holding one org file per code project.
Included directly in `org-agenda-files'; org expands directory entries
natively and non-recursively, which is why the layout is flat.")

(defvar myde-org-archive-directory
  (file-name-as-directory (expand-file-name "archive" myde-org-directory))
  "Directory holding org archive files.")

(defvar myde-org-notes-directory
  (file-name-as-directory (expand-file-name "notes" myde-org-directory))
  "Directory for denote notes, under `myde-org-directory'.")

(defcustom myde-org-code-directory "~/devel/projects/"
  "Root directory whose immediate subdirectories are code projects.
Each subdirectory maps to `<name>.org' in `myde-org-projects-directory'."
  :type 'directory
  :group 'myde)

(defun myde-org-ensure-tree ()
  "Create the org directory tree and inbox file when absent.
Both are required before `org-agenda' runs.  A missing agenda directory
is silently returned by `org-agenda-files' as though it were a file,
producing a broken agenda; a missing agenda file triggers a blocking
\"Non-existent agenda file … [R]emove from list or [A]bort?\" prompt.
Existing files are left untouched."
  (dolist (dir (list myde-org-directory
                     myde-org-projects-directory
                     myde-org-archive-directory))
    (make-directory dir :parents))
  (unless (file-exists-p myde-org-inbox-file)
    (with-temp-file myde-org-inbox-file
      (insert "#+title: Inbox\n"))))
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `make test`

Expected: `Ran 2 tests, 2 results as expected, 0 unexpected`

- [ ] **Step 5: Commit**

```bash
git add modules/core-org/lib.el tests/core-org.el
git commit -m "Add org tree variables and directory creation

Replaces myde-org-tasks-file, myde-org-bookmarks-file,
myde-projects-directory, myde-reading-notes, myde-highlight-file, and
myde-find-org-agenda-files with an inbox file plus projects and archive
directories.

myde-org-ensure-tree is load-bearing: org-agenda-files silently returns a
missing directory as though it were a file, and a missing agenda file triggers
a blocking [R]emove/[A]bort prompt at startup."
```

---

### Task 3: Project name derivation

**Files:**
- Modify: `modules/core-org/lib.el`
- Modify: `tests/core-org.el`

- [ ] **Step 1: Write the failing test**

Append to `tests/core-org.el`, before the trailing comment:

```elisp
(ert-deftest myde-org-project-name/derives-from-path ()
  "The project name is the first path component below the code directory.
Chosen over `(project-name (project-current))', which returns nil for the
non-VC project directories and reports an inner repository for
`multi-tenancy/repos/'."
  (let ((myde-org-code-directory "~/devel/projects/"))
    (dolist (case '(("~/devel/projects/scitech-idp/"                 . "scitech-idp")
                    ("~/devel/projects/hybrid-eks-poc/"              . "hybrid-eks-poc")
                    ("~/devel/projects/scitech-idp2/"                . "scitech-idp2")
                    ("~/devel/projects/scitech-idp/docs/deep/x/"     . "scitech-idp")
                    ("~/devel/projects/multi-tenancy/repos/"         . "multi-tenancy")
                    ("~/devel/projects/"                             . nil)
                    ("~/devel/repos/github.com/mojochao/myde.emacs/" . nil)
                    ("~/"                                            . nil)))
      (let ((default-directory (expand-file-name (car case))))
        (should (equal (myde-org-project-name) (cdr case)))))))
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `make test`

Expected: FAIL — `myde-org-project-name` is void.

- [ ] **Step 3: Add the function to lib.el**

Insert after `myde-org-ensure-tree`:

```elisp
(defun myde-org-project-name ()
  "Return the name of the project containing `default-directory', or nil.
The project name is the first path component below
`myde-org-code-directory'.  Returns nil when `default-directory' is that
root itself or lies outside it.

Path derivation is used rather than `project-current' because two
project directories are not under version control (so `project-current'
returns nil for them), and because a project containing nested
repositories would otherwise resolve to the inner repository."
  (let ((root (file-name-as-directory (expand-file-name myde-org-code-directory)))
        (here (file-name-as-directory (expand-file-name default-directory))))
    (when (string-prefix-p root here)
      (car (split-string (substring here (length root)) "/" t)))))
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `make test`

Expected: `Ran 3 tests, 3 results as expected, 0 unexpected`

- [ ] **Step 5: Commit**

```bash
git add modules/core-org/lib.el tests/core-org.el
git commit -m "Add project name derivation from directory path

Uses a path-prefix derivation rather than (project-name (project-current)):
project-current returns nil for the two project directories with no VC, and
descends to an inner repository in multi-tenancy/repos/."
```

---

### Task 4: Project file resolution and visiting

**Files:**
- Modify: `modules/core-org/lib.el`
- Modify: `tests/core-org.el`

- [ ] **Step 1: Write the failing tests**

Append to `tests/core-org.el`, before the trailing comment:

```elisp
(ert-deftest myde-org-project-file/maps-name-to-path ()
  "A project name maps to <name>.org in the projects directory.
Filenames are not sanitized: the `org-tag-re' restriction applies to
tags only, which keeps the name to path mapping lossless."
  (let ((myde-org-projects-directory "/tmp/myde-org-test/projects/"))
    (should (equal (myde-org-project-file "scitech-idp")
                   "/tmp/myde-org-test/projects/scitech-idp.org"))
    (should (equal (myde-org-project-file "myde.emacs")
                   "/tmp/myde-org-test/projects/myde.emacs.org"))))

(ert-deftest myde-org-project-template/filetags-is-a-valid-tag ()
  "The generated `#+filetags:' value always matches `org-tag-re'."
  (let ((myde-org-code-directory "~/devel/projects/"))
    (dolist (name '("scitech-idp" "myde.emacs" "plain"))
      (let ((text (myde-org-project-template name)))
        (should (string-match "^#\\+filetags: :\\(.*\\):$" text))
        (should (myde-test--tag-valid-p (match-string 1 text)))
        ;; #+title keeps the unsanitized name.
        (should (string-match-p (concat "^#\\+title: " (regexp-quote name) "$")
                                text))))))

(ert-deftest myde-org-project-target/creates-file-from-template ()
  "The target file is created from the template on first use, then reused."
  (let* ((tmp (make-temp-file "myde-org-test" :dir))
         (myde-org-directory (file-name-as-directory tmp))
         (myde-org-inbox-file (expand-file-name "inbox.org" myde-org-directory))
         (myde-org-projects-directory
          (file-name-as-directory (expand-file-name "projects" myde-org-directory)))
         (myde-org-archive-directory
          (file-name-as-directory (expand-file-name "archive" myde-org-directory)))
         (myde-org-code-directory "~/devel/projects/")
         (default-directory (expand-file-name "~/devel/projects/scitech-idp/")))
    (unwind-protect
        (let ((file (myde-org-project-target)))
          (should (equal (file-name-nondirectory file) "scitech-idp.org"))
          (should (file-exists-p file))
          (with-temp-buffer
            (insert-file-contents file)
            (should (string-match-p "^#\\+filetags: :scitech_idp:$" (buffer-string)))
            (should (string-match-p "^\\* Tasks$" (buffer-string))))
          ;; Second call must not overwrite user content.
          (with-temp-file file (insert "* Tasks\n** TODO keep me\n"))
          (should (equal (myde-org-project-target) file))
          (with-temp-buffer
            (insert-file-contents file)
            (should (string-match-p "keep me" (buffer-string)))))
      (delete-directory tmp :recursive))))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `make test`

Expected: FAIL — `myde-org-project-file` is void.

- [ ] **Step 3: Add the functions to lib.el**

Insert after `myde-org-project-name`:

```elisp
(defun myde-org-project-file (name)
  "Return the org file path for project NAME.
NAME is used verbatim: `org-tag-re' restricts tags, not filenames, so
the mapping between a project directory and its org file is lossless in
both directions."
  (expand-file-name (concat name ".org") myde-org-projects-directory))

(defun myde-org-project-template (name)
  "Return the initial contents of the org file for project NAME.
`#+category:' shows the project in the agenda's left column and
`#+filetags:' tags every entry in the file, both without any code.  The
`Code:' link is a convenience; `org-return-follows-link' is enabled, so
RET opens the project directory in dired."
  (let ((tag (myde-org-sanitize-tag name))
        (dir (abbreviate-file-name
              (file-name-as-directory
               (expand-file-name name myde-org-code-directory)))))
    (format (concat "#+title: %s\n"
                    "#+category: %s\n"
                    "#+filetags: :%s:\n"
                    "\n"
                    "Code: [[file:%s][%s]]\n"
                    "\n"
                    "* Tasks\n"
                    "\n"
                    "* Notes\n")
            name tag tag dir dir)))

(defun myde-org-read-project-name ()
  "Prompt for a project name, completing over existing project org files.
Used when `default-directory' lies outside `myde-org-code-directory'."
  (let ((names (when (file-directory-p myde-org-projects-directory)
                 (mapcar #'file-name-base
                         (directory-files
                          myde-org-projects-directory nil "\\.org\\'")))))
    (completing-read "Project: " names nil nil
                     (file-name-nondirectory
                      (directory-file-name default-directory)))))

(defun myde-org-project-target ()
  "Return the current project's org file path, creating the file if absent.
Falls back to `myde-org-read-project-name' when `default-directory' is
not inside `myde-org-code-directory'.  Used both by
`myde-org-visit-project' and as the `org-capture' target for template
\"T\"; org calls a target file given as a function symbol."
  (let* ((name (or (myde-org-project-name) (myde-org-read-project-name)))
         (file (myde-org-project-file name)))
    (unless (file-exists-p file)
      (myde-org-ensure-tree)
      (with-temp-file file (insert (myde-org-project-template name))))
    file))

(defun myde-org-visit-project ()
  "Visit the current project's org file, creating it from a template if absent."
  (interactive)
  (find-file (myde-org-project-target)))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `make test`

Expected: `Ran 6 tests, 6 results as expected, 0 unexpected`

- [ ] **Step 5: Commit**

```bash
git add modules/core-org/lib.el tests/core-org.el
git commit -m "Add project org file resolution, template, and visit command

myde-org-project-target doubles as the org-capture target for template T;
org calls a target file supplied as a function symbol."
```

---

### Task 5: Rewire cfg.el

**Files:**
- Modify: `modules/core-org/cfg.el`

This task has no unit test — it is declarative variable configuration. Task 8
verifies it against a live Emacs.

- [ ] **Step 1: Update the commentary header**

In `modules/core-org/cfg.el`, replace the entire `;;; Commentary:` block
(from `;;; Org mode configuration for task management` down to the line before
`;;; Code:`) with:

```elisp
;;; Commentary:
;;; Org mode configuration for task management, notes, and agenda.
;;; Entry point for the core-org module; loads lib.el automatically.
;;;
;;; Storage: ~/org/inbox.org is the single capture sink; ~/org/projects/
;;; holds one file per code project under `myde-org-code-directory'.
;;; `org-agenda-files' contains the inbox file and the projects directory
;;; itself — org expands directory entries natively and non-recursively,
;;; so a new project file joins the agenda with no restart and no
;;; discovery code.  `myde-org-ensure-tree' runs at load because a
;;; missing agenda directory is silently treated as a file and a missing
;;; agenda file triggers a blocking [R]emove/[A]bort prompt.
;;;
;;; Capture (C-c o c): t task, T task in current project, h tagged
;;; thought, b bookmark via org-protocol.  Templates n/N (denote-backed)
;;; are appended by core-notes.  C-c o p visits the current project's
;;; org file; C-c o a d is the daily agenda view.
;;;
;;; flycheck is disabled in org buffers — its bundled org-lint checker
;;; signals `Wrong type argument: number-or-marker-p' on newer org
;;; versions.  Use `M-x org-lint' on demand for the same checks.
```

- [ ] **Step 2: Extend the main org `use-package` block**

Replace the first `(use-package org ...)` form with:

```elisp
;; I use org to manage my thoughts and actions.
(use-package org  ;; https://orgmode.org
  :hook
  (org-mode . visual-line-mode)
  (org-mode . myde-delete-trailing-whitespace-setup)
  (org-mode . myde-org-mode-disable-flycheck)
  :bind (("C-c o p" . myde-org-visit-project))
  :custom
  (org-directory myde-org-directory)
  (org-return-follows-link t)
  (org-todo-keywords
   '((sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)"
               "|" "DONE(d!)" "CANCELLED(c@)")))
  (org-archive-location
   (concat myde-org-archive-directory "%s_archive::"))
  (org-id-locations-file
   (expand-file-name "emacs/org-id-locations" (xdg-state-home)))
  (org-id-link-to-org-use-id 'create-if-interactive)
  :config
  (myde-org-ensure-tree)
  :ensure nil)
```

`xdg-state-home` is available because `core-base/cfg.el` calls `(require 'xdg)`
and loads before `core-org`.

- [ ] **Step 3: Replace the capture templates**

Replace the entire `(use-package org-capture ...)` form with:

```elisp
(use-package org-capture
  :after org
  :bind (("C-c o c" . org-capture))
  :custom
  (org-capture-templates
   `(("t" "Task" entry
      (file+headline ,myde-org-inbox-file "Inbox")
      ,(string-join
        '("* TODO %?"
          "  :PROPERTIES:"
          "  :CREATED: %U"
          "  :END:"
          "  %a")
        "\n")
      :empty-lines 1)

     ("T" "Task in current project" entry
      (file+headline myde-org-project-target "Tasks")
      ,(string-join
        '("* TODO %?"
          "  :PROPERTIES:"
          "  :CREATED: %U"
          "  :END:"
          "  %a")
        "\n")
      :empty-lines 1)

     ("h" "Thought" entry
      (file+headline ,myde-org-inbox-file "Inbox")
      ,(string-join
        '("* %^{Thought} %^G"
          "  :PROPERTIES:"
          "  :CREATED: %U"
          "  :END:"
          "  %?")
        "\n")
      :empty-lines 1)

     ("b" "Bookmark, tagged (org-protocol)" entry
      (file+headline ,myde-org-inbox-file "Inbox")
      ,(string-join
        '("* [[%:link][%:description]]   :bookmark:%^G"
          "  :PROPERTIES:"
          "  :CREATED: %U"
          "  :END:"
          "  %i")
        "\n")
      :empty-lines 1)))
  :ensure nil)
```

Three details that are easy to get wrong:

1. Template `T` uses `myde-org-project-target` **unquoted and un-commaed** — it
   must reach org as a bare symbol so org calls it as a function. The other
   templates comma-splice a string path.
2. `%^G` completes tags across all agenda files. `%^g` would complete only
   within `inbox.org` and is wrong here.
3. In template `b`, `%^G` follows `:bookmark:` with **no space**. Org's `%^G`
   handler omits its leading colon when the preceding character is already a
   colon, so this produces one well-formed tag group. Verified: the template
   expands to `* [[…][…]]   :bookmark:emacs:orgmode:`, right-aligned by org.
   Inserting a space would produce a malformed `:bookmark: :emacs:orgmode:`.

The `Schedule this task?` / `Set a deadline?` / `Project` prompts are gone.
Scheduling is a triage decision made in the agenda with `C-c C-s`, where the
surrounding week is visible; the destination file now identifies the project.

- [ ] **Step 4: Replace the agenda configuration**

Replace the entire `(use-package org-agenda ...)` form with:

```elisp
(use-package org-agenda
  :after org
  :bind (("C-c o a" . org-agenda))
  :custom
  ;; The projects directory is listed as a directory on purpose: org expands
  ;; directory entries in `org-agenda-files' natively, so a new project file
  ;; appears in the agenda with no restart and no discovery function.
  (org-agenda-files (list myde-org-inbox-file myde-org-projects-directory))
  (org-agenda-custom-commands
   `(("d" "Day"
      ((agenda "" ((org-agenda-span 1)
                   (org-deadline-warning-days 14)))
       (todo "NEXT" ((org-agenda-overriding-header "Next actions")))
       (todo "TODO|NEXT"
             ((org-agenda-files (list ,myde-org-inbox-file))
              (org-agenda-overriding-header "Inbox — needs refiling")))))))
  (org-refile-targets '((org-agenda-files :maxlevel . 3)))
  (org-refile-use-outline-path 'file)
  (org-outline-path-complete-in-steps nil)
  :ensure nil)
```

- [ ] **Step 5: Byte-compile-check lib.el for unbound references**

`lib.el` carries `no-byte-compile: t` in its header line, and
`byte-compile-file` honors that — it returns `no-byte-compile`, writes nothing,
and reports no warnings. Compiling the file directly is therefore a no-op that
looks like success. Strip the cookie into a scratch copy instead:

```bash
sed '1s/no-byte-compile: t; //' modules/core-org/lib.el > /tmp/myde-chk.el
emacs -Q --batch -f batch-byte-compile /tmp/myde-chk.el 2>&1 | grep -v '^$'
rm -f /tmp/myde-chk.el /tmp/myde-chk.elc
```

Expected: exactly one warning, and no others:

```
Warning: the function ‘flycheck-mode’ is not known to be defined.
```

That one is benign — `myde-org-mode-disable-flycheck` guards the call with
`bound-and-true-p`, and flycheck is not loaded in batch.

Any `reference to free variable ‘myde-…’` or `the function ‘myde-…’ is not
known to be defined` is a real typo. This check catches misspelled symbols that
a plain load would not, because they are only referenced at runtime. Verified:
misspelling `myde-org-directory` in the source produces
`reference to free variable ‘myde-org-diretcory’`.

A warning naming `org-read-date` means a Task 6 deletion was missed — that
function is only referenced by the capture helpers being removed.

- [ ] **Step 6: Run the test suite to confirm nothing regressed**

Run: `make test`

Expected: `Ran 6 tests, 6 results as expected, 0 unexpected`

- [ ] **Step 7: Commit**

```bash
git add modules/core-org/cfg.el
git commit -m "Rewire core-org for per-project files and inbox capture

org-agenda-files lists the projects directory itself, which org expands
natively, so new project files join the agenda without a restart or a
discovery function. Adds NEXT/WAIT/CANCELLED keywords, a daily agenda view,
capture templates for project tasks and tagged thoughts, C-c o p to visit the
current project's org file, XDG-located org-id storage, and archive under
~/org/archive/.

Drops the schedule/deadline/project capture prompts: scheduling is a triage
decision better made in the agenda with C-c C-s, and the destination file now
identifies the project."
```

---

### Task 6: Delete superseded code

**Files:**
- Modify: `modules/core-org/lib.el`

Everything removed here is now unreferenced — Task 5 removed the last `cfg.el`
callers.

- [ ] **Step 1: Confirm each symbol is unreferenced**

Run:

```bash
for s in myde-reading-notes myde-highlight-file myde-find-org-agenda-files \
         myde-projects-directory myde-org-known-projects \
         myde-org-project-history myde-org-capture-project-line \
         myde-org-capture-scheduled-line myde-org-capture-deadline-line \
         myde-org-tasks-file myde-org-bookmarks-file; do
  n=$(grep -rn "$s" --include='*.el' . | grep -v '^\./elpa' | wc -l | tr -d ' ')
  printf "%-34s %s\n" "$s" "$n"
done
```

Expected: every count is the number of lines inside the definitions being
deleted, and **zero** matches outside `modules/core-org/lib.el`. If any other
file matches, stop and resolve that reference before deleting.

- [ ] **Step 2: Delete the superseded definitions**

From `modules/core-org/lib.el`, delete these forms in full:

- `(defvar myde-reading-notes ...)`
- `(defvar myde-highlight-file ...)`
- `(defvar myde-org-tasks-file ...)`
- `(defvar myde-org-bookmarks-file ...)`
- `(defcustom myde-projects-directory ...)`
- `(defun myde-find-org-agenda-files ...)`
- `(defvar myde-org-project-history ...)`
- `(defun myde-org-known-projects ...)`
- `(defun myde-org-capture-scheduled-line ...)`
- `(defun myde-org-capture-deadline-line ...)`
- `(defun myde-org-capture-project-line ...)`

Keep `myde-org-mode-disable-flycheck` — `cfg.el` still hooks it.

- [ ] **Step 3: Verify the deletions**

Run the Step 1 loop again.

Expected: every count is `0`.

- [ ] **Step 4: Run the test suite**

Run: `make test`

Expected: `Ran 6 tests, 6 results as expected, 0 unexpected`

- [ ] **Step 5: Commit**

```bash
git add modules/core-org/lib.el
git commit -m "Remove superseded core-org definitions

myde-reading-notes, myde-highlight-file, and myde-find-org-agenda-files had no
consumers at all. The rest are replaced by per-project files: the destination
file now identifies the project, so the :PROJECT: property prompt and the
central tasks/bookmarks files are unnecessary, and native directory expansion
in org-agenda-files replaces recursive discovery."
```

---

### Task 7: macOS org-protocol handler and setup doc

**Files:**
- Modify: `Makefile`
- Modify: `docs/org-protocol-setup.md`

Browser capture needs the OS to route `org-protocol://` to `emacsclient`. Linux
is already covered by `etc/org-protocol.desktop` and `make install-xdg`; macOS
ignores freedesktop `.desktop` files entirely, so this is the missing half.

macOS delivers URI activations as Apple Events, not `argv` — a plain shell
script inside a bundle never receives the URL. Hence AppleScript's
`on open location` handler.

- [ ] **Step 1: Add the macOS targets to the Makefile**

Append to `Makefile`, after the `uninstall-xdg` target and before the
`##@ Test targets` section added in Task 1:

```makefile
##@ macOS integration targets

# User applications directory; LaunchServices registers bundles placed here.
MACOS_APPS_DIR ?= $(HOME)/Applications

# Generated org-protocol:// URI handler bundle.
ORG_PROTOCOL_APP ?= $(MACOS_APPS_DIR)/OrgProtocol.app

.PHONY: install-macos
install-macos: ## Register org-protocol:// URI handler (macOS)
	@command -v emacsclient >/dev/null || { echo 'emacsclient not found in PATH'; exit 1; }
	@echo 'building $(ORG_PROTOCOL_APP)'
	rm -rf $(ORG_PROTOCOL_APP)
	mkdir -p $(MACOS_APPS_DIR)
	osacompile -o $(ORG_PROTOCOL_APP) \
	  -e 'on open location this_URL' \
	  -e 'do shell script "$(shell command -v emacsclient) " & quoted form of this_URL' \
	  -e 'end open location'
	plutil -insert CFBundleURLTypes -json \
	  '[{"CFBundleURLName":"org-protocol","CFBundleURLSchemes":["org-protocol"]}]' \
	  $(ORG_PROTOCOL_APP)/Contents/Info.plist
	codesign --force --sign - $(ORG_PROTOCOL_APP)
	@echo 'registering scheme with LaunchServices'
	open -a $(ORG_PROTOCOL_APP)

.PHONY: uninstall-macos
uninstall-macos: ## Remove org-protocol:// URI handler (macOS)
	@echo 'removing $(ORG_PROTOCOL_APP)'
	rm -rf $(ORG_PROTOCOL_APP)
```

The `codesign` line is not optional. `osacompile` ad-hoc signs the bundle, and
`plutil -insert` then invalidates that signature — without re-signing,
`codesign -v` reports `invalid Info.plist (plist or signature have been
modified)`.

`$(shell command -v emacsclient)` is expanded by make at parse time, which
resolves the Homebrew path difference between Intel (`/usr/local/bin`) and Apple
Silicon (`/opt/homebrew/bin`) without hardcoding either.

- [ ] **Step 2: Build the handler**

Run: `make install-macos`

Expected: the bundle is built and a Finder/dock launch occurs briefly. No
`osacompile` or `plutil` errors.

- [ ] **Step 3: Verify the bundle is valid and declares the scheme**

Run:

```bash
codesign -v ~/Applications/OrgProtocol.app && echo "signature valid"
plutil -p ~/Applications/OrgProtocol.app/Contents/Info.plist | grep -A4 CFBundleURLTypes
osadecompile ~/Applications/OrgProtocol.app/Contents/Resources/Scripts/main.scpt
```

Expected:

```
signature valid
  "CFBundleURLTypes" => [
    0 => {
      "CFBundleURLName" => "org-protocol"
      "CFBundleURLSchemes" => [
        0 => "org-protocol"
on open location this_URL
	do shell script "/opt/homebrew/bin/emacsclient " & quoted form of this_URL
end open location
```

Any `invalid Info.plist` from `codesign -v` means Step 1's `codesign` line was
omitted or failed.

- [ ] **Step 4: Verify the scheme routes end to end**

With an Emacs server running, run:

```bash
open 'org-protocol://capture?template=b&url=https%3A%2F%2Fexample.com&title=Example%20Domain&body=selected%20text'
```

Expected: Emacs raises and opens a capture buffer for template `b`, prompting
for tags. Enter `test` and press `C-c C-c`. Confirm `~/org/inbox.org` gained an
entry of the form:

```org
* [[https://example.com][Example Domain]]        :bookmark:test:
  :PROPERTIES:
  :CREATED: [2026-08-05 Wed 10:45]
  :END:
  selected text
```

If nothing happens, the scheme is not registered — re-run
`open -a ~/Applications/OrgProtocol.app` once and retry.

- [ ] **Step 5: Correct the setup doc**

In `docs/org-protocol-setup.md`:

1. Replace both occurrences of `template=u` with `template=b` (line 28's
   `xdg-open` example and line 74's bookmarklet). **This is a live bug** — no
   `u` template exists, so the documented bookmarklet fails with
   `No capture template referred to by "u" keys`.
2. Replace every reference to `$myde-org-dir/bookmarks.org` with `~/org/inbox.org`.
3. Replace the entire manual macOS section (the Automator app and hand-edited
   `Info.plist` instructions) with:

   ````markdown
   ### macOS

   Run:

   ```sh
   make install-macos
   ```

   This builds a minimal `~/Applications/OrgProtocol.app` whose only job is to
   forward `org-protocol://` URIs to `emacsclient`, then registers it with
   LaunchServices. It uses `osacompile`, `plutil`, and `codesign`, all of which
   ship with macOS — no Automator app and no Xcode.

   AppleScript is used rather than a shell script because macOS delivers URI
   activations as Apple Events rather than as command-line arguments; a plain
   shell script in a bundle never receives the URL.

   Verify registration:

   ```sh
   open "org-protocol://capture?template=b&url=https%3A%2F%2Fexample.com&title=Example"
   ```

   Remove it with `make uninstall-macos`.
   ````

4. Update the "Verify end-to-end" section's final example to show the `b`
   template's tagged output landing in `~/org/inbox.org`:

   ```org
   * [[https://example.com][Example Domain]]     :bookmark:reading:
   :PROPERTIES:
   :CREATED: [2026-08-05 Wed 14:30]
   :END:
   ```

5. Add a short note after the bookmarklet section:

   ```markdown
   For pages worth more than a bookmark, use template `N` instead of `b` in the
   bookmarklet URL. That routes the capture into a denote note under
   `~/org/notes/`, prompting for denote keywords and seeding the title from the
   page title.
   ```

- [ ] **Step 6: Commit**

```bash
git add Makefile docs/org-protocol-setup.md
git commit -m "Add macOS org-protocol handler and fix setup doc

make install-xdg only covers Linux; macOS ignores freedesktop .desktop files
and requires an app bundle declaring CFBundleURLTypes. make install-macos
builds the smallest such bundle with osacompile, plutil, and codesign, all of
which ship with macOS. AppleScript is required because macOS delivers URI
activations as Apple Events rather than argv, so a shell script in a bundle
never sees the URL. The codesign step is mandatory: plutil -insert invalidates
the ad-hoc signature osacompile applies.

Also fixes a live bug in the setup doc, which documented template=u when only b
exists, so the documented bookmarklet failed outright."
```

---

### Task 8: Verify against a live Emacs

**Files:** none modified.

- [ ] **Step 1: Confirm the config loads clean from scratch**

Run:

```bash
emacs -Q --batch --eval '(progn
  (setq user-emacs-directory (file-name-as-directory default-directory))
  (load (expand-file-name "init.el" default-directory))
  (princ "init loaded clean\n"))' 2>&1 | tail -30
```

Expected: `init loaded clean`. Any `Symbol'"'"'s value as variable is void` or
`void-function` naming a `myde-org-` symbol is a failure — fix before
continuing.

- [ ] **Step 2: Confirm the org tree was created**

Run: `find ~/org -maxdepth 2 | sort`

Expected output includes:

```
/Users/edwin-gooch/org
/Users/edwin-gooch/org/archive
/Users/edwin-gooch/org/inbox.org
/Users/edwin-gooch/org/projects
```

- [ ] **Step 3: Confirm agenda file expansion in the running Emacs**

Restart the Emacs server, then run:

```bash
emacsclient --eval '(progn (require (quote org-agenda)) (org-agenda-files))'
```

Expected: a list containing `~/org/inbox.org`. It will not yet contain project
files, because none exist.

- [ ] **Step 4: Create a project file and confirm it joins the agenda**

In Emacs, open any file under `~/devel/projects/scitech-idp/` and press
`C-c o p`.

Expected: `~/org/projects/scitech-idp.org` opens containing
`#+filetags: :scitech_idp:`, a `Code:` link, and `* Tasks` / `* Notes`
headings. Press `RET` on the `Code:` link and confirm it opens
`~/devel/projects/scitech-idp/` in dired.

Then run:

```bash
emacsclient --eval '(mapcar (function file-name-nondirectory) (org-agenda-files))'
```

Expected: the list now includes `scitech-idp.org`, with **no Emacs restart**.

- [ ] **Step 5: Confirm the capture templates**

In a buffer under `~/devel/projects/scitech-idp/`, press `C-c o c` then `T`.

Expected: a capture buffer targeting `~/org/projects/scitech-idp.org` under
`Tasks`. Type a task and press `C-c C-c`. Confirm the TODO lands under the
`* Tasks` heading.

Press `C-c o c` then `h`. Expected: a `Thought` prompt, then a tag prompt
offering completion over tags already present in the agenda files. Confirm the
entry lands in `~/org/inbox.org` with the tag on the headline.

- [ ] **Step 6: Confirm the daily agenda view**

Press `C-c o a` then `d`.

Expected: three blocks — today's agenda, `Next actions`, and
`Inbox — needs refiling` containing the thought captured in Step 5.

- [ ] **Step 7: Initialize the org repo**

The design specifies `~/org/` as its own private git repo. This is a manual
step, deliberately not automated by the config:

```bash
git -C ~/org init
git -C ~/org add -A
git -C ~/org commit -m "Initialize org tree"
```

- [ ] **Step 8: Update AGENTS.md**

`AGENTS.md` documents the module system and the commands available. Add the
`make test` target to the *Commands* section:

```shell
make link             # Symlink repo into ~/.config/emacs (installs config)
make unlink           # Remove the symlink
make test             # Run ERT tests in batch mode
make install-xdg      # Register org-protocol:// URI handler (Linux)
make install-macos    # Register org-protocol:// URI handler (macOS)
```

Replace the line `No build, lint, or test tooling — this is a pure Emacs Lisp
configuration, evaluated at Emacs startup.` with:

```markdown
No build or lint tooling — this is a pure Emacs Lisp configuration, evaluated
at Emacs startup. `make test` runs the ERT checks under `tests/`, which cover
logic that can fail silently (see `tests/core-org.el`).
```

- [ ] **Step 9: Commit**

```bash
git add AGENTS.md
git commit -m "Document make test target in AGENTS.md"
```

---

## Post-implementation checklist

- [ ] `make test` passes with 6 tests
- [ ] `emacs -Q --batch` init load is clean
- [ ] `C-c o p`, `C-c o c t/T/h/b`, `C-c o a d` all work interactively
- [ ] Denote templates `n` and `N` still appear in `C-c o c` (proves
      `core-notes` still composes with the rewritten `core-org`)
- [ ] `~/org/` is a git repo with an initial commit
- [ ] No `myde-` symbol from the Task 6 deletion list remains anywhere
- [ ] `codesign -v ~/Applications/OrgProtocol.app` reports a valid signature
- [ ] `open 'org-protocol://capture?template=b&…'` opens a tag-prompting capture
- [ ] The browser bookmarklet produces a tagged entry in `~/org/inbox.org`
- [ ] `docs/org-protocol-setup.md` contains no remaining `template=u` or
      `bookmarks.org` references
