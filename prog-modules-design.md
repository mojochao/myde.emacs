# Programming Language Module System Design

## Overview

Language-specific Emacs configuration is organized into self-contained modules
under `myde/`. Each module covers one language ecosystem and is independently
loadable. `init.el` remains the authoritative entry point but is reduced to
shared infrastructure; it delegates all language concerns to the modules.

## Directory layout

```
myde.el              core library (shared utilities, hooks, conventions)
init.el              top-level config; loads shared tools then language modules
myde/
├── prog-elixir/
│   ├── lib.el       library functions for Elixir support
│   └── cfg.el       package configuration for Elixir support
├── prog-go/
│   ├── lib.el       library functions for Go support
│   └── cfg.el       package configuration for Go support
└── prog-python/
    ├── lib.el       library functions for Python support
    └── cfg.el       package configuration for Python support
```

The `prog-` prefix is a namespace convention for programming language modules.
Other module categories may be introduced later (e.g. `tool-`, `ui-`) following
the same pattern.

## File conventions

### `lib.el`

Contains `defun`, `defvar`, and `defcustom` forms — pure library code with no
side effects beyond defining symbols. Always begins with `(require 'myde)` to
ensure core utilities are available. Always ends with `(provide 'myde-prog-<lang>)`.

```elisp
;;; lib.el --- <Lang> support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-
;;; Code:
(require 'myde)
;; ... defuns ...
(provide 'myde-prog-<lang>)
;;; lib.el ends here
```

### `cfg.el`

Contains `use-package` declarations and other configuration with side effects.
Is the sole public entry point for its module — `init.el` loads only `cfg.el`,
never `lib.el` directly. Begins by loading its own `lib.el` via a `featurep`
guard using `(file-name-directory load-file-name)` for path-independence.
Always ends with `(provide 'myde-prog-<lang>-cfg)`.

```elisp
;;; cfg.el --- <Lang> package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-
;;; Code:
(unless (featurep 'myde-prog-<lang>)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))
;; ... use-package blocks ...
(provide 'myde-prog-<lang>-cfg)
;;; cfg.el ends here
```

## Feature naming

| File | Feature symbol |
|------|----------------|
| `myde.el` | `myde` |
| `myde/prog-go/lib.el` | `myde-prog-go` |
| `myde/prog-go/cfg.el` | `myde-prog-go-cfg` |
| `myde/prog-python/lib.el` | `myde-prog-python` |
| `myde/prog-python/cfg.el` | `myde-prog-python-cfg` |
| `myde/prog-elixir/lib.el` | `myde-prog-elixir` |
| `myde/prog-elixir/cfg.el` | `myde-prog-elixir-cfg` |

The pattern is `myde-<category>-<name>` for lib and `myde-<category>-<name>-cfg`
for cfg.

## Loading mechanism

`init.el` loads each module with a bare `load-file`:

```elisp
(load-file (expand-file-name "myde/prog-go/cfg.el"     user-emacs-directory))
(load-file (expand-file-name "myde/prog-python/cfg.el" user-emacs-directory))
(load-file (expand-file-name "myde/prog-elixir/cfg.el" user-emacs-directory))
```

`load-file` is used rather than `require` because the files are named `lib.el`
and `cfg.el` rather than after their feature symbol. The `featurep` guard inside
each `cfg.el` provides idempotency — re-evaluating the file is a no-op.

The module load section is placed in `init.el` after the shared tool blocks
(`treesit`, `eglot`, `flycheck`, `dape`) and before non-language sections
(Markdown, Terraform, AI).

## Shared tool integration

Packages used by multiple language modules (`treesit`, `eglot`, `dape`,
`dap-mode`) are declared once in `init.el` with only their shared configuration
(keybindings, global settings). Language-specific content is added by each
module's `cfg.el` via additional `use-package` declarations for the same
package with `:ensure nil`.

Multiple `use-package` declarations for the same package are idiomatic and
fully supported — each one's `:hook`, `:config`, `:bind` etc. accumulates.
This eliminates the need for `with-eval-after-load` in module files.

### treesit

`init.el` declares the base block (load path only). Each module adds its
grammar source:

```elisp
;; in init.el
(use-package treesit
  :config (setq treesit-extra-load-path ...)
  :ensure nil)

;; in myde/prog-python/cfg.el
(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist '(python ...))
  :ensure nil)
```

### eglot

`init.el` declares shared keybindings and performance settings. Each module
adds its hooks, server program, and workspace config using
`myde/eglot-add-workspace-config` (defined in `myde.el`):

```elisp
;; in init.el
(use-package eglot
  :bind (:map eglot-mode-map ("C-c e a" . eglot-code-actions) ...)
  :config (setq eglot-autoshutdown t ...)
  :ensure nil)

;; in myde/prog-python/cfg.el
(use-package eglot
  :hook (python-ts-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs '((python-mode python-ts-mode) . (...)))
  (myde/eglot-add-workspace-config :basedpyright '(...))
  :ensure nil)
```

### dape

`init.el` declares shared keybindings and layout. Each module adds its debug
configurations:

```elisp
;; in init.el
(use-package dape
  :bind (("C-c d d" . dape) ...)
  :config (setq dape-buffer-window-arrangement 'right)
  :ensure t)

;; in myde/prog-go/cfg.el
(use-package dape
  :config
  (add-to-list 'dape-configs '(go-debug ...))
  (add-to-list 'dape-configs '(go-test ...))
  :ensure nil)
```

## Core helper: `myde/eglot-add-workspace-config`

Defined in `myde.el`. Upserts a language server's workspace configuration into
`eglot-workspace-configuration` without clobbering entries from other modules.
Modules call it in their `use-package eglot :config` block.

```elisp
(defun myde/eglot-add-workspace-config (server-key config)
  "Upsert CONFIG for SERVER-KEY in `eglot-workspace-configuration'."
  (setq-default eglot-workspace-configuration
                (cons (cons server-key config)
                      (assq-delete-all server-key
                                       (default-value
                                         'eglot-workspace-configuration)))))
```

## Keybinding conventions

All language modules follow the same keybinding prefix conventions:

| Prefix | Domain | Example |
|--------|--------|---------|
| `C-c e *` | LSP (eglot) — all languages via `eglot-mode-map` | `C-c e a` code actions |
| `C-c t *` | Tests — scoped to the mode map | `C-c t t` test at point |
| `C-c i *` | REPL / interactive — scoped to the mode map | `C-c i i` start REPL |
| `C-c d *` | Debug (dape) — global | `C-c d d` start debugger |

### Test keybindings (`C-c t`)

The same granularity convention is used across all language modules:

| Key | Granularity | Go | Python | Elixir |
|-----|-------------|-----|--------|--------|
| `C-c t t` | point (finest) | `gotest-ts-run-dwim` | `python-pytest-function-dwim` | `exunit-toggle-file-and-test` |
| `C-c t f` | file | `gotest-ts-run-file` | `python-pytest-file-dwim` | — |
| `C-c t p` | package/project | `gotest-ts-run-package` | `python-pytest` | — |
| `C-c t r` | repeat | `gotest-ts-repeat` | `python-pytest-repeat` | — |
| `C-c t a` | all | — | — | `exunit-verify-all` |
| `C-c t s` | single | — | — | `exunit-verify-single` |
| `C-c t x` | last failed | — | `python-pytest-last-failed` | — |
| `C-c t m` | menu | — | `python-pytest-dispatch` | — |

### REPL keybindings (`C-c i`)

| Key | Meaning | Go | Python | Elixir |
|-----|---------|-----|--------|--------|
| `C-c i i` | start REPL | — | `run-python` | `elixir-iex` |
| `C-c i p` | project REPL | — | — | `elixir-iex-project` |
| `C-c i l` | send line | — | — | `elixir-iex-send-line` |
| `C-c i r` | send region | — | `python-shell-send-region` | `elixir-iex-send-region` |
| `C-c i b` | send buffer | — | `python-shell-send-buffer` | `elixir-iex-send-buffer` |
| `C-c i d` | send def | — | `python-shell-send-defun` | — |
| `C-c i m` | reload module | — | — | `elixir-iex-reload-module` |
| `C-c i s` | switch/set REPL | — | `python-shell-switch-to-shell` | `elixir-iex-set-repl` |

## What stays in `init.el`

- Package archive setup and `use-package` bootstrap
- Core Emacs settings (UI, scrolling, backups, encoding)
- All non-language packages (completion stack, magit, projectile, themes, AI, etc.)
- Shared tool base declarations (`treesit`, `eglot`, `flycheck`, `dape`)
- The 3-line language module loader section

## What stays in `myde.el`

- Core utility functions used across modules (`myde/delete-trailing-whitespace-setup`,
  `myde/mise-exec-which`, `myde/keyboard-quit`, etc.)
- The `myde/eglot-add-workspace-config` shared helper
- NeoTree helpers
- Org/denote variables
- Secrets and AI helpers

`myde.el` will eventually become `myde/core/lib.el` but remains at the repo
root for now.

## Adding a new language module

1. Create `myde/prog-<lang>/` directory
2. Write `lib.el` — define functions, `(require 'myde)`, `(provide 'myde-prog-<lang>)`
3. Write `cfg.el` — load guard, `use-package` blocks, `(provide 'myde-prog-<lang>-cfg)`
4. Add `(load-file ... "myde/prog-<lang>/cfg.el" ...)` to the language module
   section of `init.el`
5. Follow the `C-c t *` and `C-c i *` keybinding conventions
