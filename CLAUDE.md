# CLAUDE.md

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

1. `early-init.el` — Runs before init.el and before Emacs startup.el creates directories. Includes critical optimizations:
   - Garbage collection suppression (restored after init)
   - File-name-handler-alist clearing (restored after init)
   - Frame parameter setup via default-frame-alist
   - Process buffer sizing for LSP throughput
   - Startup screen suppression
   - See file for complete optimization details
2. `init.el` — Loads `modules.el` via `(load-file ...)`, declares the ordered `myde-modules` descriptor list, then calls `myde-customize` (generates `defcustom` toggles) and `myde-initialize` (loads each enabled module in order).
3. `modules.el` — Defines the module system: the `myde-module` `cl-defstruct`, the `myde/m` constructor, the `myde-customize` macro, and the `myde-initialize` / `myde-load-module` functions. Provides feature `myde-modules`.
4. Each `modules/<category>-<name>/cfg.el` — The public entry point for a module.

**Performance:** Startup completes in ~1.16ms (Emacs init time), ~72ms wall-clock including binary load.

### Module system

Modules live under `modules/<category>-<name>/` and contain exactly two files:

- `lib.el` — Named definitions and built-in Emacs initialization: `defun`, `defvar`,
  `defcustom`, `setq`, and direct built-in mode/variable setup. No `use-package`
  declarations, no external package hooks, no keybindings. Provides `myde-<category>-<name>`.
- `cfg.el` — External package wiring: `use-package` declarations, hooks, keybindings.
  Begins with a `featurep` guard that loads its own `lib.el`. Provides `myde-<category>-<name>-cfg`.

`init.el` loads only `cfg.el` files. The `featurep` guard makes loading idempotent.

Categories: `core-*`, `prog-*`, `text-*`, `ebook-*`, `data-*`, `ai-*`, `auth-*`.

#### Declarative module loading

`init.el` is declarative. Its core is a single `defconst myde-modules` whose value is a list of `myde-module` descriptors built with `(myde/m "<category>-<name>" "<description>")`. List order is load order.

Two operators consume that list:

- `(myde-customize myde-modules)` — macro. Expands to a `progn` of `defcustom myde-module-<name>-enabled nil ...` forms, one per **toggleable** descriptor (i.e. neither `core-*` nor `*-base`). Toggles live in the `myde-modules` customization group and **default to `nil`** — users opt modules in.
- `(myde-initialize myde-modules)` — function. Walks the list in order calling `myde-load-module` on each name.

Loading rules enforced by `myde-load-module`:

| Module kind | Toggle generated? | Loaded when |
|-------------|-------------------|-------------|
| `core-*`    | No                | Always |
| `*-base` (non-core) | No        | Any sibling in the same category has its toggle on |
| Other       | Yes (`myde-module-<name>-enabled`, default `nil`) | Toggle is non-nil |

The `*-base` auto-load is implemented by `myde-module-category-enabled-p`, which scans interned symbols matching `myde-module-<category>-*-enabled`.

### XDG compliance

All state, data, and cache is stored outside `user-emacs-directory` via the built-in `xdg.el` library:

| Kind | Path |
|------|------|
| State (recentf, places, history, tramp, auto-save-list) | `$XDG_STATE_HOME/emacs/` |
| Data (transient, tree-sitter) | `$XDG_DATA_HOME/emacs/` |
| Cache (eln-cache, url) | `$XDG_CACHE_HOME/emacs/` |
| Packages (elpa) | `./elpa/` (repo root, git-ignored) |

XDG paths are set in `core-base/cfg.el` via `(use-package emacs :after xdg :config ...)`. Exceptions:
- `auto-save-list-file-prefix` must be set in `early-init.el` because Emacs creates the directory before init.el runs.
- `elpa` is stored in the repo root (`./elpa/`) for easier debugging, package inspection, and agent access.

### Key conventions

- `:init` blocks set variables *before* package activation; `:config` blocks run side effects after.
- Multiple `use-package` blocks for the same package accumulate — idiomatic here.
- `core-base` loads first and is the only module that calls `package-initialize`.
- Language modules share keybinding prefixes: `C-c e` (eglot/LSP), `C-c t` (tests), `C-c i` (REPL), `C-c d` (dape/debug).
- `myde/eglot-add-workspace-config` in `core-projects/lib.el` upserts LSP workspace config without clobbering other modules' settings.
- **Never use lambdas as hook functions.** Always define a named function (e.g., `myde/foo-mode-hook`) in the module's `lib.el` and reference it by name in `cfg.el`.

### Snippets

Snippets are managed by `core-snippets` (yasnippet + yasnippet-classic-snippets). Language modules that have custom snippets store them flat under `modules/<category>-<name>/snippets/` — no mode-name subdirectory.

Each such module registers its snippets near the bottom of its `cfg.el`:

```elisp
(myde/register-snippets
 (expand-file-name "snippets" (file-name-directory load-file-name))
 'the-major-mode)
```

`myde/register-snippets` is defined in `core-snippets/lib.el`; it defers to `yas--load-directory-1` and is safe to call before yasnippet has loaded.

### Adding a module

1. Create `modules/<category>-<name>/lib.el` ending with `(provide 'myde-<category>-<name>)`.
2. Create `modules/<category>-<name>/cfg.el` with a `featurep` guard at top and `(provide 'myde-<category>-<name>-cfg)` at bottom.
3. Add a `(myde/m "<category>-<name>" "<one-line description>")` entry to `myde-modules` in `init.el`, in the desired load position. The `defcustom` toggle is generated automatically (unless the module is `core-*` or `*-base`).
