# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Tasks live in `mise.toml`; `mise tasks` lists them all.

```shell
mise run init             # Set up this repo on a new machine (link + hk install)
mise run link             # Symlink repo into ~/.config/emacs
mise run unlink           # Remove the symlink
mise run tangle           # Regenerate early-init.el, init.el, user-lisp/myde.el from myde.org
mise run forms            # Assert user-lisp/myde.el contains only definitions
mise run check            # Tangle, then fail if the committed elisp differs from myde.org
mise run test             # Run the ERT checks under tests/ in batch mode
mise run probe <report>   # Boot this config as a throwaway daemon and report its state
mise run docs             # Serve docs/ as a live-reloading site on localhost:3000
mise run docs-up          # Serve docs/ from a container on localhost:3000 (docs-down stops it)
mise run docs-search <q>  # Search docs/ with qmd; index once with `mise exec -- python3 scripts/qmd.py init`
mise run docs-check       # Check docs/ links, traceability, vendored assets, and markdown lint
mise run docs-vendor      # Re-fetch the pinned docsify assets into docs/vendor/
mise run tag              # Tag HEAD v<VERSION> once docs/changelog.md has that release
mise run export           # Export myde.org to build/myde.tex and build/myde.pdf
mise run install-xdg      # Register the org-protocol:// URI handler (Linux)
mise run install-macos    # Register the org-protocol:// URI handler (macOS)
```

On a fresh clone run `mise trust` first — mise refuses to read an untrusted
config, and trust is machine-local state, so it is needed on each machine.

Git hooks are hk's, defined in `hk.pkl` and installed by `mise run init`.
`hk install` uses git's config-based hooks (2.54+), so `.git/hooks` stays
empty. **pre-commit re-tangles rather than rejecting**: it runs `mise run
tangle` as a fix step and stages the three tangled files, so `myde.org` and its
output cannot drift apart in a commit. It then runs `forms` and `test`.
pre-push verifies without rewriting anything, as a backstop for
`--no-verify`. `hk check` and `hk fix` run the same steps by hand.

Two more layers tangle before the commit ever happens. In Emacs,
`myde-tangle-source-on-save` is on the global `after-save-hook` and re-tangles
whenever `myde.org` is saved, so the elisp on disk never lags the buffer you
just edited. For Claude Code, `.claude/settings.json` runs
`scripts/claude-tangle-hook.sh`: `tangle` on PostToolUse after an agent edits
`myde.org`, and `guard` on PreToolUse to **deny** edits to `early-init.el`,
`init.el`, and `user-lisp/myde.el`. The deny matters more than the tangle -- an
agent that edits generated elisp writes a change the next tangle silently
discards, and the loss only surfaces at pre-push. The script identifies the
repo by finding `myde.org` where the file's root should be, so it is a no-op
elsewhere and the `~/.config/emacs` symlink resolves like the clone.

There is no build or lint step. Two things stand in for one, and they check different
kinds of failure.

`mise run test` runs ERT over `tests/`, covering logic that fails *silently* rather than
loudly — an invalid `#+filetags:` value that makes tag search return nothing, a missing
`#+category:` that makes every project's tasks file show up in the agenda as "tasks", an
unpruned directory scan that walks `.git` internals. The tests load
`user-lisp/myde.el` directly, which works only because that file is definitions with no
side effects; keep it that way (`mise run forms`) and the library stays testable in batch.

The probe covers the other kind: it
boots a config directory as an isolated throwaway daemon (unique socket, `PATH` stripped
to `/usr/bin:/bin`, private `XDG_STATE_HOME`) and writes a report of the declared
`use-package` forms, the global modes enabled at startup, init time, and startup errors.
Run it before and after a change and diff the `declared:` and `mode:` lines. A declared
package that disappears or a mode that flips to `off` is a regression.

## Architecture

MyDE is a single literate Emacs configuration targeting **Emacs 31.1+ compiled with
native-compile support**. 31.1 is a hard floor: `user-lisp-directory` does not exist
before it. The repo is symlinked to `~/.config/emacs` (`user-emacs-directory`).

### Files

| File                | Role                                                                                                                                                                                                                                                                                        |
|---------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `myde.org`          | **The only file edited by hand.** Three top-level subtrees, one per tangled file, each setting its target with a `:header-args:emacs-lisp: :tangle …` property.                                                                                                                             |
| `early-init.el`     | Tangled from `* Early Init`. Runs before `init.el` and before startup.el creates directories: GC and `file-name-handler-alist` suppression (restored on `emacs-startup-hook`), eln-cache redirection to `$XDG_CACHE_HOME/emacs/eln-cache`, frame defaults, `package-enable-at-startup nil`. |
| `init.el`           | Tangled from `* Bootstrap` and from the activation blocks of `* Configuration`. Installs elpaca, `(require 'myde)`, then every `use-package` form, binary gate, and variable assignment in load order.                                                                                      |
| `user-lisp/myde.el` | Tangled from the definition blocks of `* Configuration`. Definitions only — `defun`, `defvar`, `defcustom`, `defconst`, `define-derived-mode`, `define-minor-mode`. No side effects, asserted by `mise run forms`.                                                                          |

Tangled outputs are committed, so a fresh clone works without tangling and startup never
loads org. **Never edit the three `.el` files directly** — `mise run tangle` overwrites them.

### Startup sequence

1. `early-init.el`.
2. `init.el` bootstraps elpaca, then `(require 'myde)` loads every definition in
   `user-lisp/myde.el`. `use-package` forms in `init.el` queue elpaca orders as the file is
   read; the queue is processed after `after-init-hook`. One order is processed
   synchronously: `exec-path-from-shell` is `:ensure (:wait t)` so the binary gates that
   follow it see a complete `exec-path` during init.
3. `init.el` activation blocks run in section order: `core-base`, `Environment`, the
   remaining `core-*` sections, then `ai-*`, `auth-*`, `data-*`, `containers-*`, `prog-*`,
   `text-*`, `ebook-*`. This order is known-working; do not reorder for aesthetics.
4. `elpaca-after-init-hook` runs once every queued package is activated. Startup global
   modes hang off this hook (see *Startup hooks*).

**Performance:** warm start with a populated `elpaca/` reaches `elpaca-after-init-hook`
in roughly 4 s in the probe daemon, versus ~7 s for the package.el config it replaced.
A cold start from an empty `elpaca/` clones and builds every package and takes minutes.

### Section enablement: presence is intent

There are no module toggles, no override list, and no `custom.el` entries for modules.
A section that needs a toolchain is wrapped in `(when (executable-find "<binary>") …)`.
Installing the binary enables the section on the next start; removing it disables it.

| Binary    | Section                              | Binary     | Section                 |
|-----------|--------------------------------------|------------|-------------------------|
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

Everything else — `core-*`, `ai-base`, `ai-gptel`, `ai-agents`, `ai-mcp`, `data-*`,
`prog-base`, `prog-bash`, `prog-elisp`, `text-*`, `ebook-epub` — is unconditional: editing
modes need no toolchain. Runtime and tooling presence differ, so a gated section may
still contain inner `:if (executable-find "<lsp-server>")` guards on LSP or debugger forms.

**The gate must wrap the whole `use-package` form.** elpaca queues the order when the
form is *expanded*, before `:if`/`:when` is evaluated, so a keyword inside the form cannot
prevent a clone.

Gates live in `init.el` only. `myde.el` defines its functions unconditionally, so a
`myde-prog-go-*` function exists whether or not `go` is installed. Nothing calls it
unless the gate passed.

### Package management (elpaca)

- `use-package-always-ensure t` is set in `init.el`. Third-party forms need no `:ensure`;
  **every built-in form must say `:ensure nil`**, or elpaca tries to clone it.
- Git-only packages take a recipe plist: `:ensure (:host github :repo "owner/name")`.
  Add `:files (:defaults "subdir")` when a package loads files outside elpaca's default
  set — `mcp-server` needs its `tools/` directory this way.
- **One ensuring form per package.** Any additional `use-package` form for the same
  package must say `:ensure nil`. A duplicate order makes elpaca 0.12 abort init: it
  `warn`s about the duplicate and then treats the warning's return value as an order
  struct. A secondary form that is not otherwise deferred (`:hook`, `:bind`, `:mode`, …)
  also needs `:after <package>`, because under elpaca the package is not on `load-path`
  yet when the form evaluates during init.
- Packages live in `./elpaca/` (`sources/`, `builds/`, `cache/`) at the repo root,
  gitignored, for inspection and agent access. `M-x elpaca-log` shows build status;
  `M-x elpaca-manager` and `M-x elpaca-update-all` manage updates.
- MELPA recipes that clone from a dead host need a mirror recipe: `paredit` uses
  `(:host github :repo "emacsmirror/paredit")` because `paredit.org` no longer resolves.

#### A package with no `Package-Requires` will never byte-compile

`elpaca-build-compile` assembles the byte-compilation `load-path` from the order's
declared dependencies alone — `elpaca-dependencies`, read out of `Package-Requires`
or a `-pkg.el`. A package that declares nothing gets only its own build directory,
so any `require` of another package fails, the compile errors, and no `.elc` is
written. Emacs then loads the `.el`, and a source file with no `lexical-binding`
cookie warns on every startup. `elpaca-rebuild` uses the same load-path and cannot
help. `ob-zig` is the case here: it requires `zig-mode` and declares nothing. The
options are to live with the warning, pin a fork that adds the header, or drop the
package.

#### A package that will not install may be a half-finished clone

elpaca clones with `--filter=tree:0 --no-checkout`, then completes the checkout by
fetching trees and blobs back on demand. When a git host flakes during that second
phase, the source directory is left holding `.git` and no working tree. elpaca never
recovers on its own: the directory exists, so it will not re-clone, and the order fails
on every start. Codeberg-hosted packages are the usual victims — this has hit `geiser`,
`eat`, and `visual-fill-column`.

Find them by looking for source directories with no elisp, searching **recursively**:

```shell
for d in elpaca/sources/*/; do
  [ "$(find "$d" -name '*.el' -not -path '*/.git/*' | wc -l)" = 0 ] && echo "$d"
done
```

A shallow `*.el` check false-positives on `geiser` and `treemacs`, which nest their
elisp in subdirectories. Ignore a missing `elpaca/builds/<name>` on its own: most such
cases are repo-vs-package name mismatches (`emacs-async` → `async`, `otp` → `erlang`),
not failures.

Repair one by completing the checkout and rebuilding. Check the branch name first —
some repos use `main`, some `master`:

```shell
git -C elpaca/sources/<pkg> checkout "$(git -C elpaca/sources/<pkg> symbolic-ref --short HEAD)"
```

```elisp
(elpaca-rebuild '<pkg>)
(elpaca-process-queues)   ;; an already-initialised session will not drain the queue on its own
```

`elpaca-rebuild` alone only queues the order. In a running Emacs the queue sits idle
until `elpaca-process-queues` is called, which looks identical to the original failure.
An order stuck at `failed` with a healthy source directory is often just stale status —
the same rebuild clears it.

Useful accessors when inspecting state: `(elpaca-get 'pkg)` returns the order struct,
read with `elpaca<-status`, `elpaca<-builtp`, `elpaca<-build-dir`. There is no
`elpaca<-log`, and `elpaca--queued` is a function, not a variable.

### Startup hooks

Inside a `use-package` form use `:hook (elpaca-after-init . fn)` — **never** `after-init`
or `emacs-startup`. Under elpaca the form's body runs after those hooks have already
fired, so the mode would stay silently off. Top-level `add-hook` calls in `init.el` that
must wait for packages use `elpaca-after-init-hook` as well. There is no exception.

GC and `file-name-handler-alist` restoration stay on `emacs-startup-hook` in
`early-init.el`, not `elpaca-after-init-hook`, so a failed elpaca bootstrap cannot leave
a session with GC disabled and TRAMP broken.

### Session model: one daemon, many client frames

`~/Library/LaunchAgents/gnu.emacs.daemon.plist` starts `emacs --fg-daemon` at login
(`RunAtLoad` + `KeepAlive`), and that daemon is meant to be the **only** Emacs process.
GUI frames come from `emacsclient -c`; `~/Applications/Emacsclient.app` is a two-line
shell-script bundle wrapping `emacsclient -c -n -a ""` for the Dock — it carries Emacs'
own `Emacs.icns`, so the Dock tile looks like Emacs but never starts a second process.
The Dock's persistent-apps entry must point at it, not at `/Applications/Emacs.app`.
`$EDITOR` and `$VISUAL` are already `emacsclient`, so they reach the same process.

**Never launch Emacs.app alongside the daemon.** Two processes on this config fight over
three singletons: the `server` socket (the daemon wins, so the app silently skips
`server-start` and `$EDITOR` opens files in a process with no visible frame), the
`mcp-server` Unix socket under `$XDG_CACHE_HOME/emacs/`, and the XDG state files
(`recentf.eld`, `places.eld`, `history`) which are last-writer-wins.

Restart the daemon after a config change:

```shell
launchctl kickstart -k gui/$(id -u)/gnu.emacs.daemon
```

Verify through `emacsclient`; it always talks to the daemon. Anything that only exists in
a window system frame has to be confirmed by creating one.

Dashboard follows from this, by not being a startup screen at all. It is `:defer t` and
opened on demand with `M-x dashboard-open`; a client frame gets `*scratch*`.

`initial-buffer-choice` is not usable here. `elpaca-log-initial-queues` overwrites it
with elpaca's own function whenever any order is unbuilt or has failed, capturing the
previous value and restoring that capture on `elpaca-after-init-hook`. Dashboard's
`:config` runs during the same queue processing, so when the capture happens first the
restored value is `nil` and frames silently open on `*scratch*` — intermittently, only
on the starts where elpaca had work to do. Setting it also made `command-line-1` call
the function during frameless daemon startup, the render the daemon is supposed to
avoid, and charged every `emacsclient -c` frame for a full dashboard draw.

### Editing workflow

1. Edit `myde.org`. A section's `***` heading holds up to two blocks: definitions,
   carrying `:tangle user-lisp/myde.el`, and activation, inheriting `:tangle init.el`.
   Put `defun`/`defvar` in the first and `use-package`/`setq`/`add-hook` in the second.
   Wrap the activation block's body in a binary gate if the tool needs a toolchain.
2. `mise run tangle`. Then `mise run probe <report>` and diff its
   `declared:`/`mode:` lines against a report taken before the change.
3. Commit. The pre-commit hook tangles and stages the elisp for you; run `mise run
   check` first if you want to see the result before it is staged.

### XDG compliance

All state, data, and cache is stored outside `user-emacs-directory` via the built-in `xdg.el` library:

| Kind                                                    | Path                     |
|---------------------------------------------------------|--------------------------|
| State (recentf, places, history, tramp, auto-save-list) | `$XDG_STATE_HOME/emacs/` |
| Data (transient, tree-sitter)                           | `$XDG_DATA_HOME/emacs/`  |
| Cache (eln-cache, url)                                  | `$XDG_CACHE_HOME/emacs/` |
| Packages (elpaca)                                       | `./elpaca/` (repo root)  |

XDG paths are set in the `core-base` section of `init.el`. Exceptions:
- `auto-save-list-file-prefix` must be set in `early-init.el` because Emacs creates the directory before init.el runs.
- Native compilation cache (`eln-cache`) redirection must happen in `early-init.el` before any compilation occurs.

### Key conventions

- `:init` blocks set variables *before* package activation; `:config` blocks run side effects after.
- Multiple `use-package` blocks for the same package accumulate — idiomatic here, subject to the one-ensuring-form rule above.
- Language sections share keybinding prefixes: `C-c e` (eglot/LSP), `C-c t` (tests), `C-c i` (REPL), `C-c d` (dape/debug).
- Org lives under `C-c o`: `a` agenda, `c` capture, `p` visit the current project's
  `tasks.org` (creating one if there is none above point), `P` always prompt to create
  one, `t` tag cloud, `T` multi-tag search, `n …` denote. A project is any directory
  containing a `tasks.org`; there is no fixed root and no naming convention.
- `myde-eglot-add-workspace-config` (in the `core-projects` section) upserts LSP workspace config without clobbering other sections' settings. Never assign `eglot-workspace-configuration` directly.
- `myde-register-snippets` (in the `core-snippets` section) registers a flat snippet directory for a major mode and is safe to call before yasnippet loads. Snippets live under `snippets/<language>/`; assets under `etc/`.
- **Never use lambdas as hook functions.** Define a named function (e.g. `myde-foo-mode-setup`) in the same section and reference it by name.
- `user-lisp/` sits at `load-path` position 0 and shadows built-ins. Only `myde.el` belongs there — a file named `org.el` would shadow built-in Org.
- Binary gates are evaluated during init, so `exec-path` must be complete first. The `exec-path-from-shell` form uses `:ensure (:wait t)` and must stay in the Environment section, ahead of the first gated section.
- **Copyright headers use a single year range `2020-2026`** across all source files (`;; Copyright (C) 2020-2026  Allen Gooch`) and `LICENSE` (`Copyright (c) 2020-2026 Allen Gooch`). New files use the same range — do not introduce per-file or per-creation-year values. When the current year advances, bump the end year everywhere in one pass.

### Platform support

This config targets both **Linux** and **macOS**. Platform-specific code is guarded with
`(when (memq window-system '(mac ns)) ...)` or `(string= system-type "darwin")`.

Key macOS-specific concerns:
- GUI apps on macOS do not inherit the login shell's `PATH`. The Environment section runs
  `exec-path-from-shell-initialize` synchronously during init (daemon or any window
  system) with `exec-path-from-shell-arguments '("-l")`; everything gated on a binary
  depends on it having run.
- Homebrew paths differ by architecture: `/usr/local/bin` (Intel) vs `/opt/homebrew/bin`
  (Apple Silicon). Always use `executable-find` rather than hardcoded paths.
- macOS dired requires GNU `ls` (`gls` from `coreutils`) for `--group-directories-first`.
  The path is resolved via `(executable-find "gls")`.
- Native compilation of files loaded *before* `exec-path-from-shell` runs (elpaca's own
  files) fails with "error invoking gcc driver" when Emacs is launched with the bare GUI
  `PATH`, because libgccjit cannot find the Homebrew gcc driver. It is a warning, not a
  failure; those files run byte-compiled until a start with a full `PATH` compiles them.

### use-package constraints

- **All built-in packages must use `:ensure nil`.** With `use-package-always-ensure t`
  a built-in form without it is an elpaca clone attempt. Built-ins with no configuration
  should have no `use-package` form at all — `(use-package foo :defer t :ensure nil)` is
  a no-op and should be deleted.
- **Prefer a deferring keyword** (`:mode`, `:hook`, `:commands`, `:bind`) over eager
  loading. Global modes (theme, modeline, completion) legitimately stay eager.
- **A package that must draw at startup cannot be deferred.** `:commands` implies
  `:defer t`, so the package is not loaded at the moment it is needed. Dashboard was
  the one such package; it is now `:defer t` and opened on demand (see *Session model*).
- **Always verify hook target functions exist** in the installed package before using
  `:hook (event . fn)`. The function must be exported (autoloaded or `require`d). A
  non-existent hook target produces `custom-initialize-reset: Invalid function: <fn>`
  at startup, which can be mistaken for an unrelated error.
- **Do not set `use-package-expand-minimally t`** in production. It strips
  `condition-case` from `:config` blocks, making errors silent and extremely hard to
  diagnose. Useful only for byte-compilation inspection.
- `:ensure` is the **last keyword** in a form (see the `myde` skill).
