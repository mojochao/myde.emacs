# Library / Config Split — Design

**Date:** 2026-09-17
**Status:** Draft. Design decisions 1-3 settled with the user; pending review.

## Problem

`user-lisp/myde.el` is 4,930 lines holding two unrelated kinds of code: the
`myde-*` definitions that form the config's own library, and the `use-package`
forms, gates, and variable assignments that activate packages. They are
interleaved section by section, so there is no way to read the library without
reading the whole configuration, and no boundary that says which code has
side effects.

`init.el` is meanwhile a 100-line elpaca bootstrap whose only other job is
`(require 'myde)`.

## Goals

- `user-lisp/myde.el` contains **definitions only** and has no side effects.
- `init.el` contains the elpaca bootstrap and **all** activation: every
  `use-package` form, every binary gate, every variable assignment and hook.
- Binary gates live in `init.el` only. `myde.el` defines its functions
  unconditionally.
- No change to load order, keybindings, XDG layout, gate conditions, or the
  set of declared packages.

## Non-goals

- Reducing the amount of configuration.
- Adding a fourth tangle target. Three files stay three files (decision 3).
- Byte-compiling `myde.el`. See *Compilation* — this was assumed during the
  decision and the evidence does not support it.

## Decisions taken

| # | Decision | Rationale |
|---|---|---|
| 1 | `myde.el` defines unconditionally; only `init.el` gates activation | A library defines, a config activates. 16 of 20 gates currently straddle both, so the alternative is duplicating every gate condition. Unused `defun`s cost nothing when a toolchain is absent. |
| 2 | `myde.el` has no side effects, so `setq`/`add-hook`/mode calls move out | Follows from 1. Includes the XDG path assignments. |
| 3 | Three files, not four: activation goes into `init.el` | Keeps the file count and the "three-file" naming in the existing docs. Accepted cost: `init.el` becomes ~4,000 lines. |

## Verified facts

Measured on this machine (macOS, Emacs 31.1) against the tree at `16da103`.

| Fact | Evidence |
|---|---|
| A per-block `:tangle` header overrides the subtree's `header-args` property, and each target collects its blocks in document order | Tangle test: two `***` sections, each with one default block and one `:tangle cfg.el` block, produced correct `lib.el` and `cfg.el` with order preserved |
| `myde.el` top-level forms: 135 `use-package`, 57 `defun`, 22 `when`, 20 `setq`, 11 `defvar`, 4 `add-hook`, 7 bare global mode calls, 2 `global-set-key`, and one each of `add-to-list`, `require`, `let`, `let*`, `dolist`, `setq-default`, `unless`, `defcustom`, `defconst`, `define-derived-mode`, `define-minor-mode`, `eval-when-compile`, `provide` | Paren-balance parse of top-level forms |
| 20 of the 22 `when` forms are `executable-find` binary gates; **16 of those 20 contain both `use-package` forms and `def*` forms** | same parse |
| All 11 `defvar` initforms and the 1 `defcustom` initform are literals, or `expand-file-name`/`file-name-as-directory` over other `myde-*` vars and `user-emacs-directory`. **None reads a package variable.** | Inspection of every initform |
| `myde-denote-directory` reads `myde-org-notes-directory`, defined earlier in the same file | `myde.el:921` vs `:541` |
| `myde.el`, `init.el`, and `early-init.el` all carry `no-byte-compile: t`; `byte-compile-file` on `myde.el` returns `no-byte-compile` and emits no `.elc` | Compile attempt |
| The tree already uses `eval-when-compile` + `declare-function` stubs for package symbols | `myde.el:1080` (nerd-icons) |

The defvar finding matters twice: it means `(require 'myde)` may be placed
anywhere in `init.el`, including before the elpaca bootstrap, and it means no
`defvar` will break by having its `setq` neighbours move to another file.

## Architecture

### The rule

A form stays in `myde.el` if and only if it is a **definition**:

| Stays in `myde.el` | Moves to `init.el` |
|---|---|
| `defun`, `defmacro` | `use-package` |
| `defvar`, `defcustom`, `defconst` | `setq`, `setq-default`, `add-to-list` |
| `define-derived-mode`, `define-minor-mode` | `add-hook`, `global-set-key` |
| `eval-when-compile` stub blocks | bare global mode calls, `when`/`unless` gates |
| `provide` | `let`, `let*`, `dolist`, `require` |

The rule is mechanically checkable: a script can assert that every top-level
form in `myde.el` has a car in the left column.

### Org structure

Section granularity does not change. Each `***` heading keeps holding one
section, and gains a second source block:

```org
*** prog-go

#+begin_src emacs-lisp :tangle user-lisp/myde.el
(defun myde-prog-go-setup () ...)
#+end_src

#+begin_src emacs-lisp
(when (executable-find "go")
  (use-package go-ts-mode
    :hook (go-ts-mode . myde-prog-go-setup)
    :ensure nil))
#+end_src
```

The `* Configuration` subtree property becomes `:tangle init.el`, because
activation is the larger and more numerous side. Definition blocks carry the
explicit `:tangle user-lisp/myde.el` override. Sections with no definitions
keep exactly one block and need no override.

This keeps everything about `prog-go` in one place in `myde.org` while the
tangler routes the two kinds of code to different files — the property the
literate format exists to provide.

### File roles after the split

| File | Contents | Approx. size |
|---|---|---|
| `early-init.el` | unchanged | 175 lines |
| `init.el` | elpaca bootstrap, `(require 'myde)`, then all activation in load order | ~4,000 lines |
| `user-lisp/myde.el` | definitions only, `(provide 'myde)` | ~900 lines |

`(require 'myde)` moves from the end of the bootstrap to immediately before
the first activation block. It may be placed earlier; nothing in `myde.el`
depends on elpaca.

### Load order

Unchanged and load-bearing. Both tangle targets collect blocks in document
order, so the existing section sequence (`core-base`, Environment, remaining
`core-*`, `ai-*`, `auth-*`, `data-*`, `containers-*`, `prog-*`, `text-*`,
`ebook-*`) is preserved within each file. Two constraints survive as-is
because they live entirely on the activation side:

- `exec-path-from-shell` stays `:ensure (:wait t)` in the Environment section,
  ahead of the first binary gate.
- The XDG assignments stay in the `core-base` activation block, ahead of every
  package that reads them.

## Compilation

The decision was taken against a description that called the split-out
`myde.el` "compilable". That word should not have been there, and the evidence
argues against acting on it:

- `myde.el` carries `no-byte-compile: t` today, as init files conventionally do.
- Dropping it buys compiled bodies for 57 mostly-small hook functions — an
  unmeasurable gain.
- It costs a real staleness hazard: a `myde.elc` older than its `myde.el`
  loads silently stale definitions, so `make tangle` would have to recompile
  or delete the `.elc` on every run.

**Recommendation: keep `no-byte-compile: t`.** The separation of definitions
from side effects stands on its own; compilation is a separate proposal and
should be judged with a measurement rather than bundled in here.

## Risks

| Risk | Mitigation |
|---|---|
| A `defun` moved to `myde.el` silently depends on a `setq` that ran before it in the old single file | Function bodies are not evaluated at load; only initforms could break, and all 12 were inspected and are literal or `myde-*`-only |
| A gate that wrapped definitions now leaves them defined unconditionally, shadowing something | The 57 `defun`s are all `myde-`-prefixed; collision surface is the repo's own namespace |
| Mechanical split drops or duplicates a form across 4,930 lines | Count assertion: `use-package` forms before and after must both be 135, `defun` 57; plus the probe's `declared:` line, which lists every declared package |
| Section order scrambled by the two-target tangle | Verify the tangled `init.el` section sequence against the current `myde.el` sequence with a `;;;; ` header diff |

## Verification

Identical to the migration's method, since the harness already exists:

1. `scripts/myde-probe.sh "$PWD" <before>` on `16da103`.
2. Split, `make tangle`, `make check`.
3. `scripts/myde-probe.sh "$PWD" <after>`; diff `declared:` and `mode:` lines.
   A lost package or an `off` mode is a regression.
4. Assert form counts per file against the inventory in *Verified facts*.
5. Diff the `;;;; ` section-header sequence in the new `init.el` against the
   old `myde.el`.
6. `launchctl kickstart -k gui/$(id -u)/gnu.emacs.daemon` and confirm a client
   frame still renders `*dashboard*` in `dashboard-mode`.

## Follow-up work

- Byte/native compilation of `myde.el`, with a measurement, if wanted.
- The mechanical `myde.el` form-kind assertion could become a `make` target
  alongside `check`.
