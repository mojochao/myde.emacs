# Three-File Literate Config — Design

**Date:** 2026-09-15
**Status:** Approved. Revised 2026-09-15 after adversarial review; pending implementation.

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
- Linux and macOS both supported.

## Non-goals

- Reducing the amount of configuration.
- Changing keybindings, XDG layout, or platform-guard conventions.
- Auditing or rewriting individual module contents beyond what is needed to
  make them load under elpaca. Deferring more packages is a follow-up, not
  part of the migration (see "Follow-up work").

## Verified facts

These were measured or confirmed on the development machine (macOS, Emacs
31.1, `Development version a360712c9d27`, build 2026-09-08) and constrain the
design.

| Fact | Evidence |
|---|---|
| `user-lisp-directory` is `~/.config/emacs/user-lisp/` and `(require 'myde)` from it works | Probe daemon on Emacs 31.1: `REQUIRE-WORKS=probe` |
| `user-lisp` is added at **position 0** of `load-path` — it shadows built-ins | Probe daemon: entry `"/tmp/mydetest/user-lisp"`, position 0 of 27 |
| elpaca queues the order **outside** the `use-package` form, so `:if`/`:when` does **not** prevent cloning | Manual: `(use-package example :ensure t)` → `(elpaca example (use-package example))` |
| Under elpaca the `use-package` body runs after the order is activated, which is during or after `after-init-hook`. A `:hook (after-init . fn)` added there never fires | elpaca README; the current tree has 14 such `:hook` forms plus one `(emacs-startup . fn)` and dashboard's startup hook |
| `elpaca-wait` exists, is autoloaded: "Block until currently queued orders are processed." | `elpaca.el` source |
| `elpaca-after-init-hook` is a `defcustom`, "Elpaca's analogue to `after-init-hook`"; `elpaca-after-init-time` is set when it fires | `elpaca.el` lines 69-70 |
| The `elpaca-use-package` menu recipe already sets `:wait t` | `elpaca-menu-extensions` in `elpaca.el` |
| `elpaca-use-package` has **no** ensure-by-default variable of its own; the standard `use-package-always-ensure` supplies `:ensure t` to forms that omit it | `extensions/elpaca-use-package.el` source: only the minor mode is defined |
| `elpaca-ignored-dependencies` defaults to every built-in package except `compat`, so a `:ensure nil` built-in is never pulled in as a dependency | `elpaca.el`: `(delq 'compat (mapcar #'car package--builtin-versions))` |
| elpaca requires `(setq package-enable-at-startup nil)` in early-init | elpaca README; already present at `early-init.el:61` |
| `use-package-compute-statistics` records every evaluated `use-package` form, deferred or not, in `use-package-statistics`; the gather call is emitted outside the `:ensure` handler so it runs at load under elpaca too | `use-package-core.el`; verified with `macroexpand-1` |
| A third-party `use-package` placed before `package-initialize` fails with `Cannot load <pkg>` even when the package is installed | Batch test against `elpa/` with `package-archives` nil |
| `server-name` is still `"server"` when `init.el` runs under `--daemon=NAME`; startup.el renames it afterwards | Probe daemon: `server-name="server" daemonp="probe"` |
| `exec-path-from-shell-arguments` defaults to `("-l" "-i")` for zsh | `elpa/exec-path-from-shell-2.2/exec-path-from-shell.el:121` |
| `-l -i` probe costs **~575ms**; `-l` alone costs **~88ms** | 3-run timing: 1.726s vs 0.264s |
| `-l` yields an **identical 41-entry PATH** to `-l -i` on this machine | `comm` diff of both PATHs: empty |
| Binaries are spread across 7 directories including mise shims and a version-numbered gem path | `~/.local/share/mise/shims`, `/opt/homebrew/bin`, `~/.cargo/bin`, `~/.gem/ruby/4.0.0/bin`, `~/.local/bin`, `/opt/homebrew/opt/ruby/bin`, `/usr/bin` |
| `--batch` implies `--no-init-file`; `-Q` likewise | Empirical: init.el did not run under either |
| `org` is already `:ensure nil` and no built-in has been upgraded into `elpa/` | `awk` over `core-org/cfg.el`; `ls elpa` |

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
custom.el             <- faces + safe themes + a few settings (~19 lines, was 75)
elpaca/               <- gitignored, replaces elpa/
scripts/              <- migration probe harness (kept; see "Probe")
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

Substance unchanged from the current 179 lines.

- `(setq package-enable-at-startup nil)` is already present at line 61 and is
  what elpaca requires. Nothing to add.
- Garbage-collection and `file-name-handler-alist` restoration **stay on
  `emacs-startup-hook`**. That hook runs even when the elpaca bootstrap fails
  (no network on a cold clone, no `git`). Moving them to
  `elpaca-after-init-hook` would leave such a session with GC disabled and
  `file-name-handler-alist` nil, breaking TRAMP and compressed files. The
  cost of restoring GC before elpaca finishes activating is negligible.
- Gains one line: `(setq use-package-compute-statistics t)`. The migration
  probe reads `use-package-statistics` to compare declared package sets, and
  it powers `M-x use-package-report` afterwards.

Retained: GC suppression, `file-name-handler-alist` clearing, native-compile
cache redirection to `$XDG_CACHE_HOME/emacs/eln-cache`, `default-frame-alist`
setup, `auto-save-list-file-prefix`, `custom-file`, startup-screen suppression,
process buffer sizing for LSP throughput.

Note: `early-init.el` cannot evaluate binary gates, because gates depend on
`exec-path-from-shell`, which is a package, and elpaca bootstraps in `init.el`.
All detection therefore lives in `myde.el`.

### init.el

Roughly 90 lines, most of it the installer:

1. The elpaca installer block, verbatim, `elpaca-installer-version 0.12`.
2. `(setq use-package-always-ensure t)` — every `use-package` form is
   `:ensure t` unless it says `:ensure nil`.
3. `(elpaca elpaca-use-package (elpaca-use-package-mode))` — the menu recipe
   for `elpaca-use-package` already carries `:wait t`, so no explicit
   `(elpaca-wait)` is needed here.
4. `(require 'myde)` — resolved from `user-lisp/`.
5. Server start, skipped when `(daemonp)`: startup.el starts a daemon's own
   server after init, and `server-name` is still `"server"` while `init.el`
   runs, so an unguarded `server-start` would grab the user's default socket.

`custom.el` continues to load from the core-base section of `myde.el` during
init, as it does today. Nothing left in it depends on a package.

### user-lisp/myde.el

Approximately 7,000 lines, in this order:

1. **Core base.** XDG paths, `custom.el` load, and — until phase 2 —
   `package-initialize`.
2. **Environment.** `exec-path-from-shell`. Every gate below depends on it.
3. **Remaining core.** The other 11 `core-*` sections, unconditional.
4. **AI, Auth, Data, Containers, Languages, Text, Ebooks.** In `myde-modules`
   order. Gated where a binary exists; otherwise unconditional.
5. `(provide 'myde)`

## Environment detection

### exec-path-from-shell

Sits immediately after the core-base section and before the first gated
declaration:

```elisp
(use-package exec-path-from-shell
  :ensure (:wait t)
  :demand t
  :init (setq exec-path-from-shell-arguments '("-l"))
  :config (when (or (daemonp) window-system)
            (exec-path-from-shell-initialize)))
```

Why second rather than first: in phase 1 `package.el` is still active, and a
third-party `use-package` placed before core-base's `package-initialize` fails
with `Cannot load exec-path-from-shell` (verified). Under elpaca the position
is harmless. Keeping it fixed avoids moving it twice. The invariant that
matters is *before the first gate*, not *first in the file*.

Four deliberate choices:

- **`:ensure (:wait t)`** — under elpaca the package is not on `load-path`
  until queues process on `after-init-hook`, which is after `myde.el` has been
  read. `:wait t` splits the queue and processes it immediately. Anything
  queued before it (core-base's `buffer-guardian`) is built in the same wait.
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
;;;; prog-go
;;;; -------
;; Gate: go
(when (executable-find "go")
  (use-package go-mode :ensure t :mode "\\.go\\'" ...)
  (use-package gotest-ts :ensure t :after go-mode ...)
  (add-hook 'go-ts-mode-hook #'myde/go-mode-hook))
```

`:if (executable-find "gopls")`-style guards *inside* a module are retained.
Those gate configuration, not installation, and this pattern already exists in
7 of the current `cfg.el` files.

**Unconditional** — editing modes that need no toolchain, all `:mode`-deferred
so the startup cost is nil and the elpaca cost is one clone on a cold start:
all `core-*`, `prog-base`, `text-base`, `ai-base`, `prog-elisp`, `prog-bash`,
`data-csv`, `data-dotenv`, `data-hcl`, `data-json`, `data-pkl`, `data-toml`,
`data-xml`, `data-yaml`, `text-asciidoc`, `text-markdown`, `ebook-epub`,
`ai-gptel`, `ai-mcp`, `ai-agents`.

You edit `.tf`, `.pkl`, and `.adoc` files without `terraform`, `pkl`, or
`asciidoctor` installed, so gating those on a binary would remove editing
support for no gain. An earlier draft gated them and, as a consequence, would
have disabled `data-pkl` on the development machine.

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
| `ebook-pdf` | `pdftoppm` |
| `auth-1password` | `op` |
| `containers-kubernetes` | `kubectl` |
| `ai-claude` | `claude` |

### Effect of the switch on the current machine

Eleven modules that are currently **disabled** become enabled. Nine by gate,
because their binaries are present: `prog-clojure`, `prog-cpp`, `prog-elixir`,
`prog-erlang`, `prog-lua`, `prog-ruby`, `prog-rust`, `prog-scheme`,
`prog-zig`. One by gate on `op`: `auth-1password`. One unconditionally:
`text-asciidoc`.

`prog-clisp` stays disabled, matching its current state — no `sbcl` is
installed.

No currently-enabled module becomes disabled.

Note also that runtime presence and tooling presence differ: `zig` is present
but `zls` is not; `ruby` is present but neither `ruby-lsp` nor `solargraph` is.
The in-module `:if (executable-find …)` guards handle that distinction.

## Literate workflow

- `myde.org` at the repository root, three top-level subtrees.
- Each subtree sets its target via properties, e.g.
  `:header-args:emacs-lisp: :tangle early-init.el`.
- Tangled outputs are committed.
- `make tangle` tangles manually. `make check` tangles then runs
  `git diff --exit-code` on the three outputs, failing if the committed files
  have drifted from the org source.
- **No auto-tangle on save.** `make check` catches drift, and re-tangling a
  7,000-line file on every save is latency for no gain.
- Startup never loads org — it loads the tangled `.el` files directly.

Structure:

```
myde.org
├─ * Early Init          :tangle early-init.el
├─ * Bootstrap           :tangle init.el
│    └─ elpaca installer, use-package-always-ensure, elpaca-use-package, (require 'myde)
└─ * Configuration       :tangle user-lisp/myde.el
     ├─ ** Core base     (XDG, custom.el)
     ├─ ** Environment   (exec-path-from-shell :wait t)
     ├─ ** Core          (ui, ux, org, help, …)
     ├─ ** AI, Auth, Data formats, Containers
     ├─ ** Languages     (when (executable-find "go") …)
     └─ ** Text formats, Ebooks
```

The `**` order mirrors the existing `myde-modules` load order, which is
known-working. Reordering for aesthetics risks a load-order dependency for no
functional gain; org folding makes physical order largely irrelevant.

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
- **`use-package-always-ensure t`** makes `:ensure t` the default. The 26
  third-party forms that omit `:ensure` today (25 `indent-bars`, 1 `geiser`)
  need no edit. The 6 built-in forms that omit it (3 `treesit`, 3 `project`)
  **must gain `:ensure nil`** or elpaca will try to clone them. Every built-in
  form carrying `:ensure nil` is safe from dependency resolution too, because
  `elpaca-ignored-dependencies` defaults to every built-in.
- **Startup hooks must move to `elpaca-after-init-hook`.** Fourteen forms use
  `:hook (after-init . <global-mode>)` (vertico, marginalia, corfu, which-key,
  yasnippet, flycheck, diff-hl, mise, editorconfig, treesit-auto,
  spacious-padding, whole-line-or-region, buffer-guardian, dashboard) and one
  uses `(emacs-startup . …)` (ai-mcp). Under elpaca the `use-package` body
  runs after those hooks have already fired, so every one of those modes would
  silently stay off. The mechanical fix is `(elpaca-after-init . fn)`.
  Dashboard follows its README's elpaca recipe instead. The probe checks 13 of
  these modes by name; dashboard is verified in the GUI at go-live.

## Migration

Developed in a git worktree and run side by side with the working config via
`emacs --init-directory=…`. The repository symlink is switched only after
phase 3 is green. One commit per task; each phase leaves a working config.

| Phase | Change | Verification |
|---|---|---|
| 1 | Flatten 53 modules into `user-lisp/myde.el`. Inline `exec-path-from-shell` with `-l` and the widened guard. Replace toggles with gates in the same wrapping pass. `package.el` retained. | Declared `use-package` set equals baseline plus exactly the packages declared by the 11 newly-live modules; startup modes match baseline; the 11 newly-live modules load or are fixed |
| 2 | `package.el` to elpaca. `:ensure nil` on the 6 built-ins, startup hooks to `elpaca-after-init`, 8 `:vc` entries to recipes. | `rm -rf elpaca/`, cold start: declared set and startup modes identical to end of phase 1; every clone has a build |
| 3 | Wrap in `myde.org`; tangle all three outputs. | `make check` clean; tangled output differs from the phase-2 files only in blank lines |

Deferral tuning follows go-live as separate work (see "Follow-up work").

### Why there is no toggle-preserving phase

An earlier draft kept the 24 toggles alive through phase 1 so the flatten
could be verified at exact parity before gating changed anything. That needed
36 literal `defcustom` forms, a macro, a hand-wrapping pass over 39 sections,
and a second hand-wrapping pass to swap toggles for gates. The declared-package
probe makes it unnecessary: the effect of gating is fully predictable from the
gate table and the module tree, so "flattened correctly" and "gated correctly"
are checked by one comparison — nothing lost, and the additions equal the
packages declared by the 11 newly-live modules.

### What parity means

The `myde-*` module features (`myde-core-base`, `myde-prog-go-cfg`, and so on)
are eliminated by design, so a raw `features` comparison will differ.

The parity metric is the **declared package set**: the keys of
`use-package-statistics`, one per `use-package` form that was evaluated. It is
gate-sensitive and includes deferred packages. `load-history` is *not* the
metric — most language and data modules are `:mode`- or `:hook`-deferred and
never appear in it, so a comparison on loaded packages is blind to exactly
what gating changes. The probe still records loaded packages for the
follow-up deferral audit.

Startup-enabled global modes are checked by name, because that is the failure
mode elpaca introduces.

Init time is reported twice: `after-init-time` minus `before-init-time`, which
under elpaca excludes package activation, and `elpaca-after-init-time` minus
`before-init-time`, which includes it. Only the second is comparable across
phases 2 and 3. Do not trust the `~1.16ms` figure in `AGENTS.md`; the probe
measures the real baseline.

### Probe isolation

The probe boots each config as a throwaway daemon on a unique socket. Three
further isolations are required for the results to mean anything:

- **`PATH=/usr/bin:/bin`.** A daemon launched from an interactive terminal
  inherits the full PATH, so gates resolve whether or not
  `exec-path-from-shell` ran. With a minimal PATH, gates only pass if it did.
  `git` and `zsh` live in `/usr/bin`/`/bin` on both platforms.
- **Private `XDG_STATE_HOME`.** Killing the daemon runs `kill-emacs-hook`,
  which would otherwise overwrite the live session's recentf, savehist, and
  bookmarks with a near-empty probe session's. `XDG_DATA_HOME` and
  `XDG_CACHE_HOME` are left alone so tree-sitter grammars and the eln cache
  are shared.
- **`init-file-had-error`** is reported directly. It is the definitive signal
  that `init.el` failed; the `*Messages*` regexp is a heuristic on top.

### File headers

Tangled output must carry the conventions in `AGENTS.md`: a
`-*- lexical-binding: t -*-` file header, the
`;; Copyright (C) 2020-2026  Allen Gooch` line, and a closing
`;;; <file> ends here`. These come from the first and last source block of each
subtree, not from `org-babel`'s `:comments` machinery.

## Risks

1. **~1,700 lines of never-executed code.** The 11 modules that binary
   detection switches on have never been loaded in this config;
   `prog-elixir/cfg.el` alone is 288 lines that have never run. Phase 1
   surfaces this. Budget debugging time for it, separate from migration work.
2. **Startup hooks under elpaca.** Fifteen forms must move to
   `elpaca-after-init`. Missing one means a global mode silently off. The
   probe's mode list is the safety net; dashboard is outside it.
3. **`-l` is unverified on Linux.** If PATH there is assembled in `.zshrc`
   rather than `.zshenv`/`.zprofile`, the `-l` probe will miss entries and
   modules will silently vanish. Verify before go-live there: compare
   `$SHELL -l -c 'printf %s "$PATH"'` against `$SHELL -l -i -c` on that
   machine, and fall back to `("-l" "-i")` there if they differ.
4. **Emacs 31.1 floor on every machine.** `user-lisp-directory` does not exist
   in Emacs 30, so `(require 'myde)` fails on the first line of `init.el`
   there. Check `emacs --version` on the Linux machine before go-live. The
   fallback, if needed, is one appended `add-to-list 'load-path` line in
   `init.el`, which would also remove risk 6.
5. **Cold start blocks.** `:wait t` means a fresh clone blocks on git-clone
   plus byte-compile of `exec-path-from-shell` (and anything queued before it)
   before init continues. Warm starts only activate, and are fast. At go-live,
   move the worktree's `elpaca/` into the main tree to skip the rebuild.
6. **A 7,000-line buffer.** Navigation becomes `consult-imenu` plus outline
   folding rather than file-hopping. The existing rule against lambdas in
   hooks matters more, not less, since named functions are what `imenu`
   surfaces.
7. **`user-lisp` shadows built-ins.** It sits at `load-path` position 0. Only
   `myde.el` belongs there; a file named `org.el` would shadow built-in org.

Not a risk after all: upgrading built-in `org` under elpaca. The `org` form is
already `:ensure nil`, and `elpaca-ignored-dependencies` keeps it from being
cloned as a dependency.

## Follow-up work

Outside the migration, each with its own before/after comparison:

- **Deferral audit.** `M-x use-package-report` (enabled by
  `use-package-compute-statistics`) lists every form that loaded at startup.
  Add `:mode`, `:hook`, or `:commands` where a package is tied to a file type
  or a command. This changes the loaded set, which is why it is not folded
  into a parity-checked migration.
- **Collapse the 25 duplicate `indent-bars` forms** into one with a combined
  hook list.
- **`myde/clear-echo-area`** runs on `emacs-startup-hook`, before elpaca has
  finished. If package activation messages linger in the echo area, move it to
  `elpaca-after-init-hook`.

## Unchanged conventions

XDG compliance for state, data, and cache. Language keybinding prefixes
(`C-c e` eglot, `C-c t` tests, `C-c i` REPL, `C-c d` dape). The
`2020-2026` copyright range in all source files and `LICENSE`. Platform guards
via `(memq window-system '(mac ns))` and `(string= system-type "darwin")`.
Named hook functions rather than lambdas. `myde/eglot-add-workspace-config`
for non-clobbering LSP workspace config.
