# My Development Environment - Emacs

My Development Environment, or MyDE for short, is my personal Emacs configuration for modern Emacs versions (minimum v31.1, compiled with native-compile support), providing a consistent, convenient DX across Linux and macOS platforms.

## Installation

Run the following commands to install MyDE configuration into your local emacs configuration directory, `~/.config/emacs` by default.

```shell
git clone https://github.com/mojochao/myde.emacs
cd myde.emacs
make link
```

At this point, you should be able to launch Emacs. The first start clones and builds every package with [elpaca](https://github.com/progfolio/elpaca) into `./elpaca/`, which takes a few minutes; later starts only activate what is already built.

## Organization

MyDE is a literate configuration. `myde.org` is the only file edited by hand; it tangles into three committed elisp files:

| File                | Tangled from      | Role                                                                                  |
|---------------------|-------------------|---------------------------------------------------------------------------------------|
| `early-init.el`     | `* Early Init`    | Runs before `init.el`: GC and file-handler suppression, eln-cache redirection, frame defaults |
| `init.el`           | `* Bootstrap`     | Bootstraps elpaca, enables its `use-package` support, loads `user-lisp/myde.el`       |
| `user-lisp/myde.el` | `* Configuration` | All configuration, in load order, one `;;;; section` per former module               |

The tangled files are committed, so a fresh clone works without tangling and startup never loads org.

```shell
make tangle    # regenerate the three elisp files from myde.org
make check     # tangle, then fail if the committed files differ from myde.org
```

### Sections

Under `* Configuration`, sections are grouped by category and keep a `<category>-<name>` naming convention:

- **`core-*`** — Core infrastructure and productivity tools (e.g. `core-base`, `core-ui`, `core-ux`, `core-complete`, `core-dashboard`, `core-projects`)
- **`ai-*`** — AI assistant integration (e.g. `ai-base`, `ai-gptel`, `ai-claude`, `ai-mcp`)
- **`auth-*`** — Authentication and secrets (e.g. `auth-1password`)
- **`data-*`** — Data format sections (e.g. `data-csv`, `data-json`, `data-toml`, `data-xml`, `data-yaml`)
- **`containers-*`** — Container tooling (e.g. `containers-kubernetes`)
- **`prog-*`** — Programming language sections (e.g. `prog-base`, `prog-go`, `prog-rust`, `prog-zig`, `prog-python`, `prog-ruby`, `prog-elixir`, `prog-elisp`, `prog-lua`)
- **`text-*`** — Text format sections (e.g. `text-base`, `text-asciidoc`, `text-markdown`)
- **`ebook-*`** — Ebook reader sections (e.g. `ebook-pdf`, `ebook-epub`)

### Enabling sections: presence is intent

There are no toggles and nothing to customize. A section that needs a toolchain is wrapped in `(when (executable-find "<binary>") …)` and comes alive as soon as the binary is on `PATH`:

| Binary    | Section                            | Binary     | Section                 |
|-----------|------------------------------------|------------|-------------------------|
| `go`      | `prog-go`                          | `clangd`   | `prog-cpp`              |
| `cargo`   | `prog-rust`                        | `fish`     | `prog-fish`             |
| `zig`     | `prog-zig`                         | `nu`       | `prog-nushell`          |
| `lua`     | `prog-lua`                         | `sbcl`     | `prog-clisp`            |
| `ruby`    | `prog-ruby`                        | `guile`    | `prog-scheme`           |
| `python3` | `prog-python`                      | `clojure`  | `prog-clojure`          |
| `node`    | `prog-javascript`, `prog-typescript` | `erl`    | `prog-erlang`           |
| `elixir`  | `prog-elixir`                      | `pdftoppm` | `ebook-pdf`             |
| `op`      | `auth-1password`                   | `kubectl`  | `containers-kubernetes` |
| `claude`  | `ai-claude`                        |            |                         |

Everything else (all `core-*`, `data-*`, `text-*`, `prog-base`, `prog-bash`, `prog-elisp`, `ebook-epub`, and the non-gated `ai-*` sections) is always on. On macOS the login shell's `PATH` is imported during init by `exec-path-from-shell`, so GUI launches see the same binaries as a terminal.

### Packages

Packages are managed by elpaca with `use-package-always-ensure`. Third-party `use-package` forms need no `:ensure`; built-in packages say `:ensure nil`; packages that live only on git carry a recipe such as `:ensure (:host github :repo "owner/name")`. `M-x elpaca-manager` and `M-x elpaca-update-all` handle updates.

### Snippets

Snippets are managed by `core-snippets` (yasnippet + yasnippet-classic-snippets).
Language sections store custom snippets flat under `snippets/<language>/` with no mode-name subdirectory:

```text
snippets/go/func
snippets/go/iferr
snippets/elixir/defmodule
```

Each language section that has snippets registers them at its bottom:

```elisp
(myde-register-snippets
 (expand-file-name "snippets/go" user-emacs-directory)
 'go-ts-mode)
```

`myde-register-snippets` is defined in the `core-snippets` section.

### Keybinding conventions

Language sections follow consistent keybinding prefixes:

| Prefix    | Domain                                 | Example                  |
|-----------|----------------------------------------|--------------------------|
| `C-c e *` | LSP (eglot) — all languages            | `C-c e a` code actions   |
| `C-c t *` | Tests — language-specific              | `C-c t t` test at point  |
| `C-c i *` | REPL / interactive — language-specific | `C-c i i` start REPL     |
| `C-c d *` | Debug (dape) — global                  | `C-c d d` start debugger |

For detailed test and REPL keybinding granularity across languages, see `docs/prog-modules-design.md`.

## External dependencies

Several sections require external tools on PATH (or at a known path). Install these before starting Emacs.

### LSP servers

| Section       | Tool                          | Install                                       |
|---------------|-------------------------------|-----------------------------------------------|
| `data-json`   | `vscode-json-language-server` | `npm install -g vscode-langservers-extracted` |
| `data-toml`   | `taplo`                       | `brew install taplo`                          |
| `data-xml`    | `lemminx`                     | See below                                     |
| `prog-go`     | `gopls`                       | `go install golang.org/x/tools/gopls@latest`  |
| `prog-lua`    | `lua-language-server`         | `brew install lua-language-server`            |
| `prog-python` | `pylsp` / `pyright`           | `pip install python-lsp-server`               |
| `prog-ruby`   | `ruby-lsp`                    | `gem install ruby-lsp`                        |
| `prog-rust`   | `rust-analyzer`               | `rustup component add rust-analyzer`          |
| `prog-zig`    | `zls`                         | `mise use -g zls`                             |

### Debuggers

| Section     | Tool       | Install                                               |
|-------------|------------|-------------------------------------------------------|
| `prog-cpp`  | `codelldb` | `mise use -g codelldb`                                |
| `prog-go`   | `dlv`      | `go install github.com/go-delve/delve/cmd/dlv@latest` |
| `prog-ruby` | `rdbg`     | `gem install debug`                                   |
| `prog-rust` | `codelldb` | `mise use -g codelldb`                                |
| `prog-zig`  | `codelldb` | `mise use -g codelldb`                                |

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

```text
M-x myde-treesit-install-language-grammar RET xml RET
```
