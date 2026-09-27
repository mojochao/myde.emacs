<!-- markdownlint-disable MD051 -->

# Architecture Decisions

| ADR               | Title                                                               | Status   |
|-------------------|---------------------------------------------------------------------|----------|
| [ADR-00](#adr-00) | One literate `myde.org` tangled to committed elisp                  | Accepted |
| [ADR-01](#adr-01) | elpaca instead of package.el                                        | Accepted |
| [ADR-02](#adr-02) | Binary gates instead of toggles                                     | Accepted |
| [ADR-03](#adr-03) | Definitions in `user-lisp/myde.el`, activation in `init.el`         | Accepted |
| [ADR-04](#adr-04) | project.el instead of projectile                                    | Accepted |
| [ADR-05](#adr-05) | One daemon with client frames and an on-demand dashboard            | Accepted |
| [ADR-06](#adr-06) | mise tasks and hk hooks that re-tangle rather than reject           | Accepted |
| [ADR-07](#adr-07) | State, data, and cache in XDG directories                           | Accepted |
| [ADR-08](#adr-08) | Project tasks in a `tasks.org` beside the code                      | Accepted |
| [ADR-09](#adr-09) | A fixed MCP socket that never takes over a live one                 | Accepted |
| [ADR-10](#adr-10) | GC and file handlers restored on `emacs-startup-hook`               | Accepted |
| [ADR-11](#adr-11) | Vendored docsify 4 with Catppuccin Frappé                           | Accepted |
| [ADR-12](#adr-12) | GitHub Pages through an Actions deployment gated on the docs checks | Accepted |
| [ADR-13](#adr-13) | One `VERSION` file at the repo root                                 | Accepted |

Add records with `/docs-adr`, which allocates the number and keeps this table, the heading, and the cross-links in agreement.

Each record is a `## ADR-NN: <title> :id=adr-NN` heading with **Status**, **Date**, **Requirements**, **Context**, **Decision**, and **Consequences**.
The `:id=` attribute is what docsify uses as the anchor, which is why this file disables MD051.

## ADR-00: One literate `myde.org` tangled to committed elisp :id=adr-00

**Status:** Accepted

**Date:** 2026-09-15

**Requirements:** [FR-1](prd.md#fr-1), [FR-9](prd.md#fr-9)

**Context:** The previous config held 8,191 lines of Emacs Lisp across 53 modules, each split into `lib.el` and `cfg.el`, plus 24 `defcustom` toggles persisted in `custom.el`.
Changing one thing meant touching four files.
Emacs 31.1 added `user-lisp-directory`, which made it possible for one literate source to tangle into every elisp file this config loads.

**Decision:** `myde.org` became the only file edited by hand, tangled into `early-init.el`, `init.el`, and `user-lisp/myde.el`.
The three tangled outputs stay committed to the repository.

**Consequences:** A fresh clone starts Emacs without running org or tangling anything.
Startup loads the tangled elisp directly and never loads org.
`mise run tangle` regenerates the three files, and `mise run check` fails if the committed elisp has drifted from `myde.org`.

## ADR-01: elpaca instead of package.el :id=adr-01

**Status:** Accepted

**Date:** 2026-09-15

**Requirements:** [NFR-3](prd.md#nfr-3)

**Context:** package.el needed a set of workarounds documented in AGENTS.md: built-in archive pinning, `package-install-upgrade-built-in`, and version-conditional `transient` pinning among them.
Commit `803a8cc` replaced package.el with elpaca on 2026-09-15.

**Decision:** Packages are declared under `use-package-always-ensure t`, with every built-in form carrying `:ensure nil`.
Git-only packages take an elpaca recipe plist instead of a `package-vc` entry.

**Consequences:** A warm start reaches `elpaca-after-init-hook` in roughly 4 seconds, against roughly 7 seconds under the package.el config it replaced.
Startup hooks that used to fire on `after-init-hook` or `emacs-startup-hook` had to move to `elpaca-after-init-hook`, because a `use-package` body under elpaca runs after those hooks have already fired.
Packages live under `elpaca/` at the repository root, gitignored but kept for inspection and agent access.

## ADR-02: Binary gates instead of toggles :id=adr-02

**Status:** Accepted

**Date:** 2026-09-15

**Requirements:** [FR-2](prd.md#fr-2), [FR-3](prd.md#fr-3)

**Context:** The prior config carried 24 hand-maintained `defcustom` toggles, a second source of truth that could drift from the code they gated.
A section that needs a toolchain now checks `executable-find` directly instead of reading a toggle.

**Decision:** A gated section wraps its whole `use-package` form in `(when (executable-find "<binary>") ...)`, never a keyword inside the form.
`exec-path-from-shell` runs synchronously with `:ensure (:wait t)` ahead of every gated section, so `exec-path` is complete before any gate is checked.

**Consequences:** Installing a binary turns its section on at the next start, and removing it turns the section off, with no toggle to maintain.
elpaca queues a package order when a `use-package` form is expanded, before `:if` or `:when` runs, so a keyword inside the form cannot prevent a clone.
GUI processes on macOS do not inherit the login shell's `PATH`, so a gate checked before `exec-path-from-shell` ran would pass or fail unpredictably between a daemon and a windowed session.

## ADR-03: Definitions in `user-lisp/myde.el`, activation in `init.el` :id=adr-03

**Status:** Accepted

**Date:** 2026-09-17

**Requirements:** [NFR-5](prd.md#nfr-5)

**Context:** `user-lisp/myde.el` held 4,930 lines mixing `myde-*` definitions with the `use-package` forms and gates that activated them, with no boundary marking which code carried side effects.
The mixture made it impossible to read the library alone, and impossible to load it in batch without a running Emacs.

**Decision:** `myde.el` keeps only `defun`, `defvar`, `defcustom`, `defconst`, `define-derived-mode`, and `define-minor-mode` forms, with no side effects.
Every `use-package` form, binary gate, and variable assignment moved to `init.el`.

**Consequences:** `mise run forms` asserts that `myde.el` holds definitions only.
The ERT tests under `tests/` load `user-lisp/myde.el` directly in batch, which only works because that file has no side effects.
Binary gates live in `init.el` alone, so a `myde-prog-go-*` function exists whether or not `go` is installed, and nothing calls it unless the gate in `init.el` passed.

## ADR-04: project.el instead of projectile :id=adr-04

**Status:** Accepted

**Date:** 2026-05-11

**Requirements:** [NFR-4](prd.md#nfr-4)

**Context:** projectile held the active keybindings, the dashboard backend, and one function call in the C++ module, while the built-in project.el sat configured but passive.
The commands this config actually used, find-file, find-regexp, compile, and project-root resolution, all had a project.el equivalent with no functional gap.

**Decision:** Commit `59c95ab` removed projectile and the `rg` package it pulled in, and switched the dashboard backend and the C++ debugger's build-directory lookup to project.el.

**Consequences:** Project state now lives in one XDG-routed `projects.eld` file instead of two competing known-projects files.
The config carries one fewer external package.
`project-find-regexp` uses ripgrep through `xref` when `rg` is on `exec-path`, with no wrapper package required.

## ADR-05: One daemon with client frames and an on-demand dashboard :id=adr-05

**Status:** Accepted

**Date:** 2026-09-18

**Requirements:** [FR-4](prd.md#fr-4)

**Context:** A launchd agent starts `emacs --fg-daemon` at login, and every GUI frame is meant to come from `emacsclient -c` against that one process.
`initial-buffer-choice` does not survive under elpaca: `elpaca-log-initial-queues` overwrites it whenever any order is unbuilt or failed, and restores the captured value on `elpaca-after-init-hook`, racing dashboard's own `:config` block.
Commit `6dec388` traced an intermittent bug to this race: a client frame's initial buffer depended on whether elpaca had work to do that particular start.

**Decision:** Dashboard became `:defer t`, opened on demand with `M-x dashboard-open`, instead of being set as the initial buffer.
`$EDITOR` and `$VISUAL` point at `emacsclient`, so every entry point reaches the same daemon.

**Consequences:** A client frame now opens on `*scratch*` and costs nothing at startup.
The first `dashboard-open` costs about 0.70 s to load the package, and later calls cost about 0.05 s.
Emacs.app must never run alongside the daemon, since the two processes would contend for the server socket, the MCP socket, and the XDG state files.

## ADR-06: mise tasks and hk hooks that re-tangle rather than reject :id=adr-06

**Status:** Accepted

**Date:** 2026-09-18

**Requirements:** [FR-9](prd.md#fr-9)

**Context:** A Makefile previously drove tangle and check targets by hand, with no hook enforcing that `myde.org` and its tangled output stayed in sync at commit time.
Commit `1d8c3e0` replaced it with mise tasks and hk hooks on 2026-09-18.
Commit `6f3393e` added two further layers.
An Emacs `after-save-hook` re-tangles on save.
A Claude Code PostToolUse hook does the same for agent edits, paired with a PreToolUse hook that denies edits to the three tangled files outright.

**Decision:** hk's pre-commit hook treats drift between `myde.org` and the tangled elisp as a fix, not a rejection.
It stashes unstaged changes, runs `mise run tangle`, stages the three tangled files, then runs `mise run forms` and `mise run test`.
pre-push runs the same checks without rewriting anything, as a backstop for `--no-verify`.

**Consequences:** `myde.org` and its tangled output cannot drift apart in a commit made through the normal hook path.
An agent that edited a tangled file directly would have its change silently discarded at the next tangle.
The PreToolUse guard denies the edit, rather than letting the loss surface later at pre-push.
`stage` is restricted to the three tangled files, so a partially staged `myde.org` keeps whatever staging the user chose.

## ADR-07: State, data, and cache in XDG directories :id=adr-07

**Status:** Accepted

**Date:** 2026-04-27

**Requirements:** [NFR-4](prd.md#nfr-4)

**Context:** Emacs state, data, and cache files used to accumulate directly inside `user-emacs-directory`, cluttering the config directory.
Commit `4a8c68c` redirected them to the XDG base directory locations.

**Decision:** State such as recentf, places, history, tramp, and auto-save-list goes to `$XDG_STATE_HOME/emacs/`.
Data such as transient and tree-sitter goes to `$XDG_DATA_HOME/emacs/`.
Cache such as eln-cache and url goes to `$XDG_CACHE_HOME/emacs/`.
Only packages, under `elpaca/` at the repository root, and the gitignored `custom.el` stay inside `user-emacs-directory`.

**Consequences:** `auto-save-list-file-prefix` has to be set in `early-init.el`, because Emacs creates that directory before `init.el` runs.
Native compilation cache redirection has to happen in `early-init.el` too, before any compilation occurs.
A fresh clone leaves nothing but packages and `custom.el` inside `user-emacs-directory`.

## ADR-08: Project tasks in a `tasks.org` beside the code :id=adr-08

**Status:** Accepted

**Date:** 2026-08-10

**Requirements:** [FR-5](prd.md#fr-5), [FR-6](prd.md#fr-6)

**Context:** An earlier design kept two half-built, mutually exclusive layouts at once: a central `tasks.org` keyed by a `:PROJECT:` property, and a separate `~/org/projects/` tree.
Neither was wired into `org-agenda-files`.
The design was revised on 2026-08-10 to colocate each project's tasks in a `tasks.org` inside the project directory itself, located by an upward search from point.

**Decision:** A project is any directory containing a `tasks.org`, found with `locate-dominating-file`, with no fixed root and no naming convention.
Capture, tagged thoughts, and browser bookmarks all route through the same `org-protocol` layout.

**Consequences:** A `tasks.org` travels with its project directory and shows up in `git status` there, mitigated by one global gitignore entry rather than a per-repo edit.
Org derives a missing `#+category:` from the file name, so every project's tasks file would otherwise report the same category, `tasks`, and the creation template sets it explicitly instead.
Agenda discovery prunes dot-directories and `node_modules`, keeping a recursive scan close to free.

## ADR-09: A fixed MCP socket that never takes over a live one :id=adr-09

**Status:** Accepted

**Date:** 2026-09-18

**Requirements:** [FR-8](prd.md#fr-8)

**Context:** The MCP server's default conflict-resolution setting, `warn`, silently rebound to an alternative `emacs-mcp-server-N.sock` path instead of the fixed one the stdio bridge hardcodes.
Agents were left unable to reach a live daemon.
Commit `69470b4` switched the setting to `force`, which unlinked whatever held the fixed path.
Commit `9ee87eb` found that `force` let a second Emacs, such as Emacs.app launched by mistake or `mise run probe`, steal the daemon's own socket.
It switched the setting to `error` instead.

**Decision:** `mcp-server-socket-conflict-resolution` is set to `error`, so a second Emacs on this config leaves a live daemon's socket alone and starts without an MCP server.
The startup hook catches that error so the rest of `elpaca-after-init-hook` still runs.

**Consequences:** Agents reach the MCP server on one fixed socket path, `$XDG_CACHE_HOME/emacs/emacs-mcp-server.sock`, that the socat bridge hardcodes.
A socket left behind by a dead daemon is still reclaimed as stale ahead of the conflict-resolution check.
A second Emacs process now logs that the MCP server did not start and carries on, rather than taking the daemon's socket.

## ADR-10: GC and file handlers restored on `emacs-startup-hook` :id=adr-10

**Status:** Accepted

**Date:** 2025-12-08

**Requirements:** [NFR-6](prd.md#nfr-6)

**Context:** Commit `8f18f5a` established both the garbage-collection and `file-name-handler-alist` restoration on `emacs-startup-hook` together, well before elpaca replaced package.el.
When commit `803a8cc` later moved fifteen other startup hooks to `elpaca-after-init-hook`, it deliberately left this pair on `emacs-startup-hook`.
That hook fires even when the elpaca bootstrap fails outright, such as a cold clone with no network or no `git`.

**Decision:** GC suppression and `file-name-handler-alist` clearing stay restored on `emacs-startup-hook` in `early-init.el`, never moved to `elpaca-after-init-hook`.

**Consequences:** A failed elpaca bootstrap still restores `gc-cons-threshold` and `file-name-handler-alist`, so TRAMP and compressed files keep working even when no package loaded.
The cost of restoring GC before elpaca finishes activating packages is negligible.
Every other startup hook that depends on a package being loaded has to use `elpaca-after-init-hook` instead, since a `use-package` body under elpaca runs after `emacs-startup-hook` has already fired.

## ADR-11: Vendored docsify 4 with Catppuccin Frappé :id=adr-11

**Status:** Accepted

**Date:** 2026-09-27

**Requirements:** [FR-10](prd.md#fr-10), [NFR-7](prd.md#nfr-7)

**Context:** The docs site ran docsify 5 loaded from a CDN, fetching third-party scripts and stylesheets at runtime on every visit.
Catppuccin's Frappé theme and docsify-themeable's simple-dark layout both target docsify 4, not 5.

**Decision:** `docs/vendor/` now holds docsify 4.13.1, its search plugin, docsify-themeable's simple-dark CSS, the Catppuccin Frappé mauve theme, and the Prism grammars the docs actually use.
Each is pinned to a version or commit.
The Catppuccin theme's remote `@import` is rewritten to a vendored file so no stylesheet loads from a CDN.

**Consequences:** The published site fetches no third-party script or stylesheet at runtime.
`scripts/vendor_docs.py` writes every pinned file and fails if the expected `@import` line is missing, so an upstream change cannot silently reintroduce a remote import.
Upgrading a pinned version means editing one pin table and reviewing the resulting git diff.

## ADR-12: GitHub Pages through an Actions deployment gated on the docs checks :id=adr-12

**Status:** Accepted

**Date:** 2026-09-27

**Requirements:** [FR-11](prd.md#fr-11), [NFR-7](prd.md#nfr-7)

**Context:** The repository had no Pages site configured, and `docs/.nojekyll` existed only to suppress a Jekyll build that a GitHub Actions deployment never runs.

**Decision:** A `docs.yml` workflow runs a check job that installs markdownlint and runs `mise run docs-check`, the same check a developer runs locally.
A deploy job follows and needs the check job to pass.
The deploy job alone carries the `pages` and `id-token` permissions, and every action is pinned to a full commit SHA.

**Consequences:** A push to `main` that changes docs, `VERSION`, scripts, the lint config, or `mise.toml` triggers a deploy, gated on the same checks a developer would run by hand.
A failing `docs-check` blocks the publish instead of shipping broken links or lint violations.
`docs/.nojekyll` was deleted, since an Actions deployment has no Jekyll step to suppress.

## ADR-13: One `VERSION` file at the repo root :id=adr-13

**Status:** Accepted

**Date:** 2026-09-27

**Requirements:** [FR-12](prd.md#fr-12)

**Context:** The docs site is served three different ways: `docsify serve` locally, a GitHub Pages artifact, and a container mounting the repository.
Each needed the same version string without maintaining three separate copies of it.

**Decision:** A single `VERSION` file at the repository root holds one semver string, starting at `0.1.0`, and `docs/VERSION` is a relative symlink to it.
The file names the version most recently released, so the sidebar shows the last tag between releases rather than an unreleased placeholder.

**Consequences:** `actions/upload-pages-artifact` tars with `--dereference`, so the Pages artifact holds the real file rather than a dangling symlink.
The docs container mounts the repository root, so the same symlink resolves inside it.
docsify-cli's local dev server answers any extensionless path that accepts HTML with `index.html`, so the sidebar plugin fetches `VERSION` with an explicit `Accept: text/plain` header, which commit `fb7ee5e` fixed.
`mise run tag` creates the annotated tag `v<VERSION>` and refuses when `docs/changelog.md` has no matching release heading.
