# Changelog

No release has been cut yet.
Entries start at 2026-09-15, the three-file literate config.
Earlier history is in `git log`.
Each entry traces to the roadmap item it shipped.

## Unreleased

### Added

- 2026-09-28: `docs/` follows the SciPlay doc schema, and `mise run docs-check` enforces requirement traceability, links, vendored assets, and markdown lint.
  The site is vendored docsify 4 themed Catppuccin Frappé, and the sidebar shows the root `VERSION`.
  A push to `main` that changes the docs publishes them to GitHub Pages once the checks pass.
  Traces to [RM-9](roadmap.md#rm-9), [FR-10](prd.md#fr-10), [FR-11](prd.md#fr-11), [FR-12](prd.md#fr-12), [NFR-7](prd.md#nfr-7), [ADR-11](adr.md#adr-11), [ADR-12](adr.md#adr-12), [ADR-13](adr.md#adr-13).
  Commits `e0a8a05` to `1e552fd`.
- 2026-09-27: A docsify site for `docs/`, served natively or from a container, with qmd search.
  Traces to [RM-8](roadmap.md#rm-8), [FR-10](prd.md#fr-10).
  Commits `161892c`, `9ea6ba4`, `68326e4`, and `b784ddd`.
- 2026-09-21: Saving `myde.org` in Emacs re-tangles it, so the elisp on disk never lags the buffer.
  Traces to [RM-7](roadmap.md#rm-7), [FR-9](prd.md#fr-9), [ADR-06](adr.md#adr-06).
  Commit `6f3393e`.
- 2026-09-18: The org workflow branch is ported into `myde.org`, with `tasks.org` projects, ERT tests for the silent failures, and the macOS `org-protocol://` handler.
  Traces to [RM-4](roadmap.md#rm-4), [FR-5](prd.md#fr-5), [FR-6](prd.md#fr-6), [ADR-08](adr.md#adr-08).
  Commits `a2578f6`, `88aaf9c`, and `8c5a886`.

### Changed

- 2026-09-27: The dashboard opens on demand instead of as the initial buffer, and daemon startup warnings stay off the first client frame.
  Traces to [RM-5](roadmap.md#rm-5), [FR-4](prd.md#fr-4), [ADR-05](adr.md#adr-05).
  Commits `16da103`, `6dec388`, and `1d87ae0`.
- 2026-09-18: mise tasks replace the Makefile, and hk hooks re-tangle on pre-commit and verify on pre-push.
  Traces to [RM-3](roadmap.md#rm-3), [FR-9](prd.md#fr-9), [ADR-06](adr.md#adr-06).
  Commit `1d8c3e0`.
- 2026-09-18: `user-lisp/myde.el` holds only definitions, and every `use-package` form, gate, and assignment moved to `init.el`.
  `mise run forms` asserts the split.
  Traces to [RM-2](roadmap.md#rm-2), [NFR-5](prd.md#nfr-5), [ADR-03](adr.md#adr-03).
  Commits `aefb6ea` to `74fbf2f`.
- 2026-09-15: One literate `myde.org` replaces the `modules/` tree and tangles to `early-init.el`, `init.el`, and `user-lisp/myde.el`.
  elpaca replaces package.el, and toolchain sections are gated on their binary instead of a toggle.
  Traces to [RM-1](roadmap.md#rm-1), [FR-1](prd.md#fr-1), [FR-2](prd.md#fr-2), [FR-3](prd.md#fr-3), [FR-9](prd.md#fr-9), [NFR-1](prd.md#nfr-1), [NFR-3](prd.md#nfr-3), [ADR-00](adr.md#adr-00), [ADR-01](adr.md#adr-01), [ADR-02](adr.md#adr-02).
  Commits `9ad474e` to `f33658c`.

### Fixed

- 2026-09-28: `C-c ! n`, `p`, and `l` navigate the language server's diagnostics in eglot buffers.
  flycheck's `C-c !` map used to shadow them in every flycheck buffer, so they only ever reached flycheck.
  They now dispatch to flymake where it runs and to flycheck elsewhere.
  Traces to [RM-14](roadmap.md#rm-14).
  Commit `422c059`.
- 2026-09-28: Elixir buffers keep the `C-c d` dape keys, and the Mix task keys move to `C-c x`.
  Traces to [RM-10](roadmap.md#rm-10), [FR-7](prd.md#fr-7).
  Commit `cfc53f0`.
- 2026-09-28: Keys bound to commands that do not exist now run real ones, across dape, Common Lisp, Erlang, Go, Zig, Python, and Ruby.
  gotest-ts now loads in Go buffers, so its test keys work there.
  Traces to [RM-14](roadmap.md#rm-14), [FR-7](prd.md#fr-7).
  Commit `cfc53f0`.
- 2026-09-28: Lua buffers run their full setup again, and the `C-c i` REPL keys work in both Lua modes.
  A hook to `inf-lua-minor-mode`, which inf-lua never defined, stopped each Lua buffer's setup before eglot and format-on-save ran.
  inf-lua is dropped for each mode's own inferior Lua.
  Traces to [RM-13](roadmap.md#rm-13), [FR-7](prd.md#fr-7).
  Commit `57901d0`.
- 2026-09-28: `.lua` files open in `lua-ts-mode`.
  The Lua grammar source named a branch and a source directory the repository does not have, so the grammar never installed.
  It is now pinned to the commit Emacs 31's `lua-ts-mode` is written against.
  Traces to [RM-13](roadmap.md#rm-13), [FR-7](prd.md#fr-7).
  Commit `adad9bd`.
- 2026-09-28: The Go, Zig, Clojure, and Common Lisp grammars install from their real repositories.
  Elixir buffers use the built-in `heex-ts-mode`, since the external package of the same name broke `elixir-ts-mode`.
  XML files open in `nxml-mode` directly, since Emacs 31 has no `xml-ts-mode`.
  Traces to [RM-13](roadmap.md#rm-13), [FR-7](prd.md#fr-7).
  Commit `35e41ff`.
- 2026-09-22: The MCP server keeps a fixed socket path, and a second Emacs on this config no longer takes the socket from a live daemon.
  Traces to [RM-6](roadmap.md#rm-6), [FR-8](prd.md#fr-8), [ADR-09](adr.md#adr-09).
  Commits `69470b4` and `9ee87eb`.
