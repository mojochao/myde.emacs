# Python IDE Integration Plan

PyCharm-class Python workflow for myde.el built on native Emacs tooling.

## How mise fits in

`global-mise-mode` is already active in the config. When a file is visited,
`mise.el` runs `mise env` for that file's directory and applies the full
resulting environment — including `PATH`, `VIRTUAL_ENV`, and all other vars —
as buffer-local `process-environment` and `exec-path` via `inheritenv`.

This is the critical insight: **`mise.el` eliminates the need for `pet` or any
other venv-detection package.** As long as a project's `mise.toml` declares its
Python version and venv activation, every Emacs package that calls
`executable-find` or launches a subprocess in a Python buffer (eglot,
ruff-format, python-pytest, dape) will automatically use the correct
executables from the project's venv.

No manual venv activation. No per-package executable path configuration.

### Required per-project `mise.toml` configuration

For this to work each Python project needs a `mise.toml` that:

1. Declares Python version:
   ```toml
   [tools]
   python = "3.12"
   ```

2. Activates the venv. For **uv-managed projects** (have a `uv.lock`):
   ```toml
   [settings]
   python.uv_venv_auto = "source"   # or "create|source" to auto-create
   ```

   For **non-uv projects** (plain venv, poetry, etc.):
   ```toml
   [env]
   _.python.venv = { path = ".venv", create = true }
   ```

Once this is in place, `mise env` exports the activated venv environment.
`mise.el` picks that up and applies it buffer-locally. Done.

### Global tools via mise

`basedpyright` and `ruff` are dev tools, not project dependencies. Install
them globally so they are always available regardless of which project is open:

```sh
mise use -g basedpyright@latest
mise use -g ruff@latest
```

`pytest` and `debugpy` are project dependencies and belong in the project venv.

---

## Tool Stack

| Layer         | Tool                   | Notes                                             |
|---------------|------------------------|---------------------------------------------------|
| Mode          | `python-ts-mode`       | Built-in (Emacs 29+); tree-sitter syntax          |
| Env           | `mise` + `mise.el`     | Already in config; propagates venv env buffer-locally |
| LSP           | `basedpyright`         | Pyright fork; stricter types + pylance features   |
| Format        | `ruff-format`          | Replaces black + isort; ~100x faster              |
| Test runner   | `python-pytest`        | Transient popup; dwim function/file detection     |
| Debugger      | `dape` + `debugpy`     | Already in config for Go; add Python config       |
| REPL          | built-in `python-mode` | `C-c C-p` / `C-c C-z`; no extra package needed   |

### LSP: basedpyright vs alternatives

- **basedpyright** — active fork of Microsoft pyright with stricter type
  checking, pylance inlay hints, semantic tokens. Best eglot option.
- **pylsp** — plugin-heavy, slower, not recommended for eglot.
- **ruff server** (`ruff server`) — ruff now ships a built-in LSP, but it only
  covers linting/formatting diagnostics. No type inference or go-to-definition.
  Complementary to basedpyright rather than a replacement.

---

## Changes

### 1. Add `python` tree-sitter grammar

**File:** `init.el`

Add `python` to `treesit-language-source-alist` alongside the existing `go`,
`hcl`, `elixir`, and `heex` entries in the `treesit` block:

```elisp
(add-to-list 'treesit-language-source-alist
             '(python "https://github.com/tree-sitter/tree-sitter-python"))
```

`treesit-auto` (already active) will handle the `python-mode` →
`python-ts-mode` remap once the grammar is installed.

### 2. Add `python` mode setup with eglot and REPL bindings

**File:** `init.el`

```elisp
(use-package python
  :hook ((python-ts-mode . eglot-ensure)
         (python-ts-mode . myde/python-ts-mode-setup)
         (python-ts-mode . myde/delete-trailing-whitespace-setup)
         (python-ts-mode . flycheck-mode))
  :bind (:map python-ts-mode-map
              ("C-c i i" . run-python)                 ; start REPL
              ("C-c i r" . python-shell-send-region)   ; send region
              ("C-c i b" . python-shell-send-buffer)   ; send buffer
              ("C-c i d" . python-shell-send-defun)    ; send def/class at point
              ("C-c i s" . python-shell-switch-to-shell)) ; switch to REPL
  :mode ("\\.py\\'" . python-ts-mode)
  :ensure nil)
```

REPL bindings follow the `C-c i *` convention established by `elixir-iex`:

| Key       | Command                        | Elixir equivalent          |
|-----------|--------------------------------|----------------------------|
| `C-c i i` | `run-python`                   | `elixir-iex`               |
| `C-c i r` | `python-shell-send-region`     | `elixir-iex-send-region`   |
| `C-c i b` | `python-shell-send-buffer`     | `elixir-iex-send-buffer`   |
| `C-c i d` | `python-shell-send-defun`      | — (Python-specific)        |
| `C-c i s` | `python-shell-switch-to-shell` | `elixir-iex-set-repl`      |

`C-c i l` (send line) and `C-c i p` (project REPL) have no direct built-in
equivalents in `python-mode` and are omitted. `python-shell-interpreter` is set
buffer-locally in `myde/python-ts-mode-setup` so `run-python` always launches
the mise-managed Python for the project.

### 3. Register basedpyright in `eglot` and add workspace configuration

**File:** `init.el`

Add to the existing `eglot` `use-package` `:config` block alongside the
existing Elixir server registration:

```elisp
(add-to-list 'eglot-server-programs
             '((python-mode python-ts-mode) . ("basedpyright-langserver" "--stdio")))
```

`eglot` resolves `basedpyright-langserver` via the buffer-local `exec-path`
that `mise.el` has already set — no `myde/mise-exec-which` lambda needed
(unlike `elixir-ls` which is per-project; basedpyright is a global tool).

Add basedpyright workspace configuration to the existing
`eglot-workspace-configuration` plist. The current default only has `:gopls`.
Merge the Python config in alongside it:

```elisp
(setq-default eglot-workspace-configuration
              '((:gopls . ( ... existing gopls config ... ))
                (:basedpyright .
                 (:typeCheckingMode "standard"
                  :useLibraryCodeForTypes t
                  :diagnosticMode "workspace"
                  :inlayHints (:variableTypes t
                               :functionReturnTypes t
                               :callArgumentNames t
                               :genericTypes t)))))
```

The existing `eglot-mode-map` keybindings (`C-c e *`) reuse as-is for Python.

**basedpyright workspace settings:**

| Setting                         | Value        | Effect                                         |
|---------------------------------|--------------|------------------------------------------------|
| `typeCheckingMode`              | `"standard"` | Strict-ish checks without full strict mode     |
| `useLibraryCodeForTypes`        | `t`          | Infer types from untyped third-party libs      |
| `diagnosticMode`                | `"workspace"`| Check all project files, not just open ones    |
| inlay hint: `variableTypes`     | `t`          | Show inferred types on variable declarations   |
| inlay hint: `functionReturnTypes` | `t`        | Show inferred return types                     |
| inlay hint: `callArgumentNames` | `t`          | Show parameter names at call sites             |
| inlay hint: `genericTypes`      | `t`          | Show resolved generic type parameters          |

Note: `pythonVersion` is intentionally omitted. basedpyright reads it from
`pyproject.toml` / `pyrightconfig.json` in the project, which is the right
source of truth rather than a global Emacs setting.

### 4. Add `ruff-format` for format-on-save

**File:** `init.el`

```elisp
(use-package ruff-format  ;; https://github.com/scop/emacs-ruff-format
  :hook (python-ts-mode . ruff-format-on-save-mode)
  :ensure t)
```

`ruff-format-on-save-mode` hooks `ruff-format-buffer` onto `before-save-hook`
buffer-locally. `ruff-format-command` defaults to `"ruff"`, which `mise.el`
resolves to the global mise-managed `ruff` binary via `exec-path`.

Do not also hook `eglot-format-buffer` for Python (unlike Go where gopls owns
formatting). ruff is faster and its formatting is configured via
`pyproject.toml` alongside the project's other tooling.

### 5. Add `python-pytest` for test running

**File:** `init.el`

```elisp
(use-package python-pytest  ;; https://github.com/wbolster/emacs-python-pytest
  :after python
  :hook (python-ts-mode . python-pytest-mode)
  :bind (:map python-ts-mode-map
              ("C-c t t" . python-pytest-function-dwim)
              ("C-c t f" . python-pytest-file-dwim)
              ("C-c t p" . python-pytest)
              ("C-c t r" . python-pytest-repeat)
              ("C-c t x" . python-pytest-last-failed)
              ("C-c t m" . python-pytest-dispatch))
  :custom
  (python-pytest-unsaved-buffers-behavior 'save-all)
  :ensure t)

`python-pytest-executable` defaults to `"pytest"`. `mise.el` ensures the
project venv's `pytest` is in `exec-path`, so no path configuration is needed.

`python-pytest` uses tree-sitter for function/class detection at point, and
`projectile` for test-file heuristics — both already in config.

Keybindings follow the same granularity convention as Go (`C-c t t/f/p/r`),
with two Python-specific extras:

| Key       | Command                       | Go equivalent          |
|-----------|-------------------------------|------------------------|
| `C-c t t` | `python-pytest-function-dwim` | `gotest-ts-run-dwim`   |
| `C-c t f` | `python-pytest-file-dwim`     | `gotest-ts-run-file`   |
| `C-c t p` | `python-pytest`               | `gotest-ts-run-package`|
| `C-c t r` | `python-pytest-repeat`        | `gotest-ts-repeat`     |
| `C-c t x` | `python-pytest-last-failed`   | —                      |
| `C-c t m` | `python-pytest-dispatch`      | —                      |

### 6. Add Python `dape` configs for `debugpy`

**File:** `init.el`

Add two Python debug configurations to the existing `dape` `use-package`
`:config` block alongside the `go-debug` and `go-test` configs:

```elisp
(add-to-list 'dape-configs
             '(python-debug
               modes (python-mode python-ts-mode)
               command "python"
               command-args ("-m" "debugpy.adapter")
               :type "python"
               :request "launch"
               :program dape-buffer-default
               :justMyCode nil))

(add-to-list 'dape-configs
             '(python-test
               modes (python-mode python-ts-mode)
               command "python"
               command-args ("-m" "debugpy.adapter")
               :type "python"
               :request "launch"
               :module "pytest"
               :args ["-x" "-s"]
               :justMyCode nil))
```

- `python-debug` — launches the current file under debugpy
- `python-test` — launches pytest under debugpy (for stepping through failures)
- `command "python"` resolves via the buffer-local `exec-path` set by
  `mise.el`, so dape automatically uses the project venv's Python.

The existing `C-c d *` dape keybindings reuse as-is for Python.

### 7. Add `myde/python-ts-mode-setup` function

**File:** `myde.el`

```elisp
;; -----------------------------------------------------------------------------
;; Python support
;; -----------------------------------------------------------------------------

(defun myde/python-ts-mode-setup ()
  "Set buffer-local settings for python-ts-mode buffers.
Runs after mise-mode has applied the project environment, so
`executable-find' resolves against the project venv."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 88  ; ruff/black default line length
              python-shell-interpreter (or (executable-find "python3")
                                           (executable-find "python")
                                           "python3")
              compile-command "python -m pytest"))
```

Setting `python-shell-interpreter` here (rather than globally) ensures the
built-in `C-c C-p` REPL and `C-c C-z` switch-to-shell commands launch the
mise-managed Python for the project, not a system Python.

---

## Files Changed

| File      | Summary                                                                              |
|-----------|--------------------------------------------------------------------------------------|
| `myde.el` | Add Python section with `myde/python-ts-mode-setup`                                 |
| `init.el` | Add treesit python grammar; add python, ruff-format, python-pytest blocks; extend eglot and dape |

## What Is NOT Changed

- `mise` / `global-mise-mode` — already active; no changes needed
- `flycheck` global config — already active; picks up ruff diagnostics automatically
- `dap-mode` / `dap-elixir` — kept as-is for Elixir debugging
- Existing Go, Elixir, Terraform stacks — untouched
- Existing eglot keybindings (`C-c e *`) — reused as-is for Python
- Existing dape keybindings (`C-c d *`) — reused as-is for Python

## Prerequisites

### Global tools (install once)

```sh
mise use -g basedpyright@latest   # LSP server
mise use -g ruff@latest           # formatter/linter
```

### Per-project (in project venv)

```sh
uv add --dev pytest debugpy       # or: pip install pytest debugpy
```

### Per-project `mise.toml`

uv project:
```toml
[tools]
python = "3.12"

[settings]
python.uv_venv_auto = "source"
```

Non-uv project:
```toml
[tools]
python = "3.12"

[env]
_.python.venv = { path = ".venv", create = true }
```

### Tree-sitter grammar

```
M-x treesit-install-language-grammar RET python RET
```

Or it will be installed automatically on first use since `treesit-auto-install`
is set to `t` in the config.
