# Roadmap

Status as of 2026-09-28.

## Now

Nothing is in progress.

## Next

Nothing is queued.

## Later

Nothing is planned.

## Shipped

### RM-17: The probe reports what went wrong on its own :id=rm-17

- **Requirements:** [FR-2](prd.md#fr-2), [NFR-3](prd.md#nfr-3)
- **Shipped:** 2026-09-28, [0.1.1](changelog.md#_011-2026-09-28)

The report's `error:` lines now include the `Error (…)` and `Warning (…)` lines that `display-warning` logs, which is where RM-11's hook failure and the `ob-zig` warnings surfaced.
They leave out the MCP "Socket already exists" line, because under ADR-09 it only means the live daemon owns the socket.
The daemon boots with stdin from `/dev/null` and a 5 minute deadline on init.
Reproducing RM-11 without its fix showed why both are needed: the first mise prompt's read signalled end-of-file, but a second one, raised while elpaca reported the first, spun at 100% CPU.
Past the deadline the probe fails with the tail of the daemon's output, which names the prompt.

### RM-16: GitHub releases on tag push :id=rm-16

- **Requirements:** [FR-12](prd.md#fr-12)
- **Shipped:** 2026-09-28, [0.1.1](changelog.md#_011-2026-09-28)

Pushing a `v*` tag runs `.github/workflows/release.yml`, which checks the tag against `VERSION` and runs `mise run release`.
The task publishes the GitHub release with `gh release create --verify-tag`, so it never creates a tag.
Its notes are the version's changelog section, cut by `scripts/release_notes.py` with the relative doc links rewritten to the Pages site.
The same task published the v0.1.0 release, whose tag predates the workflow.

### RM-12: Decide on `ob-zig` :id=rm-12

- **Decisions:** [ADR-01](adr.md#adr-01)
- **Shipped:** 2026-09-28, [0.1.0](changelog.md#_010-2026-09-28)

`ob-zig` is pinned to [`mojochao/ob-zig.el`](https://github.com/mojochao/ob-zig.el), a fork that adds the `lexical-binding` cookie and the `Package-Requires` line upstream lacks.
Without them elpaca compiled it with no `zig-mode` on `load-path`, the compile failed, and Emacs warned about the source on every start.
Upstream has been quiet since 2024-08, and none of its forks had the fix.
With it elpaca builds `ob-zig.elc`, and startup logs no warnings.

### RM-11: Find what reads stdin during a throwaway daemon's startup :id=rm-11

- **Requirements:** [FR-2](prd.md#fr-2), [NFR-3](prd.md#nfr-3)
- **Shipped:** 2026-09-28, [0.1.0](changelog.md#_010-2026-09-28)

The read was `global-mise-mode` asking whether to trust the repo's `mise.toml`.
The probe's private `XDG_STATE_HOME` hid mise's trust store, and elpaca's buffers under `elpaca/` led mise to that config whatever the daemon's working directory.
A daemon with no frame reads the answer from stdin, so the failed read ended `elpaca-after-init-hook` right after `global-mise-mode`.
The probe now sets `MISE_TRUSTED_CONFIG_PATHS` to the config it boots, and every startup mode reports `on`.

### RM-15: Every key, hook, and setting goes through a use-package keyword :id=rm-15

- **Requirements:** [FR-7](prd.md#fr-7), [NFR-4](prd.md#nfr-4)
- **Shipped:** 2026-09-28, [0.1.0](changelog.md#_010-2026-09-28)

An audit of `myde.org` moved every raw `define-key`, `add-hook`, and `setq` inside a `use-package` form onto `:bind`, `:bind-keymap`, `:hook`, `:custom`, or `:interpreter`.
The conversion exposed defects the raw calls had hidden: recentf never loaded, hl-line stayed on in terminal buffers, nov wrote reading positions to the repo root, and cider's test keys and slime's setup never applied.
`CLAUDE.md` records the three use-package traps behind them.

### RM-10: Resolve the `C-c d` collision in Elixir buffers :id=rm-10

- **Requirements:** [FR-7](prd.md#fr-7)
- **Shipped:** 2026-09-28, [0.1.0](changelog.md#_010-2026-09-28)

`mix.el`'s command map moved from `C-c d` to `C-c x`.
The global dape keys under `C-c d` now reach Elixir buffers.

### RM-14: Every bound key runs a real command :id=rm-14

- **Requirements:** [FR-7](prd.md#fr-7)
- **Shipped:** 2026-09-28, [0.1.0](changelog.md#_010-2026-09-28)

Several keys across dape, Common Lisp, Erlang, Go, Zig, Python, and Ruby were bound to commands that did not exist.
Each now runs a real command, and gotest-ts now loads in Go buffers.
`C-c ! n`, `p`, and `l` reach flymake in eglot buffers, where flycheck's own map used to shadow them.

### RM-9: Docs schema, traceability, theme, Pages, and `VERSION` :id=rm-9

- **Requirements:** [FR-10](prd.md#fr-10), [FR-11](prd.md#fr-11), [FR-12](prd.md#fr-12), [NFR-7](prd.md#nfr-7)
- **Decisions:** [ADR-11](adr.md#adr-11), [ADR-12](adr.md#adr-12), [ADR-13](adr.md#adr-13)
- **Shipped:** 2026-09-28, [0.1.0](changelog.md#_010-2026-09-28)

`docs/` follows the SciPlay doc schema with requirement traceability, a vendored Catppuccin Frappé theme, GitHub Pages publishing, and a root `VERSION` file.
The first deploy published the site on 2026-09-28.

### RM-13: Lua and tree-sitter grammar fixes :id=rm-13

- **Requirements:** [FR-7](prd.md#fr-7)
- **Shipped:** 2026-09-28, [0.1.0](changelog.md#_010-2026-09-28)

Lua buffers run their full setup and open in `lua-ts-mode`.
Every configured tree-sitter grammar installs, and each mode that uses one passes its font-lock queries against it.

### RM-8: Docs site with preview and search :id=rm-8

- **Requirements:** [FR-10](prd.md#fr-10)
- **Shipped:** 2026-09-27, [0.1.0](changelog.md#_010-2026-09-28)

A docsify site for `docs/`, served natively or from a container, with qmd search.

### RM-5: Daemon session :id=rm-5

- **Requirements:** [FR-4](prd.md#fr-4)
- **Decisions:** [ADR-05](adr.md#adr-05)
- **Shipped:** 2026-09-27, [0.1.0](changelog.md#_010-2026-09-28)

The dashboard opens on demand, and daemon startup warnings stay off the first client frame.

### RM-6: MCP server on a fixed socket :id=rm-6

- **Requirements:** [FR-8](prd.md#fr-8)
- **Decisions:** [ADR-09](adr.md#adr-09)
- **Shipped:** 2026-09-22, [0.1.0](changelog.md#_010-2026-09-28)

The MCP server listens on a fixed socket that a second Emacs cannot take from a live daemon.

### RM-7: Tangle on save :id=rm-7

- **Requirements:** [FR-9](prd.md#fr-9)
- **Decisions:** [ADR-06](adr.md#adr-06)
- **Shipped:** 2026-09-21, [0.1.0](changelog.md#_010-2026-09-28)

Saving `myde.org` in Emacs re-tangles it.

### RM-4: Org workflow in `myde.org` :id=rm-4

- **Requirements:** [FR-5](prd.md#fr-5), [FR-6](prd.md#fr-6)
- **Decisions:** [ADR-08](adr.md#adr-08)
- **Shipped:** 2026-09-18, [0.1.0](changelog.md#_010-2026-09-28)

Capture, `tasks.org` projects, ERT tests, and the macOS `org-protocol://` handler.

### RM-3: mise tasks and hk hooks :id=rm-3

- **Requirements:** [FR-9](prd.md#fr-9)
- **Decisions:** [ADR-06](adr.md#adr-06)
- **Shipped:** 2026-09-18, [0.1.0](changelog.md#_010-2026-09-28)

mise tasks replace the Makefile, and hk runs the git hooks.

### RM-2: Library and config split :id=rm-2

- **Requirements:** [NFR-5](prd.md#nfr-5)
- **Decisions:** [ADR-03](adr.md#adr-03)
- **Shipped:** 2026-09-18, [0.1.0](changelog.md#_010-2026-09-28)

`user-lisp/myde.el` holds only definitions.

### RM-1: Three-file literate config :id=rm-1

- **Requirements:** [FR-1](prd.md#fr-1), [FR-2](prd.md#fr-2), [FR-3](prd.md#fr-3), [FR-9](prd.md#fr-9), [NFR-1](prd.md#nfr-1), [NFR-3](prd.md#nfr-3)
- **Decisions:** [ADR-00](adr.md#adr-00), [ADR-01](adr.md#adr-01), [ADR-02](adr.md#adr-02)
- **Shipped:** 2026-09-15, [0.1.0](changelog.md#_010-2026-09-28)

One literate `myde.org`, elpaca, and binary gates replace the `modules/` tree.
