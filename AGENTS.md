# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```shell
make link      # Symlink repo into ~/.config/emacs (installs config)
make unlink    # Remove the symlink
```

No build, lint, or test tooling — this is a pure Emacs Lisp configuration, evaluated at Emacs startup.

## Architecture

MyDE is a modular Emacs configuration targeting **Emacs 30+ compiled with native-compile support**. The repo is symlinked to `~/.config/emacs` (`user-emacs-directory`).

### Startup sequence

1. `early-init.el` — Runs before init.el and before Emacs startup.el creates directories. Currently sets `auto-save-list-file-prefix` to its XDG path (must be here — too late in init.el).
2. `init.el` — Defines `myde/load-module` and calls it for every module in order.
3. Each `myde/<category>-<name>/cfg.el` — The public entry point for a module.

### Module system

Modules live under `myde/<category>-<name>/` and contain exactly two files:

- `lib.el` — Pure definitions (`defun`, `defvar`, `defcustom`). Provides `myde-<category>-<name>`.
- `cfg.el` — All side effects: `use-package` declarations, hooks, keybindings. Begins with a `featurep` guard that loads its own `lib.el`. Provides `myde-<category>-<name>-cfg`.

`init.el` loads only `cfg.el` files. The `featurep` guard makes loading idempotent.

Categories: `core-*`, `prog-*`, `text-*`, `ebook-*`, `data-*`, `ai-*`, `auth-*`.

### XDG compliance

All state, data, and cache is stored outside `user-emacs-directory` via the built-in `xdg.el` library:

| Kind | Path |
|------|------|
| State (recentf, places, history, tramp, auto-save-list) | `$XDG_STATE_HOME/emacs/` |
| Data (elpa, transient, tree-sitter) | `$XDG_DATA_HOME/emacs/` |
| Cache (eln-cache, url) | `$XDG_CACHE_HOME/emacs/` |

XDG paths are set in `core-base/cfg.el` via `(use-package emacs :after xdg :config ...)`. Exception: `auto-save-list-file-prefix` must be set in `early-init.el` because Emacs creates the directory before init.el runs.

### Key conventions

- `:init` blocks set variables *before* package activation; `:config` blocks run side effects after.
- Multiple `use-package` blocks for the same package accumulate — idiomatic here.
- `core-base` loads first and is the only module that calls `package-initialize`.
- Language modules share keybinding prefixes: `C-c e` (eglot/LSP), `C-c t` (tests), `C-c i` (REPL), `C-c d` (dape/debug).
- `myde/eglot-add-workspace-config` in `core-projects/lib.el` upserts LSP workspace config without clobbering other modules' settings.

### Adding a module

1. Create `myde/<category>-<name>/lib.el` ending with `(provide 'myde-<category>-<name>)`.
2. Create `myde/<category>-<name>/cfg.el` with a `featurep` guard at top and `(provide 'myde-<category>-<name>-cfg)` at bottom.
3. Add `(myde/load-module "<category>-<name>")` to `init.el` in the appropriate section.
