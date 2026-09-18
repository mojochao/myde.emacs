# My Development Environment - Emacs

My Development Environment, or MyDE for short, is my personal Emacs configuration for modern Emacs versions (minimum v31.1, compiled with native-compile support), providing a consistent, convenient DX across Linux and macOS platforms.

## Installation

Run the following commands to install MyDE configuration into your local emacs configuration directory, `~/.config/emacs` by default.

```shell
git clone https://github.com/mojochao/myde.emacs
cd myde.emacs
mise trust
mise run init
```

`mise trust` is needed once per machine — mise refuses to read an untrusted config, and trust is machine-local state. `mise run init` symlinks the repo into `~/.config/emacs` and installs the git hooks.

At this point, you should be able to launch Emacs. The first start clones and builds every package with [elpaca](https://github.com/progfolio/elpaca) into `./elpaca/`, which takes a few minutes; later starts only activate what is already built, reaching the end of init in roughly four seconds.

## Tasks

Tasks live in `mise.toml`; `mise tasks` lists them all.

| Task                       | What it does                                                               |
|----------------------------|----------------------------------------------------------------------------|
| `mise run init`            | Set up this repo on a new machine (`link` + `hk install`)                  |
| `mise run link` / `unlink` | Add or remove the `~/.config/emacs` symlink                                |
| `mise run tangle`          | Regenerate `early-init.el`, `init.el`, `user-lisp/myde.el` from `myde.org` |
| `mise run forms`           | Assert `user-lisp/myde.el` contains only definitions                       |
| `mise run check`           | Tangle, then fail if the committed elisp differs from `myde.org`           |
| `mise run test`            | Run the ERT checks under `tests/` in batch mode                            |
| `mise run probe <report>`  | Boot this config as a throwaway daemon and report its state                |
| `mise run docs`            | Serve `docs/` as a live-reloading site on http://localhost:3000            |
| `mise run install-xdg`     | Register the `org-protocol://` URI handler (Linux)                         |
| `mise run install-macos`   | Register the `org-protocol://` URI handler (macOS)                         |

There is no build or lint step. `test` and `probe` stand in for one, and they catch
different kinds of failure. The ERT tests cover logic that fails *silently* — an invalid
`#+filetags:` value that makes tag search return nothing, a missing `#+category:` that
makes every project's tasks file show up in the agenda as "tasks". The probe boots the
config as an isolated throwaway daemon (unique socket, `PATH` stripped to `/usr/bin:/bin`,
private `XDG_STATE_HOME`) and writes a report of the declared `use-package` forms, the
global modes enabled at startup, init time, and startup errors. Run it before and after a
change and diff the `declared:` and `mode:` lines; a package that disappears or a mode
that flips to `off` is a regression.

### Git hooks

Hooks are [hk](https://hk.jdx.dev)'s, defined in `hk.pkl` and installed by `mise run
init`. `hk install` uses git's config-based hooks (2.54+), so `.git/hooks` stays empty.

**pre-commit re-tangles rather than rejecting**: it runs `mise run tangle` as a fix step
and stages the three tangled files, so `myde.org` and its output cannot drift apart in a
commit. It then runs `forms` and `test`. pre-push verifies without rewriting anything, as
a backstop for `--no-verify`. `hk check` and `hk fix` run the same steps by hand.

## Organization

MyDE is a literate configuration. `myde.org` is the only file edited by hand; it tangles into three committed elisp files:

| File                | Tangled from                                                 | Role                                                                                                                                                     |
|---------------------|--------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `early-init.el`     | `* Early Init`                                               | Runs before `init.el`: GC and file-handler suppression, eln-cache redirection, frame defaults                                                            |
| `init.el`           | `* Bootstrap` and the activation blocks of `* Configuration` | Installs elpaca, `(require 'myde)`, then every `use-package` form, binary gate, and variable assignment in load order                                    |
| `user-lisp/myde.el` | The definition blocks of `* Configuration`                   | Definitions only — `defun`, `defvar`, `defcustom`, `defconst`, `define-derived-mode`, `define-minor-mode`. No side effects, asserted by `mise run forms` |

The tangled files are committed, so a fresh clone works without tangling and startup never loads org. **Never edit the three elisp files directly** — `mise run tangle` overwrites them.

Each section's `***` heading holds up to two blocks: definitions, carrying `:tangle
user-lisp/myde.el`, and activation, inheriting `:tangle init.el`. `defun` and `defvar` go
in the first; `use-package`, `setq`, and `add-hook` go in the second.

### Sections

Under `* Configuration`, sections are grouped by category and keep a `<category>-<name>` naming convention:

- **`core-*`** — infrastructure and productivity: `core-base`, `core-ui`, `core-ux`, `core-org`, `core-help`, `core-terminals`, `core-dashboard`, `core-complete`, `core-notes`, `core-snippets`, `core-projects`, `core-spell`
- **`ai-*`** — AI assistant integration: `ai-base`, `ai-gptel`, `ai-agents`, `ai-claude`, `ai-mcp`
- **`auth-*`** — authentication and secrets: `auth-1password`
- **`data-*`** — data formats: `data-csv`, `data-dotenv`, `data-hcl`, `data-json`, `data-pkl`, `data-toml`, `data-xml`, `data-yaml`
- **`containers-*`** — container tooling: `containers-kubernetes`
- **`prog-*`** — programming languages: `prog-base`, `prog-bash`, `prog-fish`, `prog-nushell`, `prog-elisp`, `prog-clisp`, `prog-scheme`, `prog-clojure`, `prog-erlang`, `prog-elixir`, `prog-cpp`, `prog-go`, `prog-rust`, `prog-zig`, `prog-python`, `prog-ruby`, `prog-lua`, `prog-javascript`, `prog-typescript`
- **`text-*`** — text formats: `text-base`, `text-asciidoc`, `text-markdown`
- **`ebook-*`** — ebook readers: `ebook-epub`, `ebook-pdf`

### Enabling sections: presence is intent

There are no toggles and nothing to customize. A section that needs a toolchain is wrapped in `(when (executable-find "<binary>") …)` and comes alive as soon as the binary is on `PATH`:

| Binary    | Section                              | Binary     | Section                 |
|-----------|--------------------------------------|------------|-------------------------|
| `go`      | `prog-go`                            | `clangd`   | `prog-cpp`              |
| `cargo`   | `prog-rust`                          | `fish`     | `prog-fish`             |
| `zig`     | `prog-zig`                           | `nu`       | `prog-nushell`          |
| `lua`     | `prog-lua`                           | `sbcl`     | `prog-clisp`            |
| `ruby`    | `prog-ruby`                          | `guile`    | `prog-scheme`           |
| `python3` | `prog-python`                        | `clojure`  | `prog-clojure`          |
| `node`    | `prog-javascript`, `prog-typescript` | `erl`      | `prog-erlang`           |
| `elixir`  | `prog-elixir`                        | `pdftoppm` | `ebook-pdf`             |
| `op`      | `auth-1password`                     | `kubectl`  | `containers-kubernetes` |
| `claude`  | `ai-claude`                          |            |                         |

Everything else (all `core-*`, `data-*`, `text-*`, `prog-base`, `prog-bash`, `prog-elisp`, `ebook-epub`, and the non-gated `ai-*` sections) is always on. On macOS the login shell's `PATH` is imported during init by `exec-path-from-shell`, so GUI launches see the same binaries as a terminal.

The gate lives in `init.el` and wraps the whole `use-package` form — elpaca queues a
package order when the form is *expanded*, so a `:if` inside the form cannot prevent a
clone. Definitions in `user-lisp/myde.el` are unconditional: a `myde-prog-go-*` function
exists whether or not `go` is installed, and nothing calls it unless the gate passed.

### Packages

Packages are managed by elpaca with `use-package-always-ensure`. Third-party `use-package` forms need no `:ensure`; built-in packages say `:ensure nil`; packages that live only on git carry a recipe such as `:ensure (:host github :repo "owner/name")`. `M-x elpaca-manager` and `M-x elpaca-update-all` handle updates, and `M-x elpaca-log` shows build status.

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

Sections follow consistent keybinding prefixes:

| Prefix    | Domain                                 | Example                  |
|-----------|----------------------------------------|--------------------------|
| `C-c o *` | Org — agenda, capture, notes, tags     | `C-c o a` agenda         |
| `C-c e *` | LSP (eglot) — all languages            | `C-c e a` code actions   |
| `C-c t *` | Tests — language-specific              | `C-c t t` test at point  |
| `C-c i *` | REPL / interactive — language-specific | `C-c i i` start REPL     |
| `C-c d *` | Debug (dape) — global                  | `C-c d d` start debugger |

For detailed test and REPL keybinding granularity across languages, see `docs/prog-modules-design.md`.

### XDG paths

Nothing but packages is written inside `user-emacs-directory`:

| Kind                                               | Path                     |
|----------------------------------------------------|--------------------------|
| State (recentf, places, history, tramp, bookmarks) | `$XDG_STATE_HOME/emacs/` |
| Data (transient, tree-sitter, forge)               | `$XDG_DATA_HOME/emacs/`  |
| Cache (eln-cache, url)                             | `$XDG_CACHE_HOME/emacs/` |
| Packages (elpaca)                                  | `./elpaca/` (repo root)  |

## Org workflow

`core-org` and `core-notes` implement task management and note-taking. The org tree
under `~/org/` — `inbox.org`, `archive/`, `notes/` — is created on first start.

**A project is any directory containing a `tasks.org`.** There is no fixed root and no
naming convention; the file is located by searching upward from the current directory.
`myde-org-code-directory` (`~/devel/projects/` by default) is scanned to build
`org-agenda-files`, so a project outside it still works for capture and visiting — it
just is not in the agenda. The scan prunes dot-directories and `node_modules`, which
also keeps archived projects parked in `.ATTIC/` out of the agenda.

| Key         | Command                                                                 |
|-------------|-------------------------------------------------------------------------|
| `C-c o a`   | Agenda (rescans for tasks files first)                                  |
| `C-c o c`   | Capture                                                                 |
| `C-c o p`   | Visit the current project's `tasks.org`, creating one if absent         |
| `C-c o P`   | Always prompt to create a `tasks.org`                                   |
| `C-c o t`   | Tag cloud — every tag in use, by frequency                              |
| `C-c o T`   | Multi-tag search                                                        |
| `C-c o n n` | New denote note (`l` link, `b` backlinks, `f` open or create, `s` grep) |

Capture templates: `t` task to the inbox, `T` task to the current project, `h` tagged
thought, `b` tagged bookmark from the browser, `n` denote note, `N` denote note from the
browser.

The last two arrive over `org-protocol`, which needs a system URI handler —
`mise run install-xdg` on Linux, `mise run install-macos` on macOS — plus a browser
bookmarklet. See `docs/org-protocol-setup.md` for both, and `docs/org-workflow-design.md`
for the design.

## Running as a daemon

The intended setup is one `emacs --fg-daemon` started at login, with every GUI frame
coming from `emacsclient -c`. `$EDITOR` and `$VISUAL` point at `emacsclient`, so they
reach the same process.

**Do not launch Emacs.app alongside the daemon.** Two processes on this config fight over
three singletons: the `server` socket (the daemon wins, so the app silently skips
`server-start` and `$EDITOR` opens files in a process with no visible frame), the
`mcp-server` socket under `$XDG_CACHE_HOME/emacs/`, and the XDG state files, which are
last-writer-wins.

Because a daemon has no frame to render against at startup, the dashboard is installed as
`initial-buffer-choice` and each client frame draws its own. A direct `emacs` launch keeps
dashboard's usual startup-hook path.

On macOS, restart the daemon after a config change with:

```shell
launchctl kickstart -k gui/$(id -u)/gnu.emacs.daemon
```

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

### Emacs MCP server (`ai-mcp`)

The `ai-mcp` section runs an MCP server inside Emacs on a Unix socket at
`$XDG_CACHE_HOME/emacs/emacs-mcp-server.sock`, exposing live Emacs state
(`eval-elisp`, diagnostics, Org tools) to agents. It needs `socat`
(`brew install socat`). Register the stdio bridge once:

```shell
claude mcp add emacs --scope user -- \
  socat - UNIX-CONNECT:$HOME/.cache/emacs/emacs-mcp-server.sock
```

The server starts from `elpaca-after-init`, and
`mcp-server-socket-conflict-resolution` is `force` so the socket path stays
fixed — the bridge above hardcodes it. If the bridge reports
`CONNECTION_CLOSED`, the Emacs side is down: check with `M-x mcp-server-status`
and restart with `M-x mcp-server-start-unix`.

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

## Documentation

| Document                                  | Covers                                           |
|-------------------------------------------|--------------------------------------------------|
| `AGENTS.md`                               | Repo conventions, in the form agents read        |
| `docs/org-workflow-design.md`             | The task, note, and tag design behind `core-org` |
| `docs/org-protocol-setup.md`              | URI handler and browser bookmarklet setup        |
| `docs/prog-modules-design.md`             | Per-language test and REPL keybinding layout     |
| `docs/elixir-developer-guide.md`          | Elixir tooling, tests, and debugging             |
| `docs/projectile-to-project-migration.md` | Notes from the move to built-in `project.el`     |
