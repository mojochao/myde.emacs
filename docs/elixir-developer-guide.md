# MyDE Elixir Developer Guide

Comprehensive reference for Elixir development in MyDE Emacs. Covers all IDE features, workflows, and keybindings.

## Table of Contents

- [Overview](#overview)
- [Keybindings Reference](#keybindings-reference)
  - [LSP (C-c e)](#lsp-c-c-e)
  - [Testing (C-c t)](#testing-c-c-t)
  - [REPL (C-c i)](#repl-c-c-i)
  - [Debugging (C-c d)](#debugging-c-c-d)
  - [Mix Tasks (C-c d)](#mix-tasks-c-c-d)
  - [Diagnostics (C-c !)](#diagnostics-c-c-)
- [Git Usage with Magit](#git-usage-with-magit)
  - [Magit Status](#magit-status)
  - [Forge (GitHub/GitLab)](#forge-githubgitlab)
  - [Diff-hl (Git Gutter)](#diff-hl-git-gutter)
  - [Blamer (Inline Blame)](#blamer-inline-blame)
  - [AI-Assisted Git](#ai-assisted-git)
- [Dape Configurations](#dape-configurations)
- [Linting](#linting)
- [Snippets](#snippets)
- [Phoenix Development](#phoenix-development)
- [Org Babel](#org-babel)
- [Code Formatting](#code-formatting)
- [Workflows](#workflows)

## Overview

### File Associations

| Extension | Mode | Description |
|-----------|------|-------------|
| `.ex` | `elixir-ts-mode` | Elixir source files |
| `.exs` | `elixir-ts-mode` | Elixir script files |
| `.heex` | `heex-ts-mode` | Phoenix HEEx templates |

### Tree-sitter Support

Grammars auto-installed on first use:
- `elixir` - Elixir syntax
- `heex` - HEEx templates

### LSP Server

- **Server**: `elixir-ls` (resolved via mise per-project)
- **Features**: Completions, diagnostics, code actions, formatting
- **Auto-start**: Enabled for `elixir-ts-mode` and `heex-ts-mode`

### Dependencies

- `prog-erlang` module (required for `elixir-ts-mode`)
- `mise` for tool version management

## Keybindings Reference

### LSP (C-c e)

| Key       | Command                     | Description                |
|-----------|-----------------------------|----------------------------|
| `C-c e a` | `eglot-code-actions`        | Code actions at point      |
| `C-c e r` | `eglot-rename`              | Rename symbol project-wide |
| `C-c e f` | `eglot-format`              | Format buffer              |
| `C-c e i` | `eglot-find-implementation` | Find implementation        |
| `C-c e t` | `eglot-find-typeDefinition` | Find type definition       |

### Testing (C-c t)

| Key       | Command                       | Description                  |
|-----------|-------------------------------|------------------------------|
| `C-c t a` | `exunit-verify-all`           | Run all tests in project     |
| `C-c t s` | `exunit-verify-single`        | Run single test at point     |
| `C-c t t` | `exunit-toggle-file-and-test` | Toggle between file and test |

### REPL (C-c i)

| Key       | Command                    | Description              |
|-----------|----------------------------|--------------------------|
| `C-c i i` | `elixir-iex`               | Start IEx session        |
| `C-c i p` | `elixir-iex-project`       | Start project IEx        |
| `C-c i l` | `elixir-iex-send-line`     | Send current line to IEx |
| `C-c i r` | `elixir-iex-send-region`   | Send region to IEx       |
| `C-c i b` | `elixir-iex-send-buffer`   | Send buffer to IEx       |
| `C-c i m` | `elixir-iex-reload-module` | Reload module in IEx     |
| `C-c i s` | `elixir-iex-set-repl`      | Set IEx REPL buffer      |

### Debugging (C-c d)

| Key       | Command                  | Description                |
|-----------|--------------------------|----------------------------|
| `C-c d d` | `dape`                   | Start debugging session    |
| `C-c d b` | `dape-breakpoint-toggle` | Toggle breakpoint          |
| `C-c d n` | `dape-next`              | Step over                  |
| `C-c d s` | `dape-step-in`           | Step into                  |
| `C-c d o` | `dape-step-out`          | Step out                   |
| `C-c d c` | `dape-continue`          | Continue execution         |
| `C-c d q` | `dape-quit`              | Quit debug session         |
| `C-c d l` | `dape-last`              | Restart last debug session |

### Mix Tasks (C-c d)

| Key       | Command                   | Description            |
|-----------|---------------------------|------------------------|
| `C-c d e` | `mix-execute-task`        | Execute any mix task   |
| `C-c d t` | `mix-test`                | Run all tests          |
| `C-c d o` | `mix-test-current-buffer` | Test current buffer    |
| `C-c d f` | `mix-test-current-test`   | Test current test      |
| `C-c d l` | `mix-last-command`        | Rerun last mix command |

**Umbrella subproject variants**:

| Key         | Command                              | Description                |
|-------------|--------------------------------------|----------------------------|
| `C-c d d e` | `mix-execute-task` (umbrella)        | Execute task in subproject |
| `C-c d d t` | `mix-test` (umbrella)                | Test in subproject         |
| `C-c d d o` | `mix-test-current-buffer` (umbrella) | Test buffer in subproject  |
| `C-c d d f` | `mix-test-current-test` (umbrella)   | Test current in subproject |

**Mix task modifiers**:

| Prefix        | Effect                          |
|---------------|---------------------------------|
| `C-u`         | Choose `MIX_ENV`                |
| `C-u C-u`     | Add extra params                |
| `C-u C-u C-u` | Choose `MIX_ENV` + extra params |

### Diagnostics (C-c !)

| Key       | Command                           | Description          |
|-----------|-----------------------------------|----------------------|
| `C-c ! n` | `flymake-goto-next-error`         | Next error           |
| `C-c ! p` | `flymake-goto-prev-error`         | Previous error       |
| `C-c ! l` | `flymake-show-buffer-diagnostics` | Show all diagnostics |

## Git Usage with Magit

### Magit Status

| Key       | Command        | Description              |
|-----------|----------------|--------------------------|
| `C-c g`   | `magit-status` | Open magit status buffer |
| `C-c g b` | `blamer-mode`  | Toggle inline blame      |

**Magit status buffer commands**:

| Key   | Command               | Description       |
|-------|-----------------------|-------------------|
| `s`   | `magit-stage`         | Stage file/hunk   |
| `u`   | `magit-unstage`       | Unstage file/hunk |
| `c c` | `magit-commit-create` | Create commit     |
| `c a` | `magit-commit-amend`  | Amend commit      |
| `r`   | `magit-rebase`        | Rebase            |
| `R`   | `magit-pull`          | Pull              |
| `P`   | `magit-push`          | Push              |
| `b`   | `magit-branch`        | Branch operations |
| `m`   | `magit-merge`         | Merge             |
| `F`   | `magit-fetch`         | Fetch             |
| `d`   | `magit-diff`          | Diff              |
| `l`   | `magit-log`           | Log               |
| `!`   | `magit-shell-command` | Shell command     |
| `k`   | `magit-discard`       | Discard changes   |
| `e`   | `magit-edit-line`     | Edit line         |

### Forge (GitHub/GitLab)

| Key         | Command                | Description         |
|-------------|------------------------|---------------------|
| `C-c g f`   | `forge-dispatch`       | Forge menu          |
| `C-c g f r` | `forge-create-pullreq` | Create pull request |
| `C-c g f i` | `forge-create-issue`   | Create issue        |
| `C-c g f p` | `forge-pullreq-list`   | List pull requests  |
| `C-c g f i` | `forge-issue-list`     | List issues         |

### Diff-hl (Git Gutter)

- Shows added/modified/deleted lines in gutter
- Integrates with magit refresh hooks
- Visual indicators in fringe

### Blamer (Inline Blame)

| Key       | Command       | Description         |
|-----------|---------------|---------------------|
| `C-c g b` | `blamer-mode` | Toggle inline blame |

**Configuration**:
- Idle time: 0.05s
- Author format: `%s `
- Date format: `[%s]`
- Commit format: `: %s`

### AI-Assisted Git

Requires `ai-gptel` module:

- **gptel-magit**: AI-generated commit messages in magit buffers
- **gptel-forge-prs**: AI-assisted PR review

## Dape Configurations

### Available Configurations

| Name                | Description      | Use Case                        |
|---------------------|------------------|---------------------------------|
| `elixir-debug`      | Default mix task | Run `mix run`                   |
| `elixir-mix-test`   | Test debugging   | Debug tests with `requireFiles` |
| `elixir-phoenix`    | Phoenix server   | Start `phx.server`              |
| `elixir-remote`     | Remote node      | Attach to running node          |
| `elixir-exs-script` | .exs scripts     | Standalone scripts              |

### Debugging Workflow

1. **Start**: `M-x dape` → select configuration
2. **Breakpoints**: `C-c d b` to toggle
3. **Step**: `C-c d n/s/o` for step over/in/out
4. **Continue**: `C-c d c` to resume
5. **Quit**: `C-c d q` to end session

### .exs Script Debugging

**Limitations**:
- Race condition: scripts execute immediately upon compilation
- Must wrap in module functions
- Use `Task.start` with sleep delay to give debugger time

**Example structure**:

```elixir
defmodule MyScript do
  def run do
    a = [1, 2, 3]
    b = Enum.map(a, &(&1 + 1))
    IO.inspect(b, label: "result")
    b
  end
end

Task.start(fn ->
  Process.sleep(4000)  # Give debugger time to interpret
  MyScript.run()
end)
```

**Alternative**: Use `Kernel.dbg/2` with `breakOnDbg: t` setting for automatic breaking on `dbg()` calls.

## Linting

### Credo (flycheck-credo)

- Automatic linting on save
- Strict mode enabled
- Diagnostics in flycheck

### Dialyzer (flycheck-dialyxir)

- Type analysis
- Automatic checking on save

## Snippets

Available snippets for `elixir-ts-mode`:

| Snippet     | Expansion           |
|-------------|---------------------|
| `case`      | Case statement      |
| `def`       | Function definition |
| `defmacro`  | Macro definition    |
| `defmodule` | Module definition   |
| `defp`      | Private function    |
| `receive`   | Receive block       |
| `test`      | Test block          |

## Phoenix Development

### HEEx Templates

- `heex-ts-mode` for `.heex` files
- Tree-sitter support
- Phoenix LiveView integration

### Phoenix Server Debugging

Use `elixir-phoenix` configuration:
- `exitAfterTaskReturns: nil` for long-running server
- Automatic app start with `startApps: t`

## Org Babel

### ob-elixir

Execute Elixir code in Org blocks:

```org
#+begin_src elixir
  Enum.to_list(1..10)
#+end_src
```

## Code Formatting

### Format Buffer

- `C-c e f` via eglot
- EditorConfig support
- indent-bars mode for visual indentation

## Workflows

### Testing Workflow

1. **Run all**: `C-c t a` or `C-c d t`
2. **Run single**: `C-c t s`
3. **Toggle file/test**: `C-c t t`
4. **Debug test**: `M-x dape` → `elixir-mix-test`

### REPL Workflow

1. **Start IEx**: `C-c i i`
2. **Send line**: `C-c i l`
3. **Send region**: `C-c i r`
4. **Reload module**: `C-c i m`

### Git Workflow

1. **Status**: `C-c g`
2. **Stage**: `s` in magit
3. **Commit**: `c c` in magit
4. **Push**: `P` in magit
5. **Blame**: `C-c g b` for inline blame

### Debugging Workflow

1. **Start**: `M-x dape` → select config
2. **Breakpoints**: `C-c d b`
3. **Step**: `C-c d n/s/o`
4. **Inspect**: Use dape info buffer
5. **Quit**: `C-c d q`

---

*Generated from MyDE Emacs configuration. See `modules/prog-elixir/` and `modules/core-projects/` for source.*
