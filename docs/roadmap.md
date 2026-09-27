# Roadmap

Status as of 2026-09-27.

## Now

### RM-9: Docs schema, traceability, theme, Pages, and `VERSION` :id=rm-9

- **Requirements:** [FR-10](prd.md#fr-10), [FR-11](prd.md#fr-11), [FR-12](prd.md#fr-12), [NFR-7](prd.md#nfr-7)
- **Decisions:** [ADR-11](adr.md#adr-11), [ADR-12](adr.md#adr-12), [ADR-13](adr.md#adr-13)

Bring `docs/` onto the SciPlay doc schema with requirement traceability, a vendored Catppuccin Frappé theme, GitHub Pages publishing, and a root `VERSION` file.
It moves to Shipped once the owner enables Pages and the first deploy succeeds.

## Next

### RM-10: Resolve the `C-c d` collision in Elixir buffers :id=rm-10

- **Requirements:** [FR-7](prd.md#fr-7)

`mix.el` binds `C-c d` in `mix-minor-mode` (`elpaca/sources/mix/mix.el:322`).
The global dape keys under `C-c d` therefore do not reach Elixir buffers.

### RM-11: Boot the probe daemon with stdin closed :id=rm-11

- **Requirements:** [FR-2](prd.md#fr-2), [NFR-3](prd.md#nfr-3)

`scripts/myde-probe.sh` starts its throwaway daemon without redirecting stdin.
A startup read of stdin then aborts `elpaca-after-init-hook`, so the probe reports modes as off that are on in a real session.

## Later

### RM-12: Decide on `ob-zig` :id=rm-12

- **Decisions:** [ADR-01](adr.md#adr-01)

`ob-zig` requires `zig-mode` but declares no `Package-Requires`, so elpaca never byte-compiles it and Emacs warns about it on every start.
AGENTS.md lists three options: live with the warning, pin a fork that adds the header, or drop the package.

## Shipped

### RM-8: Docs site with preview and search :id=rm-8

- **Requirements:** [FR-10](prd.md#fr-10)
- **Shipped:** 2026-09-27, [Unreleased](changelog.md#unreleased)

A docsify site for `docs/`, served natively or from a container, with qmd search.

### RM-5: Daemon session :id=rm-5

- **Requirements:** [FR-4](prd.md#fr-4)
- **Decisions:** [ADR-05](adr.md#adr-05)
- **Shipped:** 2026-09-27, [Unreleased](changelog.md#unreleased)

The dashboard opens on demand, and daemon startup warnings stay off the first client frame.

### RM-6: MCP server on a fixed socket :id=rm-6

- **Requirements:** [FR-8](prd.md#fr-8)
- **Decisions:** [ADR-09](adr.md#adr-09)
- **Shipped:** 2026-09-22, [Unreleased](changelog.md#unreleased)

The MCP server listens on a fixed socket that a second Emacs cannot take from a live daemon.

### RM-7: Tangle on save :id=rm-7

- **Requirements:** [FR-9](prd.md#fr-9)
- **Decisions:** [ADR-06](adr.md#adr-06)
- **Shipped:** 2026-09-21, [Unreleased](changelog.md#unreleased)

Saving `myde.org` in Emacs re-tangles it.

### RM-4: Org workflow in `myde.org` :id=rm-4

- **Requirements:** [FR-5](prd.md#fr-5), [FR-6](prd.md#fr-6)
- **Decisions:** [ADR-08](adr.md#adr-08)
- **Shipped:** 2026-09-18, [Unreleased](changelog.md#unreleased)

Capture, `tasks.org` projects, ERT tests, and the macOS `org-protocol://` handler.

### RM-3: mise tasks and hk hooks :id=rm-3

- **Requirements:** [FR-9](prd.md#fr-9)
- **Decisions:** [ADR-06](adr.md#adr-06)
- **Shipped:** 2026-09-18, [Unreleased](changelog.md#unreleased)

mise tasks replace the Makefile, and hk runs the git hooks.

### RM-2: Library and config split :id=rm-2

- **Requirements:** [NFR-5](prd.md#nfr-5)
- **Decisions:** [ADR-03](adr.md#adr-03)
- **Shipped:** 2026-09-18, [Unreleased](changelog.md#unreleased)

`user-lisp/myde.el` holds only definitions.

### RM-1: Three-file literate config :id=rm-1

- **Requirements:** [FR-1](prd.md#fr-1), [FR-2](prd.md#fr-2), [FR-3](prd.md#fr-3), [FR-9](prd.md#fr-9), [NFR-1](prd.md#nfr-1), [NFR-3](prd.md#nfr-3)
- **Decisions:** [ADR-00](adr.md#adr-00), [ADR-01](adr.md#adr-01), [ADR-02](adr.md#adr-02)
- **Shipped:** 2026-09-15, [Unreleased](changelog.md#unreleased)

One literate `myde.org`, elpaca, and binary gates replace the `modules/` tree.
