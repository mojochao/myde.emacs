# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```shell
make link      # Symlink repo into ~/.config/emacs (installs config)
make unlink    # Remove the symlink
make tangle    # Regenerate early-init.el, init.el, user-lisp/myde.el from myde.org
make check     # Tangle, then fail if the committed elisp differs from myde.org

scripts/myde-probe.sh <init-directory> <report-file>   # Verify a config change
```

There is no build or lint step beyond `make check`. The probe is the test harness: it
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

| File | Role |
|------|------|
| `myde.org` | **The only file edited by hand.** Three top-level subtrees, one per tangled file, each setting its target with a `:header-args:emacs-lisp: :tangle …` property. |
| `early-init.el` | Tangled from `* Early Init`. Runs before `init.el` and before startup.el creates directories: GC and `file-name-handler-alist` suppression (restored on `emacs-startup-hook`), eln-cache redirection to `$XDG_CACHE_HOME/emacs/eln-cache`, frame defaults, `package-enable-at-startup nil`. |
| `init.el` | Tangled from `* Bootstrap`. Installs and loads elpaca, enables `elpaca-use-package-mode`, sets `use-package-always-ensure t`, then `(require 'myde)`. |
| `user-lisp/myde.el` | Tangled from `* Configuration`. All configuration in load order, one `;;;; section` per former module. Emacs 31 puts `user-lisp/` at `load-path` position 0. |

Tangled outputs are committed, so a fresh clone works without tangling and startup never
loads org. **Never edit the three `.el` files directly** — `make tangle` overwrites them.

### Startup sequence

1. `early-init.el`.
2. `init.el` bootstraps elpaca. `use-package` forms in `myde.el` queue elpaca orders as the
   file is read; the queue is processed after `after-init-hook`. One order is processed
   synchronously: `exec-path-from-shell` is `:ensure (:wait t)` so the binary gates that
   follow it see a complete `exec-path` during init.
3. `myde.el` sections evaluate in file order: `core-base`, `Environment`, the remaining
   `core-*` sections, then `ai-*`, `auth-*`, `data-*`, `containers-*`, `prog-*`, `text-*`,
   `ebook-*`. This order is known-working; do not reorder for aesthetics.
4. `elpaca-after-init-hook` runs once every queued package is activated. Startup global
   modes hang off this hook (see *Startup hooks*).

**Performance:** warm start with a populated `elpaca/` reaches `elpaca-after-init-hook`
in roughly 4 s in the probe daemon, versus ~7 s for the package.el config it replaced.
A cold start from an empty `elpaca/` clones and builds every package and takes minutes.

### Section enablement: presence is intent

There are no module toggles, no override list, and no `custom.el` entries for modules.
A section that needs a toolchain is wrapped in `(when (executable-find "<binary>") …)`.
Installing the binary enables the section on the next start; removing it disables it.

| Binary | Section | Binary | Section |
|--------|---------|--------|---------|
| `go` | `prog-go` | `clangd` | `prog-cpp` |
| `cargo` | `prog-rust` | `fish` | `prog-fish` |
| `zig` | `prog-zig` | `nu` | `prog-nushell` |
| `lua` | `prog-lua` | `sbcl` | `prog-clisp` |
| `ruby` | `prog-ruby` | `guile` | `prog-scheme` |
| `python3` | `prog-python` | `clojure` | `prog-clojure` |
| `node` | `prog-javascript`, `prog-typescript` | `erl` | `prog-erlang` |
| `elixir` | `prog-elixir` | `pdftoppm` | `ebook-pdf` |
| `op` | `auth-1password` | `kubectl` | `containers-kubernetes` |
| `claude` | `ai-claude` | | |

Everything else — `core-*`, `ai-base`, `ai-gptel`, `ai-agents`, `ai-mcp`, `data-*`,
`prog-base`, `prog-bash`, `prog-elisp`, `text-*`, `ebook-epub` — is unconditional: editing
modes need no toolchain. Runtime and tooling presence differ, so a gated section may
still contain inner `:if (executable-find "<lsp-server>")` guards on LSP or debugger forms.

**The gate must wrap the whole `use-package` form.** elpaca queues the order when the
form is *expanded*, before `:if`/`:when` is evaluated, so a keyword inside the form cannot
prevent a clone.

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

### Startup hooks

Inside a `use-package` form use `:hook (elpaca-after-init . fn)` — **never** `after-init`
or `emacs-startup`. Under elpaca the form's body runs after those hooks have already
fired, so the mode would stay silently off. Top-level `add-hook` calls in `myde.el` that
must wait for packages use `elpaca-after-init-hook` as well. Dashboard is the exception
that needs its README recipe (`dashboard-insert-startupify-lists` and
`dashboard-initialize` on `elpaca-after-init-hook`), guarded so a daemon skips it.

GC and `file-name-handler-alist` restoration stay on `emacs-startup-hook` in
`early-init.el`, not `elpaca-after-init-hook`, so a failed elpaca bootstrap cannot leave
a session with GC disabled and TRAMP broken.

### Editing workflow

1. Edit `myde.org`. New configuration is a `#+begin_src emacs-lisp` block under its own
   `***` heading beneath the right `**` category heading in `* Configuration`. Wrap it in
   a binary gate if the tool needs a toolchain to be useful.
2. `make tangle`. Then `scripts/myde-probe.sh "$PWD" /tmp/after.txt` and diff its
   `declared:`/`mode:` lines against a report taken before the change.
3. `make check` before committing. Commit `myde.org` together with the tangled files.

### XDG compliance

All state, data, and cache is stored outside `user-emacs-directory` via the built-in `xdg.el` library:

| Kind | Path |
|------|------|
| State (recentf, places, history, tramp, auto-save-list) | `$XDG_STATE_HOME/emacs/` |
| Data (transient, tree-sitter) | `$XDG_DATA_HOME/emacs/` |
| Cache (eln-cache, url) | `$XDG_CACHE_HOME/emacs/` |
| Packages (elpaca) | `./elpaca/` (repo root) |

XDG paths are set in the `core-base` section of `myde.el`. Exceptions:
- `auto-save-list-file-prefix` must be set in `early-init.el` because Emacs creates the directory before init.el runs.
- Native compilation cache (`eln-cache`) redirection must happen in `early-init.el` before any compilation occurs.

### Key conventions

- `:init` blocks set variables *before* package activation; `:config` blocks run side effects after.
- Multiple `use-package` blocks for the same package accumulate — idiomatic here, subject to the one-ensuring-form rule above.
- Language sections share keybinding prefixes: `C-c e` (eglot/LSP), `C-c t` (tests), `C-c i` (REPL), `C-c d` (dape/debug).
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
  loading. Global modes (theme, modeline, completion, dashboard) legitimately stay eager.
- **Do not add `:commands` to startup-screen packages.** `:commands` implies `:defer t`,
  which prevents the package from loading at startup — exactly when it is needed.
- **Always verify hook target functions exist** in the installed package before using
  `:hook (event . fn)`. The function must be exported (autoloaded or `require`d). A
  non-existent hook target produces `custom-initialize-reset: Invalid function: <fn>`
  at startup, which can be mistaken for an unrelated error.
- **Do not set `use-package-expand-minimally t`** in production. It strips
  `condition-case` from `:config` blocks, making errors silent and extremely hard to
  diagnose. Useful only for byte-compilation inspection.
- `:ensure` is the **last keyword** in a form (see the `myde` skill).
