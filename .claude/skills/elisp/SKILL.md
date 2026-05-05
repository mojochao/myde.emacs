---
name: elisp
description: This skill should be used when writing, reviewing, or editing Emacs Lisp (.el) files, use-package declarations, hooks, macros, or any Emacs configuration code.
version: 1.0.0
---

# Emacs Lisp Coding Skill

Apply all rules below without being asked. These rules take precedence over any general coding defaults.

## Lexical binding

Every `.el` file must start with:

```elisp
;;; -*- lexical-binding: t; -*-
```

Never write code that relies on dynamic binding unless explicitly required (e.g., intentional use of `defvar` specials across call stacks).

## Naming

- All public names use `lisp-case` with a package/module prefix: `my-pkg-do-thing`.
- Private (internal) names use `--` as a secondary separator: `my-pkg--internal-helper`.
- Predicate functions: single-word ends with `p` (`evenp`), multi-word ends with `-p` (`buffer-live-p`).
- Unused lexically-scoped parameters are prefixed with `_`: `(lambda (x _ignored) x)`.
- Face names must **not** end in `-face`.

## Function design

- Prefer ≤4 positional parameters. Use a plist, alist, or struct for more.
- Use `#'` (sharp quote) when referencing function names — enables byte-compile warnings.
- **Never use lambdas as hook functions.** Define a named function and reference it by symbol:

  ```elisp
  (defun my-pkg/foo-mode-hook ()
    (setq-local fill-column 100))

  (add-hook 'foo-mode-hook #'my-pkg/foo-mode-hook)
  ```

- Never hard-quote lambdas with `'(lambda ...)` — defeats byte-compilation.
- Avoid wrapping named functions in anonymous lambdas: `#'evenp` not `(lambda (x) (evenp x))`.

## Macros

- Only write macros when functions cannot accomplish the task.
- Design the call-site syntax first (write examples), then implement.
- Always declare `(declare (debug t))` and indent specs when body args deviate from function alignment.
- Use backquote syntax, not manual `list`/`cons` construction.
- Extract complex logic into helper functions; the macro provides only syntactic sugar.

## Control flow

- Use `when` instead of `(if COND (progn ...))`.
- Use `unless` instead of `(when (not ...))`.
- Never wrap `else` branches in `progn` — `if` already wraps them.
- Use `t` as the catch-all in `cond`.
- Use `not` for boolean negation; use `null` only when checking for empty lists.
- Use variadic comparisons: `(< 5 x 10)` not `(and (> x 5) (< x 10))`.
- Use `(1+ x)` / `(1- x)` not `(+ x 1)` / `(- x 1)`.
- Use `with-eval-after-load` not `eval-after-load`.

## Lists and sequences

- Use `dolist` (not `mapcar` + discard) when results are not needed.
- Use `pcase-let` for destructuring — cleaner than manual `car`/`cdr` unpacking.
- Use `cl-loop` for list collection in performance-sensitive code (compiles efficiently).
- Prefer hash tables over alists/plists for datasets with more than ~20 entries.

## Loading and providing

- End every library with `(provide 'feature-name)` followed by `;;; filename.el ends here`.
- Use `require` (idempotent), never `load` or `load-library`, for dependencies.
- Mark public entry points with `;;;###autoload`; never autoload internal names or globals.
- Never place side-effecting forms at the top level in ways that alter user config on autoload.

## use-package conventions

- `:init` — set variables *before* package activation (no side effects requiring the package).
- `:config` — run side effects after the package has loaded.
- Multiple `use-package` blocks for the same package accumulate and are idiomatic.
- Hooks in `:hook` must reference named functions (see Function design above).

## Comments and docstrings

- Docstrings begin with an imperative, terse, complete sentence: `"Return the project root."` not `"Returns..."`.
- Describe arguments in UPPERCASE in the order they appear: `"Search REGEXP in BUFFER."`.
- Always capitalize "Emacs" in docstrings and comments.
- Do not indent continuation lines in docstrings — it produces bizarre output in `describe-function`.
- `;;;` — section headings.
- `;;` — block comments preceding a code fragment, or inline at top level.
- `;` — margin comments on the same line as code.
- At least one space after every `;`.
- Prefer self-documenting code; only add a comment when the *why* is non-obvious.
- Annotation format: `TAG: Description (initials date)` immediately above the relevant code.
  Valid tags: `TODO`, `FIXME`, `OPTIMIZE`, `HACK`, `REVIEW`.

## Formatting

- Spaces only for indentation; `indent-tabs-mode` must be `nil`.
- Align function arguments under the first argument (after the opening paren), not under the function name.
- `let` bindings align vertically.
- One space between text and brackets: `(foo (bar baz))` not `(foo(bar baz))`.
- 80-character line limit where feasible.
- No trailing whitespace.
- One blank line between top-level definitions; no blank lines inside function bodies except to separate paired constructs.
- Trailing parens stay on the last line, not on their own line.

## Quality checklist (before declaring done)

- [ ] `;;; -*- lexical-binding: t; -*-` present on line 1.
- [ ] All top-level names are prefixed with the module/package name.
- [ ] No lambda hook functions — all hooks reference named symbols.
- [ ] Docstrings use imperative voice and UPPERCASE arg names.
- [ ] `(provide ...)` and `;;; filename.el ends here` at the bottom.
- [ ] No trailing whitespace; 80-char line target respected.
- [ ] `use-package` `:init` / `:config` split is correct.
