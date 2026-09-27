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

## 5. Error handling

## 6. FAQ

## 7. References
