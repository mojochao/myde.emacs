# Product Requirements

## 1. Summary

MyDE is a literate Emacs configuration for Emacs 31.1 and later, compiled with native-compile support.
It targets Linux and macOS.
One file, `myde.org`, is edited by hand.
`mise run tangle` regenerates three committed files from it: `early-init.el`, `init.el`, and `user-lisp/myde.el`.

## 2. Background & Motivation

MyDE replaced an earlier package.el configuration built from a `modules/` tree, one directory per module, each carrying its own enable toggle.
The toggles were a second source of truth that could drift from the code they gated.
Commit `803a8cc` replaced package.el with elpaca, and the 2026-09-15 design (`superpowers/specs/2026-09-15-three-file-literate-config-design.md`) replaced the module tree and its toggles with binary-presence gates tangled from one literate source.
AGENTS.md records the result: a warm start now reaches `elpaca-after-init-hook` in roughly 4 seconds, against roughly 7 seconds for the package.el configuration it replaced.

## 3. Scope

### 3.1 Architecture

`myde.org` is the only file edited by hand.
It tangles into three committed files: `early-init.el`, `init.el`, and `user-lisp/myde.el`.
The tangled files are committed, so a fresh clone starts Emacs without tangling anything (FR-1).
Saving `myde.org` re-tangles it on the global `after-save-hook`, and the pre-commit hook re-tangles again and stages the three files, so `myde.org` and its tangled output cannot drift apart in a commit (FR-9).

`user-lisp/myde.el` holds only definitions and declarations, such as `defun`, `defvar`, `defcustom`, and `define-minor-mode`.
It has no side effects, which lets it load in batch with no running Emacs and keeps it testable under ERT (NFR-5).
`init.el` holds the `use-package` forms, binary gates, and variable assignments that activate what `myde.el` defines.

A section that needs a toolchain is wrapped in a binary-presence gate, `(when (executable-find "<binary>") ...)`, around the whole `use-package` form.
Installing the binary turns the section on at the next start, and removing it turns the section off, with no toggle to maintain (FR-2).
elpaca queues a package order when the `use-package` form is expanded, before any `:if` or `:when` runs, so the gate has to wrap the whole form or it cannot prevent a clone.
Binary gates run during init, so `exec-path` has to be complete first.
GUI processes on macOS do not inherit the login shell's `PATH`.
The Environment section therefore runs `exec-path-from-shell-initialize` synchronously, with `:ensure (:wait t)`, ahead of every gated section.
Gates see the same `PATH` in a daemon or a windowed session (FR-3).

Packages are managed by elpaca instead of package.el.
A warm start with a populated `elpaca/` directory reaches `elpaca-after-init-hook` in roughly 4 seconds (NFR-3).

Nothing but packages and the gitignored `custom.el` lives inside `user-emacs-directory`.
State, data, and cache are redirected to `$XDG_STATE_HOME/emacs/`, `$XDG_DATA_HOME/emacs/`, and `$XDG_CACHE_HOME/emacs/` (NFR-4).

The docs site under `docs/` is vendored rather than loaded from a CDN.
docsify, its search plugin, the theme, and the Prism grammars all ship under `docs/vendor/`, so the published site fetches no third-party script or stylesheet at runtime (NFR-7).

### 3.2 In scope

The section categories under `* Configuration` in `myde.org`:

- `core-*`: infrastructure and productivity (base, UI, UX, org, help, terminals, dashboard, completion, notes, snippets, projects, spell)
- `ai-*`: AI assistant integration (base, gptel, agents, claude, mcp)
- `auth-*`: authentication and secrets (1Password)
- `data-*`: data formats (CSV, dotenv, HCL, JSON, pkl, TOML, XML, YAML)
- `containers-*`: container tooling (Kubernetes)
- `prog-*`: programming languages, one section per language
- `text-*`: text formats (base, AsciiDoc, Markdown)
- `ebook-*`: ebook readers (EPUB, PDF)

Org capture and projects.
Tasks, thoughts, bookmarks, and notes can be captured from Emacs and from a browser through `org-protocol` (FR-5).
Any directory holding a `tasks.org` is a project, and its tasks appear in the agenda (FR-6).

Keybinding prefixes are shared across every language section: `C-c e` for eglot, `C-c t` for tests, `C-c i` for the REPL, `C-c d` for the debugger (FR-7).

The `ai-mcp` section runs an MCP server inside Emacs, so agents can query and drive the running session (FR-8).

The docs site under `docs/` can be previewed and searched locally (FR-10), and a push to `main` that changes it publishes it to GitHub Pages (FR-11).

A root `VERSION` file names the released version and shows in the docs sidebar (FR-12).

### 3.3 Out of scope

Windows.
AGENTS.md names only Linux and macOS as supported platforms.

Emacs before 31.1.
`user-lisp-directory` does not exist in earlier versions, so `(require 'myde)` would fail.

Per-section toggles.
Enablement follows binary presence on `PATH`, and there is no override list and no `custom.el` entry for a section.

A startup dashboard.
Dashboard is `:defer t` and opened on demand with `M-x dashboard-open`, and an `emacsclient -c` frame opens on `*scratch*` instead.

## 4. Target Audience

The owner, Allen Gooch, running MyDE on Linux and macOS (NFR-2).
Coding agents working in the repository, for which AGENTS.md exists.
Emacs 31.1, compiled with native-compile support, is the floor, since `user-lisp-directory` does not exist before it (NFR-1).

## 5. User Flow

### 5.1 Happy path

Clone the repository.
Run `mise trust` once per machine, since mise refuses to read an untrusted config.
Run `mise run init`, which symlinks the repo into `~/.config/emacs` and installs the hk git hooks.
Start Emacs.
The first, cold start clones and builds every package with elpaca into `./elpaca/`, which takes a few minutes.
Later starts only activate what is already built.
A launchd agent (`gnu.emacs.daemon.plist`) starts `emacs --fg-daemon` at login.
Every GUI frame comes from `emacsclient -c`, and `$EDITOR` and `$VISUAL` point at `emacsclient`, so they reach the same daemon (FR-4).

### 5.2 Failure flow

A git host can flake mid-clone and leave an elpaca source directory holding `.git` but no working tree.
elpaca does not recover on its own, so the order fails on every start until the checkout is completed and `elpaca-rebuild` is called.
A missing binary leaves its gated section off, with no error, and installing the binary turns the section on at the next start.
GC and `file-name-handler-alist` restoration stay on `emacs-startup-hook` in `early-init.el`, not `elpaca-after-init-hook`.
A failed elpaca bootstrap therefore cannot leave a session with GC disabled or TRAMP broken (NFR-6).

## 6. Configuration

There are no toggles.
Presence of a binary on `PATH` is the setting, checked with `executable-find` around the whole `use-package` form for a gated section.
`custom.el` is gitignored (`.gitignore`: `custom.el`, under "user customizations") and holds only what Customize writes.
`myde.org` sets `custom-file` to `custom.el` under `user-emacs-directory` and loads it if present, so a theme saved through Customize survives a restart, but it carries no section toggles.

## 7. Open Questions

There are no open questions at present.
The `C-c d` collision in Elixir buffers is resolved, see [RM-10](roadmap.md#rm-10).

## 8. Requirements Inventory

A consolidated, traceable view of the requirements described above, split into functional and non-functional.

Priority follows:

- **Must** (the config is broken without it)
- **Should** (expected, not blocking)
- **Won't** (explicitly excluded, tracked for visibility)

### 8.1 Functional Requirements

| ID    | Requirement                                                                                                          | Priority | Source                    |
|-------|-----------------------------------------------------------------------------------------------------------------------|----------|---------------------------|
| FR-1  | A fresh clone starts Emacs without tangling `myde.org`.                                                              | Must     | [§3.1](#_31-architecture) |
| FR-2  | A section that needs a toolchain turns on when its binary is on `PATH` and stays off when it is not, with no toggle. | Must     | [§3.1](#_31-architecture) |
| FR-3  | Binary gates see the login shell's `PATH`, including in macOS GUI and daemon sessions.                               | Must     | [§3.1](#_31-architecture) |
| FR-4  | One daemon serves every frame, and `$EDITOR` reaches it.                                                             | Must     | [§5.1](#_51-happy-path)   |
| FR-5  | Tasks, thoughts, bookmarks, and notes can be captured, including from a browser.                                     | Must     | [§3.2](#_32-in-scope)     |
| FR-6  | Any directory with a `tasks.org` is a project, and its tasks appear in the agenda.                                   | Must     | [§3.2](#_32-in-scope)     |
| FR-7  | Every language uses the same prefixes for LSP, tests, REPL, and debugging.                                           | Should   | [§3.2](#_32-in-scope)     |
| FR-8  | Agents can query and drive the running Emacs over MCP.                                                               | Should   | [§3.2](#_32-in-scope)     |
| FR-9  | Saving `myde.org` keeps the tangled elisp current, and no commit carries drift between them.                         | Must     | [§3.1](#_31-architecture) |
| FR-10 | The docs can be previewed and searched locally.                                                                      | Should   | [§3.2](#_32-in-scope)     |
| FR-11 | A push to `main` that changes the docs publishes them to GitHub Pages, and a failing docs check blocks the publish.  | Should   | [§3.2](#_32-in-scope)     |
| FR-12 | The config carries one version, which names its git tags and shows in the docs sidebar.                              | Should   | [§3.2](#_32-in-scope)     |

### 8.2 Non-Functional Requirements

| ID    | Requirement                                                                                     | Type          | Priority | Source                    |
|-------|---------------------------------------------------------------------------------------------------|---------------|----------|---------------------------|
| NFR-1 | Emacs 31.1 with native compilation is the minimum supported Emacs.                              | Compatibility | Must     | [§4](#_4-target-audience) |
| NFR-2 | The config runs on Linux and macOS.                                                             | Compatibility | Must     | [§4](#_4-target-audience) |
| NFR-3 | A warm start reaches `elpaca-after-init-hook` in about 4 s.                                     | Performance   | Should   | [§3.1](#_31-architecture) |
| NFR-4 | Only packages and `custom.el` live inside `user-emacs-directory`. State, data, and cache go to XDG directories. | Operability   | Must     | [§3.1](#_31-architecture) |
| NFR-5 | `user-lisp/myde.el` holds definitions only, so it loads in batch without side effects.          | Testability   | Must     | [§3.1](#_31-architecture) |
| NFR-6 | A failed package bootstrap cannot leave GC disabled or TRAMP broken.                            | Reliability   | Must     | [§5.2](#_52-failure-flow) |
| NFR-7 | The docs site fetches no third-party script or stylesheet at runtime.                           | Security      | Must     | [§3.1](#_31-architecture) |

### 8.3 Requirements Details

One subsection per requirement above, in full.

#### FR-1

A fresh clone starts Emacs without tangling `myde.org`.

- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-00](adr.md#adr-00)
- **Designed in:** [§1.1](tdd.md#_11-the-three-tangled-files)
- **Verified by:** [§2.2](qa.md#_22-integration-tests), [§2.4](qa.md#_24-enforcement-with-git-hooks)
- **Roadmap:** [RM-1](roadmap.md#rm-1)

#### FR-2

A section that needs a toolchain turns on when its binary is on `PATH` and stays off when it is not, with no toggle.

- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-02](adr.md#adr-02)
- **Designed in:** [§1.3](tdd.md#_13-binary-gates)
- **Verified by:** [§2.2](qa.md#_22-integration-tests)
- **Roadmap:** [RM-1](roadmap.md#rm-1), [RM-11](roadmap.md#rm-11), [RM-17](roadmap.md#rm-17)

#### FR-3

Binary gates see the login shell's `PATH`, including in macOS GUI and daemon sessions.

- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-02](adr.md#adr-02)
- **Designed in:** [§4.2](tdd.md#_42-shell-environment-and-platforms)
- **Verified by:** [§2.2](qa.md#_22-integration-tests)
- **Roadmap:** [RM-1](roadmap.md#rm-1)

#### FR-4

One daemon serves every frame, and `$EDITOR` reaches it.

- **Priority:** Must
- **Source:** [§5.1](#_51-happy-path)
- **Decided by:** [ADR-05](adr.md#adr-05)
- **Designed in:** [§1.4](tdd.md#_14-session-model)
- **Verified by:** [§2.1](qa.md#_21-unit-tests), [§3.1](qa.md#_31-daemon-frames-and-mcp)
- **Roadmap:** [RM-5](roadmap.md#rm-5)

#### FR-5

Tasks, thoughts, bookmarks, and notes can be captured, including from a browser.

- **Priority:** Must
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** [ADR-08](adr.md#adr-08)
- **Designed in:** [§2.3](tdd.md#_23-org-files-and-projects), [§4.5](tdd.md#_45-org-protocol-handlers)
- **Verified by:** [§2.1](qa.md#_21-unit-tests), [§3.2](qa.md#_32-browser-capture)
- **Roadmap:** [RM-4](roadmap.md#rm-4)

#### FR-6

Any directory with a `tasks.org` is a project, and its tasks appear in the agenda.

- **Priority:** Must
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** [ADR-08](adr.md#adr-08)
- **Designed in:** [§2.3](tdd.md#_23-org-files-and-projects)
- **Verified by:** [§2.1](qa.md#_21-unit-tests)
- **Roadmap:** [RM-4](roadmap.md#rm-4)

#### FR-7

Every language uses the same prefixes for LSP, tests, REPL, and debugging.

- **Priority:** Should
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** none
- **Designed in:** [§4.3](tdd.md#_43-language-servers-tests-repls-and-debuggers)
- **Verified by:** [§3.5](qa.md#_35-language-keys)
- **Roadmap:** [RM-10](roadmap.md#rm-10), [RM-13](roadmap.md#rm-13), [RM-14](roadmap.md#rm-14), [RM-15](roadmap.md#rm-15)

#### FR-8

Agents can query and drive the running Emacs over MCP.

- **Priority:** Should
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** [ADR-09](adr.md#adr-09)
- **Designed in:** [§3.1](tdd.md#_31-endpoints)
- **Verified by:** [§3.1](qa.md#_31-daemon-frames-and-mcp)
- **Roadmap:** [RM-6](roadmap.md#rm-6)

#### FR-9

Saving `myde.org` keeps the tangled elisp current, and no commit carries drift between them.

- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-00](adr.md#adr-00), [ADR-06](adr.md#adr-06)
- **Designed in:** [§5.1](tdd.md#_51-tangling-and-hooks)
- **Verified by:** [§2.1](qa.md#_21-unit-tests), [§2.4](qa.md#_24-enforcement-with-git-hooks)
- **Roadmap:** [RM-1](roadmap.md#rm-1), [RM-3](roadmap.md#rm-3), [RM-7](roadmap.md#rm-7)

#### FR-10

The docs can be previewed and searched locally.

- **Priority:** Should
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** [ADR-11](adr.md#adr-11)
- **Designed in:** [§5.3](tdd.md#_53-docs-site)
- **Verified by:** [§3.4](qa.md#_34-docs-site)
- **Roadmap:** [RM-8](roadmap.md#rm-8), [RM-9](roadmap.md#rm-9)

#### FR-11

A push to `main` that changes the docs publishes them to GitHub Pages, and a failing docs check blocks the publish.

- **Priority:** Should
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** [ADR-12](adr.md#adr-12)
- **Designed in:** [§5.4](tdd.md#_54-publishing-and-versions)
- **Verified by:** [§2.5](qa.md#_25-docs-checks)
- **Roadmap:** [RM-9](roadmap.md#rm-9), [RM-18](roadmap.md#rm-18)

#### FR-12

The config carries one version, which names its git tags and shows in the docs sidebar.

- **Priority:** Should
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** [ADR-13](adr.md#adr-13)
- **Designed in:** [§5.4](tdd.md#_54-publishing-and-versions)
- **Verified by:** [§3.4](qa.md#_34-docs-site)
- **Roadmap:** [RM-9](roadmap.md#rm-9), [RM-16](roadmap.md#rm-16)

#### NFR-1

Emacs 31.1 with native compilation is the minimum supported Emacs.

- **Type:** Compatibility
- **Priority:** Must
- **Source:** [§4](#_4-target-audience)
- **Decided by:** none
- **Designed in:** [§1.1](tdd.md#_11-the-three-tangled-files)
- **Verified by:** [§3.3](qa.md#_33-platforms-emacs-version-and-startup-state)
- **Roadmap:** [RM-1](roadmap.md#rm-1)

#### NFR-2

The config runs on Linux and macOS.

- **Type:** Compatibility
- **Priority:** Must
- **Source:** [§4](#_4-target-audience)
- **Decided by:** none
- **Designed in:** [§4.2](tdd.md#_42-shell-environment-and-platforms)
- **Verified by:** [§3.3](qa.md#_33-platforms-emacs-version-and-startup-state)
- **Roadmap:** none

#### NFR-3

A warm start reaches `elpaca-after-init-hook` in about 4 s.

- **Type:** Performance
- **Priority:** Should
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-01](adr.md#adr-01)
- **Designed in:** [§4.1](tdd.md#_41-elpaca)
- **Verified by:** [§2.2](qa.md#_22-integration-tests)
- **Roadmap:** [RM-1](roadmap.md#rm-1), [RM-11](roadmap.md#rm-11), [RM-17](roadmap.md#rm-17)

#### NFR-4

Only packages and `custom.el` live inside `user-emacs-directory`.
State, data, and cache go to XDG directories.

- **Type:** Operability
- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-04](adr.md#adr-04), [ADR-07](adr.md#adr-07)
- **Designed in:** [§2.1](tdd.md#_21-xdg-paths)
- **Verified by:** [§3.3](qa.md#_33-platforms-emacs-version-and-startup-state)
- **Roadmap:** [RM-15](roadmap.md#rm-15)

#### NFR-5

`user-lisp/myde.el` holds definitions only, so it loads in batch without side effects.

- **Type:** Testability
- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-03](adr.md#adr-03)
- **Designed in:** [§1.1](tdd.md#_11-the-three-tangled-files)
- **Verified by:** [§2.1](qa.md#_21-unit-tests)
- **Roadmap:** [RM-2](roadmap.md#rm-2)

#### NFR-6

A failed package bootstrap cannot leave GC disabled or TRAMP broken.

- **Type:** Reliability
- **Priority:** Must
- **Source:** [§5.2](#_52-failure-flow)
- **Decided by:** [ADR-10](adr.md#adr-10)
- **Designed in:** [§5.2](tdd.md#_52-startup-failure-containment)
- **Verified by:** [§3.3](qa.md#_33-platforms-emacs-version-and-startup-state)
- **Roadmap:** none

#### NFR-7

The docs site fetches no third-party script or stylesheet at runtime.

- **Type:** Security
- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-11](adr.md#adr-11), [ADR-12](adr.md#adr-12)
- **Designed in:** [§5.3](tdd.md#_53-docs-site)
- **Verified by:** [§2.5](qa.md#_25-docs-checks)
- **Roadmap:** [RM-9](roadmap.md#rm-9)

## 9. Stakeholders

| Name        | Role                |
|-------------|---------------------|
| Allen Gooch | Owner and sole user |

## 10. References

- [Root README](https://github.com/mojochao/myde.emacs/blob/main/README.md)
- [AGENTS.md](https://github.com/mojochao/myde.emacs/blob/main/.agents/AGENTS.md)
- [2026-05-11 Projectile to project.el design](superpowers/specs/2026-05-11-projectile-to-project-design.md)
- [2026-08-05 Org workflow design](superpowers/specs/2026-08-05-org-workflow-design.md)
- [2026-09-15 Three-file literate config design](superpowers/specs/2026-09-15-three-file-literate-config-design.md)
- [2026-09-17 Library config split design](superpowers/specs/2026-09-17-library-config-split-design.md)
- [2026-09-27 Docs schema design](superpowers/specs/2026-09-27-docs-schema-design.md)
