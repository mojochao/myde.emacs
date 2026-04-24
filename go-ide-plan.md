# Go IDE Integration Plan

Integration of `~/devel/research/emacs-go-ide` into myde.el.

## Source

The research config (`~/devel/research/emacs-go-ide/init.el`) is a standalone
GoLand-class Go workflow built on native Emacs tooling: `eglot`, `go-ts-mode`,
`flymake`, `gotest-ts`, and `dape`. This plan integrates those improvements into
the existing myde.el config without disrupting other language stacks (Elixir,
Terraform, etc.).

## Changes

### 1. Remap denote bindings: `C-c d` → `C-c n`

**File:** `init.el`

Free up `C-c d` for dape debug commands. The mnemonic shifts from "d for denote"
to "n for notes".

| Old       | New       | Command                  |
|-----------|-----------|--------------------------|
| `C-c d n` | `C-c n n` | `denote`                 |
| `C-c d l` | `C-c n l` | `denote-link`            |
| `C-c d b` | `C-c n b` | `denote-backlinks`       |
| `C-c d f` | `C-c n f` | `denote-open-or-create`  |
| `C-c d s` | `C-c n s` | `denote-search`          |

### 2. Add `dape` for Go debugging

**File:** `init.el`

Add `dape` (DAP client) alongside the existing `dap-mode`/`dap-elixir` setup.
`dape` is lighter-weight and integrates better with `eglot`. Two custom configs
are registered for `dlv`:

- `go-debug` — launches `dlv dap` in `debug` mode on `.` (current package)
- `go-test` — launches `dlv dap` in `test` mode on `.` (current package tests)

Keybindings (global, `C-c d` prefix):

| Key       | Command                   |
|-----------|---------------------------|
| `C-c d d` | `dape`                    |
| `C-c d l` | `dape-last`               |
| `C-c d b` | `dape-breakpoint-toggle`  |
| `C-c d n` | `dape-next`               |
| `C-c d s` | `dape-step-in`            |
| `C-c d o` | `dape-step-out`           |
| `C-c d c` | `dape-continue`           |
| `C-c d q` | `dape-quit`               |

**Prerequisite:** `dlv` must be installed (`go install github.com/go-delve/delve/cmd/dlv@latest`).

### 3. Enhance `eglot` configuration

**File:** `init.el`

The current eglot block has no gopls-specific config and no performance tuning.

**Performance settings:**
- `eglot-autoshutdown t` — shut down gopls when the last managed buffer closes
- `eglot-events-buffer-size 0` — disable the events buffer (reduces memory use)

**gopls workspace configuration** (via `eglot-workspace-configuration`):

| Setting                | Value | Effect                                        |
|------------------------|-------|-----------------------------------------------|
| `staticcheck`          | `t`   | Run staticcheck linter via gopls              |
| `gofumpt`              | `t`   | Use gofumpt formatter (stricter than gofmt)   |
| `usePlaceholders`      | `t`   | Insert parameter placeholders in completions  |
| `completeUnimported`   | `t`   | Complete symbols from unimported packages     |
| `semanticTokens`       | `t`   | Semantic syntax highlighting                  |

**Inlay hints** (all enabled):
`assignVariableTypes`, `compositeLiteralFields`, `compositeLiteralTypes`,
`constantValues`, `functionTypeParameters`, `parameterNames`, `rangeVariableTypes`

**`eglot-mode-map` keybindings** (`C-c e` prefix, currently unused):

| Key       | Command                      |
|-----------|------------------------------|
| `C-c e a` | `eglot-code-actions`         |
| `C-c e r` | `eglot-rename`               |
| `C-c e f` | `eglot-format`               |
| `C-c e i` | `eglot-find-implementation`  |
| `C-c e t` | `eglot-find-typeDefinition`  |
| `C-c e h` | `eldoc-box-help-at-point`    |
| `C-c e q` | `eldoc-box-quit-frame`       |

### 4. Add `eldoc-box` and silence auto-eldoc

**File:** `init.el`

Disable automatic eldoc display (which fires on idle and clutters the echo area)
and replace it with on-demand popup docs via `eldoc-box`.

- Set `eldoc-idle-delay` to `most-positive-fixnum` to effectively disable auto display
- Add `eldoc-box` package
- Bindings wired via `eglot-mode-map` (see change #3)

### 5. Overhaul Go setup

**File:** `init.el`

The current `go-mode` block has two bugs and is missing key configuration:

1. **Bug:** `myde/goimports-setup` is only hooked onto `go-mode`, not `go-ts-mode`.
   Since `.go` files open in `go-ts-mode` when tree-sitter is available,
   format-on-save does not fire in practice.

2. **Replaced:** Switch from `goimports`/`gofmt-before-save` to
   `eglot-format-buffer` on save. gopls with `gofumpt: t` handles both formatting
   and import organization via LSP.

3. **Missing:** `go-ts-mode` has no buffer-local settings (tab width, fill column,
   compile command).

Changes:
- Remove `(setq gofmt-command "goimports")`
- Remove `(go-mode . myde/goimports-setup)` hook
- Add `(go-ts-mode . myde/go-ts-mode-setup)` hook
- Add `go-ts-mode-indent-offset 4`
- Add `(add-hook 'before-save-hook #'myde/go-eglot-format-buffer)` in `:config`

### 6. Add two new functions

**File:** `myde.el`

**`myde/go-ts-mode-setup`** — buffer-local settings applied when entering `go-ts-mode`:

```elisp
(defun myde/go-ts-mode-setup ()
  "Set buffer-local settings for go-ts-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode t
              fill-column 100
              compile-command "go test ./..."))
```

**`myde/go-eglot-format-buffer`** — guarded formatter for `before-save-hook`:

```elisp
(defun myde/go-eglot-format-buffer ()
  "Format buffer via eglot when in go-ts-mode and eglot is active."
  (when (and (eq major-mode 'go-ts-mode)
             (bound-and-true-p eglot--managed-mode))
    (eglot-format-buffer)))
```

The guard ensures the hook is a no-op in non-Go and non-eglot buffers even though
it is added to `before-save-hook` globally.

### 7. Add `gotest-ts` for tree-sitter-aware test running

**File:** `init.el`

`gotest-ts` uses the tree-sitter parse tree to detect the test function and
subtest at point, constructing precise `-run '^TestFoo/bar_baz$'` patterns.

Installed via `package-vc` from `https://github.com/chmouel/gotest-ts.el`.

Keybindings in `go-ts-mode-map` (no conflict with exunit's `C-c t *` in
`exunit-mode-map`):

| Key       | Command                  |
|-----------|--------------------------|
| `C-c t t` | `gotest-ts-run-dwim`     |
| `C-c t f` | `gotest-ts-run-file`     |
| `C-c t p` | `gotest-ts-run-package`  |
| `C-c t r` | `gotest-ts-repeat`       |

### 8. Add `read-process-output-max` LSP tuning

**File:** `init.el`

```elisp
(setq read-process-output-max (* 1024 1024))  ; 1 MiB
```

Increases the max bytes Emacs reads from a subprocess per call. The default
(4096 bytes) is a bottleneck for gopls which sends large JSON payloads.

### 9. Add flymake navigation bindings

**File:** `init.el`

eglot reports diagnostics via flymake (not flycheck). Add navigation bindings
on `C-c !` (currently unused in myde.el) to complement the existing flycheck
global setup used by Elixir:

| Key       | Command                          |
|-----------|----------------------------------|
| `C-c ! n` | `flymake-goto-next-error`        |
| `C-c ! p` | `flymake-goto-prev-error`        |
| `C-c ! l` | `flymake-show-buffer-diagnostics`|

## Files Changed

| File      | Summary                                                                         |
|-----------|---------------------------------------------------------------------------------|
| `myde.el` | Add `myde/go-ts-mode-setup`, `myde/go-eglot-format-buffer`                     |
| `init.el` | Remap denote; enhance eglot; overhaul go-mode; add eldoc-box, gotest-ts, dape  |

## What Is NOT Changed

- `flycheck` global config — kept for Elixir, Terraform, and other modes
- `dap-mode` / `dap-elixir` — kept as-is for Elixir debugging
- Vertico / consult / corfu / embark completion stack — already matches research config
- YASnippets for Go — kept as-is
- `myde/go-ts-or-plain-mode` dispatch function — kept as-is

## Prerequisites

Ensure the following tools are installed and on `$PATH`:

| Tool      | Install                                                        | Purpose              |
|-----------|----------------------------------------------------------------|----------------------|
| `gopls`   | `go install golang.org/x/tools/gopls@latest`                   | Go LSP server        |
| `gofumpt` | `go install mvdan.cc/gofumpt@latest`                           | Strict Go formatter  |
| `dlv`     | `go install github.com/go-delve/delve/cmd/dlv@latest`          | Go debugger          |
