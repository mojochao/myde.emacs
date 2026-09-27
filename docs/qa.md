# Quality Assurance

## 1. Summary

AGENTS.md states it plainly: "There is no build or lint step."
Two things stand in for one, and they check different kinds of failure.
`mise run test` runs ERT checks under `tests/`, which catch logic that fails silently rather than loudly.
The probe (`mise run probe`) boots a throwaway daemon and catches what only shows up at runtime, such as a package that never loads or a mode that never turns on.

### 1.1 Layers of assurance

| Layer      | What runs                              | Where                        | What it catches                                                             |
|------------|-----------------------------------------|-------------------------------|-------------------------------------------------------------------------------|
| ERT        | `mise run test`                        | Local, pre-commit, pre-push  | Silent logic failures in `user-lisp/myde.el`, one file per module under `tests/` |
| `forms`    | `mise run forms`                       | Local, pre-commit, pre-push  | A side effect creeping into `user-lisp/myde.el`, breaking batch loading      |
| `check`    | `mise run check`                       | Local, pre-push              | Tangled elisp drifting from `myde.org`                                      |
| Probe      | `mise run probe <report>`              | Local, by hand                | A declared package or startup mode regressing, diffed across two reports    |
| hk hooks   | `hk.pkl` pre-commit and pre-push       | Every commit and push        | A commit or push that would carry drift, a broken definitions-only invariant, or a test failure |
| Docs checks | `mise run docs-check`                 | Local, CI                    | A broken link, a traceability mismatch, a missing or remote-loaded vendored asset, a markdown lint violation |
| CI         | `.github/workflows/docs.yml` `check` job | GitHub Actions on push to `main` | The same docs checks, gating the `deploy` job                              |

## 2. Automatic unit and integration testing

### 2.1 Unit tests

`mise run test` loads every file under `tests/*.el` and runs ERT in batch mode.
Each file's `;;; Commentary:` block names the silent failure its tests cover.

| File                | Covers, from its commentary                                                                                                          |
|----------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `tests/core-base.el` | `myde-tangle-source-on-save` comparing a symlinked path against the true name, and `myde-display-warning-advice` suppressing a daemon's first-frame `*Warnings*` pop-up below `warning-minimum-level` |
| `tests/core-help.el` | `myde-help-which-key-align-docstrings` finding each docstring by its face, so alignment can fail while which-key still draws the popup |
| `tests/core-org.el`  | Project discovery and tag sanitization: an invalid `#+filetags:` value, a missing `#+category:`, a missing agenda directory or file, and an unpruned recursive scan walking `.git` internals |

`myde-tangle-source-on-save/fires-through-either-path` backs [FR-9](prd.md#fr-9), asserting that saving `myde.org` through either its real path or the `~/.config/emacs` symlink tangles it.
`myde-display-warning-advice/drops-daemon-display-below-threshold` backs [FR-4](prd.md#fr-4), asserting that a daemon's first client frame shows a warning only if it would be shown anyway.
`myde-org-capture-target/falls-back-to-inbox` backs [FR-5](prd.md#fr-5), asserting that a capture lands on the nearest project's tasks file or falls back to the inbox.
`myde-org-project-root/finds-nearest-tasks-file`, `myde-org-find-task-files/prunes-dot-dirs-and-node-modules`, and `myde-org-project-tasks-template/sets-category-and-valid-filetags` back [FR-6](prd.md#fr-6), asserting that any directory with a `tasks.org` is found as a project and given a category distinct from every other project's.

All three test files load `user-lisp/myde.el` directly, which [NFR-5](prd.md#nfr-5) requires to hold definitions only.
`mise run forms` (`scripts/myde-forms.py`) asserts that invariant by rejecting any top-level form outside its fixed set of definition kinds.

### 2.2 Integration tests

`mise run probe <report>` boots this config as an isolated throwaway daemon: a unique socket, `PATH` stripped to `/usr/bin:/bin`, and a private `XDG_STATE_HOME`.
It writes a report of the declared `use-package` forms, the global modes enabled at startup, init time, and startup errors.

The stripped `PATH` leaves only `git` and the login shell on it, so a gated section turns on only if `exec-path-from-shell` recovered the rest during init ([FR-2](prd.md#fr-2), [FR-3](prd.md#fr-3)).
A fresh clone boots with nothing tangled ([FR-1](prd.md#fr-1)), and a warm start's `elpaca-init-time-seconds` line shows it reaching `elpaca-after-init-hook` in about 4 seconds ([NFR-3](prd.md#nfr-3)).

Run the probe before and after a change and diff its `declared:` and `mode:` lines.
A declared package that disappears, or a mode that flips to `off`, is a regression.

**Limit:** `scripts/myde-probe.sh` boots the daemon at lines 30-31 without redirecting stdin.
Every throwaway daemon of this config, this probe or one booted by hand, logs an end-of-file error reading from stdin during startup.
That error aborts `elpaca-after-init-hook` at `global-flycheck-mode`.
It and every hook after it report `mode: … off` whether or not the mode actually loaded.
A stripped `PATH` is not the cause: a full `PATH` reproduces the same error, and the stdin reader itself is unidentified.
The `mode:` lines are only useful as a diff between two probes taken the same way, not as an absolute reading.
Fixing the stdin handling is tracked as [RM-11](roadmap.md#rm-11).

### 2.3 How tests are specified

Tests are written as ERT (`ert-deftest`) checks under `tests/`.
Each file loads `user-lisp/myde.el` directly with `load`, rather than requiring a running Emacs session or a byte-compiled build.
That works only because the library holds definitions only, with no side effects, so loading it in batch is safe and needs no package to be installed.
Each test builds its own temporary tree rather than depending on `~/org` or `~/devel/projects`, so a developer's local state cannot make a test pass or fail by accident.

### 2.4 Enforcement with git hooks

`hk.pkl` defines the git hooks that `mise run init` installs.
`pre-commit` stashes unstaged changes, tangles `myde.org`, and stages `early-init.el`, `init.el`, and `user-lisp/myde.el`, so a commit cannot carry drift between the source and its tangled output ([FR-9](prd.md#fr-9)).
It then runs `forms` and `test`, both declared to depend on `tangle` so they read the file `tangle` just wrote rather than a stale one.
`pre-push` runs `mise run check` and `mise run test` as a backstop for a commit made with `--no-verify`.
It verifies without rewriting anything: `check` tangles, asserts the definitions-only invariant, and fails if the result differs from what is committed ([FR-1](prd.md#fr-1)).
`hk check` and `hk fix` run the same steps by hand.

### 2.5 Docs checks

`mise run docs-check` runs five checks in order, stopping at the first failure.

| Command                        | Catches                                                                                     |
|----------------------------------|-------------------------------------------------------------------------------------------------|
| `scripts/check_links.py`        | A broken relative link or an anchor that does not match docsify's slugify algorithm         |
| `scripts/check_trace.py`        | A requirement's section 8.3 block and a downstream doc (ADR, TDD, QA, roadmap, changelog) disagreeing on which links which, or a link missing from the chain |
| `scripts/test_check_trace.py`   | Regressions in `check_trace.py` itself, checked by its own 12 tests against fixtures         |
| `scripts/vendor_docs.py --check` | A pinned asset that is missing or never loaded, an unpinned asset that is loaded, or a reference to a live CDN URL instead of `docs/vendor/` ([NFR-7](prd.md#nfr-7)) |
| `markdownlint docs/`            | Markdown lint violations against this repo's markdownlint config                             |

A push to `main` that changes `docs/` runs the same five checks in the `check` job of `.github/workflows/docs.yml`.
The `deploy` job that publishes to GitHub Pages declares `needs: check`, so a failing check blocks the publish ([FR-11](prd.md#fr-11)).

## 3. Manual testing

The requirements below have no automated check and are confirmed by hand.

### 3.1 Daemon, frames, and MCP

1. On macOS, restart the daemon: `launchctl kickstart -k gui/$(id -u)/gnu.emacs.daemon`.
   Expected: the command exits without error and a new daemon process is running.
2. Open a client frame: `emacsclient -c`.
   Expected: a GUI frame opens on `*scratch*`, confirming one daemon serves the frame ([FR-4](prd.md#fr-4)).
3. Open a file with `$EDITOR`.
   Expected: the file opens in that same daemon's frame, not in a second Emacs process.
4. From an agent, call the MCP `eval-elisp` tool with `(+ 1 2)`.
   Expected: it returns `3`, confirming an agent can query and drive the session ([FR-8](prd.md#fr-8)).

### 3.2 Browser capture

Follow the end-to-end steps in [User Guide §2.6](user.md#_26-browser-capture): start Emacs, click the bookmarklet from any page, and save the resulting capture.
Expected: the capture buffer opens pre-filled with the page's URL and title in the `b` template.
The saved entry lands in `~/org/inbox.org` tagged `:bookmark:`, confirming a browser can capture into the config ([FR-5](prd.md#fr-5)).

### 3.3 Platforms, Emacs version, and startup state

1. Start the daemon on Linux and confirm it boots cleanly.
2. Start the daemon on macOS and confirm it boots cleanly, confirming both supported platforms start clean ([NFR-2](prd.md#nfr-2)).
3. Evaluate `emacs-version` and confirm it reports 31.1 or later.
4. Evaluate `(native-comp-available-p)` and confirm it returns non-nil, confirming the native-compile floor ([NFR-1](prd.md#nfr-1)).
5. Run `git status` right after a start and confirm it shows no new files, confirming nothing but packages is written inside `user-emacs-directory` ([NFR-4](prd.md#nfr-4)).
6. Evaluate `gc-cons-threshold` and `file-name-handler-alist` after startup and confirm both are restored to their non-startup values, confirming a completed bootstrap ([NFR-6](prd.md#nfr-6)).

A failed elpaca bootstrap, the case NFR-6 exists to guard against, is not exercised by this check.
Only a completed startup is confirmed.

### 3.4 Docs site

1. Run `mise run docs-up` or `mise run docs` and open `http://localhost:3000`.
2. Confirm the sidebar shows `v0.1.0`, read from the root `VERSION` file ([FR-12](prd.md#fr-12)).
3. Run `mise run docs-search <question>` and confirm it returns a relevant page from `docs/`, confirming the docs can be searched locally ([FR-10](prd.md#fr-10)).
4. With `docs/changelog.md` missing a `## <VERSION> - <date>` heading, run `mise run tag` and confirm it refuses with an error rather than tagging.

### 3.5 Language keys

1. Open a buffer in each gated language.
   Confirm `C-c e`, `C-c t`, `C-c i`, and `C-c d` each run that language's command.
   Expected: every language shares the same prefixes ([FR-7](prd.md#fr-7)).
2. In an Elixir buffer, confirm `C-c e`, `C-c t`, and `C-c i` reach eglot, tests, and the REPL as expected.
3. In the same buffer, confirm `C-c d` does not reach dape.
   `mix-minor-mode` binds `C-c d` to `mix-minor-mode-command-map` (`elpaca/sources/mix/mix.el:322`), and it wins over the global dape binding.
   Tracked as [RM-10](roadmap.md#rm-10).
