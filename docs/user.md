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
| Emacs 31.1 or later, compiled with native-compile support | The whole config (`user-lisp-directory` first appears in 31.1) |
| mise | Every task in `mise.toml`, including install and tangle |
| git 2.54 or later | hk's config-based git hooks |
| `socat` | The Emacs MCP server's stdio bridge |
| `enchant`, `pkg-config`, and a C compiler | `jinx` spell checking in `core-spell`, which compiles a native module on first use |
| `pandoc` | Markdown preview and export in `text-markdown` |
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

Never launch Emacs.app alongside the daemon.
Two processes fight over three singletons: the `server` socket, the `mcp-server` Unix socket under `$XDG_CACHE_HOME/emacs/`, and the XDG state files (`recentf.eld`, `places.eld`, `history`).
The daemon wins the socket race, so the app silently skips `server-start`, and `$EDITOR` never reaches the app's window.
The state files are last-writer-wins.

### 2.4 Turn on a language

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
There is no other switch for a section, see [3.1](#_31-sections).

### 2.5 Language servers and debuggers

Language sections, and the JSON, TOML, and XML data sections, connect a language server through eglot.
Most language sections also register a dape debug configuration.
MyDE installs none of these tools.
Put each one on `PATH` before using the feature.
The table covers every language server and debug adapter the config names.

| Language | Language server | Debug adapter | Install |
|---|---|---|---|
| [Bash](#_422-bash) | `bash-language-server` | `bash-debug` | adapter: see [4.2.2](#_422-bash) |
| [Nushell](#_424-nushell) | `nu --lsp` | none | built into nushell 0.87 and later |
| [Common Lisp](#_426-common-lisp) | `cl-lsp`, optional | none | needs Roswell (`ros`) on `PATH` |
| [Scheme](#_427-scheme) | `scheme-langserver`, `guile-lsp-server`, or `chicken-lsp-server` | none | |
| [Clojure](#_428-clojure) | `clojure-lsp` | none | `brew install clojure-lsp` |
| [Erlang](#_429-erlang) | `elp` | none | |
| [Elixir](#_4210-elixir) | `elixir-ls` | `elixir-ls` | |
| [C and C++](#_4211-c-and-c) | `clangd` | `codelldb` | `clangd` is the gate binary, `codelldb` see below |
| [Go](#_4212-go) | `gopls` | `dlv` | |
| [Rust](#_4213-rust) | `rust-analyzer` | `codelldb` | `codelldb` see below |
| [Zig](#_4214-zig) | `zls` | `codelldb` | `codelldb` see below |
| [Python](#_4215-python) | `basedpyright-langserver` | `debugpy` | the adapter runs as `python -m debugpy.adapter` |
| [Ruby](#_4216-ruby) | `ruby-lsp` | `rdbg` | |
| [Lua](#_4217-lua) | `lua-language-server` | none | |
| [JavaScript](#_4218-javascript) and [TypeScript](#_4219-typescript) | `rass`, over `typescript-language-server` and `vscode-eslint-language-server` | `js-debug` | adapter: see [4.2.18](#_4218-javascript) |
| JSON (`data-json`) | `vscode-json-language-server` | none | |
| TOML (`data-toml`) | `taplo` | none | |
| XML (`data-xml`) | `lemminx` | none | see [2.5.1](#_251-lemminx) |

The C, C++, Rust, and Zig dape configurations run `codelldb --port <port>`, so `codelldb` must be on `PATH`.
Download it for your platform from the [vadimcn/codelldb releases](https://github.com/vadimcn/codelldb/releases) and put its `codelldb` executable on `PATH`.

#### 2.5.1 LemMinX

LemMinX is not available through Homebrew.
It ships as a Java uber-JAR.
`data-xml` runs it as `~/.local/bin/lemminx`, by that exact path, so the wrapper below goes there.

```sh
# Download the JAR
mkdir -p ~/.local/share/lemminx
curl -fL https://download.eclipse.org/lemminx/releases/0.31.1/org.eclipse.lemminx-uber.jar \
     -o ~/.local/share/lemminx/lemminx-0.31.1-uber.jar

# Create a wrapper script (requires a java on PATH)
mkdir -p ~/.local/bin
cat > ~/.local/bin/lemminx <<'EOF'
#!/bin/sh
exec java \
  -jar "$HOME/.local/share/lemminx/lemminx-0.31.1-uber.jar" "$@"
EOF
chmod +x ~/.local/bin/lemminx
```

### 2.6 Browser capture

`org-protocol` lets the browser send a URL, page title, and any selected text to a running Emacs session.
That triggers the `b` capture template and appends a tagged bookmark to `~/org/inbox.org`.
Two things are required: a system-level URI handler and a browser bookmarklet.

#### 2.6.1 Linux

The desktop file is included in this repo.
Install it with:

```sh
mise run install-xdg
```

Verify registration:

```sh
xdg-open "org-protocol://capture?template=b&url=https%3A%2F%2Fexample.com&title=Example"
```

A running Emacs server should open the capture buffer.

#### 2.6.2 macOS

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

#### 2.6.3 Browser bookmarklet

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

Chrome blocks `javascript:` bookmarklets from running on `chrome://` pages and Chrome Web Store pages.
They work on all normal websites.

For a page worth more than a bookmark, use template `N` instead of `b` in the bookmarklet URL.
That routes the capture into a denote note under `~/org/notes/`, prompting for denote keywords and seeding the title from the page title.

#### 2.6.4 Verify it works end to end

1. Make sure the daemon from [2.3](#_23-run-as-a-daemon) is running.
2. Navigate to any page in your browser.
3. Click the bookmarklet.
4. Emacs raises and opens an org-capture buffer, pre-filled with the URL and page title in the `b` (bookmark) template, and prompts for tags.
5. Enter tags, add any extra notes, then `C-c C-c` to save.

The entry lands in `~/org/inbox.org` under its `Inbox` heading, which capture creates the first time:

```org
* Inbox
** [[https://example.com][Example Domain]]   :bookmark:reading:
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

The command assumes the default `XDG_CACHE_HOME` of `~/.cache`.
Change the path if yours is set elsewhere.

The server starts from `elpaca-after-init` on a fixed socket path, because the bridge above hardcodes it.
See [5.4](#_54-mcp-bridge-connection_closed) for what a second Emacs does with the socket, and for restarting the server when the bridge reports `CONNECTION_CLOSED`.

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

There are no section toggles, no override list, and no `custom.el` entries for sections.
See [2.4](#_24-turn-on-a-language) for the full binary-to-section table, and the gating rules behind it.

The gate wraps the whole `use-package` form.
elpaca queues a package order when the form is expanded, before `:if` or `:when` is evaluated, so a keyword inside the form cannot prevent a clone.
Definitions in `user-lisp/myde.el` are unconditional.
A function such as `myde-go-mode-setup` exists whether or not `go` is installed.
Nothing calls it unless the gate passed.

### 3.2 Keybinding prefixes

Sections follow consistent keybinding prefixes.

| Prefix    | Domain                                 | Example                  |
|-----------|------------------------------------------|---------------------------|
| `C-c o *` | Org: agenda, capture, notes, tags      | `C-c o a` agenda         |
| `C-c e *` | LSP (eglot) and documentation popups, see [4.2.1](#_421-common-workflow) | `C-c e a` code actions   |
| `C-c t *` | Tests, language-specific               | `C-c t t` test at point  |
| `C-c i *` | REPL or interactive, language-specific | `C-c i i` start REPL     |
| `C-c d *` | Debug (dape), global, see [4.2.1](#_421-common-workflow) | `C-c d d` start debugger |
| `C-c p *` | Project commands (`project-prefix-map`), also on `s-p` | `C-c p f` find a file in the project |
| `C-c ! *` | Diagnostics, see [4.2.1](#_421-common-workflow) | `C-c ! l` list errors |
| `C-c g *` | Git blame, see [4.3](#_43-git) | `C-c g b` toggle `blamer-mode` |
| `C-c s *` | Font previews (`show-font`) | `C-c s f` preview a font |
| `C-c k *` | Kubernetes (`kubed`), when `kubectl` is installed | `C-c k k` kubed menu |
| `C-c C`   | Claude Code menu, when `claude` is installed | `C-c C` opens it |
| `C-c m`   | Configure the `minuet` AI completion provider | `C-c m` starts the setup |
| `C-c u`   | Open the URL at point in the browser | `C-c u` on a link |

A few modes bind a key that shadows one of these prefixes.

- In C and C++ buffers, `C-c o` runs `ff-find-other-file`, which hides the whole Org prefix, see [4.2.11](#_4211-c-and-c).
- In Elixir buffers, the Mix task keys sit under `C-c x`, see [4.2.10](#_4210-elixir).
- In Elixir buffers, `C-c t t` toggles between a file and its test instead of running the test at point, see [4.2.10](#_4210-elixir).
- In Common Lisp buffers under SLY, `C-c t b` evaluates the buffer, since there is no test runner, see [4.2.6](#_426-common-lisp).
- In Markdown buffers, `C-c t` aligns the table at point, which hides the test prefix, see [4.4.2](#_442-markdown).

### 3.3 Projects

A project is any directory containing a `tasks.org`.
There is no fixed root and no naming convention.
Capture and visiting locate a project by searching upward from the current directory.
`myde-org-code-directory` (`~/devel/projects/` by default) is scanned to build `org-agenda-files`.
The scan runs again before every `org-agenda` call, so a new `tasks.org` appears without a restart.
A project outside that directory still works for capture and visiting.
It does not appear in the agenda.
The scan skips dot-directories and `node_modules`, which also keeps an archived project parked in `.ATTIC/` out of the agenda.

| Key | Command | Does |
|---|---|---|
| `C-c o p` | `myde-org-visit-project-tasks` | Visit this project's `tasks.org`, creating one if absent |
| `C-c o P` | `myde-org-create-project-tasks` | Create a `tasks.org` in a chosen directory |
| `C-c o t` | `myde-org-tag-cloud` | List every tag in use, by frequency |
| `C-c o T` | `myde-org-search-tags` | Pick tags with completion, show the matching agenda |
| `C-c o c` | `org-capture` | Open the capture menu, see [4.1.1](#_411-capturing) for the templates |
| `C-c o a` | `org-agenda` | Open the agenda dispatcher |

A missing `#+category:` makes a project's tasks show up in the agenda under the generic name `tasks`.
Org falls back to the file name when `#+category:` is missing, and every project's file is named `tasks.org`.
`#+filetags:` tags every entry in the file, so a tag search for the project returns all of it.
Hyphens and dots are not legal in org tags, so `myde-org-sanitize-tag` replaces them with underscores: `scitech-idp` becomes `scitech_idp`.

### 3.4 Where files live

Nothing but packages and `custom.el` is written inside `user-emacs-directory`.

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
To keep `tasks.org` out of `git status` in a shared repository, add it to your own global gitignore.
`git add -f tasks.org` then commits one on purpose.

## 4. Usage and workflows

### 4.1 Org and notes

Org handles tasks, thoughts, bookmarks, and durable notes across the files and directories described in [3.4](#_34-where-files-live).

#### 4.1.1 Capturing

`C-c o c` opens the capture menu, then one more key picks a template.

| Key | Captures | Files into |
|---|---|---|
| `t` | Task | `~/org/inbox.org` |
| `T` | Task in the current project | the nearest `tasks.org`, falling back to the inbox |
| `h` | Thought, tagged | `~/org/inbox.org` |
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
| `SPC` | Show the item in another window, staying in the agenda |
| `TAB` | Jump to the item in another window |
| `t` | Change its TODO state |
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

In an Org file, `C-c C-t` opens a menu of these states, keyed by the letters in the table.
`t` in the agenda opens the same menu.
`S-<left>` and `S-<right>` cycle through the states in a file without the menu.
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
| Shell (`sh`, `bash`, `zsh`, `fish`, and other shells) | none, loaded by `prog-bash` |
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
A shell block needs no gate, but it runs only if its shell is installed.

`ob-async` adds an `:async` header argument, which runs a block in a child Emacs process.
The child loads only the languages in `org-babel-load-languages`.
Go, Rust, TypeScript, Erlang, and Elixir come from separate `ob-*` packages outside that list, so `:async` does not work for them.

### 4.2 Programming

#### 4.2.1 Common workflow

Every language section builds on `prog-base` and `core-projects`.
`prog-mode` buffers get line numbers and current-line highlighting.
The Lisp family shares `paredit` for structural editing and `rainbow-delimiters` for nested parens, in `emacs-lisp-mode`, `lisp-mode`, `scheme-mode`, `clojure-mode`, `clojure-ts-mode`, `cider-repl-mode`, `sly-mode`, and `slime-repl-mode`.

`apheleia-global-mode` formats a buffer each time it is saved.
It runs the formatter that `apheleia-mode-alist` maps the buffer's major mode to.
Most entries are apheleia's own defaults, and a few language sections add or override one.
A formatter that is not installed, or that fails, leaves the buffer unchanged.
Several sections also run `eglot-format-buffer` from `before-save-hook`, so their buffers get two formatters on each save.
Each subsection below names the formatters its buffers get.

| Key | Command | Does |
|---|---|---|
| `C-c p` | `project-prefix-map` | Project commands: switch, find file, and so on |
| `s-p` | `project-prefix-map` | Same, on the super key |
| `<f8>` | `myde-neotree-project-root-toggle` | Toggle a project tree explorer, rooted at the current project |
| `C-c ! n` | `flycheck-next-error` | Next flycheck error |
| `C-c ! p` | `flycheck-previous-error` | Previous flycheck error |
| `C-c ! l` | `flycheck-list-errors` | List the buffer's flycheck errors |

The `C-c !` keys are flycheck's wherever flycheck is on, which includes every programming buffer.
Eglot reports its diagnostics through flymake instead.
Reach those with `M-x flymake-goto-next-error`, `M-x flymake-goto-prev-error`, and `M-x flymake-show-buffer-diagnostics`.

Eglot keys, in every buffer eglot manages:

| Key | Command | Does |
|---|---|---|
| `C-c e a` | `eglot-code-actions` | Offer code actions at point |
| `C-c e r` | `eglot-rename` | Rename the symbol at point |
| `C-c e f` | `eglot-format-buffer` | Format the buffer through the language server |
| `C-c e i` | `eglot-find-implementation` | Find implementations of the symbol at point |
| `C-c e t` | `eglot-find-typeDefinition` | Go to the type definition of the symbol at point |
| `C-c e h` | `eldoc-box-help-at-point` | Show documentation for the symbol at point in a popup |
| `C-c e q` | `eldoc-box-quit-frame` | Close that popup |

`core-projects` binds `C-c e f` to `eglot-format`, which formats the active region.
`prog-bash`, `prog-nushell`, `prog-javascript`, and `prog-typescript` rebind it to `eglot-format-buffer` in `eglot-mode-map`.
Every eglot buffer shares that map, and `prog-bash` is always on, so `C-c e f` formats the whole buffer in every language.
`C-c e h` and `C-c e q` are global, so they also work outside eglot buffers.

Dape keys, global, including in Elixir buffers (see [4.2.10](#_4210-elixir)):

| Key | Command | Does |
|---|---|---|
| `C-c d d` | `dape` | Start a debug session, choosing a configuration |
| `C-c d l` | `dape-restart` | Restart the session, or re-run the last configuration when none is live |
| `C-c d b` | `dape-breakpoint-toggle` | Toggle a breakpoint on the current line |
| `C-c d n` | `dape-next` | Step over |
| `C-c d s` | `dape-step-in` | Step in |
| `C-c d o` | `dape-step-out` | Step out |
| `C-c d c` | `dape-continue` | Continue |
| `C-c d q` | `dape-quit` | End the session |

`treesit-auto` installs a language's tree-sitter grammar on first visit and remaps its major mode to the `-ts-mode` variant, once, at startup.
`mise-mode` and `editorconfig-mode` are both global, picking up a project's tool versions and formatting rules with no per-language setup.
See [2.4](#_24-turn-on-a-language) for the binary that gates each language below.
See [2.5](#_25-language-servers-and-debuggers) for the language servers and debug adapters to install.
Each subsection below lists its own `C-c t` and `C-c i` keys, on top of the eglot and dape keys above.

Snippets run on `yasnippet`, enabled globally.
`TAB` is deliberately left unbound in `yas-minor-mode-map`, since it collides with REPL completion.
Expand a snippet with `M-x yas-insert-snippet` or `M-x yas-expand` instead.
Snippets come from two places.
`myde-register-snippets` registers a flat `snippets/<language>/` directory from this repo, and only Go and Elixir have one today.
`yasnippet-classic-snippets` adds the classic collection, which covers C, C++, Emacs Lisp, Erlang, JavaScript, Python, and Ruby, among others.

#### 4.2.2 Bash

`prog-bash` is always on, with no gate binary.
It sets `bash-ts-mode` for `.sh`, `.bash`, and `.bats` files, and connects `bash-language-server` over eglot, which reports `shellcheck` diagnostics.
`shfmt` formats on save through apheleia.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `myde-bash-open-shell` | Open or switch to the `*shell*` buffer |
| `C-c i r` | `myde-bash-send-region` | Send the region to the shell |
| `C-c i b` | `myde-bash-send-buffer` | Send the buffer to the shell |
| `C-c i x` | `myde-bash-run-buffer` | Save the buffer and run it with `bash` in a compilation buffer |

- Dape configuration `bash-debug` needs the `bash-debug` VS Code extension unzipped by hand into `$XDG_DATA_HOME/emacs/debug-adapters/bash-debug/`.
  Nothing else in the config installs it.
  It runs the adapter with `node`, and needs `bashdb` on `PATH`.
- Org Babel runs shell blocks with no gate, see [4.1.6](#_416-org-babel).

#### 4.2.3 Fish

`prog-fish` gates on `fish` and adds `fish-mode` for `.fish` files, with a 2-space indent.
`fish_indent` formats on save through apheleia.
There is no LSP, test runner, REPL, or debugger for fish.
Org Babel runs `fish` blocks through ob-shell, which `prog-bash` loads with no gate, see [4.1.6](#_416-org-babel).
A `shell` block also runs under fish with the header argument `:shebang "#!/usr/bin/env fish"`.

#### 4.2.4 Nushell

`prog-nushell` gates on `nu` and adds `nushell-mode` for `.nu` files and `nu` shebangs, with a 2-space indent.
LSP runs through `nu --lsp`, built into nushell 0.87 and later, with no separate server to install.
It offers completion, hover, go to definition, and diagnostics, but not formatting or code actions.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `myde-nushell-open-repl` | Open or switch to the `*nu*` REPL buffer |
| `C-c i r` | `myde-nushell-send-region` | Send the region to the REPL |
| `C-c i b` | `myde-nushell-send-buffer` | Send the buffer to the REPL |
| `C-c i x` | `myde-nushell-run-buffer` | Save the buffer and run it with `nu` in a compilation buffer |

- `nufmt` is registered as an apheleia formatter, but no mode maps to it, so it never runs on save.
  It is pre-alpha and can corrupt a script.
  In a Nushell buffer, `M-x apheleia-format-buffer` prompts for a formatter, so pick `nufmt` there.
  To format on save in one project, add `((nushell-mode . ((apheleia-formatter . nufmt))))` to its `.dir-locals.el`.
- Org Babel runs `nushell` blocks through `nushell-ts-babel`, once the `nu` tree-sitter grammar is installed (`M-x myde-treesit-install-language-grammar RET nu RET`).
  `nushell-ts-babel` loads only when that grammar is present at startup, so restart Emacs after installing it.
  It is not in the [4.1.6](#_416-org-babel) table, since the grammar is a second gate beyond the `nu` binary.
- No snippets.

#### 4.2.5 Emacs Lisp

`prog-elisp` is always on, with no gate binary.
`M-x compile` byte-compiles the current buffer.
Apheleia re-indents the buffer on save with its default `lisp-indent` formatter.
`dash`, `s`, and `plz` are available to `require` from your own elisp: list and string utilities, and an HTTP client, respectively.
`buttercup` is available for BDD-style tests, and `package-lint`, `cask-mode`, and `eask-mode` support packaging a library, all with no dedicated keys.
Org Babel runs elisp blocks with no gate, org's own default, see [4.1.6](#_416-org-babel).

#### 4.2.6 Common Lisp

`prog-clisp` gates on `sbcl` and adds `lisp-mode` for `.lisp`, `.cl`, and `.asd` files.
SLY is the primary REPL, falling back to SLIME only when SLY is not loaded.
LSP through `cl-lsp` is optional and needs Roswell (`ros`) on `PATH`.
SLY and SLIME cover interactive development without it.
Apheleia re-indents the buffer on save with its default `lisp-indent` formatter.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `sly` (or `slime`) | Start the REPL |
| `C-c i r` | `sly-eval-region` (or `slime-eval-region`) | Evaluate the region |
| `C-c i b` | `sly-eval-buffer` (or `slime-eval-buffer`) | Evaluate the buffer |
| `C-c i e` | `sly-eval-last-expression` (or `slime-eval-last-expression`) | Evaluate the expression before point |
| `C-c i d` | `sly-documentation` (or `slime-documentation`) | Look up documentation |
| `C-c i z` | `sly-mrepl` (or `slime-switch-to-output-buffer`) | Switch to the REPL |
| `C-c t b` | `sly-eval-buffer` | Evaluate the buffer, the closest thing to a test key: neither SLY nor SLIME has a FiveAM test runner |

- No dape configuration.
  SLDB, SLY and SLIME's own debugger, is REPL-integrated rather than a step-through GUI debugger.
- Org Babel runs `lisp` blocks through `sly-eval` when SLY is loaded, see [4.1.6](#_416-org-babel).

#### 4.2.7 Scheme

`prog-scheme` gates on `guile` and adds `scheme-mode` for `.scm`, `.ss`, and `.sls` files.
LSP tries `scheme-langserver`, `guile-lsp-server`, and `chicken-lsp-server` in that order, using whichever is on `PATH`.
Geiser adds the REPL, offering Guile, CHICKEN, and Chez backends at `M-x geiser`.
Its default keys, not customized here, are:

| Key | Command | Does |
|---|---|---|
| `C-c C-r` | `geiser-eval-region` | Evaluate the region |
| `C-c C-b` | `geiser-eval-buffer` | Evaluate the buffer |
| `C-c C-z` | `geiser-mode-switch-to-repl` | Switch to the REPL |
| `C-c C-d C-m` | `geiser-doc-module` | Show module documentation |

- `schemat` formats every Scheme save through apheleia when it is on `PATH` (`cargo install schemat`).
  When eglot manages the buffer, a `before-save-hook` also runs it before the save.
- No dape configuration.
  Errors drop into a `*Geiser Dbg*` buffer instead of a step-through GUI debugger.
- Org Babel runs `scheme` blocks through Geiser, see [4.1.6](#_416-org-babel).

#### 4.2.8 Clojure

`prog-clojure` gates on `clojure` and adds `clojure-ts-mode` for `.clj`, `.cljs`, and `.cljc` files, remapped in front of the plain `clojure-mode` CIDER depends on.
LSP runs through `clojure-lsp`.
The section raises `eglot-connect-timeout` to 60 seconds for slow first-time indexing.
That setting is global, so every eglot server gets the longer timeout, not only `clojure-lsp`.
`cljfmt` (via `clojure-lsp format`) formats on save through apheleia.
`M-x cider-jack-in` starts a REPL, CIDER's own default, not rebound here.

| Key | Command | Does |
|---|---|---|
| `C-c t t` | `cider-test-run-test` | Run the test at point |
| `C-c t f` | `cider-test-run-ns-tests` | Run the namespace's tests |
| `C-c t p` | `cider-test-run-project-tests` | Run the project's tests |
| `C-c t r` | `cider-test-run-loaded-tests` | Run the tests of every loaded namespace |

- No dape configuration.
- Org Babel runs `clojure` blocks through CIDER, see [4.1.6](#_416-org-babel).

#### 4.2.9 Erlang

`prog-erlang` gates on `erl` and adds `erlang-mode` for `.erl`, `.hrl`, and `.escript` files.
LSP runs through ELP (`elp server`).
No formatter runs on save.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `erlang-shell` | Start an Erlang shell |
| `C-c i s` | `erlang-shell-display` | Show the Erlang shell buffer |
| `C-c t p` | `myde-erlang-run-tests` | Run the Common Test suite with `rebar3 ct` |

- No dape configuration.
  WhatsApp's `edb` DAP adapter is pre-release.
- Snippets come from the classic collection only, see [4.2.1](#_421-common-workflow).
- Org Babel runs `erlang` blocks through `ob-erlang`, see [4.1.6](#_416-org-babel).

#### 4.2.10 Elixir

`prog-elixir` gates on `elixir`.
`.ex` and `.exs` files open in `elixir-ts-mode`, and HEEx templates (`.heex`) in `heex-ts-mode`.
LSP runs through `elixir-ls`, resolved per project through `mise exec`.
`mix format` runs on save through apheleia's default `mix-format` formatter.
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

`mix.el` binds its command map on `C-c d`, and `myde.org` moves it to `C-c x` ([RM-10](roadmap.md#rm-10)).
The global dape keys from [4.2.1](#_421-common-workflow) reach Elixir buffers as a result.

| Key | Command | Does |
|---|---|---|
| `C-c x e` | `mix-execute-task` | Run a chosen mix task |
| `C-c x t` | `mix-test` | Run all tests through mix |
| `C-c x o` | `mix-test-current-buffer` | Test the current buffer |
| `C-c x f` | `mix-test-current-test` | Test the item at point |
| `C-c x q` | `mix-compile` | Compile |
| `C-c x l` | `mix-last-command` | Rerun the last mix command |

Prefix `e`, `t`, `o`, `f`, or `q` with an extra `d` (for example `C-c x d t`) to target a chosen umbrella subproject.
`l` has no umbrella variant.

Dape has configurations registered for Elixir, chosen by name through `C-c d d`.
They are `elixir-debug` (`mix run`), `elixir-mix-test`, `elixir-phoenix`, `elixir-remote` (attach), and `elixir-exs-script`.

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

`prog-cpp` gates on `clangd` and adds `c++-ts-mode` for `.cpp`, `.cc`, `.cxx`, `.hpp`, `.hh`, `.hxx`, and `.h` files, `c-ts-mode` for `.c`, and `cmake-ts-mode` for `CMakeLists.txt` and `.cmake` files.
`clangd` itself is the language server, with no separate install (see [2.5](#_25-language-servers-and-debuggers)), run with `--header-insertion=never --clang-tidy --completion-style=detailed`.
Two formatters run on each save: clangd through `eglot-format-buffer` in `before-save-hook`, then apheleia's default `clang-format`.
Apheleia formats CMake files with its default `cmake-format`.

| Key | Command | Does |
|---|---|---|
| `C-c t p` | `myde-cpp-run-tests` | Build with CMake and run CTest |
| `C-c o` | `ff-find-other-file` | Jump between a header and its source file |

In C and C++ buffers, `C-c o` hides the whole Org `C-c o` prefix.
Run the Org commands with `M-x` there, or from another buffer.

- Dape configuration `cpp-debug` runs `codelldb`, prompting for the binary and defaulting to the project's `build/` directory.
- Org Babel runs `C` blocks, gated on `clangd`, see [4.1.6](#_416-org-babel).
- Snippets come from the classic collection only, see [4.2.1](#_421-common-workflow).

#### 4.2.12 Go

`prog-go` gates on `go` and adds `go-ts-mode` for `.go` files, falling back to `go-mode` when tree-sitter is unavailable.
LSP runs through `gopls`, with `staticcheck`, `gofumpt`, and inlay hints for variable, field, and parameter types turned on.
Two formatters run on each save: gopls through `eglot-format-buffer` in `before-save-hook`, then apheleia's default `gofmt`.

| Key | Command | Does |
|---|---|---|
| `C-c t t` | `gotest-ts-run-dwim` | Run the test or subtest at point |
| `C-c t r` | `gotest-ts-run-dwim` | Same as `C-c t t` |
| `C-c t f` | `gotest-ts-run-function` | Run the whole test function at point, ignoring subtests |
| `C-c t i` | `gotest-ts-show-test-info` | Show the test and subtest at point |
| `C-c t n` | `gotest-ts-next-subtest` | Move to the next subtest |
| `C-c t p` | `gotest-ts-prev-subtest` | Move to the previous subtest |
| `C-c t m` | `gotest-ts-imenu-goto` | Jump to a test or subtest with imenu |

`gotest-ts-setup` binds these keys, except `C-c t t`, when a `go-ts-mode` buffer opens.
It binds them in both `go-ts-mode-map` and `go-mode-map`.
`C-c t t` is bound in `go-ts-mode` only.
A session that never opens a `go-ts-mode` buffer has no test keys in `go-mode`.

- Dape configurations `go-debug` and `go-test` both run `dlv dap`, for a normal run and for `go test` respectively.
- Snippets: `snippets/go/` (17 of them, covering `func`, `struct`, `range`, `iferr`, `test`, and more).
- Org Babel runs `go` blocks through `ob-go`, see [4.1.6](#_416-org-babel).

#### 4.2.13 Rust

`prog-rust` gates on `cargo` and adds Rust support through `rustic`.
`rust-mode-treesitter-derive` is on, so `rust-mode`, and `rustic-mode` on top of it, derive from the built-in `rust-ts-mode`.
LSP runs through `rust-analyzer`, with `clippy` on save, inlay hints for types and closures, and full cargo feature checking.
Two formatters run on each save: rustic's own `rustfmt` run (`rustic-format-trigger` is `on-save`), then apheleia's default `rustfmt`.

| Key | Command | Does |
|---|---|---|
| `C-c t t` | `rustic-cargo-current-test` | Run the test at point |
| `C-c t p` | `rustic-cargo-test` | Run all tests |

- Dape configurations `rust-debug` and `rust-test` both run `codelldb`, resolving the binary at `target/debug/<project>` and adding `--test` for the test variant.
- Org Babel runs `rust` blocks through `ob-rust`, see [4.1.6](#_416-org-babel).
- No snippets.

#### 4.2.14 Zig

`prog-zig` gates on `zig` and adds `zig-ts-mode` for `.zig` and `.zon` files, falling back to `zig-mode` when tree-sitter is unavailable.
LSP runs through `zls`, with build-on-save and inlay hints for builtins, parameter names, and variable types turned on.
Two formatters run on each save: zls through `eglot-format-buffer` in `before-save-hook`, then apheleia's default `zig fmt`.

| Key | Command | Does |
|---|---|---|
| `C-c t p` | `zig-test-buffer` | Run `zig test` on the current file |

The key is bound in both `zig-mode` and `zig-ts-mode`.

- Dape configuration `zig-debug` runs `codelldb`, resolving the binary at `zig-out/bin/<project>`.
- Org Babel runs `zig` blocks through `ob-zig`, see [4.1.6](#_416-org-babel).
  `ob-zig` declares no `Package-Requires`, so it never byte-compiles and warns once at every startup, see [RM-12](roadmap.md#rm-12).
- No snippets.

#### 4.2.15 Python

`prog-python` gates on `python3` and adds `python-ts-mode` for `.py` files.
LSP runs through `basedpyright-langserver`, in standard type-checking mode with inlay hints for variables, return types, and call arguments.
`ruff-format-on-save-mode` runs `ruff format` on each save.
Apheleia also runs its default, `black`, when `black` is installed.

| Key | Command | Does |
|---|---|---|
| `C-c i i` | `run-python` | Start a Python shell |
| `C-c i r` | `python-shell-send-region` | Send the region |
| `C-c i b` | `python-shell-send-buffer` | Send the buffer |
| `C-c i d` | `python-shell-send-defun` | Send the current function |
| `C-c i s` | `python-shell-switch-to-shell` | Switch to the shell |
| `C-c t t` | `python-pytest-run-def-at-point-treesit` | Run the test function at point |
| `C-c t f` | `python-pytest-file-dwim` | Run the file's tests |
| `C-c t p` | `python-pytest` | Run pytest |
| `C-c t r` | `python-pytest-repeat` | Repeat the last run |
| `C-c t x` | `python-pytest-last-failed` | Rerun only what failed |
| `C-c t m` | `python-pytest-dispatch` | Open the pytest argument menu |

- Dape configurations `python-debug` and `python-test` both run `python -m debugpy.adapter`, for the current file and for `pytest` respectively.
- Org Babel runs `python` blocks, see [4.1.6](#_416-org-babel).
- Snippets come from the classic collection only, see [4.2.1](#_421-common-workflow).

#### 4.2.16 Ruby

`prog-ruby` gates on `ruby` and adds `ruby-ts-mode` for `.rb`, `.rake`, `.gemspec`, `Gemfile`, and `Rakefile`, falling back to `ruby-mode` when tree-sitter is unavailable.
LSP runs through `ruby-lsp`, with `rubocop` as its formatter and inlay hints for implicit rescues and hash values.
Two formatters run on each save: ruby-lsp through `eglot-format-buffer` in `before-save-hook`, then apheleia's default `prettier-ruby`.
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
| `C-c t x` | `rspec-run-last-failed` | Rerun the specs that failed last run |

- Dape configuration `ruby-debug` launches the current file under `rdbg`, which dape reaches over a local port.
- Org Babel runs `ruby` blocks, see [4.1.6](#_416-org-babel).
- Snippets come from the classic collection only, see [4.2.1](#_421-common-workflow).

#### 4.2.17 Lua

`prog-lua` gates on `lua` and opens `.lua` files in `lua-ts-mode`, falling back to `lua-mode` when the Lua grammar is not installed.
The grammar installs on the first visit to a `.lua` file, pinned to the commit Emacs 31's `lua-ts-mode` is written against.
LSP runs through `lua-language-server`, with inlay hints and completion that replaces a call with its full snippet.
Two formatters run on each save: lua-language-server through `eglot-format-buffer` in `before-save-hook`, then apheleia's default `stylua`.
The REPL keys use each mode's own inferior Lua.

| Key | `lua-ts-mode` | `lua-mode` | Does |
|---|---|---|---|
| `C-c i i` | `lua-ts-inferior-lua` | `lua-start-process` | Start a Lua REPL |
| `C-c i r` | `lua-ts-send-region` | `lua-send-region` | Send the region to the REPL |
| `C-c i b` | `lua-ts-send-buffer` | `lua-send-buffer` | Send the buffer to the REPL |
| `C-c i s` | `lua-ts-show-process-buffer` | `lua-show-process-buffer` | Show the REPL buffer |

- No dape configuration and no test runner.
- Org Babel runs `lua` blocks, see [4.1.6](#_416-org-babel).
- No snippets.

#### 4.2.18 JavaScript

`prog-javascript` gates on `node` and adds `js-ts-mode` for `.js` and `.jsx` files.
LSP runs through `rass tslint`, a multiplexer over `typescript-language-server` and `vscode-eslint-language-server`, so completions and ESLint diagnostics both arrive through eglot.
`add-node-modules-path` prefers a project's local `node_modules/.bin` over global installs.
Two formatters run on each save: the language server through `eglot-format-buffer` in `before-save-hook`, then `prettier` through apheleia.

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

`jest-test-mode` keeps most of its own `C-c C-t` keys.
Only `C-c C-t t`, `n`, `p`, and `a` are unbound here.
The control variants (`C-c C-t C-t`, `C-c C-t C-n`, `C-c C-t C-p`, `C-c C-t C-a`) and the `C-c C-t d` debug keys still work.

- Dape configurations `node-script` and `node-jest` run `node` on `${userHome}/node_modules/@vscode/js-debug/src/dapDebugServer.js`, for a script and for Jest respectively.
  The adapter is not on npm.
  Download `js-debug-dap-<version>.tar.gz` from the [microsoft/vscode-js-debug releases](https://github.com/microsoft/vscode-js-debug/releases).
  It unpacks to a `js-debug/` directory, so `mkdir -p ~/node_modules/@vscode && tar -xzf js-debug-dap-<version>.tar.gz -C ~/node_modules/@vscode` puts it at that path.
- Org Babel runs `js` blocks, see [4.1.6](#_416-org-babel).
- Snippets come from the classic collection only, see [4.2.1](#_421-common-workflow).

#### 4.2.19 TypeScript

`prog-typescript` gates on `node` and adds `typescript-ts-mode` for `.ts` files and `tsx-ts-mode` for `.tsx` files, and marks `tsconfig.json`, `jsconfig.json`, and `package.json` as project roots.
LSP runs through the same `rass tslint` multiplexer as JavaScript, streaming diagnostics from both servers incrementally.
Two formatters run on each save: the language server through `eglot-format-buffer` in `before-save-hook`, then `prettier` through apheleia.
`jest-test-mode` provides the same test keys as JavaScript's.

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

- Dape configurations `ts-node-script` and `ts-jest` both run `js-debug` from the same path as JavaScript's, see [4.2.18](#_4218-javascript).
  The script variant uses `ts-node` as its runtime executable.
- Org Babel runs `typescript` blocks through `ob-typescript`, see [4.1.6](#_416-org-babel).
- No snippets.

### 4.3 Git

`magit`, `forge`, `git-modes`, `diff-hl`, and `blamer` are always on, with no gate binary.

Magit adds its own global keys.
`C-x g` opens `magit-status` for the current repository, `C-x M-g` opens `magit-dispatch`, and `C-c M-g` opens `magit-file-dispatch`.
`C-c g b` toggles `blamer-mode`, showing the last commit for the current line inline.
It is the only `C-c g` binding.

- `forge` adds pull requests and issues to magit buffers.
  It needs a repository remote pointing at a supported forge, such as GitHub or GitLab.
  Its database lives at `$XDG_DATA_HOME/emacs/forge-database.sqlite`, see [3.4](#_34-where-files-live).
- `git-modes` adds major modes for `.gitignore`, `.gitconfig`, and `.gitattributes` files.
  It binds no keys.
- `diff-hl` marks uncommitted changes in the fringe everywhere.
  It refreshes itself around every magit operation.

Two more packages add AI-generated text through gptel.
`ai-gptel` points gptel at OpenRouter.
It reads the OpenRouter API key from auth-source, stored under the host name `OPENROUTER_API_KEY`.

`gptel-magit` adds these inside magit:

| Key | Command | Does |
|---|---|---|
| `M-g` | `gptel-magit-generate-message` | Generate a commit message in the commit buffer, in place |
| `g` | `gptel-magit-commit-generate` | Generate a message and open it in the commit buffer for editing, from magit's commit transient (`c` in `magit-status`) |
| `x` | `gptel-magit-diff-explain` | Explain the diff at point, from magit's diff transient |

`gptel-forge-prs` adds these inside the buffer forge opens for `forge-create-pullreq`:

| Key | Command | Does |
|---|---|---|
| `M-g` | `gptel-forge-prs-generate-description` | Generate a PR description from the diff between the source and target branches |
| `M-r` | `gptel-forge-prs-generate-description-with-rationale` | Same, after prompting for a rationale |

Both commands run only in a buffer for a new pull request.
Both replace the buffer's contents with the generated description.
Either one first reads any PR template forge inserted into the buffer, and uses it as the structure to fill in.

### 4.4 Writing

`core-spell` and `text-markdown` are always on, with no gate binary.

#### 4.4.1 Spell checking

`jinx` checks spelling across whatever text is visible, not word by word.
It compiles a small native module against the enchant library the first time `jinx-mode` turns on.
That needs a C compiler and `pkg-config` on `PATH`, plus enchant itself.
Install enchant with `brew install enchant` on macOS, or `libenchant-2-dev` on Debian and Ubuntu.

| Buffer | Checks |
|---|---|
| Any `text-mode` buffer, including Markdown and AsciiDoc | Prose, minus jinx's default exclusions, such as Markdown code, links, URLs, and markup |
| Any `prog-mode` buffer | Comments and docstrings only |
| Org buffers | Prose, and comments inside `#+begin_src` blocks, but not code |

Org gets its own face list rather than jinx's default, so a src block's comments stay checked while its code does not.

| Key | Command | Does |
|---|---|---|
| `M-$` | `jinx-correct` | Correct the word at point |
| `C-M-$` | `jinx-correct-all` | Correct every misspelling in the buffer |

#### 4.4.2 Markdown

`text-markdown` maps `gfm-mode` to `.md` and `README.md` files, and renders through `pandoc`.

| Key | Command | Does |
|---|---|---|
| `C-c C-p` | `markdown-preview-mode` | Open a live-updating browser preview, mermaid diagrams included |
| `C-c C-g` | `grip-mode` | Open a second live preview through `mdopen`, `go-grip`, or `grip` |
| `C-c C-e h` | `myde-markdown-export-html` | Export to HTML alongside the source |
| `C-c C-e p` | `myde-markdown-export-pdf` | Export to PDF alongside the source |
| `C-c v` | `visual-fill-column-mode` | Toggle wrapping at `fill-column` instead of window width |
| `C-c t` | `markdown-table-align` | Align the table at point |

`grip-mode` uses the first of `mdopen`, `go-grip`, or `grip` (`pip install grip`) it finds on `PATH`.
Only `grip` renders through GitHub's API.
PDF export also needs a TeX engine, for example `brew install --cask basictex`.
`markdown-do`, markdown-mode's own default, keeps its usual `C-c C-d`.
`C-c C-e` is a prefix here, holding the two export keys above.

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

### 5.3 A second Emacs next to the daemon

`$EDITOR` opens a file in a new daemon frame instead of the Emacs.app window already on screen.

Emacs.app is running as a second Emacs next to the daemon, see [2.3](#_23-run-as-a-daemon).
The daemon owns the `server` socket, so Emacs.app skipped `server-start`, and `emacsclient` reaches the daemon instead.

Quit the second Emacs, confirm only the daemon remains, then retry:

```sh
ps aux | grep -i "[E]macs" | grep -v emacsclient
```

Launch frames only through `emacsclient -c`, or through `~/Applications/Emacsclient.app` on macOS, never `Emacs.app` directly.

### 5.4 MCP bridge CONNECTION_CLOSED

`/mcp` reports `CONNECTION_CLOSED` although the daemon is running, see [2.7](#_27-emacs-mcp-server).

The `mcp-server` process inside the daemon is not listening on its socket, usually because the daemon restarted without it, or because it crashed.
A socket left behind by a dead daemon has no listener, so the next start reclaims it as stale.
`mcp-server-socket-conflict-resolution` is `error`, so a second Emacs (`Emacs.app`, or `mise run probe`) never steals a live socket.
That Emacs starts without an MCP server and leaves the daemon's socket alone.

Restart the server inside the daemon:

```sh
emacsclient --eval '(progn (ignore-errors (mcp-server-stop)) (mcp-server-start-unix))'
```

Then reconnect with `/mcp`.

### 5.5 "error invoking gcc driver"

Native compilation logs `error invoking gcc driver` for one of elpaca's own files during startup, on macOS.

Those files load before `exec-path-from-shell` runs.
Emacs launched from the Dock, from Finder, or by the launchd agent starts with the bare `PATH` that launchd gives it.
On that `PATH`, libgccjit cannot find the Homebrew gcc driver.

It is a warning, not a failure.
The affected file runs byte-compiled until a start with a full `PATH` compiles it, such as `emacs` started from a terminal.
No action is needed.

### 5.6 Org problems

**A project's tasks all show up as `tasks` in the agenda.**
The file is missing `#+category:`, see [3.3](#_33-projects).
Add `#+category: <project_name>` at the top, with underscores in place of hyphens or dots.

**A new `tasks.org` is not in the agenda.**
The agenda rescans before every `C-c o a`, so no restart is needed, see [3.3](#_33-projects).
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
There is no other switch, see [3.1](#_31-sections).
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
