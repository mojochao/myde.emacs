---
name: myde
description: This skill should be used when adding or editing modules in the myde.el repository, creating lib.el or cfg.el files, wiring use-package declarations for myde modules, or working with the myde module system (myde-modules, myde/m, myde-initialize).
version: 1.0.0
---

# Myde Project Conventions

Apply these rules whenever writing code in the myde.el repository. They extend the `elisp` skill — follow both.

## Module file split

Every module under `modules/<category>-<name>/` contains exactly two files:

- `lib.el` — named definitions and built-in Emacs setup only: `defun`, `defvar`, `defcustom`, `setq`, direct built-in mode/variable configuration. No `use-package`, no external package hooks, no keybindings.
- `cfg.el` — external package wiring via `use-package`: hooks, keybindings, package configuration.

`cfg.el` must begin with a `featurep` guard that loads its own `lib.el`:

```elisp
(unless (featurep 'myde-<category>-<name>)
  (load (expand-file-name "lib" (file-name-directory load-file-name))))
```

`cfg.el` must end with `(provide 'myde-<category>-<name>-cfg)`.
`lib.el` must end with `(provide 'myde-<category>-<name>)`.

## Naming

Public symbols are prefixed `myde-<category>-<name>-` matching the module path.  
Internal symbols use `myde--` as the secondary separator.  
Interactive helper functions exposed as commands use the `/` separator: `myde/do-thing`.

## Hook functions

**Never use lambdas as hook functions.** Define a named function in `lib.el` and reference it by symbol in `cfg.el`:

```elisp
;; lib.el
(defun myde/foo-mode-hook ()
  (setq-local fill-column 100))

;; cfg.el
(add-hook 'foo-mode-hook #'myde/foo-mode-hook)
```

## Keybinding prefixes

Language modules share these prefixes consistently across all `prog-*` modules:

| Prefix  | Purpose            |
|---------|--------------------|
| `C-c e` | eglot / LSP        |
| `C-c t` | tests              |
| `C-c i` | REPL / interactive |
| `C-c d` | dape / debug       |

## LSP workspace config

Use `myde/eglot-add-workspace-config` (defined in `core-projects/lib.el`) to upsert LSP server settings. Never assign `eglot-workspace-configuration` directly — it clobbers other modules' settings.

```elisp
(myde/eglot-add-workspace-config :my-server '(:option value))
```

## Snippets

Custom snippets live flat under `modules/<category>-<name>/snippets/` — no mode-name subdirectory. Register them near the bottom of `cfg.el`:

```elisp
(myde/register-snippets
 (expand-file-name "snippets" (file-name-directory load-file-name))
 'the-major-mode)
```

`myde/register-snippets` is defined in `core-snippets/lib.el` and is safe to call before yasnippet loads.

## XDG paths

All state/data/cache redirection is handled in `core-base/cfg.el`. Never redirect XDG paths in other modules.

## Adding a new module

1. Create `modules/<category>-<name>/lib.el` ending with `(provide 'myde-<category>-<name>)`.
2. Create `modules/<category>-<name>/cfg.el` with the `featurep` guard at top and `(provide 'myde-<category>-<name>-cfg)` at bottom.
3. Add `(myde/m "<category>-<name>" "<one-line description>")` to `myde-modules` in `init.el` at the desired load position.

The `defcustom` toggle is generated automatically unless the module is `core-*` or `*-base`.

## Quality checklist (before declaring done)

- [ ] `lib.el` contains only named definitions and built-in setup — no `use-package`.
- [ ] `cfg.el` starts with `featurep` guard, ends with `provide`.
- [ ] All hook references are named functions defined in `lib.el`.
- [ ] Keybindings use the shared `C-c e/t/i/d` prefixes where applicable.
- [ ] LSP config uses `myde/eglot-add-workspace-config`, not direct assignment.
- [ ] New module is registered in `init.el` `myde-modules` list.
