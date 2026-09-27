# User Guide

## 1. Summary

MyDE is a personal Emacs configuration for Emacs 31.1 and later, compiled with native-compile support.
It targets Linux and macOS from the same source.
This guide covers installing it, turning on languages and tools, and the ideas behind how it is organized.

## 2. Onboarding

### 2.1 Prerequisites

Install these before the first start.

| Requirement | Needed for |
|---|---|
| Emacs 31.1 or later, compiled with native-compile support | The whole config, `user-lisp-directory` does not exist before 31.1 |
| mise | Every task in `mise.toml`, including install and tangle |
| git 2.54 or later | hk's config-based git hooks |
| `socat` | The Emacs MCP server's stdio bridge |
| GNU `ls` (`gls`, from `coreutils`), on macOS | Dired's `--group-directories-first` |

### 2.2 Install

```sh
git clone https://github.com/mojochao/myde.emacs
cd myde.emacs
mise trust
mise run init
```

`mise trust` is needed once per machine.
mise refuses to read an untrusted config, and trust is machine-local state.
`mise run init` symlinks the repo into `~/.config/emacs` and installs the git hooks.

At this point Emacs is ready to start.
The first start clones and builds every package with [elpaca](https://github.com/progfolio/elpaca) into `./elpaca/`.
That takes a few minutes.
Later starts only activate what is already built, reaching the end of init in roughly four seconds.

### 2.3 Run as a daemon

The intended setup is one `emacs --fg-daemon` process, started at login by a launchd agent (`RunAtLoad` plus `KeepAlive`).
Every GUI frame comes from `emacsclient -c`.
`~/Applications/Emacsclient.app` wraps `emacsclient -c -n -a ""` in a two-line shell script for the Dock.
It carries Emacs' own icon, so the Dock tile looks like Emacs but never starts a second process.
The Dock's persistent-apps entry must point at it, not at `/Applications/Emacs.app`.
`$EDITOR` and `$VISUAL` are already `emacsclient`, so they reach the same daemon.

Restart the daemon after a config change:

```sh
launchctl kickstart -k gui/$(id -u)/gnu.emacs.daemon
```

Verify through `emacsclient`.
It always talks to the daemon.
Anything that only exists in a window-system frame has to be confirmed by creating one.

> Never launch Emacs.app alongside the daemon.
> Two processes fight over three singletons: the `server` socket, the `mcp-server` Unix socket under `$XDG_CACHE_HOME/emacs/`, and the XDG state files (`recentf.eld`, `places.eld`, `history`).
> The daemon wins the socket race, so the app silently skips `server-start` and `$EDITOR` opens files in a process with no visible frame.
> The state files are last-writer-wins.

### 2.4 Turn on a language

There are no module toggles, no override list, and no `custom.el` entries for sections.
A section that needs a toolchain is wrapped in `(when (executable-find "<binary>") ...)`.
Installing the binary turns the section on at the next start.
Removing the binary turns it off.

| Binary    | Section                              | Binary     | Section                 |
|-----------|---------------------------------------|------------|--------------------------|
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

Everything else (every `core-*` section, every `data-*` section, every `text-*` section, `prog-base`, `prog-bash`, `prog-elisp`, `ebook-epub`, and the non-gated `ai-*` sections) is always on.
On macOS, the login shell's `PATH` is imported during init by `exec-path-from-shell`, so a GUI launch sees the same binaries as a terminal.

### 2.5 Language servers and debuggers

Several sections need a tool beyond the gating binary itself.
Install these before using the feature.

#### LSP servers

| Section       | Tool                          | Install                                       |
|---------------|--------------------------------|------------------------------------------------|
| `data-json`   | `vscode-json-language-server` | `npm install -g vscode-langservers-extracted` |
| `data-toml`   | `taplo`                       | `brew install taplo`                          |
| `data-xml`    | `lemminx`                     | See below                                     |
| `prog-go`     | `gopls`                       | `go install golang.org/x/tools/gopls@latest`  |
| `prog-lua`    | `lua-language-server`         | `brew install lua-language-server`            |
| `prog-python` | `basedpyright-langserver`     | `pip install basedpyright`                    |
| `prog-ruby`   | `ruby-lsp`                    | `gem install ruby-lsp`                        |
| `prog-rust`   | `rust-analyzer`               | `rustup component add rust-analyzer`          |
| `prog-zig`    | `zls`                         | `mise use -g zls`                             |

`prog-cpp` needs no separate LSP install: `clangd`, the section's gate binary, is the language server.

#### Debuggers

| Section     | Tool       | Install                                               |
|-------------|------------|---------------------------------------------------------|
| `prog-cpp`  | `codelldb` | `mise use -g codelldb`                                |
| `prog-go`   | `dlv`      | `go install github.com/go-delve/delve/cmd/dlv@latest` |
| `prog-ruby` | `rdbg`     | `gem install debug`                                   |
| `prog-rust` | `codelldb` | `mise use -g codelldb`                                |
| `prog-zig`  | `codelldb` | `mise use -g codelldb`                                |

#### LemMinX

LemMinX is not available through Homebrew.
It ships as a Java uber-JAR.

```sh
# Download the JAR
mkdir -p ~/.local/share/lemminx
curl -fL https://download.eclipse.org/lemminx/releases/0.31.1/org.eclipse.lemminx-uber.jar \
     -o ~/.local/share/lemminx/lemminx-0.31.1-uber.jar

# Create a wrapper script (requires Java, brew install openjdk)
mkdir -p ~/.local/bin
cat > ~/.local/bin/lemminx <<'EOF'
#!/bin/sh
exec /opt/homebrew/opt/openjdk/bin/java \
  -jar "$HOME/.local/share/lemminx/lemminx-0.31.1-uber.jar" "$@"
EOF
chmod +x ~/.local/bin/lemminx
```

#### XML tree-sitter grammar

After the first Emacs startup, install the XML tree-sitter grammar with the MyDE wrapper.
It installs to `$XDG_DATA_HOME/emacs/tree-sitter/` instead of the repo root.

```text
M-x myde-treesit-install-language-grammar RET xml RET
```

### 2.6 Browser capture

`org-protocol` lets the browser send a URL, page title, and any selected text to a running Emacs session.
That triggers the `b` capture template and appends a tagged bookmark to `~/org/inbox.org`.
Two things are required: a system-level URI handler and a browser bookmarklet.

#### Linux

The desktop file is included in this repo.
Install it with:

```sh
mise run install-xdg
```

Verify registration:

```sh
xdg-open "org-protocol://capture?template=b&url=https%3A%2F%2Fexample.com&title=Example"
```

A running Emacs, with `emacsclient`'s server started, should open the capture buffer.

> Emacs must be running with a server.
> Add `(server-start)` to your config if it is not already present, or start Emacs with `emacs --daemon`.

#### macOS

Run:

```sh
mise run install-macos
```

This builds a minimal `~/Applications/OrgProtocol.app` whose only job is to forward `org-protocol://` URIs to `emacsclient`, then registers it with LaunchServices.
It uses `osacompile`, `plutil`, and `codesign`, all of which ship with macOS.
No Automator app and no Xcode are needed.

Two details are easy to get wrong by hand.

- AppleScript is required, not a stylistic choice.
  macOS delivers URI activations as Apple Events rather than as command-line arguments, so a plain shell script inside a bundle never receives the URL.
- The bundle must be re-signed.
  `osacompile` ad-hoc signs the bundle, and editing `Info.plist` to add `CFBundleURLTypes` invalidates that signature.
  Without the `codesign --force --sign -` step, `codesign -v` reports `invalid Info.plist (plist or signature have been modified)`.

Verify registration:

```sh
codesign -v ~/Applications/OrgProtocol.app && echo "signature valid"
open "org-protocol://capture?template=b&url=https%3A%2F%2Fexample.com&title=Example"
```

Remove it with `mise run uninstall-macos`.

#### Browser bookmarklet

A bookmarklet is more reliable than an extension.
It builds the `org-protocol://capture` URL directly, with no intermediary, and cannot break when an extension API changes.

Create a new bookmark in Chrome or Firefox with the following as the URL:

```javascript
javascript:location.href='org-protocol://capture?template=b&url='+encodeURIComponent(location.href)+'&title='+encodeURIComponent(document.title)+'&body='+encodeURIComponent(window.getSelection())
```

Setup steps:

1. Show the bookmarks bar (`Ctrl+Shift+B` in Chrome, `Cmd+Shift+B` on macOS).
2. Right-click the bookmarks bar and choose **Add page…** (Chrome) or **New Bookmark** (Firefox).
3. Set **Name** to something short, for example `Org Capture`.
4. Set **URL** to the `javascript:` snippet above.
5. Save.

Navigate to any page, optionally select text, then click the bookmarklet.
Emacs raises and opens the capture buffer, pre-filled with the URL, the title, and any selected text, and prompts for tags.

> Chrome blocks `javascript:` bookmarklets from running on `chrome://` pages and Chrome Web Store pages.
> They work on all normal websites.

For a page worth more than a bookmark, use template `N` instead of `b` in the bookmarklet URL.
That routes the capture into a denote note under `~/org/notes/`, prompting for denote keywords and seeding the title from the page title.

#### Verify it works end to end

1. Start Emacs: `emacs --daemon` (or make sure a server is running).
2. Navigate to any page in your browser.
3. Click the bookmarklet.
4. Emacs raises and opens an org-capture buffer, pre-filled with the URL and page title in the `b` (bookmark) template, and prompts for tags.
5. Enter tags, add any extra notes, then `C-c C-c` to save.

The entry lands in `~/org/inbox.org` as:

```org
* [[https://example.com][Example Domain]]              :bookmark:reading:
  :PROPERTIES:
  :CREATED: [2026-08-05 Wed 14:30]
  :END:
  any text selected in the browser
```

Tag completion covers every tag already present across `org-agenda-files`.
The `:bookmark:` tag is applied automatically, and any tags entered at the prompt are appended to it.

### 2.7 Emacs MCP server

The `ai-mcp` section runs an MCP server inside Emacs on a Unix socket at `$XDG_CACHE_HOME/emacs/emacs-mcp-server.sock`.
It exposes live Emacs state (`eval-elisp`, diagnostics, Org tools) to agents.
It needs `socat` (`brew install socat`).
Register the stdio bridge once:

```sh
claude mcp add emacs --scope user -- \
  socat - UNIX-CONNECT:$HOME/.cache/emacs/emacs-mcp-server.sock
```

The server starts from `elpaca-after-init` on a fixed socket path, because the bridge above hardcodes it.
A socket left behind by a dead daemon is reclaimed as stale.
`mcp-server-socket-conflict-resolution` is `error`.
A second Emacs on this config (Emacs.app launched by mistake, or `mise run probe`) leaves a live daemon's socket alone.
It starts without an MCP server.

If the bridge reports `CONNECTION_CLOSED`, restart the server in the daemon:

```sh
emacsclient --eval '(progn (ignore-errors (mcp-server-stop)) (mcp-server-start-unix))'
```

Then reconnect with `/mcp`.

## 3. Key concepts

### 3.1 Sections

Under `* Configuration` in `myde.org`, sections are grouped by category and follow a `<category>-<name>` naming convention.

| Category | Sections |
|---|---|
| `core-*` | infrastructure and productivity: `core-base`, `core-ui`, `core-ux`, `core-org`, `core-help`, `core-terminals`, `core-dashboard`, `core-complete`, `core-notes`, `core-snippets`, `core-projects`, `core-spell` |
| `ai-*` | AI assistant integration: `ai-base`, `ai-gptel`, `ai-agents`, `ai-claude`, `ai-mcp` |
| `auth-*` | authentication and secrets: `auth-1password` |
| `data-*` | data formats: `data-csv`, `data-dotenv`, `data-hcl`, `data-json`, `data-pkl`, `data-toml`, `data-xml`, `data-yaml` |
| `containers-*` | container tooling: `containers-kubernetes` |
| `prog-*` | programming languages: `prog-base`, `prog-bash`, `prog-fish`, `prog-nushell`, `prog-elisp`, `prog-clisp`, `prog-scheme`, `prog-clojure`, `prog-erlang`, `prog-elixir`, `prog-cpp`, `prog-go`, `prog-rust`, `prog-zig`, `prog-python`, `prog-ruby`, `prog-lua`, `prog-javascript`, `prog-typescript` |
| `text-*` | text formats: `text-base`, `text-asciidoc`, `text-markdown` |
| `ebook-*` | ebook readers: `ebook-epub`, `ebook-pdf` |

There are no toggles and nothing to customize.
See [2.4](#_24-turn-on-a-language) for the full binary-to-section table, and the gating rules behind it.

The gate wraps the whole `use-package` form.
elpaca queues a package order when the form is expanded, before `:if` or `:when` is evaluated, so a keyword inside the form cannot prevent a clone.
Definitions in `user-lisp/myde.el` are unconditional.
A function such as `myde-prog-go-run-tests` exists whether or not `go` is installed.
Nothing calls it unless the gate passed.

### 3.2 Keybinding prefixes

Sections follow consistent keybinding prefixes.

| Prefix    | Domain                                 | Example                  |
|-----------|------------------------------------------|---------------------------|
| `C-c o *` | Org: agenda, capture, notes, tags      | `C-c o a` agenda         |
| `C-c e *` | LSP (eglot), all languages             | `C-c e a` code actions   |
| `C-c t *` | Tests, language-specific               | `C-c t t` test at point  |
| `C-c i *` | REPL or interactive, language-specific | `C-c i i` start REPL     |
| `C-c d *` | Debug (dape), global                   | `C-c d d` start debugger |

`C-c g` is not a shared prefix.
Only one binding lives under it: `C-c g b` runs `blamer-mode`.
No `C-c g` binding opens magit.

### 3.3 Projects

A project is any directory containing a `tasks.org`.
There is no fixed root and no naming convention.
Capture and visiting locate a project by searching upward from the current directory.
`myde-org-code-directory` (`~/devel/projects/` by default) is scanned to build `org-agenda-files`.
A project outside it still works for capture and visiting.
It just does not appear in the agenda.
The scan skips dot-directories and `node_modules`, which also keeps an archived project parked in `.ATTIC/` out of the agenda.

| Key | Command | Does |
|---|---|---|
| `C-c o p` | `myde-org-visit-project-tasks` | Visit this project's `tasks.org`, creating one if absent |
| `C-c o P` | `myde-org-create-project-tasks` | Create a `tasks.org` in a chosen directory |
| `C-c o t` | `myde-org-tag-cloud` | List every tag in use, by frequency |
| `C-c o T` | `myde-org-search-tags` | Pick tags with completion, show the matching agenda |
| `C-c o c` | `org-capture` | Open the capture menu |
| `C-c o a` | `org-agenda` | Open the agenda dispatcher |

Capture templates, from `C-c o c`:

| Key | Template | Goes to |
|---|---|---|
| `t` | Task | `~/org/inbox.org` |
| `T` | Task in current project | the nearest `tasks.org`, falling back to the inbox if none is found |
| `h` | Thought, tagged | `~/org/inbox.org` |
| `b` | Bookmark, tagged, from the browser | `~/org/inbox.org` |
| `n` | Note (Denote) | `~/org/notes/` |
| `N` | Note from the browser (Denote) | `~/org/notes/` |

A missing `#+category:` makes a project's tasks show up in the agenda under the generic name `tasks`.
Org falls back to the file name when `#+category:` is missing, and every project's file is named `tasks.org`.
`#+filetags:` tags every entry in the file, so a tag search for the project returns all of it.
Hyphens and dots are not legal in org tags, so `myde-org-sanitize-tag` replaces them with underscores: `scitech-idp` becomes `scitech_idp`.

### 3.4 Where files live

Nothing but packages is written inside `user-emacs-directory`.

| Kind                                                               | Path                     |
|----------------------------------------------------------------------|---------------------------|
| State (recentf, places, history, tramp, bookmarks, auto-save-list) | `$XDG_STATE_HOME/emacs/` |
| Data (transient, tree-sitter, forge)                               | `$XDG_DATA_HOME/emacs/`  |
| Cache (eln-cache, url)                                              | `$XDG_CACHE_HOME/emacs/` |
| Packages (elpaca)                                                   | `./elpaca/` (repo root)  |

Org and Denote files live outside `user-emacs-directory` too:

```text
~/org/
├── inbox.org              # everything captured that has no project
├── notes/                 # Denote notes
└── archive/               # completed items, <file>.org_archive

~/devel/projects/<project>/tasks.org    # per-project tasks, beside the code
```

`myde-org-ensure-tree` creates `~/org/`, `~/org/archive/`, and `inbox.org` on first start, if they are missing.
`tasks.org` is listed in the global gitignore (`~/.gitignore`), so it does not show up in `git status` for a shared repo.
Use `git add -f tasks.org` to commit one on purpose.

## 4. Usage and workflows

### 4.1 Org and notes

Org handles tasks, thoughts, bookmarks, and durable notes across the files and directories described in [3.4](#_34-where-files-live).

#### 4.1.1 Capturing

`C-c o c` opens the capture menu, then one more key picks a template.

| Key | Captures | Files into |
|---|---|---|
| `t` | Task | `~/org/inbox.org` |
| `T` | Task in the current project | the nearest `tasks.org`, falling back to the inbox |
| `h` | Thought | `~/org/inbox.org` |
| `b` | Bookmark, tagged, from the browser | `~/org/inbox.org` |
| `n` | Note (Denote) | `~/org/notes/` |
| `N` | Note from the browser (Denote) | `~/org/notes/` |

Finish a capture with `C-c C-c`, or abandon it with `C-c C-k`.
Templates `b` and `N` need the `org-protocol` setup in [2.6](#_26-browser-capture).
Template `T` files under a `Tasks` heading, creating one at the end of the file if it is missing.

#### 4.1.2 The agenda and task states

`C-c o a` opens the agenda dispatcher.
Press `d` for the day view built for this setup.

| Block | Shows |
|---|---|
| Today | today's scheduled items and deadlines, warning 14 days ahead |
| Next actions | every entry marked `NEXT`, across all files |
| `Inbox — needs refiling` | `TODO`/`NEXT` items still sitting in the inbox |

The rest of the dispatcher is stock Org, not configured here.

| Key | Shows |
|---|---|
| `C-c o a a` | Agenda for the current day or week |
| `C-c o a t` | The global TODO list |
| `C-c o a m` | Headlines matching a tag or property condition |
| `C-c o a s` | Full-text search across agenda files |

Inside an agenda buffer:

| Key | Does |
|---|---|
| `RET` | Jump to the item |
| `TAB` | Peek at the item in another window |
| `t` | Cycle its TODO state |
| `C-c C-s` | Schedule |
| `C-c C-d` | Set a deadline |
| `C-c C-w` | Refile |
| `r` | Rebuild the view |
| `q` | Quit |

Task states:

```text
TODO → NEXT → WAIT → DONE / CANCELLED
```

| State | Meaning | Key |
|---|---|---|
| `TODO` | Captured, not yet actionable | `t` |
| `NEXT` | The thing to do next | `n` |
| `WAIT` | Blocked on someone else | `w` |
| `DONE` | Finished | `d` |
| `CANCELLED` | Dropped | `c` |

Cycle with `C-c C-t` in a file, or `t` in the agenda.
Entering `WAIT` prompts for a note and logs a timestamp on exit.
Entering `DONE` logs a timestamp.
Entering `CANCELLED` prompts for a note.

#### 4.1.3 Finding things by tag

Two commands cover org tags: thoughts, bookmarks, and the `#+filetags:` on a project's `tasks.org` (see [3.3](#_33-projects)).
Denote keywords are a separate namespace, searched with `C-c o n s` instead.

`C-c o t` lists every tag in use, most-used first, with an entry count and a file count per tag.
Press `RET` to search the tag on the current line, `s` to search a combination of tags, `g` to rescan, or `q` to quit.

`C-c o T` reads one or more tags with completion over every tag in use.
By default it matches entries carrying all of the given tags.
Add a prefix argument (`C-u`) before it to match any of them instead.
A match is required, so a typo cannot silently return an empty agenda.

#### 4.1.4 Notes with denote

Denote is for durable notes, the kind worth finding again later.

| Key | Command | Does |
|---|---|---|
| `C-c o n n` | `denote` | New note, prompting for a title then keywords |
| `C-c o n l` | `denote-link` | Insert a link to another note |
| `C-c o n b` | `denote-backlinks` | Show notes linking to this one |
| `C-c o n f` | `denote-open-or-create` | Open a note by name, creating it if absent |
| `C-c o n s` | `denote-grep` | Search note contents |

Notes live in `~/org/notes/`.
Keyword completion offers every keyword already in use plus a preset list: `paper`, `book`, `research`, `distributed-systems`, `kubernetes`, `consensus`, `raft`.
Typing any other keyword works too.
Denote itself loads lazily, on first use, but its capture templates (`n` and `N`) are on the `C-c o c` menu from startup.

#### 4.1.5 Refiling and archiving

Refile moves an item to its real home: `C-c C-w`, then pick a target.
Targets are any heading up to three levels deep across the inbox and every project's `tasks.org`.
This is how the inbox gets drained.

Archive moves finished work out of the agenda: `C-c C-x C-a`.
It goes to `~/org/archive/<file>.org_archive` (see [3.4](#_34-where-files-live)), off the agenda but still on disk and greppable.

#### 4.1.6 Org Babel

Code blocks in an org file run without a confirmation prompt, since `org-confirm-babel-evaluate` is off.

| Language | Gate |
|---|---|
| Emacs Lisp | none, org's own default |
| Shell (bash) | none |
| Shell (fish, via a `#!/usr/bin/env fish` shebang) | `fish` |
| Common Lisp | `sbcl` |
| Scheme | `guile` |
| Clojure | `clojure` |
| C | `clangd` |
| Zig | `zig` |
| Python | `python3` |
| Ruby | `ruby` |
| Lua | `lua` |
| JavaScript | `node` |
| TypeScript | `node` |
| Erlang | `erl` |
| Elixir | `elixir` |
| Go | `go` |
| Rust | `cargo` |

A gate is the binary that turns the language's section on, from [2.4](#_24-turn-on-a-language).
A gated language only runs once that binary is installed and Emacs has restarted.
`:async` works on any of them, added unconditionally by `ob-async`.

### 4.2 Programming

#### 4.2.1 Common workflow

Every language section builds on `prog-base` and `core-projects`.
`prog-mode` buffers get line numbers and current-line highlighting.
`apheleia` runs on save as the shared formatting engine, and each language module below registers its own formatter into it.
The Lisp family shares `paredit` for structural editing and `rainbow-delimiters` for nested parens, in `emacs-lisp-mode`, `lisp-mode`, `scheme-mode`, `clojure-mode`, `clojure-ts-mode`, `cider-repl-mode`, `sly-mode`, and `slime-repl-mode`.

| Key | Command | Does |
|---|---|---|
| `C-c p` | `project-prefix-map` | Project commands: switch, find file, and so on |
| `s-p` | `project-prefix-map` | Same, on the super key |
| `<f8>` | `myde-neotree-project-root-toggle` | Toggle a project tree explorer, rooted at the current project |
| `C-c ! n` | `flymake-goto-next-error` | Next LSP diagnostic |
| `C-c ! p` | `flymake-goto-prev-error` | Previous LSP diagnostic |
| `C-c ! l` | `flymake-show-buffer-diagnostics` | List diagnostics for the buffer |

`treesit-auto` installs a language's tree-sitter grammar on first visit and remaps its major mode to the `-ts-mode` variant, once, at startup.
`mise-mode` and `editorconfig-mode` are both global, picking up a project's tool versions and formatting rules with no per-language setup.
See [2.4](#_24-turn-on-a-language) for the binary that gates each language below.
See [2.5](#_25-language-servers-and-debuggers) for the LSP servers and debuggers to install.
See [3.2](#_32-keybinding-prefixes) for the shared `C-c e`, `C-c t`, `C-c i`, and `C-c d` prefixes each subsection follows.

Snippets run on `yasnippet`, enabled globally.
`TAB` is deliberately left unbound in `yas-minor-mode-map`, since it collides with REPL completion.
Expand a snippet with `M-x yas-insert-snippet` or `M-x yas-expand` instead.
`myde-register-snippets` registers a flat `snippets/<language>/` directory for a mode before yasnippet has loaded.
Go and Elixir are the only languages with one today.

#### 4.2.2 Bash

prog-bash is always on, with no gate binary.
It sets `bash-ts-mode` for `.sh`, `.bash`, and `.bats` files, and connects `bash-language-server` over eglot for diagnostics through `shellcheck` and formatting through `shfmt`.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `myde-bash-open-shell` | Open or switch to the `*shell*` buffer |
| `C-c i r` | `myde-bash-send-region` | Send the region to the shell |
| `C-c i b` | `myde-bash-send-buffer` | Send the buffer to the shell |
| `C-c i x` | `myde-bash-run-buffer` | Save the buffer and run it with `bash` in a compilation buffer |

- Dape configuration `bash-debug` needs the `bash-debug` VS Code extension unzipped by hand into `$XDG_DATA_HOME/emacs/debug-adapters/bash-debug/`.
  Nothing else in the config installs it.
- Org Babel runs shell blocks with no gate, see [4.1.6](#_416-org-babel).

#### 4.2.3 Fish

prog-fish gates on `fish` and adds `fish-mode` for `.fish` files, with a 2-space indent.
There is no LSP, test runner, REPL, or debugger for fish.
Org Babel runs a shell block as fish when it opens with a `#!/usr/bin/env fish` shebang, gated on `fish`, see [4.1.6](#_416-org-babel).

#### 4.2.4 Nushell

prog-nushell gates on `nu` and adds `nushell-mode` for `.nu` files and `nu` shebangs, with a 2-space indent.
LSP runs through `nu --lsp`, built into nushell 0.87 and later, with no separate server to install.
It offers completion, hover, go to definition, and diagnostics, but not formatting or code actions.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `myde-nushell-open-repl` | Open or switch to the `*nu*` REPL buffer |
| `C-c i r` | `myde-nushell-send-region` | Send the region to the REPL |
| `C-c i b` | `myde-nushell-send-buffer` | Send the buffer to the REPL |
| `C-c i x` | `myde-nushell-run-buffer` | Save the buffer and run it with `nu` in a compilation buffer |

- `nufmt` is registered with apheleia but not enabled on save.
  It is pre-alpha and can corrupt a script, so formatting stays opt-in through `M-x apheleia-format-buffer` or a project's `.dir-locals.el`.
- Org Babel needs the `nu` tree-sitter grammar installed first (`M-x treesit-install-language-grammar RET nu RET`), then runs `nu` blocks through `nushell-ts-babel`.
  It is not in the [4.1.6](#_416-org-babel) table, since the grammar is a second gate beyond the `nu` binary.
- No snippets directory.

#### 4.2.5 Emacs Lisp

prog-elisp is always on, with no gate binary.
`M-x compile` byte-compiles the current buffer.
`dash`, `s`, and `plz` are available to `require` from your own elisp: list and string utilities, and an HTTP client, respectively.
`buttercup` is available for BDD-style tests, and `package-lint`, `cask-mode`, and `eask-mode` support packaging a library, all with no dedicated keys.
Org Babel runs elisp blocks with no gate, org's own default, see [4.1.6](#_416-org-babel).

#### 4.2.6 Common Lisp

prog-clisp gates on `sbcl` and adds `lisp-mode` for `.lisp`, `.cl`, and `.asd` files.
SLY is the primary REPL, falling back to SLIME only when SLY is not loaded.
LSP through `cl-lsp` is optional and needs Roswell (`ros`) on `PATH`.
SLY and SLIME cover interactive development without it.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `sly` (or `slime`) | Start the REPL |
| `C-c i r` | `sly-eval-region` (or `slime-eval-region`) | Evaluate the region |
| `C-c i b` | `sly-eval-buffer` (or `slime-eval-buffer`) | Evaluate the buffer |
| `C-c i e` | `sly-eval-last-expression` (or `slime-eval-last-expression`) | Evaluate the expression before point |
| `C-c i d` | `sly-documentation` (or `slime-documentation`) | Look up documentation |
| `C-c i z` | `sly-switch-to-repl` (or `slime-switch-to-repl`) | Switch to the REPL |
| `C-c t b` | `sly-eval-buffer` | Evaluate the buffer, the closest thing to a test key: neither SLY nor SLIME has a FiveAM test runner |

- No dape configuration.
  SLDB, SLY and SLIME's own debugger, is REPL-integrated rather than a step-through GUI debugger.
- Org Babel runs `lisp` blocks through `sly-eval` when SLY is loaded, see [4.1.6](#_416-org-babel).

#### 4.2.7 Scheme

prog-scheme gates on `guile` and adds `scheme-mode` for `.scm`, `.ss`, and `.sls` files.
LSP tries `scheme-langserver`, `guile-lsp-server`, and `chicken-lsp-server` in that order, using whichever is on `PATH`.
Geiser adds the REPL, offering Guile, CHICKEN, and Chez backends at `M-x geiser`.
Its default keys, not customized here, are:

| Key | Command | Does |
|---|---|---|
| `C-c C-r` | `geiser-eval-region` | Evaluate the region |
| `C-c C-b` | `geiser-eval-buffer` | Evaluate the buffer |
| `C-c C-z` | `geiser-mode-switch-to-repl` | Switch to the REPL |
| `C-c C-d C-m` | `geiser-doc-module` | Show module documentation |

- `schemat` formats on save through apheleia, but only when it is on `PATH` and eglot is managing the buffer, since it is opt-in like `nufmt`.
- No dape configuration.
  Errors drop into a `*Geiser Dbg*` buffer instead of a step-through GUI debugger.
- Org Babel runs `scheme` blocks through Geiser, see [4.1.6](#_416-org-babel).

#### 4.2.8 Clojure

prog-clojure gates on `clojure` and adds `clojure-ts-mode` for `.clj`, `.cljs`, and `.cljc` files, remapped in front of the plain `clojure-mode` CIDER depends on.
LSP runs through `clojure-lsp`, with its connect timeout raised to 60 seconds for slow first-time indexing.
`cljfmt` (via `clojure-lsp format`) formats on save through apheleia.
`M-x cider-jack-in` starts a REPL, CIDER's own default, not rebound here.

| Key | Command | Does |
|---|---|---|
| `C-c t t` | `cider-test-run-test` | Run the test at point |
| `C-c t f` | `cider-test-run-ns-tests` | Run the namespace's tests |
| `C-c t p` | `cider-test-run-project-tests` | Run the project's tests |
| `C-c t r` | `cider-test-run-loaded-tests` | Rerun loaded tests |

- No dape configuration.
- Org Babel runs `clojure` blocks through CIDER, see [4.1.6](#_416-org-babel).

#### 4.2.9 Erlang

prog-erlang gates on `erl` and adds `erlang-mode` for `.erl`, `.hrl`, and `.escript` files.
LSP runs through ELP (`elp server`), which replaced the now-archived `erlang_ls`.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `erlang-shell` | Start an Erlang shell |
| `C-c i s` | `erlang-shell-buffer` | Switch to the shell buffer |
| `C-c i r` | `inferior-erlang-send-region` | Send the region to the shell |
| `C-c t p` | `myde-erlang-run-tests` | Run the Common Test suite with `rebar3 ct` |

- No dape configuration.
  WhatsApp's `edb` DAP adapter is pre-release.
- No snippets directory.
- Org Babel runs `erlang` blocks through `ob-erlang`, see [4.1.6](#_416-org-babel).

#### 4.2.10 Elixir

prog-elixir gates on `elixir` and adds `elixir-ts-mode` for `.ex`, `.exs`, and `.heex` files, with `heex-ts-mode` layered on top for HEEx templates.
LSP runs through `elixir-ls`, resolved per project through `mise exec`.
Linting adds `credo` and `dialyzer` diagnostics to flycheck.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `elixir-iex` | Start an IEx session |
| `C-c i p` | `elixir-iex-project` | Start an IEx session for the project |
| `C-c i l` | `elixir-iex-send-line` | Send the current line |
| `C-c i r` | `elixir-iex-send-region` | Send the region |
| `C-c i b` | `elixir-iex-send-buffer` | Send the buffer |
| `C-c i m` | `elixir-iex-reload-module` | Reload the module in IEx |
| `C-c i s` | `elixir-iex-set-repl` | Set the IEx REPL buffer |
| `C-c t a` | `exunit-verify-all` | Run all tests |
| `C-c t s` | `exunit-verify-single` | Run the test at point |
| `C-c t t` | `exunit-toggle-file-and-test` | Toggle between a file and its test |

`mix-minor-mode` binds the whole `C-c d` prefix to its own Mix task keymap (`elpaca/sources/mix/mix.el:322`).
The global `C-c d` dape keys from [3.2](#_32-keybinding-prefixes) do not reach Elixir buffers as a result.

| Key | Command | Does |
|---|---|---|
| `C-c d e` | `mix-execute-task` | Run a chosen mix task |
| `C-c d t` | `mix-test` | Run all tests through mix |
| `C-c d o` | `mix-test-current-buffer` | Test the current buffer |
| `C-c d f` | `mix-test-current-test` | Test the item at point |
| `C-c d q` | `mix-compile` | Compile |
| `C-c d l` | `mix-last-command` | Rerun the last mix command |

Prefix any of these keys with an extra `d` (for example `C-c d d t`) to target a chosen umbrella subproject.

Dape still has configurations registered for Elixir, reached by name through `M-x dape` rather than the `C-c d` prefix.
They are `elixir-debug` (`mix run`), `elixir-mix-test`, `elixir-phoenix`, `elixir-remote` (attach), and `elixir-exs-script`.
[RM-10](roadmap.md#rm-10) tracks resolving the collision.

Debugging a `.exs` script still needs a workaround.
A bare script's top-level code runs immediately, before the debugger can attach a breakpoint.
The `elixir-exs-script` configuration's comments describe wrapping the logic in a module function and delaying it with `Task.start`, for example:

```elixir
defmodule MyScript do
  def run do
    a = [1, 2, 3]
    b = Enum.map(a, &(&1 + 1))
    IO.inspect(b, label: "result")
    b
  end
end

Task.start(fn ->
  Process.sleep(4000)
  MyScript.run()
end)
```

`Kernel.dbg/2` with `breakOnDbg` is a lighter alternative that needs no breakpoints.

- Snippets live in `snippets/elixir/`: `case`, `def`, `defmacro`, `defmodule`, `defp`, `receive`, and `test`.
- Org Babel runs `elixir` blocks through `ob-elixir`, see [4.1.6](#_416-org-babel).

#### 4.2.11 C and C++

prog-cpp gates on `clangd` and adds `c++-ts-mode` for `.cpp`, `.cc`, `.cxx`, `.hpp`, `.hh`, `.hxx`, and `.h` files, `c-ts-mode` for `.c`, and `cmake-ts-mode` for `CMakeLists.txt` and `.cmake` files.
`clangd` itself is the language server, with no separate install (see [2.5](#_25-language-servers-and-debuggers)), run with `--header-insertion=never --clang-tidy --completion-style=detailed`.
Formatting runs through eglot's own formatter on save, not apheleia.

| Key | Command | Does |
|---|---|---|
| `C-c t p` | `myde-cpp-run-tests` | Build with CMake and run CTest |
| `C-c o` | `ff-find-other-file` | Jump between a header and its source file |

- Dape configuration `cpp-debug` runs `codelldb`, prompting for the binary and defaulting to the project's `build/` directory.
- Org Babel runs `C` blocks, gated on `clangd`, see [4.1.6](#_416-org-babel).
- No snippets directory.

#### 4.2.12 Go

prog-go gates on `go` and adds `go-ts-mode` for `.go` files, falling back to `go-mode` when tree-sitter is unavailable.
LSP runs through `gopls`, with `staticcheck`, `gofumpt`, and inlay hints for variable, field, and parameter types turned on.
Formatting runs through eglot's own formatter on save.

| Key | Command | Does |
|---|---|---|
| `C-c t t` | `gotest-ts-run-dwim` | Run the test at point |
| `C-c t f` | `gotest-ts-run-file` | Run the file's tests |
| `C-c t p` | `gotest-ts-run-package` | Run the package's tests |
| `C-c t r` | `gotest-ts-repeat` | Repeat the last run |

These test keys are bound on `go-ts-mode` only, not on the `go-mode` fallback.

- Dape configurations `go-debug` and `go-test` both run `dlv dap`, for a normal run and for `go test` respectively.
- Snippets: `snippets/go/` (16 of them, covering `func`, `struct`, `range`, `iferr`, `test`, and more).
- Org Babel runs `go` blocks through `ob-go`, see [4.1.6](#_416-org-babel).

#### 4.2.13 Rust

prog-rust gates on `cargo` and adds Rust support through `rustic`, which derives `rust-ts-mode` from `rust-mode` when tree-sitter is available.
LSP runs through `rust-analyzer`, with `clippy` on save, inlay hints for types and closures, and full cargo feature checking.
Formatting runs on save through `rustic-format-trigger`.

| Key | Command | Does |
|---|---|---|
| `C-c t t` | `rustic-cargo-current-test` | Run the test at point |
| `C-c t p` | `rustic-cargo-test` | Run all tests |

- Dape configurations `rust-debug` and `rust-test` both run `codelldb`, resolving the binary at `target/debug/<project>` and adding `--test` for the test variant.
- Org Babel runs `rust` blocks through `ob-rust`, see [4.1.6](#_416-org-babel).
- No snippets directory.

#### 4.2.14 Zig

prog-zig gates on `zig` and adds `zig-ts-mode` for `.zig` and `.zon` files, falling back to `zig-mode` when tree-sitter is unavailable.
LSP runs through `zls`, with build-on-save and inlay hints for builtins, parameter names, and variable types turned on.
Formatting runs through eglot's own formatter on save.

| Key | Command | Does |
|---|---|---|
| `C-c t p` | `zig-test-all` | Run all tests |

- Dape configuration `zig-debug` runs `codelldb`, resolving the binary at `zig-out/bin/<project>`.
- Org Babel runs `zig` blocks through `ob-zig`, see [4.1.6](#_416-org-babel).
  `ob-zig` declares no `Package-Requires`, so it never byte-compiles and warns once at every startup, see [RM-12](roadmap.md#rm-12).
- No snippets directory.

#### 4.2.15 Python

prog-python gates on `python3` and adds `python-ts-mode` for `.py` files.
LSP runs through `basedpyright-langserver`, in standard type-checking mode with inlay hints for variables, return types, and call arguments.
`ruff-format` formats on save.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `run-python` | Start a Python shell |
| `C-c i r` | `python-shell-send-region` | Send the region |
| `C-c i b` | `python-shell-send-buffer` | Send the buffer |
| `C-c i d` | `python-shell-send-defun` | Send the current function |
| `C-c i s` | `python-shell-switch-to-shell` | Switch to the shell |
| `C-c t t` | `python-pytest-function-dwim` | Run the test at point |
| `C-c t f` | `python-pytest-file-dwim` | Run the file's tests |
| `C-c t p` | `python-pytest` | Run pytest |
| `C-c t r` | `python-pytest-repeat` | Repeat the last run |
| `C-c t x` | `python-pytest-last-failed` | Rerun only what failed |
| `C-c t m` | `python-pytest-dispatch` | Open the pytest argument menu |

- Dape configurations `python-debug` and `python-test` both run `python -m debugpy.adapter`, for the current file and for `pytest` respectively.
- Org Babel runs `python` blocks, see [4.1.6](#_416-org-babel).
- No snippets directory.

#### 4.2.16 Ruby

prog-ruby gates on `ruby` and adds `ruby-ts-mode` for `.rb`, `.rake`, `.gemspec`, `Gemfile`, and `Rakefile`, falling back to `ruby-mode` when tree-sitter is unavailable.
LSP runs through `ruby-lsp`, formatting with `rubocop` and inlay hints for implicit rescues and hash values.
`robe-mode` adds Ruby-aware navigation and documentation lookup from a running Ruby process.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `inf-ruby` | Start a Ruby REPL |
| `C-c i r` | `ruby-send-region` | Send the region |
| `C-c i b` | `ruby-send-buffer` | Send the buffer |
| `C-c i s` | `ruby-switch-to-inf` | Switch to the REPL |
| `C-c t t` | `rspec-verify-single` | Run the test at point |
| `C-c t f` | `rspec-verify` | Run the file's tests |
| `C-c t p` | `rspec-verify-all` | Run all tests |
| `C-c t r` | `rspec-rerun` | Rerun the last run |
| `C-c t x` | `rspec-verify-failures` | Rerun only what failed |

- Dape configuration `ruby-debug` runs `rdbg`, attaching over a local port.
- Org Babel runs `ruby` blocks, see [4.1.6](#_416-org-babel).
- No snippets directory.

#### 4.2.17 Lua

prog-lua gates on `lua` and adds `lua-ts-mode` for `.lua` files, falling back to `lua-mode` when tree-sitter is unavailable.
LSP runs through `lua-language-server`, with hover hints and completion that replaces a call with its full snippet.
`inf-lua` provides the REPL, with the same keys bound in both `lua-mode` and `lua-ts-mode` buffers, to slightly different underlying commands in each.

| Key | Does |
|---|---|
| `C-c i i` | Start a Lua REPL |
| `C-c i r` | Send the region |
| `C-c i b` | Send the buffer |
| `C-c i s` | Switch to the REPL |

- No dape configuration and no test runner.
- Org Babel runs `lua` blocks, see [4.1.6](#_416-org-babel).
- No snippets directory.

#### 4.2.18 JavaScript

prog-javascript gates on `node` and adds `js-ts-mode` for `.js` and `.jsx` files.
LSP runs through `rass tslint`, a multiplexer over `typescript-language-server` and `vscode-eslint-language-server`, so completions and ESLint diagnostics both arrive through eglot.
`add-node-modules-path` prefers a project's local `node_modules/.bin` over global installs, and `prettier` formats on save through apheleia.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `nodejs-repl` | Start a Node REPL |
| `C-c i r` | `nodejs-repl-send-region` | Send the region |
| `C-c i b` | `nodejs-repl-send-buffer` | Send the buffer |
| `C-c i s` | `nodejs-repl-switch-to-repl` | Switch to the REPL |
| `C-c t t` | `jest-test-run-at-point` | Run the test at point |
| `C-c t f` | `jest-test-run` | Run the file's tests |
| `C-c t p` | `jest-test-run-all-tests` | Run all tests |
| `C-c t r` | `jest-test-rerun-test` | Rerun the last run |

`jest-test-mode`'s own defaults sit on `C-c C-t *`, unbound here in favor of the `C-c t` keys above.

- Dape configurations `node-script` and `node-jest` both run through `@vscode/js-debug` (`npm install -g @vscode/js-debug`), for a script and for Jest respectively.
- Org Babel runs `js` blocks, see [4.1.6](#_416-org-babel).
- No snippets directory.

#### 4.2.19 TypeScript

prog-typescript gates on `node` and adds `typescript-ts-mode` for `.ts` files and `tsx-ts-mode` for `.tsx` files, and marks `tsconfig.json`, `jsconfig.json`, and `package.json` as project roots.
LSP runs through the same `rass tslint` multiplexer as JavaScript, streaming diagnostics from both servers incrementally.
`prettier` formats on save through apheleia, and `jest-test-mode` provides the same test keys as JavaScript's.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `run-ts` | Start a TypeScript REPL |
| `C-c i r` | `ts-send-region` | Send the region |
| `C-c i b` | `ts-send-buffer` | Send the buffer |
| `C-c i s` | `ts-send-buffer-and-go` | Send the buffer and switch to the REPL |
| `C-c t t` | `jest-test-run-at-point` | Run the test at point |
| `C-c t f` | `jest-test-run` | Run the file's tests |
| `C-c t p` | `jest-test-run-all-tests` | Run all tests |
| `C-c t r` | `jest-test-rerun-test` | Rerun the last run |

The REPL keys are bound on `typescript-ts-mode` only, not on `tsx-ts-mode`.

- Dape configurations `ts-node-script` and `ts-jest` both run through `@vscode/js-debug`, the same as JavaScript, with `ts-node` as the runtime executable for the script variant.
- Org Babel runs `ts` blocks through `ob-typescript`, see [4.1.6](#_416-org-babel).
- No snippets directory.

### 4.3 Git

`magit`, `forge`, `git-modes`, `diff-hl`, and `blamer` are always on, with no gate binary.

`magit-status` has no bound key.
Reach it directly with `M-x magit-status`, which opens the status buffer for the current repository.
`C-c g b` toggles `blamer-mode`, showing the last commit for the current line inline.
It is the only `C-c g` binding, see [3.2](#_32-keybinding-prefixes).

- `forge` adds pull requests and issues to magit buffers.
  It needs a repository remote pointing at a supported forge, such as GitHub or GitLab.
  Its database lives at `$XDG_DATA_HOME/emacs/forge-database.sqlite`, see [3.4](#_34-where-files-live).
- `git-modes` adds major modes for `.gitignore`, `.gitconfig`, and `.gitattributes` files.
  It binds no keys.
- `diff-hl` marks uncommitted changes in the fringe everywhere.
  It refreshes itself around every magit operation.

Two more packages add AI-generated text through the `gptel` backend from [3.1](#_31-sections).

`gptel-magit` adds these inside magit:

| Key | Command | Does |
|---|---|---|
| `M-g` | `gptel-magit-generate-message` | Generate a commit message in the commit buffer, in place |
| `g` | `gptel-magit-commit-generate` | Create the commit directly, with a generated message, from magit's commit transient (`c` in `magit-status`) |
| `x` | `gptel-magit-diff-explain` | Explain the diff at point, from magit's diff transient |

`gptel-forge-prs` adds these inside the buffer forge opens for `forge-create-pullreq`:

| Key | Command | Does |
|---|---|---|
| `M-g` | `gptel-forge-prs-generate-description` | Generate a PR description from the diff between the source and target branches |
| `M-r` | `gptel-forge-prs-generate-description-with-rationale` | Same, after prompting for a rationale |

Either key reuses a PR template forge already inserted into the buffer, as the structure to fill in.

### 4.4 Writing

`core-spell` and `text-markdown` are always on, with no gate binary.

**Spell checking.**
`jinx` checks spelling across whatever text is visible, not word by word.
It compiles a small native module against `libenchant` at build time, so that library needs to be on the system first: `brew install enchant` on macOS, or `libenchant-2-dev` (Debian, Ubuntu) or the equivalent for your distribution on Linux.

| Buffer | Checks |
|---|---|
| Any `text-mode` buffer, including Markdown and AsciiDoc | Everything |
| Any `prog-mode` buffer | Comments and docstrings only |
| Org buffers | Prose, and comments inside `#+begin_src` blocks, but not code |

Org gets its own face list rather than jinx's default, so a src block's comments stay checked while its code does not.

| Key | Command | Does |
|---|---|---|
| `M-$` | `jinx-correct` | Correct the word at point |
| `C-M-$` | `jinx-correct-all` | Correct every misspelling in the buffer |

**Markdown.**
`text-markdown` maps `gfm-mode` to `.md` and `README.md` files, and renders through `pandoc`.

| Key | Command | Does |
|---|---|---|
| `C-c C-p` | `markdown-preview-mode` | Open a live-updating browser preview, mermaid diagrams included |
| `C-c C-g` | `grip-mode` | Open a second preview rendered by GitHub's own API, exact GFM fidelity but no mermaid |
| `C-c C-e h` | `myde-markdown-export-html` | Export to HTML alongside the source |
| `C-c C-e p` | `myde-markdown-export-pdf` | Export to PDF alongside the source |
| `C-c v` | `visual-fill-column-mode` | Toggle wrapping at `fill-column` instead of window width |
| `C-c t` | `markdown-table-align` | Align the table at point |

`grip-mode` needs `mdopen`, `go-grip`, or `grip` (`pip install grip`) on `PATH`, tried in that order.
PDF export also needs a TeX engine, for example `brew install --cask basictex`.
`markdown-do`, markdown-mode's own default, keeps its usual `C-c C-d`.
`C-c C-e` is freed from that default so the export keys above can use it as a prefix.

## 5. Error handling

### 5.1 A package will not install

An elpaca order fails on every start, and `elpaca/sources/<pkg>/` holds a `.git` folder but no working tree.

elpaca clones with `--filter=tree:0 --no-checkout`, then completes the checkout later by fetching trees and blobs on demand.
When a git host flakes during that second step, the checkout never finishes, and elpaca does not retry it on its own.
Codeberg-hosted packages are the usual victims.

Find every half-finished clone, searching recursively since some packages nest their elisp in subdirectories:

```sh
for d in elpaca/sources/*/; do
  [ "$(find "$d" -name '*.el' -not -path '*/.git/*' | wc -l)" = 0 ] && echo "$d"
done
```

Complete the checkout, checking the branch name first since some repos use `main` and some use `master`:

```sh
git -C elpaca/sources/<pkg> checkout "$(git -C elpaca/sources/<pkg> symbolic-ref --short HEAD)"
```

Then rebuild from a running Emacs:

```elisp
(elpaca-rebuild '<pkg>)
(elpaca-process-queues)
```

`elpaca-rebuild` only queues the order.
`elpaca-process-queues` drains it, since a running session will not drain the queue on its own.

### 5.2 "Cannot open load file" after an update

`require` fails for a file that is plainly present under `elpaca/sources/<pkg>/`.

`elpaca-merge` and `elpaca-update` reuse the file list elpaca cached the first time it built that package in the running session.
A file added upstream afterward never gets linked into `elpaca/builds/<pkg>/`, so nothing fails until the next daemon restart.

Rebuild the package, which clears the cached list:

```elisp
(elpaca-rebuild 'pkg)
(elpaca-process-queues)
```

Restarting the daemon before running `M-x elpaca-update-all` avoids the problem entirely.

### 5.3 $EDITOR opens files nowhere

`$EDITOR` or `$VISUAL` returns with no visible frame, even though a terminal editor should have opened one.

A second Emacs is running next to the daemon, most often `Emacs.app` launched by mistake instead of an `emacsclient -c` frame, see [2.3](#_23-run-as-a-daemon).
The daemon wins the `server` socket, so the second process silently skips `server-start`, and `$EDITOR` reaches a process with no frame.

Quit the second Emacs, confirm only the daemon remains, then retry:

```sh
ps aux | grep -i "[E]macs" | grep -v emacsclient
```

Launch frames only through `emacsclient -c`, or through `~/Applications/Emacsclient.app` on macOS, never `Emacs.app` directly.

### 5.4 MCP bridge CONNECTION_CLOSED

`/mcp` reports `CONNECTION_CLOSED` although the daemon is running, see [2.7](#_27-emacs-mcp-server).

The `mcp-server` process inside the daemon is not listening on its socket, usually because the daemon restarted without it, or because it crashed.
`mcp-server-socket-conflict-resolution` is `error`, so a second Emacs (`Emacs.app`, or `mise run probe`) never steals the socket, it just starts without an MCP server and leaves the daemon's alone.

Restart the server inside the daemon:

```sh
emacsclient --eval '(progn (ignore-errors (mcp-server-stop)) (mcp-server-start-unix))'
```

Then reconnect with `/mcp`.

### 5.5 "error invoking gcc driver"

Native compilation logs `error invoking gcc driver` for one of elpaca's own files during startup, on macOS.

Those files load before `exec-path-from-shell` runs, so libgccjit cannot find the Homebrew gcc driver on the bare GUI `PATH` Emacs starts with.

It is a warning, not a failure.
The affected file runs byte-compiled for that start, and compiles natively on the next start that has a full `PATH`, such as the daemon started from a login shell.
No action is needed.

### 5.6 Org problems

**A project's tasks all show up as `tasks` in the agenda.**
The file is missing `#+category:`.
Org falls back to the file name, and every project's file is named `tasks.org`.
Add `#+category: <project_name>` at the top, with underscores in place of hyphens or dots.

**A `tasks.org` I just created is not in the agenda.**
The agenda rescans before every `C-c o a`, so no restart is needed, see [4.1.2](#_412-the-agenda-and-task-states).
Check instead that the directory is under `myde-org-code-directory` (`~/devel/projects/` by default), and outside a dot-directory or `node_modules`, both pruned on purpose.

**Capture went to the inbox instead of the project.**
There was no `tasks.org` at or above the current directory, see [3.3](#_33-projects).
`M-: (myde-org-project-root)` returns nil when none is found.
`C-c o P` creates one.

**`M-x org-lint` instead of on-the-fly checking.**
Flycheck is off in org buffers on purpose.
Its bundled `org-lint` checker crashes on current org versions, on save and whenever the agenda first visits a `tasks.org`.
Run `M-x org-lint` by hand when you want the checks.

## 6. FAQ

**Why doesn't Emacs show a dashboard when a frame opens?**
Dashboard is deliberately not a startup screen.
`initial-buffer-choice` cannot be relied on under elpaca, since `elpaca-log-initial-queues` overwrites it whenever any package order is unbuilt or has failed.
Dashboard is `:defer t`, opened on demand with `M-x dashboard-open`.
A client frame from `emacsclient -c` opens on `*scratch*` instead, at no cost.

**How do I turn a section off?**
Uninstall the binary that gates it, or remove it from `PATH`, then restart the daemon, see [2.4](#_24-turn-on-a-language).
There is no toggle, no override list, and no `custom.el` entry for a section.
The section comes back the next time the binary is on `PATH` again.

**What does `custom.el` hold?**
Only what `M-x customize-*` writes, such as a theme marked safe.
It is gitignored, and `myde.org` loads it if present, so a setting saved through Customize survives a restart.
It carries no section toggles.

## 7. References

- [Org manual](https://orgmode.org/manual/)
- [Denote manual](https://protesilaos.com/emacs/denote)
- [elpaca](https://github.com/progfolio/elpaca)
- [Eglot manual](https://www.gnu.org/software/emacs/manual/html_node/eglot/)
- [Dape](https://elpa.gnu.org/packages/dape.html)
- [Magit manual](https://docs.magit.vc/magit)
- [Root README](https://github.com/mojochao/myde.emacs/blob/main/README.md)
- [Developer Guide](developer.md)
