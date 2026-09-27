# Glossary

One `## {Term}` section per entry, alphabetical.

## Activation block

One of the two blocks a `myde.org` section's `***` heading can hold, tangled into `init.el`.
It carries `use-package` forms, `setq`, and `add-hook` calls.
It gets wrapped in a binary gate when the section needs a toolchain.
See [Developer Guide §3.1](developer.md#_31-editing-mydeorg).

## Binary gate

A `(when (executable-find "<binary>") ...)` form wrapped around a whole `use-package` form.
It gates a section on whether its toolchain is on `PATH`.
The gate must wrap the whole form, since elpaca queues the package order when the form is expanded, before `:if` or `:when` runs.
See [Technical Design §1.3](tdd.md#_13-binary-gates).

## Client frame

A GUI frame opened with `emacsclient -c` against the single running daemon, instead of a separate Emacs process.
The Dock's `Emacsclient.app` wraps that same call.
A new client frame opens on `*scratch*` rather than a startup dashboard.
See [Technical Design §1.4](tdd.md#_14-session-model).

## Daemon

The one `emacs --fg-daemon` process meant to be the only Emacs running on a machine.
A launchd agent starts it at login with `RunAtLoad` and `KeepAlive`.
It holds the `server` socket and the MCP socket, so a second Emacs process started by mistake gets neither.
See [Developer Guide §5.1](developer.md#_51-the-launchd-agent-and-emacsclientapp).

## Definition block

The other block a `myde.org` section's `***` heading can hold, tangled into `user-lisp/myde.el`.
It carries only `defun`, `defvar`, `defcustom`, `defconst`, `define-derived-mode`, and `define-minor-mode` forms, with no side effects.
`mise run forms` asserts that invariant holds.
See [Developer Guide §3.1](developer.md#_31-editing-mydeorg).

## elpaca order

The unit of work elpaca queues for a package when its `use-package` form is expanded, before any `:if` or `:when` inside it runs.
Every package needs exactly one form that ensures it.
A duplicate order makes elpaca 0.12 abort init.
See [Technical Design §4.1](tdd.md#_41-elpaca).

## Half-finished clone

A package source directory left holding a `.git` folder with no working tree.
elpaca clones with `--filter=tree:0 --no-checkout`, then completes the checkout later by fetching trees and blobs on demand.
A flaky git host can leave that second step unfinished, and elpaca never retries it on its own.
See [User Guide §5.1](user.md#_51-a-package-will-not-install).

## hk

The tool that runs this repo's git hooks, defined in `hk.pkl` and installed by `mise run init`.
It uses git's config-based hooks (2.54 or later), so `.git/hooks` stays empty.
See [Quality Assurance §2.4](qa.md#_24-enforcement-with-git-hooks).

## MCP server

The `ai-mcp` section's server, running inside Emacs on a fixed Unix socket at `$XDG_CACHE_HOME/emacs/emacs-mcp-server.sock`.
It exposes live Emacs state, such as `eval-elisp`, diagnostics, and Org tools, to agents over a `socat` bridge.
A socket left behind by a dead daemon is reclaimed as stale rather than blocking the next start.
See [Technical Design §2.4](tdd.md#_24-singleton-state).

## mise

The task runner behind every `mise run <task>` command in this repo, reading its task definitions from `mise.toml`.
`mise trust` must run once per machine before any other mise command, since mise refuses to read an untrusted config.
See [Developer Guide §2.3](developer.md#_23-initialize-project).

## org-protocol

A URI scheme the browser uses to send a URL, page title, and any selected text to a running Emacs session.
It needs a system-level URI handler and a browser bookmarklet.
It triggers a capture template that appends a tagged entry to `~/org/inbox.org`.
See [Technical Design §4.5](tdd.md#_45-org-protocol-handlers).

## Presence is intent

The design principle behind section enablement: no module toggles, no override list, and no `custom.el` entries.
Installing a section's binary enables it on the next start, and removing the binary disables it.
Presence on `PATH` is the only signal.
See [Architecture Decisions ADR-02](adr.md#adr-02).

## Probe

The `mise run probe <report>` task, which boots this config as an isolated throwaway daemon.
It uses a unique socket, a `PATH` stripped to `/usr/bin:/bin`, and a private `XDG_STATE_HOME`.
It writes a report of declared packages, startup modes, init time, and errors, meant to be diffed against an earlier run.
See [Quality Assurance §1.1](qa.md#_11-layers-of-assurance).

## Project

Any directory containing a `tasks.org`, with no fixed root and no naming convention.
The file is located by searching upward from the current directory.
Only projects under `myde-org-code-directory` show up in the agenda.
See [Technical Design §2.3](tdd.md#_23-org-files-and-projects).

## Section

A named unit under `* Configuration` in `myde.org`, grouped into categories with a `<category>-<name>` naming convention.
`core-*`, `ai-*`, `auth-*`, `data-*`, `containers-*`, `prog-*`, `text-*`, and `ebook-*` are the eight categories.
Each one holds sections such as `core-base` or `prog-go`.

## Tangle

The act of `mise run tangle` regenerating `early-init.el`, `init.el`, and `user-lisp/myde.el` from `myde.org`.
`myde.org` is the only file edited by hand, and the tangled files are committed.
Editing one of the three tangled files directly gets silently overwritten at the next tangle.
See [Technical Design §1.1](tdd.md#_11-the-three-tangled-files).

## Traceability

The consolidated, traceable view section 8 of the PRD gives its requirements, split into functional and non-functional.
Each requirement's block links forward to the ADR, technical design section, QA section, and roadmap item that serve it.
Each of those downstream docs links back to the requirement it serves.
See [Quality Assurance §2.5](qa.md#_25-docs-checks).

## user-lisp

The `user-lisp/` directory, which sits at `load-path` position 0 and shadows built-in Emacs libraries.
Only `myde.el` belongs there, since a file named `org.el` there would shadow built-in Org.

## XDG directories

The `$XDG_STATE_HOME/emacs/`, `$XDG_DATA_HOME/emacs/`, and `$XDG_CACHE_HOME/emacs/` paths that hold this config's state, data, and cache.
They are set in the `core-base` section through the built-in `xdg.el` library.
Only packages live inside `user-emacs-directory` itself, in `./elpaca/` at the repo root.
See [Technical Design §2.1](tdd.md#_21-xdg-paths).
