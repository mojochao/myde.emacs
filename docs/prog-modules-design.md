# Programming Language Module System Design

**⚠️ DEPRECATED** — This document describes an older version of the module system.
For current, accurate information, see [AGENTS.md](/AGENTS.md).

---

## Overview

Language-specific Emacs configuration is organized into self-contained modules
under `modules/`. Each module covers one language ecosystem and is independently
loadable via the declarative module system.

## Current System

The module system uses a declarative descriptor list in `init.el`:

1. **`myde-modules`** — An ordered list of `myde-module` descriptors defining all modules
2. **`myde-customize`** — Generates `defcustom` toggles for optional modules
3. **`myde-initialize`** — Loads each module according to its enable state

**See [AGENTS.md](/AGENTS.md) for:**
- Complete module loading rules
- Module structure (lib.el / cfg.el)
- Feature naming conventions
- How to add a new module

## Module Directory Layout

```
modules/
├── core-*          core infrastructure modules (always loaded)
├── prog-*          programming language modules
├── text-*          text format modules
├── data-*          data format modules
├── ebook-*         ebook reader modules
├── auth-*          authentication/secrets modules
└── ai-*            AI integration modules
```

Each module directory contains:
- `lib.el` — Named definitions and built-in Emacs initialization
- `cfg.el` — External package configuration via `use-package`

## File Conventions

### `lib.el`

Contains `defun`, `defvar`, `defcustom`, plus direct built-in Emacs variable
initialization (`setq`) and built-in mode setup. No `use-package` declarations,
no external package hooks, no keybindings.

```elisp
;;; lib.el --- <Lang> support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-
;;; Code:
;; ... defuns, defvars, defcustoms ...
(provide 'myde-<category>-<name>)
;;; lib.el ends here
```

### `cfg.el`

Contains `use-package` declarations and package configuration. Is the sole public
entry point. Begins by loading its own `lib.el` via a `featurep` guard using
`(file-name-directory load-file-name)` for path-independence.

```elisp
;;; cfg.el --- <Lang> package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-
;;; Code:
(unless (featurep 'myde-<category>-<name>)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))
;; ... use-package blocks ...
(provide 'myde-<category>-<name>-cfg)
;;; cfg.el ends here
```

## Feature Naming

| Module path | lib.el feature | cfg.el feature |
|---|---|---|
| `modules/prog-go/lib.el` | `myde-prog-go` | `myde-prog-go-cfg` |
| `modules/prog-python/lib.el` | `myde-prog-python` | `myde-prog-python-cfg` |

Pattern: `myde-<category>-<name>` for lib, `myde-<category>-<name>-cfg` for cfg.

## Keybinding Conventions

All language modules follow consistent keybinding prefix conventions:

| Prefix | Domain | Example |
|--------|--------|---------|
| `C-c e *` | LSP (eglot) — all languages | `C-c e a` code actions |
| `C-c t *` | Tests — language-specific | `C-c t t` test at point |
| `C-c i *` | REPL / interactive — language-specific | `C-c i i` start REPL |
| `C-c d *` | Debug (dape) — global | `C-c d d` start debugger |

For detailed test and REPL keybinding granularity, see [AGENTS.md](/AGENTS.md).

## How to Add a Module

See the "Adding a module" section in [AGENTS.md](/AGENTS.md) for current instructions.
