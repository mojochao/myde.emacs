# My Development Environment - Emacs

My Development Environment, or MyDE for short, is my personal Emacs configuration
for modern Emacs versions (minimum v30, compiled with native-compile support),
providing a consistent, convenient DX across Linux and macOS platforms.

## Installation

Run the following commands to install MyDE configuration into your local emacs
config directory, `~/.config/emacs` by default

```shell
git clone https://github.com/mojochao/myde.el
cd myde.el
make link
```

At this point, you should be able to launch Emacs, at which time packages
will be downloaded and configured as defined by this elisp configuration.

## Organization

MyDE uses a modular architecture where configuration is organized into self-contained modules under the `modules/` directory.

### Module categories

Modules follow a `<category>-<name>` naming convention:

- **`core-*`** — Core infrastructure and productivity tools (e.g. `core-base`, `core-ui`, `core-ux`, `core-complete`, `core-dashboard`, `core-projects`)
- **`ai-*`** — AI assistant integration (e.g. `ai-base`, `ai-gptel`, `ai-claude`)
- **`auth-*`** — Authentication and secrets (e.g. `auth-1password`)
- **`data-*`** — Data format modules (e.g. `data-csv`, `data-json`, `data-toml`, `data-xml`, `data-yaml`)
- **`prog-*`** — Programming language modules (e.g. `prog-base`, `prog-go`, `prog-rust`, `prog-zig`, `prog-python`, `prog-elixir`, `prog-elisp`)
- **`text-*`** — Text format modules (e.g. `text-markdown`)
- **`ebook-*`** — Ebook reader modules (e.g. `ebook-pdf`, `ebook-epub`)

### Module structure

Each module contains:
- `lib.el` — Library code (functions, variables, customizations)
- `cfg.el` — Configuration code (the public entry point)

### File conventions

**`lib.el`**
- Contains pure library code: `defun`, `defvar`, `defcustom`
- Does not require other modules (all utilities are distributed across modules)
- Provides a feature symbol: `(provide 'myde-<category>-<name>)`
- Hook functions must be defined here as named functions (e.g., `myde/foo-mode-hook`) — never use lambdas as hook functions

**`cfg.el`**
- Contains all configuration with side effects: `use-package` declarations, hooks, etc.
- Loads its own `lib.el` via a `featurep` guard
- Is the sole public entry point — `init.el` loads only `cfg.el`
- Provides a feature symbol: `(provide 'myde-<category>-<name>-cfg)`

### Feature naming

| Module path | lib.el feature | cfg.el feature |
|-------------|---|---|
| `modules/core-base/lib.el` | `myde-core-base` | `myde-core-base-cfg` |
| `modules/prog-go/lib.el` | `myde-prog-go` | `myde-prog-go-cfg` |
| `modules/core-dashboard/lib.el` | `myde-core-dashboard` | `myde-core-dashboard-cfg` |
| `modules/core-ui/lib.el` | `myde-core-ui` | `myde-core-ui-cfg` |
| `modules/text-markdown/lib.el` | `myde-text-markdown` | `myde-text-markdown-cfg` |
| `modules/ebook-pdf/lib.el` | `myde-ebook-pdf` | `myde-ebook-pdf-cfg` |

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

## External dependencies

Several modules require external tools on PATH (or at a known path). Install these before starting Emacs.

### LSP servers

| Module | Tool | Install |
|--------|------|---------|
| `data-json` | `vscode-json-language-server` | `npm install -g vscode-langservers-extracted` |
| `data-toml` | `taplo` | `brew install taplo` |
| `data-xml` | `lemminx` | See below |
| `prog-go` | `gopls` | `go install golang.org/x/tools/gopls@latest` |
| `prog-python` | `pylsp` / `pyright` | `pip install python-lsp-server` |
| `prog-rust` | `rust-analyzer` | `rustup component add rust-analyzer` |
| `prog-zig` | `zls` | `mise use -g zls` |

### Debuggers

| Module | Tool | Install |
|--------|------|---------|
| `prog-cpp` | `codelldb` | `mise use -g codelldb` |
| `prog-go` | `dlv` | `go install github.com/go-delve/delve/cmd/dlv@latest` |
| `prog-rust` | `codelldb` | `mise use -g codelldb` |
| `prog-zig` | `codelldb` | `mise use -g codelldb` |

### LemMinX (XML language server)

LemMinX is not available via Homebrew. It ships as a Java uber-JAR:

```shell
# Download the JAR
mkdir -p ~/.local/share/lemminx
curl -fL https://download.eclipse.org/lemminx/releases/0.31.1/org.eclipse.lemminx-uber.jar \
     -o ~/.local/share/lemminx/lemminx-0.31.1-uber.jar

# Create a wrapper script (requires Java — brew install openjdk)
mkdir -p ~/.local/bin
cat > ~/.local/bin/lemminx <<'EOF'
#!/bin/sh
exec /opt/homebrew/opt/openjdk/bin/java \
  -jar "$HOME/.local/share/lemminx/lemminx-0.31.1-uber.jar" "$@"
EOF
chmod +x ~/.local/bin/lemminx
```

### XML tree-sitter grammar

After first Emacs startup, install the XML tree-sitter grammar using the
MyDE wrapper (which installs to `$XDG_DATA_HOME/emacs/tree-sitter/` instead
of the repo root):

```
M-x myde/treesit-install-language-grammar RET xml RET
```
