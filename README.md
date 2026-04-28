# My Development Environment

My Development Environment, or MyDE for short, is my personal Emacs configuration
for modern Emacs versions (minimum v29), providing a consistent, convenient DX
across Linux and macOS platforms.

## Installation

Run the following commands to install MyDE configuration into your

```shell
git clone https://github.com/mojochao/myde.el
cd myde.el
make link
```

At this point, you should be able to launch Emacs, at which time packages
will be downloaded and configured as defined by MyDE elisp configuration.

## Organization

MyDE uses a modular architecture where configuration is organized into self-contained modules under the `myde/` directory.

### Module categories

Modules follow a `<category>-<name>` naming convention:

- **`prog-*`** — Programming language modules (e.g. `prog-go`, `prog-python`, `prog-elixir`, `prog-elisp`)
- **`core-*`** — Core infrastructure and productivity tools (e.g. `core-complete`, `core-dashboard`, `core-projects`)
- **`text-*`** — Text format modules (e.g. `text-markdown`)

### Module structure

Each module contains:
- `lib.el` — Library code (functions, variables, customizations)
- `cfg.el` — Configuration code (the public entry point)

### File conventions

**`lib.el`**
- Contains pure library code: `defun`, `defvar`, `defcustom`
- Requires core utilities via `(require 'myde)`
- Provides a feature symbol: `(provide 'myde-<category>-<name>)`

**`cfg.el`**
- Contains all configuration with side effects: `use-package` declarations, hooks, etc.
- Loads its own `lib.el` via a `featurep` guard
- Is the sole public entry point — `init.el` loads only `cfg.el`
- Provides a feature symbol: `(provide 'myde-<category>-<name>-cfg)`

### Feature naming

| Module path | lib.el feature | cfg.el feature |
|-------------|---|---|
| `myde/prog-go/lib.el` | `myde-prog-go` | `myde-prog-go-cfg` |
| `myde/core-dashboard/lib.el` | `myde-core-dashboard` | `myde-core-dashboard-cfg` |
| `myde/text-markdown/lib.el` | `myde-text-markdown` | `myde-text-markdown-cfg` |

Pattern: `myde-<category>-<name>` for lib, `myde-<category>-<name>-cfg` for cfg.

### Keybinding conventions

Language modules follow consistent keybinding prefixes:

| Prefix | Domain | Example |
|--------|--------|---------|
| `C-c e *` | LSP (eglot) — all languages | `C-c e a` code actions |
| `C-c t *` | Tests — language-specific | `C-c t t` test at point |
| `C-c i *` | REPL / interactive — language-specific | `C-c i i` start REPL |
| `C-c d *` | Debug (dape) — global | `C-c d d` start debugger |

For detailed test and REPL keybinding granularity across languages, see `docs/prog-modules-design.md`.
