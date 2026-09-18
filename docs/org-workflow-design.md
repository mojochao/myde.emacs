# Org Workflow Design

Design for a personal project management and personal information management
(PIM) system in `core-org`: task scheduling, note taking, and tagged thought
capture, linked to code projects under `~/devel/projects/`.

Status: **implemented**. Revised 2026-08-10 to colocate project tasks in a
`tasks.org` inside each project directory, located by upward marker search,
replacing the original one-file-per-project layout under `~/org/projects/`.

## Verified starting state

Facts established by introspecting the live Emacs server (`emacsclient --eval`)
and by batch-evaluating against Emacs 30.2, not assumed:

| Fact                                 | Value                                                                          |
|--------------------------------------|--------------------------------------------------------------------------------|
| Emacs / org version                  | 30.2 / 9.7.11 (built-in)                                                       |
| `org-agenda-files` (live, pre-change) | `("~/org/tasks.org")` — the file did not exist                                 |
| `~/org/` contents                    | empty — greenfield, zero migration cost                                        |
| `org-tag-re`                         | `[[:alnum:]_@#%]+` — excludes `-` and `.`; applies to tags only, not filenames |
| `~/devel/projects/`                  | 6 git repos plus a `.ATTIC/` archive directory                                  |
| missing agenda file                  | blocks startup on `[R]emove from list or [A]bort?`                             |
| missing agenda directory             | silently returned as though it were a file                                     |
| org category with no `#+category:`   | derived from file name, so every `tasks.org` reports `"tasks"`                  |

Before this work the `core-org` section contained two half-built, mutually exclusive
designs: a central `tasks.org` keyed by a `:PROJECT:` property, *and* recursive
per-project `tasks.org` discovery via `myde-find-org-agenda-files`. Neither was
wired into `org-agenda-files`. The final design is closer to the second of those
than to the intermediate `~/org/projects/` layout that replaced them both.

## Scope

A personal system with a single consumer. It covers:

- **Project management** — a project is any directory containing a `tasks.org`,
  at any depth and under any name. `~/devel/projects/` is searched to build the
  agenda; a project outside it still works for capture, just not in the agenda.
- **Task scheduling** — agenda, `SCHEDULED`/`DEADLINE`, a next-actions view.
- **Information management** — durable tagged notes via denote, plus a capture
  path for unfiled thoughts.
- **Web capture** — tagged bookmarks and notes sent from the browser via
  `org-protocol`.

## Storage layout

Project tasks live **inside the project directory**, in a `tasks.org`. That file
is also the project marker: a project is any directory containing one, at any
depth, under any name.

```
~/org/                          # its own private git repo
├── inbox.org                   # capture sink: thoughts, bookmarks, orphan tasks
├── notes/                      # denote — existing, unchanged
└── archive/                    # <file>.org_archive

~/devel/projects/
├── scitech-idp/
│   ├── tasks.org               # project tasks, colocated with the code
│   └── ...
├── multi-tenancy/
│   └── repos/…                 # no tasks.org yet — not a project until it has one
└── .ATTIC/                     # archived work; excluded from discovery
    └── chainguard-eval/
```

There is no catch-all file for non-project items. Anything that is not project
work is a tagged thought in `inbox.org` or a denote note.

Denote with tags is the reference layer of the PIM. It already exists in
`core-notes` and is not modified by this design.

### Why colocated, and the cost

Colocating puts a project's tasks where its code is: the file travels with the
directory, and `~/org/` stays small. The cost is that `tasks.org` appears in
`git status` for the 6 project directories that are shared git repos, and is one
`git add -A` away from being committed where teammates would see it.

The mitigation is a single global gitignore entry rather than a `.gitignore`
edit in every repo. `core.excludesFile` is already configured to `~/.gitignore`,
so one line in that file covers every current and future repo:

```
tasks.org
```

An earlier revision of this design put project files in `~/org/projects/`
instead, to avoid exactly this. That was reversed deliberately: colocation was
preferred, and the global-gitignore mitigation is one line.

### Variables

Declared in the `core-org` definitions block, replacing the deleted ones listed under
*Net change*:

| Variable                     | Value                                                          |
|------------------------------|----------------------------------------------------------------|
| `myde-org-directory`         | `~/org/` — unchanged                                           |
| `myde-org-inbox-file`        | `inbox.org` under `myde-org-directory`                         |
| `myde-org-archive-directory` | `archive/` under `myde-org-directory`                           |
| `myde-org-notes-directory`   | `notes/` — unchanged, consumed by `core-notes`                 |
| `myde-org-code-directory`    | `~/devel/projects/` — `defcustom`, searched to build the agenda |
| `myde-org-tasks-file-name`   | `tasks.org` — `defconst`, the project marker                    |

`myde-org-code-directory` bounds **agenda discovery only**. Capture and visiting
search upward from `default-directory`, so a project outside that root still
works — it just does not appear in the agenda.

## Project identity

A project is any directory containing a `tasks.org`. Identity is the nearest such
directory at or above `default-directory`, found with built-in
`locate-dominating-file`:

```elisp
(defun myde-org-project-root (&optional dir)
  (locate-dominating-file (or dir default-directory) myde-org-tasks-file-name))
```

That is the whole implementation. `locate-dominating-file` walks upward and stops
at the filesystem root, which satisfies the requirement to search "up to `$HOME`
or even `/`" without a configurable bound: if no `tasks.org` exists anywhere
above, it returns nil and capture falls back to the inbox.

Verified against the real tree:

| Directory                                       | Project        | Capture target                          |
|-------------------------------------------------|----------------|-----------------------------------------|
| `~/devel/projects/scitech-idp/`                 | `scitech-idp`  | `~/devel/projects/scitech-idp/tasks.org` |
| `~/devel/projects/scitech-idp/docs/`            | `scitech-idp`  | `~/devel/projects/scitech-idp/tasks.org` |
| `~/devel/projects/multi-tenancy/`               | nil            | `~/org/inbox.org`                       |
| `~/devel/repos/github.com/mojochao/myde.emacs/` | nil            | `~/org/inbox.org`                       |

This replaces two earlier approaches, both now removed:

- **Path-prefix derivation** from a fixed root. It required project directories
  to be direct children of `myde-org-code-directory` and to be named after their
  org file. Marker-file search imposes neither constraint.
- **`(project-name (project-current))`**. It returns nil for directories not
  under version control, and in a project containing nested repositories it
  descends to the inner repository and reports the wrong project.

Nesting now resolves correctly for free: a task captured in
`multi-tenancy/repos/foo/` files into `multi-tenancy/tasks.org` if that is the
nearest marker, and into `repos/foo/tasks.org` if that directory has its own.

### Tags

The project name is the basename of the directory holding the tasks file.
Sanitization applies to `#+category:` and `#+filetags:`:

```elisp
(replace-regexp-in-string "[^[:alnum:]_@#%]" "_" name)
```

So `scitech-idp` yields the tag `scitech_idp`. This is a correctness requirement,
not cosmetic: `org-tag-re` is `[[:alnum:]_@#%]+`, which excludes `-` and `.`, and
an invalid `#+filetags:` value fails silently, making tag search return nothing.

## Creating a tasks file

Two commands, one for each intent:

| Key       | Command                         | Behaviour                                                                  |
|-----------|---------------------------------|----------------------------------------------------------------------------|
| `C-c o p` | `myde-org-visit-project-tasks`  | Visit the nearest tasks file. With none above point, delegates to the below |
| `C-c o P` | `myde-org-create-project-tasks` | Always prompts for the directory, seeded with the enclosing repo root       |

The prompt is seeded with `myde-org-vc-root` — an upward search for `.git` —
falling back to `default-directory`. The seed is a default, not a constraint: any
directory can be typed, so a project need not be under version control.

`.git` is searched for directly rather than via `vc-root-dir`, so no VC backend
machinery loads for what is one filesystem walk. The search matches both a `.git`
directory and a `.git` *file*, the latter being what git worktrees and submodules
use to hold a gitdir pointer. Verified against both forms.

An existing tasks file is never overwritten; it is visited as-is and the command
says so. Creation refreshes `org-agenda-files` immediately.

## Project tasks template

Written when `C-c o p` creates a new tasks file:

```org
#+title: scitech-idp tasks
#+category: scitech_idp
#+filetags: :scitech_idp:

* Tasks
```

**`#+category:` is load-bearing here, not decoration.** Org derives a missing
category from the file name. Because every project's file is now named
`tasks.org`, omitting the category makes every project show up in the agenda as
`tasks` — indistinguishable from every other one. Verified: a `tasks.org` with no
`#+category:` reports category `"tasks"`; with one, it reports the project name.

This matters more than in the previous design, where the file was named after the
project and the default category was already useful.

`#+filetags:` tags every entry in the file, so `C-c o a m scitech_idp` returns
everything for that project.

## Agenda scope

Project tasks files live inside project directories, so there is no single
directory for org to expand. They are discovered:

```elisp
(defun myde-org-find-task-files ()
  (directory-files-recursively
   (expand-file-name myde-org-code-directory)
   "\\`tasks\\.org\\'" nil
   (lambda (dir)
     (let ((name (file-name-nondirectory dir)))
       (not (or (string-prefix-p "." name) (equal name "node_modules")))))))
```

`org-agenda-files` is then the inbox plus that list.

Pruning does two jobs. Measured on the real tree:

| Strategy                                  | Time     |
|-------------------------------------------|----------|
| recursive, no pruning                     | 15.85 ms |
| recursive, prune dot-dirs + node_modules  | 0.68 ms  |
| glob `*/tasks.org` (depth 1 only)         | 0.33 ms  |

The unpruned scan spends its time inside `.git` internals. At 0.68 ms the pruned
scan is effectively free — worth noting in a config whose whole init is ~1.16 ms
— and unlike the depth-1 glob it handles projects at any depth. Pruning
dot-directories also excludes archived work parked in `.ATTIC/`, which should not
clutter the agenda.

Because the list is computed rather than declared, a `tasks.org` created by hand
would otherwise be silently absent until restart. `myde-org-refresh-agenda-files`
is wired as `:before` advice on `org-agenda` to rescan on every agenda build.
Silent absence is the failure mode being prevented; 0.68 ms is the price.

## Tag surfacing and search

Tags are only useful if you can see which ones exist and search combinations of
them. Two commands, built on `tabulated-list-mode` and
`completing-read-multiple` — both built in, no new package.

| Key | Command | Behaviour |
|-----|---------|-----------|
| `C-c o t` | `myde-org-tag-cloud` | Every tag in use, ordered by frequency, with entry and file counts |
| `C-c o T` | `myde-org-search-tags` | Read tags with completion; ANDed, or ORed with a prefix argument |

`tabulated-list-mode` was chosen over a font-size-weighted cloud: it gives column
sorting and `RET` handling for free, scales past a handful of tags, and renders
identically in a terminal, where `:height` faces are ignored. The `Count` column
uses a numeric sort predicate, since the mode sorts as strings by default and
would otherwise place 10 before 9.

### Counts must not lie

The count shown against a tag has to equal what pressing `RET` on it returns,
or the view is actively misleading. Two facts were verified rather than assumed:

- `org-agenda-use-tag-inheritance` defaults to `(todo search agenda)`, which
  does **not** include `tags` — so `org-tags-view` looked like it might ignore
  inherited tags.
- It does not matter. A file with `#+filetags: :proj:` yields the same three
  matching entries from `org-tags-view` whether or not `tags` is in that list,
  because filetags land on entries directly.

So counting with `org-get-tags`, which includes filetags, agrees with the search.
No change to `org-agenda-use-tag-inheritance` was needed.

Tags are stripped with `substring-no-properties` before use: org returns
inherited tags propertized, which breaks both display and `equal` comparison.

### Scope

Both commands cover org tags only. Denote keywords are a separate namespace with
its own search (`C-c o n s`, `denote-grep`), and folding them in would make `RET`
mean two different things depending on the row. Add a unified view if switching
between the two proves annoying in practice.

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
| `T`      | Task in current project | nearest `tasks.org` under `Tasks`, else `inbox.org` |
| `h`      | Thought (tagged)        | `inbox.org`                                   |
| `b`      | Bookmark, tagged (org-protocol) | `inbox.org`                           |
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
`(file+headline myde-org-capture-target "Tasks")`.

### Removed capture prompts

The `Schedule this task?` and `Set a deadline?` y-or-n prompts are removed.
Capture has to be fast or it stops being used; scheduling is a triage decision
better made in the agenda with `C-c C-s`, where the surrounding week is visible.
The `:PROJECT:` property prompt is removed because the destination file now
identifies the project.

## Web capture

Browser capture uses built-in `org-protocol`, which is already required in
the `core-org` activation block. Two paths, differing in weight:

| Path | Trigger | Result |
|------|---------|--------|
| Bookmark | template `b` | One tagged headline in `inbox.org` |
| Note | template `N` | A denote note in `notes/`, tagged with denote keywords |

Template `b` covers "capture and tag this page". Template `N` already exists in
`core-notes` for pages worth a durable note, and seeds the title from the
protocol payload via `myde-denote-capture-from-protocol`.

### Bookmark template

```
* [[%:link][%:description]]   :bookmark:%^G
  :PROPERTIES:
  :CREATED: %U
  :END:
  %i
```

`%^G` is appended directly after `:bookmark:` with no space. Verified: org's
`%^G` handler omits its leading colon when the preceding character is already a
colon, so this yields a single well-formed tag group —
`:bookmark:emacs:orgmode:` — rather than a malformed `:bookmark::emacs:`. Org
right-aligns the result. Tag completion covers all agenda files.

`%i` carries any text selected in the browser at capture time.

### URI handler registration

The browser emits an `org-protocol://` URI, which the OS must route to
`emacsclient`. This is per-platform and is the only part of the design that
touches the system outside `~/org/`.

**Linux** — already covered by the existing `etc/org-protocol.desktop` and
`mise run install-xdg`.

**macOS** — `mise run install-xdg` installs a freedesktop
`.desktop` file, which macOS ignores. Registration requires an application
bundle declaring `CFBundleURLTypes`, so the `mise run install-macos` task builds
the smallest such bundle using only tools already present on macOS:

1. `osacompile` compiles a two-line AppleScript `on open location` handler into
   `~/Applications/OrgProtocol.app`. AppleScript is used because macOS delivers
   URI activations as Apple Events, not as `argv` — a plain shell script in a
   bundle never receives the URL.
2. `plutil -insert` adds the `CFBundleURLTypes` entry declaring the
   `org-protocol` scheme.
3. `codesign --force --sign -` re-signs the bundle. This step is mandatory:
   editing `Info.plist` invalidates the ad-hoc signature `osacompile` applies,
   and `codesign -v` then reports `invalid Info.plist (plist or signature have
   been modified)`.
4. A one-time `open -a` registers the bundle with LaunchServices.

`osacompile`, `plutil`, and `codesign` are all part of macOS. No Automator app,
no Xcode, no manually edited plist, no new dependency. The bundle is built
locally so it carries no `com.apple.quarantine` attribute and Gatekeeper does
not block it.

### Bookmarklet

A `javascript:` bookmarklet constructs the capture URL directly, with no
extension to install or keep working:

```javascript
javascript:location.href='org-protocol://capture?template=b&url='+encodeURIComponent(location.href)+'&title='+encodeURIComponent(document.title)+'&body='+encodeURIComponent(window.getSelection())
```

`docs/org-protocol-setup.md` currently documents `template=u`, but no `u`
template exists — the key is `b`. As written, the documented bookmarklet fails.
That doc also still refers to `bookmarks.org`, which this design replaces with
`inbox.org`. Both need correcting.

## Code

Roughly 60 lines in the `core-org` definitions block. This is the only hand-written
logic in the
design; everything else is built-in org variable configuration.

| Function                          | Responsibility                                                                                    |
|-----------------------------------|---------------------------------------------------------------------------------------------------|
| `myde-org-sanitize-tag`           | Replace every character outside `[[:alnum:]_@#%]` with `_`                                        |
| `myde-org-project-root`           | `locate-dominating-file` upward search for `tasks.org`; nil when none                             |
| `myde-org-project-tasks-file`     | Path of the nearest `tasks.org`, or nil                                                           |
| `myde-org-project-name`           | Basename of the directory holding the nearest `tasks.org`, or nil                                 |
| `myde-org-find-task-files`        | Pruned recursive scan under `myde-org-code-directory`                                             |
| `myde-org-agenda-files`           | Inbox plus every discovered tasks file                                                            |
| `myde-org-refresh-agenda-files`   | Rescan and reset `org-agenda-files`; `:before` advice on `org-agenda`                             |
| `myde-org-capture-target`         | Target resolver for capture template `T`; nearest tasks file, else inbox                          |
| `myde-org-project-tasks-template` | Initial contents for a new tasks file, including the load-bearing `#+category:`                   |
| `myde-org-vc-root`                | `.git` upward search; matches the `.git` *file* form used by worktrees and submodules             |
| `myde-org-create-project-tasks`   | Interactive, `C-c o P`. Create a tasks file in a chosen directory, seeded with the repo root      |
| `myde-org-visit-project-tasks`    | Interactive, `C-c o p`. Visit the nearest tasks file, delegating creation when there is none      |
| `myde-org-ensure-tree`            | Create `~/org/` and `archive/` and the inbox file                                                 |
| `myde-org-tag-counts`             | Tally of (tag, entry count, file count) across agenda files, most frequent first                  |
| `myde-org-tags-match-string`      | Join tags with `+` (all) or `\|` (any) into an org match string                                    |
| `myde-org-search-tags`            | Interactive, `C-c o T`. Read tags with `completing-read-multiple`, show the matching agenda        |
| `myde-org-tag-cloud`              | Interactive, `C-c o t`. Frequency-ordered tag list in `tabulated-list-mode`                       |
| `myde-org-mode-disable-flycheck`  | Existing; unchanged                                                                               |

Per the convention in `AGENTS.md`, every section of `myde.org` holds up to two
source blocks: named definitions tangle to `user-lisp/myde.el`, while
`use-package` declarations, hooks, keybindings and the advice wiring tangle to
`init.el`. `mise run forms` enforces the division.

The definitions block carries a `(defvar org-agenda-files)` forward declaration so the
byte-compiler does not report an assignment to a free variable without pulling
org-agenda into the file.

## Housekeeping

- `org-archive-location` → `~/org/archive/%s_archive::`
- `org-id-locations-file` → XDG state directory, matching the repo's XDG policy
- `org-id-link-to-org-use-id` → `create-if-interactive`, for durable links
  between notes and tasks
- Refile targets unchanged: agenda files, `:maxlevel 3`

## Net change

Deleted from the `core-org` definitions block: `myde-reading-notes`, `myde-highlight-file`,
`myde-find-org-agenda-files`, `myde-projects-directory`,
`myde-org-known-projects`, `myde-org-project-history`,
`myde-org-capture-project-line`, `myde-org-capture-scheduled-line`,
`myde-org-capture-deadline-line`, `myde-org-tasks-file`,
`myde-org-bookmarks-file`.

Roughly 70 lines removed, 40 added. **No new packages.** One file edited by hand,
`myde.org`, in the two blocks of its `core-org` section.

`myde-org-notes-directory` is retained unchanged because the `core-notes`
definitions block consumes it.

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
- **Full page content archiving** — `org-protocol` sends the URL, title, and
  any selected text. Capturing readable page *body* text would need a reader
  extractor or pandoc. Add when selections prove insufficient.
- **Browser extension** — the bookmarklet needs nothing installed and cannot
  break on extension API changes. Chrome blocks `javascript:` bookmarklets on
  `chrome://` and Web Store pages only.
- **Contacts, calendar sync, mobile access, org-habit** — not requested.

## Verification

`tests/core-org.el`, run by `mise run test`. Every test builds its own temporary
tree, so none depend on the contents of `~/devel/projects` or `~/org`. Seven
checks covering the logic that fails silently:

| Test | Guards against |
|------|----------------|
| `sanitize-tag/produces-valid-org-tags` | invalid `#+filetags:` making tag search return nothing |
| `ensure-tree/creates-dirs-and-inbox` | missing agenda dir treated as a file; missing agenda file blocking startup |
| `project-root/finds-nearest-tasks-file` | nearest-wins shadowing, upward walk, nil rather than error |
| `project-name/is-the-root-directory-name` | wrong project name from a nested subdirectory |
| `capture-target/falls-back-to-inbox` | capture failing, or creating a stray tasks file, outside any project |
| `find-task-files/prunes-dot-dirs-and-node-modules` | `.git` internals and archived `.ATTIC/` work entering the agenda |
| `project-tasks-template/sets-category-and-valid-filetags` | every project appearing in the agenda as `tasks` |
