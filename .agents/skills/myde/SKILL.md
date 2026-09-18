---
name: myde
description: This skill should be used when editing myde.org, the literate source for the myde.emacs configuration — adding or changing use-package declarations, binary-presence gates, elpaca recipes, or startup hooks.
version: 3.0.0
---

# Myde Project Conventions

Apply these rules whenever changing configuration in the myde.emacs repository. They extend the `elisp` skill — follow both.

## Edit myde.org only

`myde.org` is the single source. `early-init.el`, `init.el`, and `user-lisp/myde.el` are tangled output; `mise run tangle` overwrites them, so never edit them directly.

- `* Early Init` tangles to `early-init.el`. `* Bootstrap` and the activation blocks of
  `* Configuration` tangle to `init.el`. The definition blocks of `* Configuration`
  tangle to `user-lisp/myde.el`.
- Under `* Configuration`, `**` headings are categories (Core base, Environment, Core, AI, Auth, Data formats, Containers, Languages, Text formats, Ebooks) in load order. Each `***` heading holds up to two `#+begin_src emacs-lisp` blocks for one section — definitions and activation — each starting with its `;;;; name` comment header.
- Do not reorder sections. The order is load order and is known-working.

## Adding support for a tool

Add a `***` heading under the matching `**` heading, with a definitions block
(`:tangle user-lisp/myde.el`) for any `defun`/`defvar` and an activation block for
`use-package` forms. If the tool needs a toolchain to be useful, wrap the **whole
activation block body** in a gate:

```org
*** prog-foo

#+begin_src emacs-lisp :tangle user-lisp/myde.el
;;;; prog-foo
;;;; --------

(defun myde-prog-foo-setup ()
  "Set buffer-local settings for Foo buffers."
  (setq-local fill-column 100))
#+end_src

#+begin_src emacs-lisp
;;;; prog-foo
;;;; --------
;; Gate: foo

(when (executable-find "foo")

(use-package foo-mode
  :mode "\\.foo\\'"
  :hook (foo-mode . myde-prog-foo-setup))

  )
#+end_src
```

- Editing modes that need no toolchain stay unconditional.
- No toggle, no registration list, no `custom.el` entry. Presence of the binary is the intent.
- The gate wraps the form. `:if` inside a `use-package` form does **not** stop elpaca from cloning — the order is queued when the form is expanded.
- Runtime and tooling presence differ: inside a gated section, guard an LSP or debugger form with `:if (executable-find "<server>")` when the server is optional.

## Packages: elpaca with use-package-always-ensure

- Third-party forms need no `:ensure`. **Built-in forms must say `:ensure nil`**, or elpaca tries to clone them.
- Git-only packages take a recipe plist: `:ensure (:host github :repo "owner/name")`. Add `:files (:defaults "subdir")` if the package loads files outside the default set.
- **One ensuring form per package.** Further `use-package` forms for the same package say `:ensure nil`. A duplicate order aborts init under elpaca 0.12.
- A secondary `:ensure nil` form that is not deferred by `:hook`/`:bind`/`:mode`/`:commands` must add `:after <package>`; during init the package is not yet on `load-path`.
- Prefer a deferring keyword (`:mode`, `:hook`, `:commands`, `:bind`) over eager loading.

## Startup hooks

Inside `use-package`, use `:hook (elpaca-after-init . fn)` — never `after-init` or `emacs-startup`. The form's body runs after those hooks have fired, so the mode would stay silently off. Top-level `add-hook` calls that must wait for packages also use `elpaca-after-init-hook`.

## Hook functions

**Never use lambdas as hook functions.** Define a named function in the same section and reference it by symbol:

```elisp
(defun myde-foo-mode-setup ()
  (setq-local fill-column 100))

(use-package foo-mode
  :hook (foo-mode . myde-foo-mode-setup))
```

## Naming

Section-scoped symbols are prefixed `myde-<section>-` (e.g. `myde-prog-go-…`). Internal symbols use `myde--`. Interactive commands may use the `/` separator: `myde/do-thing`.

## Keybinding prefixes

Language sections share these prefixes consistently across all `prog-*` sections:

| Prefix  | Purpose            |
|---------|--------------------|
| `C-c e` | eglot / LSP        |
| `C-c t` | tests              |
| `C-c i` | REPL / interactive |
| `C-c d` | dape / debug       |

## LSP workspace config

Use `myde-eglot-add-workspace-config` (defined in the `core-projects` section) to upsert LSP server settings. Never assign `eglot-workspace-configuration` directly — it clobbers other sections' settings.

```elisp
(myde-eglot-add-workspace-config :my-server '(:option value))
```

## Snippets

Custom snippets live flat under `snippets/<language>/` at the repo root — no mode-name subdirectory. Register them at the bottom of the language section:

```elisp
(myde-register-snippets
 (expand-file-name "snippets/go" user-emacs-directory)
 'go-ts-mode)
```

`myde-register-snippets` is defined in the `core-snippets` section and is safe to call before yasnippet loads.

## XDG paths

All state/data/cache redirection is handled in the `core-base` section (and `early-init.el` for the two paths Emacs needs before init). Never redirect XDG paths elsewhere.

## use-package keyword ordering

`:ensure` must always be the **last keyword** in a `use-package` form. All other
keywords (`:after`, `:init`, `:custom`, `:config`, `:hook`, `:mode`, `:bind`, etc.)
come before it:

```elisp
(use-package some-package
  :after other-package
  :custom
  (some-package-option t)
  :config
  (some-package-setup)
  :bind (:map some-package-map
              ("C-c s" . some-command))
  :ensure t)
```

## Verifying a change

1. `mise run tangle`.
2. `scripts/myde-probe.sh "$PWD" /tmp/after.txt`, then diff its `declared:` and `mode:` lines against a report taken before the change. A declared package that vanished or a mode that turned `off` is a regression. `init-file-had-error: t` means init aborted — read `*Messages*` in the probe daemon or start one by hand.
3. Commit. hk's pre-commit hook re-tangles and stages the elisp, so `myde.org` and
   its output cannot be committed out of sync.

## Quality checklist (before declaring done)

- [ ] Change made in `myde.org`, tangled with `mise run tangle`, and `mise run check` passes.
- [ ] Definitions are in the `:tangle user-lisp/myde.el` block, activation in the
  inheriting block. `mise run forms` passes.
- [ ] New block sits under the right `**` heading, in its own `***` heading, gated if it needs a toolchain.
- [ ] Every built-in `use-package` form says `:ensure nil`; each third-party package is ensured by exactly one form.
- [ ] Startup hooks use `elpaca-after-init`, not `after-init`/`emacs-startup`.
- [ ] All hook references are named functions.
- [ ] Keybindings use the shared `C-c e/t/i/d` prefixes where applicable.
- [ ] LSP config uses `myde-eglot-add-workspace-config`, not direct assignment.
- [ ] Probe report shows no lost declared packages, no modes off, no new errors.
