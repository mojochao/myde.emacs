# Org Workflow Design

Design for a personal project management and personal information management
(PIM) system in `core-org`: task scheduling, note taking, and tagged thought
capture, linked to code projects under `~/devel/projects/`.

Status: **approved, not yet implemented**. Date: 2026-08-05.

## Verified starting state

Facts established by introspecting the live Emacs server (`emacsclient --eval`)
and by batch-evaluating against Emacs 30.2, not assumed:

| Fact                                 | Value                                                                          |
|--------------------------------------|--------------------------------------------------------------------------------|
| Emacs / org version                  | 30.2 / 9.7.11 (built-in)                                                       |
| `org-agenda-files` (live)            | `("~/org/tasks.org")` — the file does not exist                                |
| `~/org/` contents                    | empty — greenfield, zero migration cost                                        |
| `org-tag-re`                         | `[[:alnum:]_@#%]+` — excludes `-` and `.`; applies to tags only, not filenames |
| `~/devel/projects/`                  | 9 directories; 7 git repos, 2 with no VC                                       |
| `org-agenda-files` directory entries | expanded natively, non-recursively                                             |

`core-org/lib.el` currently contains two half-built, mutually exclusive designs:
a central `tasks.org` keyed by a `:PROJECT:` property, *and* recursive
per-project `tasks.org` discovery via `myde-find-org-agenda-files`. Neither is
wired into `org-agenda-files`. This design picks per-project files and deletes
the rest.

## Scope

A personal system with a single consumer. It covers:

- **Project management** — every project lives in a direct subdirectory of
  `~/devel/projects/`. Repos elsewhere, including `~/devel/repos/`, are not
  projects in this system.
- **Task scheduling** — agenda, `SCHEDULED`/`DEADLINE`, a next-actions view.
- **Information management** — durable tagged notes via denote, plus a capture
  path for unfiled thoughts.

## Storage layout

```
~/org/                          # its own private git repo
├── inbox.org                   # single capture sink: tasks, thoughts, bookmarks
├── projects/
│   ├── scitech-idp.org         # one flat file per project
│   └── hybrid-eks-poc.org
├── notes/                      # denote — existing, unchanged
└── archive/                    # <file>.org_archive
```

Every file in `projects/` corresponds one-to-one with a directory under
`myde-org-code-directory`. There is no catch-all file for non-project items;
anything that is not project work is either a tagged thought in `inbox.org` or a
denote note.

Denote with tags is the reference layer of the PIM. It already exists in
`core-notes` and is not modified by this design.

### Variables

Declared in `core-org/lib.el`, replacing the deleted ones listed under
*Net change*:

| Variable                      | Value                                                        |
|-------------------------------|--------------------------------------------------------------|
| `myde-org-directory`          | `~/org/` — unchanged                                         |
| `myde-org-inbox-file`         | `inbox.org` under `myde-org-directory`                       |
| `myde-org-projects-directory` | `projects/` under `myde-org-directory`                       |
| `myde-org-archive-directory`  | `archive/` under `myde-org-directory`                        |
| `myde-org-notes-directory`    | `notes/` — unchanged, consumed by `core-notes`               |
| `myde-org-code-directory`     | `~/devel/projects/` — `defcustom`, root of all code projects |

### Why org files live outside the code repos

Org files are **not** stored inside project directories, and are not gitignored
there either.

- Gitignored files are not backed up with the repo, which removes the only
  advantage colocation offers. Deleting and re-cloning a repo would destroy the
  task history.
- It requires a `.gitignore` entry in every repo, forever. Two of the nine
  project directories are not git repos at all.
- Agenda discovery stops being free: a flat `~/org/projects/` directory is
  expanded natively by org, whereas colocated files require a recursive scan.

`~/org/` as a single tree is one backup unit, one grep scope, one agenda scope.
As the sole consumer, a private git repo at `~/org/` covers versioning and sync.

## Project identity

Because every project is a direct subdirectory of `myde-org-code-directory`,
identity is a path-prefix derivation rather than a VC lookup:

```elisp
(defun myde-org-project-name ()
  "Return the project directory name containing `default-directory', or nil."
  (let ((root (file-name-as-directory (expand-file-name myde-org-code-directory)))
        (here (file-name-as-directory (expand-file-name default-directory))))
    (when (string-prefix-p root here)
      (car (split-string (substring here (length root)) "/" t)))))
```

Verified against all relevant cases:

| Directory                                       | Result           |
|-------------------------------------------------|------------------|
| `~/devel/projects/scitech-idp/` (git)           | `scitech-idp`    |
| `~/devel/projects/hybrid-eks-poc/` (no VC)      | `hybrid-eks-poc` |
| `~/devel/projects/scitech-idp2/` (no VC)        | `scitech-idp2`   |
| `~/devel/projects/scitech-idp/docs/deep/x/`     | `scitech-idp`    |
| `~/devel/projects/multi-tenancy/repos/`         | `multi-tenancy`  |
| `~/devel/projects/` (root itself)               | nil              |
| `~/devel/repos/github.com/mojochao/myde.emacs/` | nil              |
| `~/`                                            | nil              |

This was chosen over `(project-name (project-current))` for two verified
reasons:

1. `project-current` returns nil in the two project directories that are not
   under version control, which would force a disambiguation prompt in normal
   use.
2. In `multi-tenancy/repos/`, `project-current` descends to an inner repository
   and reports the wrong project. Path-prefix derivation correctly reports the
   containing project.

It is also fewer lines, because no fallback prompt is needed for the in-project
case. A `completing-read` fallback over existing project org files remains for
the case where point is outside `myde-org-code-directory` entirely.

### Filenames and tags

The org filename preserves the directory name exactly — `scitech-idp` becomes
`~/org/projects/scitech-idp.org`. The `org-tag-re` restriction applies to tags,
not filenames, so no sanitization is needed here, and both directions of the
mapping are lossless convention:

- forward: `<dirname>` → `~/org/projects/<dirname>.org`
- reverse: `<basename>.org` → `~/devel/projects/<basename>/`

Sanitization applies only to `#+category:` and `#+filetags:`:

```elisp
(replace-regexp-in-string "[^[:alnum:]_@#%]" "_" name)
```

So `scitech-idp` yields the tag `scitech_idp`. This is a correctness
requirement, not cosmetic: `org-tag-re` is `[[:alnum:]_@#%]+`, and an invalid
`#+filetags:` value fails silently, making tag search return nothing.

## Project file template

Generated on first visit:

```org
#+title: scitech-idp
#+category: scitech_idp
#+filetags: :scitech_idp:

Code: [[file:~/devel/projects/scitech-idp/][~/devel/projects/scitech-idp/]]

* Tasks

* Notes
```

- `#+category:` puts the project name in the agenda's left column with no code.
- `#+filetags:` auto-tags every entry in the file, so `C-c o a m scitech_idp`
  returns everything for that project.
- The `Code:` link is convenience only, since the reverse mapping is already
  conventional. `org-return-follows-link` is enabled in `core-org/cfg.el`, so
  `RET` opens dired there. This replaces a dedicated jump command with zero
  lines of code.

## Agenda scope

```elisp
(org-agenda-files (list myde-org-inbox-file myde-org-projects-directory))
```

The Emacs 30.2 `org-agenda-files` docstring states: *"If an entry is a
directory, all files in that directory that are matched by
`org-agenda-file-regexp` will be part of the file list."*

A new project file therefore appears in the agenda immediately — no restart, no
cache invalidation, no custom discovery function. This deletes
`myde-find-org-agenda-files`.

Expansion is non-recursive, which is why the layout is one flat file per project
rather than one directory per project.

## TODO keywords

```elisp
(org-todo-keywords
 '((sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)" "|" "DONE(d!)" "CANCELLED(c@)")))
```

`NEXT` distinguishes an actionable agenda from a wishlist. `WAIT(w@/!)` records
a note on entry and a timestamp on exit — the two facts worth re-reading weeks
later when a blocked item resurfaces.

## Agenda views

One custom view, under the existing `C-c o a` prefix as `C-c o a d`:

```elisp
(org-agenda-custom-commands
 `(("d" "Day"
    ((agenda "" ((org-agenda-span 1)
                 (org-deadline-warning-days 14)))
     (todo "NEXT" ((org-agenda-overriding-header "Next actions")))
     (todo "TODO|NEXT" ((org-agenda-files (list ,myde-org-inbox-file))
                        (org-agenda-overriding-header "Inbox — needs refiling")))))))
```

Today's schedule, what to do next, and what remains unfiled. Built-in tag and
todo search cover every other query.

## Capture templates

| Key      | Template                | Target                                        |
|----------|-------------------------|-----------------------------------------------|
| `t`      | Task                    | `inbox.org`                                   |
| `T`      | Task in current project | `projects/<current>.org` under `Tasks`        |
| `h`      | Thought (tagged)        | `inbox.org`                                   |
| `b`      | Bookmark (org-protocol) | `inbox.org`                                   |
| `n`, `N` | Denote note             | `notes/` — unchanged, remains in `core-notes` |

The thought template implements tagged thought capture:

```
* %^{Thought} %^G
  :PROPERTIES:
  :CREATED: %U
  :END:
  %?
```

`%^G` prompts for tags with completion across **all agenda files**; `%^g`
completes only within the target file and is the wrong choice here. The headline
and tags are prompted first, then point lands in the body for elaboration.

Capture targets accept a function for the file — *"A file can also be given as a
variable or as a function called with no argument"* — so template `T` uses
`(file+headline myde-org-project-capture-file "Tasks")`.

### Removed capture prompts

The `Schedule this task?` and `Set a deadline?` y-or-n prompts are removed.
Capture has to be fast or it stops being used; scheduling is a triage decision
better made in the agenda with `C-c C-s`, where the surrounding week is visible.
The `:PROJECT:` property prompt is removed because the destination file now
identifies the project.

## Code

Roughly 40 lines in `core-org/lib.el`. This is the only hand-written logic in
the design.

| Function                        | Responsibility                                                                                                                                                                           |
|---------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `myde-org-sanitize-tag`         | Replace every character outside `[[:alnum:]_@#%]` with `_`                                                                                                                               |
| `myde-org-project-name`         | Path-prefix derivation shown above; nil when outside `myde-org-code-directory`                                                                                                           |
| `myde-org-project-file`         | Interactive, `C-c o p`. Open the current project's org file, creating it from the template if absent. Falls back to `completing-read` over existing project files when outside a project |
| `myde-org-project-capture-file` | Target resolver for capture template `T`                                                                                                                                                 |

Per the convention in `AGENTS.md`, all named definitions live in `lib.el`;
`cfg.el` holds only `use-package` declarations, hooks, and keybindings.

## Housekeeping

- `org-archive-location` → `~/org/archive/%s_archive::`
- `org-id-locations-file` → XDG state directory, matching the repo's XDG policy
- `org-id-link-to-org-use-id` → `create-if-interactive`, for durable links
  between notes and tasks
- Refile targets unchanged: agenda files, `:maxlevel 3`

## Net change

Deleted from `core-org/lib.el`: `myde-reading-notes`, `myde-highlight-file`,
`myde-find-org-agenda-files`, `myde-projects-directory`,
`myde-org-known-projects`, `myde-org-project-history`,
`myde-org-capture-project-line`, `myde-org-capture-scheduled-line`,
`myde-org-capture-deadline-line`, `myde-org-tasks-file`,
`myde-org-bookmarks-file`.

Roughly 70 lines removed, 40 added. **No new packages.** Two files modified:
`modules/core-org/lib.el` and `modules/core-org/cfg.el`.

`myde-org-notes-directory` is retained unchanged because `core-notes/lib.el`
consumes it.

## Out of scope

Each exclusion below names the condition that would justify adding it:

- **Time clocking and effort estimates** — not requested. Add when hours need to
  be billed or reported.
- **`org-super-agenda`, `org-ql`, `org-roam`** — new dependencies. The single
  `Day` view plus denote covers the stated requirements. Add when that view
  measurably falls short.
- **Datetree journal** — thoughts go to `inbox.org` with tags; denote holds
  durable notes. Add when a dated daily log is wanted.
- **Nested project directories** — `myde-org-project-name` takes the first path
  component only, and `org-agenda-files` expansion is non-recursive. Add when
  projects need grouping under `~/devel/projects/<group>/<project>/`.
- **Non-project items** — no catch-all file. Anything outside project work is a
  tagged thought in `inbox.org` or a denote note. Add a file when that proves
  insufficient.
- **Contacts, calendar sync, mobile access, org-habit** — not requested.

## Verification

The non-trivial logic is name derivation and tag sanitization. Implementation
must leave behind one runnable check covering the eight directory cases in the
table above, plus:

- `myde-org-sanitize-tag` converts `-` and `.` to `_`, and its output matches
  `org-tag-re`
- the generated template's `#+filetags:` value is a valid org tag
- a directory outside `myde-org-code-directory` returns nil rather than
  signalling
