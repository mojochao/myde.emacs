# Three-File Literate Config — Design

**Date:** 2026-09-15
**Status:** Approved, pending implementation plan

## Problem

The current config is 8,191 lines of Emacs Lisp across 53 modules in
`modules/<category>-<name>/{lib,cfg}.el`, driven by a module descriptor list in
`init.el` and 24 `defcustom` toggles persisted in `custom.el`. Three specific
pains motivate the rewrite:

1. **Navigation and ceremony.** Changing one thing means touching `lib.el`,
   `cfg.el`, `init.el`, and `custom.el`.
2. **Toggle bookkeeping.** The 24 `myde-module-*-enabled` toggles are a second
   source of truth maintained by hand.
3. **package.el fighting back.** The package-system invariants documented in
   `AGENTS.md` — `package-install-upgrade-built-in`, `"builtin"` archive
   pinning, version-conditional `transient` pinning, `package-initialize`
   ordering, VC upgrade advice — are all scar tissue.

Config *volume* is explicitly not a pain. The goal is restructuring, not
deletion of functionality.

## Goals

- Three loaded elisp files, generated from one literate org source.
- Module enablement derived from the environment, not from hand-maintained
  toggles.
- `elpaca` in place of `package.el`.
- Package *loading* deferred as much as possible.
- Linux and macOS both supported.

## Non-goals

- Reducing the amount of configuration.
- Changing keybindings, XDG layout, or platform-guard conventions.
- Auditing or rewriting individual module contents beyond what is needed to
  make them load.

## Verified facts

These were measured or confirmed on the development machine (macOS, Emacs
31.1, `Development version a360712c9d27`, build 2026-09-08) and constrain the
design.

| Fact | Evidence |
|---|---|
| `user-lisp-directory` is `~/.config/emacs/user-lisp/` and `(require 'myde)` from it works | Probe daemon on Emacs 31.1: `REQUIRE-WORKS=probe` |
| `user-lisp` is added at **position 0** of `load-path` — it shadows built-ins | Probe daemon: entry `"/tmp/mydetest/user-lisp"`, position 0 of 27 |
| elpaca queues the order **outside** the `use-package` form, so `:if`/`:when` does **not** prevent cloning | Manual: `(use-package example :ensure t)` → `(elpaca example (use-package example))` |
| `elpaca-wait` exists, is autoloaded: "Block until currently queued orders are processed." | `elpaca.el` source |
| `elpaca-after-init-hook` is a `defcustom`, "Elpaca's analogue to `after-init-hook`" | `elpaca.el` source |
| The `elpaca-use-package` menu recipe already sets `:wait t` | `elpaca-menu-extensions` in `elpaca.el` |
| elpaca requires `(setq package-enable-at-startup nil)` in early-init | elpaca README |
| `exec-path-from-shell-arguments` defaults to `("-l" "-i")` for zsh | `elpa/exec-path-from-shell-2.2/exec-path-from-shell.el:121` |
| `-l -i` probe costs **~575ms**; `-l` alone costs **~88ms** | 3-run timing: 1.726s vs 0.264s |
| `-l` yields an **identical 41-entry PATH** to `-l -i` on this machine | `comm` diff of both PATHs: empty |
| Binaries are spread across 7 directories including mise shims and a version-numbered gem path | `~/.local/share/mise/shims`, `/opt/homebrew/bin`, `~/.cargo/bin`, `~/.gem/ruby/4.0.0/bin`, `~/.local/bin`, `/opt/homebrew/opt/ruby/bin`, `/usr/bin` |
| `--batch` implies `--no-init-file`; `-Q` likewise | Empirical: init.el did not run under either |

The scattered-binary finding is why a hardcoded `exec-path` seed list was
rejected: one entry embeds a Ruby version (`4.0.0`) and another is a mise shim
directory.

## Architecture

### File layout

```
myde.org              <- the ONLY file edited by hand
early-init.el         <- tangled output, committed
init.el               <- tangled output, committed
user-lisp/myde.el     <- tangled output, committed; load-path position 0
custom.el             <- faces + safe themes only (~15 lines, was 75)
elpaca/               <- gitignored, replaces elpa/
Makefile              <- gains `tangle` and `check` targets
```

The three `.el` files are build outputs. They are committed so that a fresh
clone works without a tangle step and so startup never loads org.

### Removed

| Removed | Approx. size |
|---|---|
| `modules/` — 53 directories, 106 files | ~7,900 lines |
| `modules.el` — `myde-module` struct, `myde/m`, `myde-customize`, `myde-initialize`, `myde-load-module`, `myde-module-category-enabled-p` | 180 lines |
| 24 `defcustom` toggles, `package-selected-packages` (100+ entries), `package-vc-selected-packages` (9 entries) from `custom.el` | ~60 lines |
| `myde/filter-git-only-vc-packages` advice in `core-base/lib.el` — elpaca is git-native | ~15 lines |
| `myde-exec-path-from-shell-startup-hook` in `core-base/lib.el:38` — inlined, including its hand-rolled `package-install` | 12 lines |
| All package.el invariants in `AGENTS.md`: `package-install-upgrade-built-in nil`, `"builtin"` pinning for `csharp-mode`/`wallpaper`, version-conditional `transient` archive pinning, `package-initialize` ordering rules | 5 documented workarounds |

### early-init.el

Substance unchanged from the current 179 lines. Changes:

- Add `(setq package-enable-at-startup nil)` — required by elpaca.
- Garbage-collection and `file-name-handler-alist` restoration move from
  `after-init-hook` / `emacs-startup-hook` to `elpaca-after-init-hook`.

Retained: GC suppression, `file-name-handler-alist` clearing, native-compile
cache redirection to `$XDG_CACHE_HOME/emacs/eln-cache`, `default-frame-alist`
setup, `auto-save-list-file-prefix`, startup-screen suppression, process
buffer sizing for LSP throughput.

Note: `early-init.el` cannot evaluate binary gates, because gates depend on
`exec-path-from-shell`, which is a package, and elpaca bootstraps in `init.el`.
All detection therefore lives in `myde.el`.

### init.el

Roughly 40 lines:

1. The elpaca installer block, verbatim, `elpaca-installer-version 0.12`.
2. `(elpaca elpaca-use-package (elpaca-use-package-mode))` — the menu recipe
   for `elpaca-use-package` already carries `:wait t`, so no explicit
   `(elpaca-wait)` is needed here.
3. `(require 'myde)` — resolved from `user-lisp/`.
4. `(add-hook 'elpaca-after-init-hook (lambda () (load custom-file 'noerror)))`
5. Server start, on `elpaca-after-init-hook`.

### user-lisp/myde.el

Approximately 7,000 lines, in this order:

1. **Environment.** `exec-path-from-shell`, first form in the file. Every gate
   below depends on it.
2. **Core.** The 12 `core-*` sections, unconditional.
3. **Languages.** Each wrapped in `(when (executable-find …) …)`.
4. **Data and text formats.** Unconditional — they are `:mode`-deferred and so
   cost nothing at startup.
5. **Ebooks, AI, Auth, Containers.** Gated where a binary exists.
6. `(provide 'myde)`

## Environment detection

### exec-path-from-shell

Must be the first `use-package` form in `myde.el`, above every gated
declaration:

```elisp
(use-package exec-path-from-shell
  :ensure (:wait t)
  :demand t
  :init (setq exec-path-from-shell-arguments '("-l"))
  :config (when (or (daemonp) window-system)
            (exec-path-from-shell-initialize)))
```

Four deliberate choices:

- **`:ensure (:wait t)`** — under elpaca the package is not on `load-path`
  until queues process on `after-init-hook`, which is after `myde.el` has been
  read. `:wait t` splits the queue and processes it immediately.
- **`arguments '("-l")`** — drops `-i`, taking the probe from ~575ms to ~88ms.
  Verified to produce an identical PATH on the macOS machine. Also stays under
  `exec-path-from-shell-warn-duration-millis` (500), which the current default
  exceeds.
- **`(or (daemonp) window-system)`** — widened from the current
  `(memq window-system '(mac ns))`. Under presence-as-intent, Linux is exposed
  too: Emacs launched from a `.desktop` entry or a systemd user unit has no
  login-shell ancestry. A TTY Emacs launched from an interactive shell is the
  one case that can skip the probe.
- **Keeping the dependency** rather than hand-rolling a 5-line probe. It
  handles MANPATH, shell quoting, and tcsh/fish variants, and is maintained
  upstream. Now that `-i` is off, the cost is ~88ms once per session.

### Binary gates

Semantics: **presence equals intent.** There is no override list, no deny
list, and no `defcustom`. If a toolchain is on `PATH`, its module is
configured.

The gate must wrap the entire `use-package` form, not use `:if`, because
elpaca queues the order outside the form:

```elisp
;;;; Go  --  gate: go
(when (executable-find "go")
  (use-package go-mode :ensure t :mode "\\.go\\'" ...)
  (use-package gotest-ts :ensure t :after go-mode ...)
  (add-hook 'go-ts-mode-hook #'myde/go-mode-hook))
```

`:if (executable-find "gopls")`-style guards *inside* a module are retained.
Those gate configuration, not installation, and this pattern already exists in
7 of the current `cfg.el` files.

**Unconditional** — no meaningful gating binary, and `:mode`-deferred so the
startup cost is nil: all `core-*`, `prog-elisp`, `prog-bash`, `data-csv`,
`data-dotenv`, `data-json`, `data-toml`, `data-xml`, `data-yaml`,
`text-markdown`, `ebook-epub`, `ai-gptel`, `ai-mcp`, `ai-agents`.

**Gated:**

| Module | Gate binary |
|---|---|
| `prog-go` | `go` |
| `prog-rust` | `cargo` |
| `prog-zig` | `zig` |
| `prog-lua` | `lua` |
| `prog-ruby` | `ruby` |
| `prog-python` | `python3` |
| `prog-javascript`, `prog-typescript` | `node` |
| `prog-elixir` | `elixir` |
| `prog-erlang` | `erl` |
| `prog-clojure` | `clojure` |
| `prog-scheme` | `guile` |
| `prog-clisp` | `sbcl` |
| `prog-cpp` | `clangd` |
| `prog-fish` | `fish` |
| `prog-nushell` | `nu` |
| `data-hcl` | `tofu` or `terraform` |
| `data-pkl` | `pkl` |
| `text-asciidoc` | `asciidoctor` |
| `ebook-pdf` | `pdftoppm` |
| `auth-1password` | `op` |
| `containers-kubernetes` | `kubectl` |
| `ai-claude` | `claude` |

### Effect of the switch on the current machine

Eleven modules that are currently **disabled** will become enabled, because
their binaries are present: `prog-clojure`, `prog-cpp`, `prog-elixir`,
`prog-erlang`, `prog-lua`, `prog-ruby`, `prog-rust`, `prog-scheme`,
`prog-zig`, `text-asciidoc`, `auth-1password`.

`prog-clisp` stays disabled, matching its current state — no `sbcl` is
installed. It is the only currently-disabled module whose state is unchanged.

One module that is currently **enabled** will become disabled: `data-pkl`, as
no `pkl` binary is installed.

This is presence-as-intent behaving as specified, not a defect.

Note also that runtime presence and tooling presence differ: `zig` is present
but `zls` is not; `ruby` is present but neither `ruby-lsp` nor `solargraph` is.
The in-module `:if (executable-find …)` guards handle that distinction.

## Literate workflow

- `myde.org` at the repository root, three top-level subtrees.
- Each subtree sets its target via properties, e.g.
  `:header-args:emacs-lisp: :tangle early-init.el`.
- Auto-tangle via a file-local variable in `myde.org`:
  `eval: (add-hook 'after-save-hook #'org-babel-tangle nil t)`, with that form
  registered in `safe-local-eval-forms` so it does not prompt.
- Tangled outputs are committed.
- `make tangle` tangles manually. `make check` tangles then runs
  `git diff --exit-code` on the three outputs, failing if the committed files
  have drifted from the org source.
- Startup never loads org — it loads the tangled `.el` files directly.

Structure:

```
myde.org
├─ * Early Init          :tangle early-init.el
├─ * Bootstrap           :tangle init.el
│    └─ elpaca installer, elpaca-use-package, (require 'myde)
└─ * Configuration       :tangle user-lisp/myde.el
     ├─ ** Environment    (exec-path-from-shell :wait t)
     ├─ ** Core           (ui, ux, org, help, …)
     ├─ ** Languages      (when (executable-find "go") …)
     └─ ** Formats, Ebooks, AI, Auth, Containers
```

## Package management

`package.el` is replaced by elpaca. Consequences:

- `elpa/` becomes `elpaca/` (with `builds/` and `sources/`), at the repository
  root, gitignored — preserving the current convention of keeping packages in
  the repo for inspection and agent access.
- The 9 `:vc` packages become elpaca recipes: `mcp-server`, `claude-code-ide`,
  `modusregel` (`:host codeberg`), `inf-lua`, `zig-ts-mode`, `ob-zig`,
  `nushell-ts-babel`, `ob-erlang`. `ob-csharp` is dropped — there is no C#
  module.
- `package-selected-packages` and `package-vc-selected-packages` disappear from
  `custom.el`; declarations in `myde.el` are the sole source of truth.
- **`:ensure nil` for built-ins is still required**, and matters more than
  before: without it elpaca will attempt to clone `org`, `transient`, and
  similar.

## Migration

Developed in a scratch directory and run side by side with the working config
via `emacs --init-directory=…`. The repository symlink is switched only after
phase 4 is green. One commit per phase; each phase leaves a working config.

| Phase | Change | Verification |
|---|---|---|
| 1 | Flatten 53 modules into `user-lisp/myde.el`. `package.el` retained. Toggles retained temporarily (see below). | Third-party package features and `emacs-init-time` at parity with current config |
| 2 | Toggles to binary gates. `exec-path-from-shell` inlined with `-l` and widened guard. | Each module's loaded state matches `executable-find`; the 11 newly-live modules load or are fixed |
| 3 | `package.el` to elpaca. 9 `:vc` entries to recipes. | `rm -rf elpaca/`, cold start, all packages build |
| 4 | Wrap in `myde.org`; tangle all three outputs. | `make check` clean — tangle produces no diff |

### Phase 1 detail: temporary toggles

`myde-customize` generates the 24 `defcustom` toggles from `myde-modules`, and
both are deleted in phase 1. To keep phase 1 behaviour-preserving — which is
what makes its parity check meaningful — the 24 `defcustom` forms are written
out literally into `myde.el`, and each module section is wrapped in
`(when myde-module-<name>-enabled …)`. `custom.el` continues to supply their
values unchanged.

This scaffolding is throwaway: phase 2 deletes all 24 `defcustom` forms, strips
the toggle entries from `custom.el`, and replaces each `when` condition with
its `executable-find` gate.

### Phase 1 detail: what "parity" means

The `myde-*` module features (`myde-core-base`, `myde-prog-go-cfg`, and so on)
are eliminated by design, so a raw `features` comparison will differ. Parity is
measured over third-party package features only — the set of packages actually
loaded — plus `emacs-init-time` within noise of the current ~1.16ms.

### File headers

Tangled output must carry the conventions in `AGENTS.md`: a
`-*- lexical-binding: t -*-` file header, the
`;; Copyright (C) 2020-2026  Allen Gooch` line, and a closing
`;;; <file> ends here`. These come from the first and last source block of each
subtree, not from `org-babel`'s `:comments` machinery.

## Risks

1. **~1,700 lines of never-executed code.** The 11 modules that binary
   detection switches on have never been loaded in this config;
   `prog-elixir/cfg.el` alone is 288 lines that have never run. Phase 2
   surfaces this. Budget debugging time for it, separate from migration work.
2. **`org` under elpaca.** Upgrading the built-in `org` is elpaca's known sharp
   edge and needs its documented recipe. Phase 3 risk.
3. **`-l` is unverified on Linux.** If PATH there is assembled in `.zshrc`
   rather than `.zshenv`/`.zprofile`, the `-l` probe will miss entries and
   modules will silently vanish. Verify before phase 2 ships: compare
   `$SHELL -l -c 'printf %s "$PATH"'` against `$SHELL -l -i -c` on that
   machine, and fall back to `("-l" "-i")` there if they differ.
4. **Cold start blocks.** `:wait t` means a fresh clone blocks on git-clone
   plus byte-compile of `exec-path-from-shell` before init continues. Warm
   starts only activate, and are fast.
5. **A 7,000-line buffer.** Navigation becomes `consult-imenu` plus outline
   folding rather than file-hopping. The existing rule against lambdas in
   hooks matters more, not less, since named functions are what `imenu`
   surfaces.
6. **`user-lisp` shadows built-ins.** It sits at `load-path` position 0. Only
   `myde.el` belongs there; a file named `org.el` would shadow built-in org.

## Unchanged conventions

XDG compliance for state, data, and cache. Language keybinding prefixes
(`C-c e` eglot, `C-c t` tests, `C-c i` REPL, `C-c d` dape). The
`2020-2026` copyright range in all source files and `LICENSE`. Platform guards
via `(memq window-system '(mac ns))` and `(string= system-type "darwin")`.
Named hook functions rather than lambdas. `myde/eglot-add-workspace-config`
for non-clobbering LSP workspace config.
