# Technical Design

## 1. Architecture Overview

Three tangled files run every Emacs session, and none of them is edited by hand.
[ADR-00](adr.md#adr-00) fixed `myde.org` as the one edited source, tangled into the three files below.
Startup activates them in a fixed order, gated section by section on binary presence, against one shared daemon.

| Part                    | Covers                                       |
|--------------------------|-----------------------------------------------|
| The three tangled files | What is generated from `myde.org`, and why    |
| Startup sequence        | The order Emacs loads the tangled files in    |
| Binary gates            | How a section turns on or off                 |
| Session model           | The daemon and its client frames              |

### 1.1 The three tangled files

`myde.org` is the only file edited by hand.
It tangles into three committed files.

| File                | Role                                                                                                                                         |
|---------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| `early-init.el`     | Runs before `init.el` and before startup.el creates directories. GC and `file-name-handler-alist` suppression, eln-cache redirection, frame defaults, `package-enable-at-startup nil`. |
| `init.el`           | Installs elpaca, requires `myde`, then every `use-package` form, binary gate, and variable assignment, in load order.                        |
| `user-lisp/myde.el` | Definitions and declarations only, the forms `mise run forms` allows, with no side effects.                    |

The tangled outputs are committed, so a fresh clone starts Emacs without tangling anything ([FR-1](prd.md#fr-1)).
Emacs 31.1 is a hard floor for this design ([NFR-1](prd.md#nfr-1)).
`user-lisp-directory` does not exist before it, and `init.el` needs that variable to load `myde.el`.
`mise run forms` asserts that `myde.el` holds definitions only.
That is what lets it load in batch with no running Emacs and stay testable under ERT ([NFR-5](prd.md#nfr-5)).

### 1.2 Startup sequence

Startup runs in four steps.

1. `early-init.el` runs first.
2. `init.el` bootstraps elpaca, then `(require 'myde)` loads every definition in `user-lisp/myde.el`. `use-package` forms queue elpaca orders as the file is read, and the queue drains after `after-init-hook`. `exec-path-from-shell` runs synchronously with `:ensure (:wait t)`, so every binary gate that follows it sees a complete `exec-path` during init.
3. Activation blocks run in section order: `core-base`, `Environment`, the remaining `core-*` sections, then `ai-*`, `auth-*`, `data-*`, `containers-*`, `prog-*`, `text-*`, `ebook-*`.
   This order is known-working and is not reordered for aesthetics.
4. `elpaca-after-init-hook` fires once every queued package is activated.
   Startup global modes hang off this hook.

### 1.3 Binary gates

A section that needs a toolchain wraps its whole `use-package` form in `(when (executable-find "<binary>") ...)`.
Installing the binary turns the section on at the next start, and removing it turns the section off, with no toggle to maintain ([FR-2](prd.md#fr-2)).

| Binary    | Section                              | Binary     | Section                 |
|-----------|----------------------------------------|------------|---------------------------|
| `go`      | `prog-go`                            | `clangd`   | `prog-cpp`              |
| `cargo`   | `prog-rust`                          | `fish`     | `prog-fish`             |
| `zig`     | `prog-zig`                           | `nu`       | `prog-nushell`          |
| `lua`     | `prog-lua`                           | `sbcl`     | `prog-clisp`            |
| `ruby`    | `prog-ruby`                          | `guile`    | `prog-scheme`           |
| `python3` | `prog-python`                        | `clojure`  | `prog-clojure`          |
| `node`    | `prog-javascript`, `prog-typescript` | `erl`      | `prog-erlang`           |
| `elixir`  | `prog-elixir`                        | `pdftoppm` | `ebook-pdf`             |
| `op`      | `auth-1password`                     | `kubectl`  | `containers-kubernetes` |
| `claude`  | `ai-claude`                          |            |                         |

elpaca queues a package order when a `use-package` form is expanded, before `:if` or `:when` runs.
The gate has to wrap the whole form, or a keyword inside it cannot prevent a clone ([ADR-02](adr.md#adr-02)).
`core-*`, `ai-base`, `ai-gptel`, `ai-agents`, `ai-mcp`, `data-*`, `prog-base`, `prog-bash`, `prog-elisp`, `text-*`, and `ebook-epub` carry no gate, since editing modes need no toolchain.

### 1.4 Session model

One daemon serves every frame ([ADR-05](adr.md#adr-05)).
A launchd agent starts `emacs --fg-daemon` at login, and every GUI frame comes from `emacsclient -c` against that process.
`$EDITOR` and `$VISUAL` already point at `emacsclient`, so every entry point reaches the same daemon ([FR-4](prd.md#fr-4)).
`~/Applications/Emacsclient.app` wraps `emacsclient -c -n -a ""` for the Dock, carrying Emacs' own icon, so the Dock tile looks like Emacs without starting a second process.
Dashboard is `:defer t` and opened on demand with `M-x dashboard-open`.
A client frame opens on `*scratch*` instead of a startup screen.
Never launch Emacs.app alongside the daemon.
Two processes on this config fight over the server socket, the MCP socket, and the XDG state files.

## 2. Data Model and Persistence

The config's persistent state splits three ways: XDG-routed files, elpaca packages, and org files.
A few singletons are shared by every Emacs process on this config.

### 2.1 XDG paths

Only packages and `custom.el` live inside `user-emacs-directory` ([ADR-07](adr.md#adr-07)).
Everything else is routed through the built-in `xdg.el` library ([NFR-4](prd.md#nfr-4)).

| Kind                                                     | Path                     |
|-----------------------------------------------------------|--------------------------|
| State (recentf, places, history, tramp, auto-save-list)  | `$XDG_STATE_HOME/emacs/` |
| Data (transient, tree-sitter)                            | `$XDG_DATA_HOME/emacs/`  |
| Cache (eln-cache, url)                                   | `$XDG_CACHE_HOME/emacs/` |
| Packages (elpaca)                                        | `./elpaca/` (repo root)  |

Two exceptions run ahead of the `core-base` section that sets the rest.
`auto-save-list-file-prefix` is set in `early-init.el`, because Emacs creates that directory before `init.el` runs.
Native compilation cache redirection also happens in `early-init.el`, before any compilation occurs.

### 2.2 Packages

elpaca keeps its own tree at `./elpaca/` under the repo root, gitignored.

| Directory  | Holds                                             |
|------------|-----------------------------------------------------|
| `sources/` | Cloned package repositories                       |
| `builds/`  | Symlinks into `sources/`, assembled per package   |
| `cache/`   | elpaca's own metadata                             |

`M-x elpaca-log` shows build status, and `M-x elpaca-manager` and `M-x elpaca-update-all` manage updates.
A recursive `grep` over `builds/` misses matches, since it holds symlinks rather than files.
Search `sources/` instead.

### 2.3 Org files and projects

`~/org/` holds `inbox.org`, `archive/`, and `notes/`, created on first start by `myde-org-ensure-tree`.
`inbox.org` is the single capture sink for tasks, thoughts, and bookmarks, refiled out into project files later ([FR-5](prd.md#fr-5)).

A project is any directory containing a `tasks.org`, at any depth and under any name ([ADR-08](adr.md#adr-08)).
`myde-org-project-root` finds it with `locate-dominating-file`, searching upward from `default-directory`, with no fixed root and no naming convention ([FR-6](prd.md#fr-6)).
`myde-org-code-directory` (`~/devel/projects/` by default) is scanned only to build `org-agenda-files`.
A project outside it still works for capture and visiting.
It just is not in the agenda.

`myde-org-find-task-files` prunes dot-directories and `node_modules` while it scans.
Pruning cuts a real scan from roughly 16ms to under 1ms by skipping `.git` internals, and keeps archived projects parked under `.ATTIC/` out of the agenda.
A missing `#+category:` is a real risk here, not decoration.
Org derives it from the file name, and every project's file is named `tasks.org`.
An omitted category would make every project report the same category, `tasks`.
`myde-org-project-tasks-template` sets `#+category:` and `#+filetags:` explicitly, sanitizing the project name first, since `org-tag-re` excludes `-` and `.`.

### 2.4 Singleton state

Three singletons hold last-writer-wins state.
The `server` socket picks one winner.
When a second Emacs starts, the daemon keeps the socket, and the second process silently skips `server-start`.
`$EDITOR` then opens files in a process with no visible frame.
The `mcp-server` Unix socket under `$XDG_CACHE_HOME/emacs/` is fixed, not per-process, so only one Emacs can hold it at a time.
The XDG state files (`recentf.eld`, `places.eld`, `history`) are last-writer-wins between whichever process touches them last.

## 3. API Contract

The "API" here is what other programs call: MCP tools, `org-protocol://` URIs, and `emacsclient`.

### 3.1 Endpoints

The `ai-mcp` section runs an MCP server inside Emacs on a fixed Unix socket, `$XDG_CACHE_HOME/emacs/emacs-mcp-server.sock` ([ADR-09](adr.md#adr-09)).
A `socat` bridge, registered once with `claude mcp add`, connects agents to that socket, exposing `eval-elisp`, diagnostics, and Org tools so agents can query and drive the running session ([FR-8](prd.md#fr-8)).
Two `org-protocol://capture` templates arrive over the same daemon.
`b` files a tagged bookmark into `inbox.org`, and `N` routes into a denote note under `~/org/notes/`, seeding the title from the page.

### 3.2 Error responses

`mcp-server-socket-conflict-resolution` is `error`, not `force` or `warn`.
A stale socket left by a dead daemon is reclaimed before that setting is consulted.
A second live Emacs on this config leaves the daemon's own socket alone and starts with no MCP server.
A bridge that reports `CONNECTION_CLOSED` means the server side died.
Restart it in the daemon:

```shell
emacsclient --eval '(progn (ignore-errors (mcp-server-stop)) (mcp-server-start-unix))'
```

Then reconnect with `/mcp`.

## 4. Integration Layer

These subsections cover what the config integrates with: elpaca, the shell environment, language tooling, tree-sitter, and the OS URI handlers.

### 4.1 elpaca

elpaca replaced package.el ([ADR-01](adr.md#adr-01)).
A `use-package` form queues its order as `init.el` is read, and the queue drains after `after-init-hook`, not during the form's own evaluation.
One order runs synchronously instead. `exec-path-from-shell` carries `:ensure (:wait t)`, so the binary gates that follow it see a complete `exec-path` during init.
Every package needs exactly one ensuring form.
A duplicate order makes elpaca 0.12 abort init.
Any additional `use-package` form for the same package must say `:ensure nil`.
A warm start with a populated `elpaca/` reaches `elpaca-after-init-hook` in roughly 4 seconds, against roughly 7 seconds for the package.el config it replaced ([NFR-3](prd.md#nfr-3)).
A cold start from an empty `elpaca/` clones and builds every package instead, and takes minutes.

### 4.2 Shell environment and platforms

`exec-path-from-shell-initialize` runs synchronously during init, with `exec-path-from-shell-arguments '("-l")`, because GUI apps on macOS do not inherit the login shell's `PATH` ([FR-3](prd.md#fr-3)).
Every binary gate depends on it having run first.
This config targets both Linux and macOS ([NFR-2](prd.md#nfr-2)), and platform-specific code is guarded with `(when (memq window-system '(mac ns)) ...)` or `(string= system-type "darwin")`.
Homebrew paths differ by architecture, `/usr/local/bin` on Intel against `/opt/homebrew/bin` on Apple Silicon, so a gated section always resolves a binary with `executable-find` rather than a hardcoded path.
macOS dired needs GNU `ls` for `--group-directories-first`, resolved the same way through `(executable-find "gls")`.
Native compilation fails for files loaded before `exec-path-from-shell` runs, elpaca's own files among them.
Under the bare GUI `PATH`, libgccjit cannot find the Homebrew gcc driver and reports "error invoking gcc driver".
That failure is a warning, not a fatal one, and those files run byte-compiled until a start with a full `PATH` compiles them.

### 4.3 Language servers, tests, REPLs, and debuggers

Every language section shares four keybinding prefixes: `C-c e` for eglot, `C-c t` for tests, `C-c i` for the REPL, and `C-c d` for dape ([FR-7](prd.md#fr-7)).
`myde-eglot-add-workspace-config`, in `core-projects`, upserts LSP workspace configuration for a server key without clobbering another section's settings.
Nothing assigns `eglot-workspace-configuration` directly.
`dape` binds `C-c d d` through `C-c d q` globally, for start, continue, step, and breakpoint commands.
`C-c d l` runs `dape-restart`, which restarts a live session or re-runs the last configuration when none is live.

`myde.org` moves `mix.el`'s command map from `C-c d` to `C-c x` in `mix-minor-mode`, so the dape keys win in Elixir buffers ([RM-10](roadmap.md#rm-10)).

### 4.4 Tree-sitter

`treesit-auto` remaps a major mode to its tree-sitter variant when the grammar is installed, and falls back otherwise.
`myde-treesit-install-language-grammar-advice` redirects every grammar install, including `treesit-auto`'s own, to `$XDG_DATA_HOME/emacs/tree-sitter/` instead of the default `user-emacs-directory/tree-sitter/`.
`myde-treesit-auto-setup` builds `major-mode-remap-alist` once on `elpaca-after-init-hook`, rather than letting `global-treesit-auto-mode` rebuild and re-probe every grammar on each file visit.

### 4.5 org-protocol handlers

The browser sends an `org-protocol://` URI, and the OS has to route it to `emacsclient` ([FR-5](prd.md#fr-5)).
On Linux, `mise run install-xdg` installs the desktop file already checked into `etc/org-protocol.desktop`.
On macOS, `mise run install-macos` builds `~/Applications/OrgProtocol.app` with `osacompile`, registers the `org-protocol` URL scheme in its `Info.plist` with `plutil`, and re-signs the bundle with `codesign`.
AppleScript is required there, not a stylistic choice. macOS delivers URI activations as Apple Events, and a plain shell script inside a bundle never receives the URL.
The bundle must be re-signed after `Info.plist` is edited, since `osacompile`'s ad-hoc signature does not survive the edit.
Without that step, `codesign -v` reports an invalid `Info.plist`.

## 5. Security, Deployment and Operations

Four concerns keep the tangled elisp trustworthy and the docs site reachable: tangling itself, startup failure containment, the docs site, and publishing.

### 5.1 Tangling and hooks

Three layers re-tangle `myde.org`, each catching a different editor ([ADR-06](adr.md#adr-06)).
In Emacs, `myde-tangle-source-on-save` sits on the global `after-save-hook` and re-tangles on every save.
For Claude Code, `.claude/settings.json` runs `scripts/claude-tangle-hook.sh`. `tangle` fires on PostToolUse after an edit to `myde.org`, and `guard` fires on PreToolUse to deny any edit to `early-init.el`, `init.el`, or `user-lisp/myde.el`.
The deny matters more than the tangle.
An agent that edited a tangled file directly would have the change silently discarded at the next tangle, with the loss only surfacing at pre-push.
hk's pre-commit hook re-tangles rather than rejecting.
It stashes unstaged changes, runs `mise run tangle`, stages the three tangled files, then runs `mise run forms` and `mise run test`.
pre-push runs the same checks without rewriting anything, as a backstop for `--no-verify` ([FR-9](prd.md#fr-9)).

### 5.2 Startup failure containment

GC suppression and `file-name-handler-alist` clearing are restored on `emacs-startup-hook` in `early-init.el`, never on `elpaca-after-init-hook` ([ADR-10](adr.md#adr-10)).
That hook fires even when the elpaca bootstrap fails outright, such as a cold clone with no network or no `git`.
A failed elpaca bootstrap therefore cannot leave a session with GC disabled or TRAMP broken ([NFR-6](prd.md#nfr-6)).
Every other startup hook that depends on a loaded package uses `elpaca-after-init-hook` instead, since a `use-package` body under elpaca runs after `emacs-startup-hook` has already fired.

### 5.3 Docs site

The docs site is served by a vendored docsify 4.13.1, not a CDN copy ([ADR-11](adr.md#adr-11)).
`docs/vendor/` holds docsify, its search plugin, docsify-themeable's simple-dark CSS, the Catppuccin Frappé mauve theme, and the Prism grammars the docs use, each pinned in `scripts/vendor_docs.py`.
The Catppuccin theme's remote `@import` is rewritten to a vendored file, so the published site fetches no third-party script or stylesheet at runtime ([NFR-7](prd.md#nfr-7)).
`docs/index.html` sets `noEmoji: true`, and fetches the sidebar's version string with an explicit `Accept: text/plain` header, so docsify-cli's dev server does not answer with `index.html` instead.
`vendor_docs.py --check` runs offline.
It scans `docs/index.html` and `docs/vendor/*.css` for a remaining remote `@import`, `url()`, `src`, or `href`, and exits 1 on any hit.
`mise run docs` serves `docs/` natively with `docsify serve`, for local preview ([FR-10](prd.md#fr-10)).
`mise run docs-up` serves the same site from a container, `docs.compose.yaml` mounting the repo root read-only so the `docs/VERSION` symlink resolves inside it.
`mise run docs-search` queries a qmd index, built once with `python3 scripts/qmd.py init`.

### 5.4 Publishing and versions

`.github/workflows/docs.yml` runs two jobs on a push to `main` that touches `docs/**`, `VERSION`, `scripts/**`, `.markdownlint*`, `mise.toml`, or the workflow file, and on `workflow_dispatch` ([ADR-12](adr.md#adr-12)).
`check` (`ubuntu-24.04`) installs `npm:markdownlint-cli` through mise and runs `mise run docs-check`.
`deploy` needs `check` to pass, carries `pages: write` and `id-token: write`, and runs `actions/configure-pages`, `actions/upload-pages-artifact` with `path: docs`, and `actions/deploy-pages` into the `github-pages` environment.
A failing `docs-check` blocks the publish instead of shipping broken links or lint violations ([FR-11](prd.md#fr-11)).
The published site is `https://mojochao.github.io/myde.emacs/`.

`docs/VERSION` is a relative symlink to `../VERSION`, so one file names the version everywhere the site is served ([ADR-13](adr.md#adr-13)).
`actions/upload-pages-artifact` tars its artifact with `--dereference --hard-dereference`, so the Pages artifact holds the real file rather than a dangling symlink.
Between releases, the sidebar shows the last released version, since `VERSION` only changes as part of a release ([FR-12](prd.md#fr-12)).

The release flow: edit `VERSION`, move `Unreleased` to that version and `Now` items to `Shipped` in the docs, and fix the `Shipped` links `mise run docs-check` reports.
Then commit and run `mise run tag`.
`mise run tag` refuses unless `docs/changelog.md` has a `## <VERSION> - <date>` heading, then creates the annotated tag `v<VERSION>`.
Pushing the tag runs `.github/workflows/release.yml`, which checks that the tag matches `VERSION` at its commit and runs `mise run release`.
That publishes the GitHub release, its notes cut from the version's changelog section by `scripts/release_notes.py`, with relative doc links rewritten to the Pages site.

## 6. Testing Strategy

Two checks stand in for one build step, and each catches a different kind of failure.
ERT tests under `tests/` cover logic that fails silently, and the probe covers startup state that only a running daemon shows.
See [Quality Assurance](qa.md) for both, and for the docs checks that gate them.

## 7. Open Questions

There are no open questions at present.
