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

1. `early-init.el` — Runs before init.el and before Emacs startup.el creates directories. Includes critical optimizations:
   - Garbage collection suppression (restored after init)
   - File-name-handler-alist clearing (restored after init)
   - Native compilation cache redirection to `$XDG_CACHE_HOME/emacs/eln-cache` (must happen before any compilation)
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

- `(myde-customize myde-modules)` — macro. Expands to a `progn` of `defcustom myde-module-<name>-enabled nil ...` forms, one per **toggleable** descriptor (i.e. neither `core-*` nor `*-base`). Toggles live in the `myde-modules` customization group and **default to `nil`** — users opt modules in via `M-x customize-group RET myde-modules` or `custom.el`.
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
| Packages (elpa) | `./elpa/` (repo root) |

XDG paths are set in `core-base/cfg.el` via `(use-package emacs :after xdg :config ...)`. Exceptions:
- `auto-save-list-file-prefix` must be set in `early-init.el` because Emacs creates the directory before init.el runs.
- Native compilation cache (`eln-cache`) redirection must happen in `early-init.el` before any compilation occurs.
- `elpa` is stored in the repo root (`./elpa/`) for easier debugging, package inspection, and agent access. It is git-ignored.

### Key conventions

- `:init` blocks set variables *before* package activation; `:config` blocks run side effects after.
- Multiple `use-package` blocks for the same package accumulate — idiomatic here.
- `core-base` loads first and is the only module that calls `package-initialize`.
- Language modules share keybinding prefixes: `C-c e` (eglot/LSP), `C-c t` (tests), `C-c i` (REPL), `C-c d` (dape/debug).
- `myde/eglot-add-workspace-config` in `core-projects/lib.el` upserts LSP workspace config without clobbering other modules' settings.
- **Never use lambdas as hook functions.** Always define a named function (e.g., `myde/foo-mode-hook`) in the module's `lib.el` and reference it by name in `cfg.el`.
- **Copyright headers use a single year range `2020-2026`** across all source files (`;; Copyright (C) 2020-2026  Allen Gooch`) and `LICENSE` (`Copyright (c) 2020-2026 Allen Gooch`). New files use the same range — do not introduce per-file or per-creation-year values. When the current year advances, bump the end year everywhere in one pass.

### Platform support

This config targets both **Linux** and **macOS**. Platform-specific code is guarded with
`(when (memq window-system '(mac ns)) ...)` or `(string= system-type "darwin")`.

Key macOS-specific concerns:
- GUI apps on macOS do not inherit the login shell's `PATH`. `exec-path-from-shell` is
  installed and initialized via `emacs-startup-hook` (deferred, non-blocking) in
  `core-base/cfg.el` for `mac`/`ns` window systems only.
- Homebrew paths differ by architecture: `/usr/local/bin` (Intel) vs `/opt/homebrew/bin`
  (Apple Silicon). Always use `executable-find` rather than hardcoded paths.
- macOS dired requires GNU `ls` (`gls` from `coreutils`) for `--group-directories-first`.
  The path is resolved via `(executable-find "gls")`.

### Package system invariants

These ordering constraints must be preserved in `core-base/cfg.el`:

1. `(require 'package)` and `(package-initialize)` run first.
2. `(unless package-archive-contents (package-refresh-contents))` runs immediately after
   — never before — `package-initialize`. If `package-initialize` comes after the guard,
   `package-archive-contents` is always nil and archive indexes are re-downloaded on
   every startup.
3. `custom.el` is loaded after `package-initialize` because `package-vc-selected-packages`
   has a `:set` handler that calls `package-vc-install`, which requires an initialized
   package system.
4. `package-pinned-packages` entries must be set **before** `package-initialize`. The
   pinning is applied during `package-read-all-archive-contents`, which runs inside
   `package-initialize`. Pins set after that call only take effect on the next
   `package-refresh-contents` (which `package-upgrade-all` does call, so interactive
   use is still correct, but startup-time effects require pre-init placement).
5. **`package-install-upgrade-built-in` is `nil`.** Setting it to `t` causes
   `package--upgradeable-packages` to permanently add every built-in package to the
   upgradeable list whenever an archive has a higher version. Once a built-in has been
   upgraded into `elpa/`, `package-upgrade-all` will repeatedly fail with
   `(user-error "Cannot upgrade 'X'")` because the built-in's old version is still
   detected as "upgradeable" even though the elpa copy already matches the archive.
   Packages already upgraded into `elpa/` (org, tramp, transient) continue to be
   upgraded normally via the standard `package-alist` version check (first condition in
   `package--upgradeable-packages`).

#### Built-in packages excluded from archive management

Some built-in packages that also exist on MELPA must never be managed by the package
system at all. They are pinned to the non-existent `"builtin"` archive in
`core-base/cfg.el`, which causes `package-read-all-archive-contents` to omit them from
`package-archive-contents` entirely:

| Package | Reason |
|---------|--------|
| `csharp-mode` | Built-in since Emacs 29; no C# module in this config |
| `wallpaper` | Built-in since Emacs 29; not used |

If a package keeps reinstalling itself after being removed from `custom.el` and `elpa/`,
check whether `package-install-upgrade-built-in` is `t` and whether the package is
built-in — that combination causes a reinstall loop. The fix is either to pin the package
to `"builtin"` (if unwanted) or to set the flag to `nil` (preferred).

#### VC package upgrade behavior

**`package--upgradeable-packages` in Emacs 30 unconditionally marks all `kind=vc`
packages as upgradeable**, regardless of `:rev` setting. This means packages installed
via `:vc :ensure t` will always appear in `package-upgrade-all` output, even when
already at the remote HEAD. Pinning `:rev` to a specific commit hash has no effect
on this code path.

The fix is a `:filter-return` advice on `package--upgradeable-packages` defined in
`core-base/lib.el` (`myde/filter-git-only-vc-packages`) and wired in `core-base/cfg.el`
immediately after `package-initialize`. It removes VC packages that have no
`package-archive-contents` entry — i.e., packages that exist only on git and not on
MELPA/ELPA. If a git-only package later appears on MELPA with a genuinely newer version,
the advice passes it through normally.

**Corollary:** if a VC-installed package is also on MELPA, do not use `:vc` — install
it from MELPA instead so it gets normal archive-based upgrade tracking. Switching
requires:
1. Removing `:vc` from the `use-package` declaration
2. Deleting the VC-installed copy: `M-x package-delete`
3. Reinstalling from MELPA: `M-x package-install`
4. Removing the entry from `package-vc-selected-packages` in both `custom.el` and
   in-memory via `(customize-save-variable 'package-vc-selected-packages ...)`

**`custom.el` is the authoritative source for `package-vc-selected-packages`.**
`use-package` `:vc` declarations do not update `custom.el` when the package is already
installed — `package-vc-install` is idempotent and skips if the package directory
exists. Any `:rev` change in a cfg.el file must also be applied manually to the
corresponding entry in `custom.el` to take effect.

#### Version-conditional archive pinning

Some built-in packages have MELPA versions with `compat` requirements that differ between
Emacs 30 and 31. Use two `use-package` forms with `:if` and `:pin` to select the right
archive per version:

```elisp
(use-package some-package
  :if (= emacs-major-version 30)
  :pin "melpa-stable"   ;; requires (compat (30 1))
  :ensure nil)

(use-package some-package
  :if (>= emacs-major-version 31)
  :pin "melpa"          ;; requires (compat (31 0))
  :ensure nil)
```

`transient` uses this pattern. The built-in `compat` stub in Emacs reports version
`(emacs-major-version emacs-minor-version 9999)`, so on Emacs 30 it satisfies
`(compat (30 1))` but not `(compat (31 0))`.

### use-package constraints (Emacs 30)

- **Do not set `use-package-ensure-function` to `#'package-install`.** Emacs 30's
  built-in `use-package` calls ensure functions with three arguments `(name ensure-value
  state)`; `package-install` only accepts one or two. The correct default is
  `use-package-ensure-elpa` — do not override it.
- **Do not set `use-package-expand-minimally t`** in production. It strips
  `condition-case` from `:config` blocks, making errors silent and extremely hard to
  diagnose. Useful only for byte-compilation inspection.
- **Do not add `:commands` to startup-screen packages.** `:commands` implies `:defer t`,
  which prevents the package from loading at startup — exactly when it is needed.
- **Always verify hook target functions exist** in the installed package before using
  `:hook (event . fn)`. The function must be exported (autoloaded or `require`d). A
  non-existent hook target produces `custom-initialize-reset: Invalid function: <fn>`
  at startup, which can be mistaken for an unrelated error.
- **All built-in packages must use `:ensure nil`.** Using `:ensure t` on a built-in is
  a latent bug: if an archive later publishes a newer version, the package system will
  install it, add it to `package-selected-packages`, and trigger reinstall loops. Built-in
  packages that should never be installed from archives are additionally pinned to
  `"builtin"` in `package-pinned-packages` (see above). Built-ins that have no
  configuration at all should have no `use-package` declaration at all — a
  `(use-package foo :defer t :ensure nil)` block with no other keywords is a no-op and
  should be deleted.

### Adding a module

1. Create `modules/<category>-<name>/lib.el` ending with `(provide 'myde-<category>-<name>)`.
2. Create `modules/<category>-<name>/cfg.el` with a `featurep` guard at top and `(provide 'myde-<category>-<name>-cfg)` at bottom.
3. Add a `(myde/m "<category>-<name>" "<one-line description>")` entry to `myde-modules` in `init.el`, in the desired load position. The `defcustom` toggle is generated automatically (unless the module is `core-*` or `*-base`).
