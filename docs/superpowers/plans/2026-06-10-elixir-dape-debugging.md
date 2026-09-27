# Plan: Add Elixir Debugging with Dape-Mode

## Context

The user wants to replace `dap-mode` with `dape-mode` for Elixir interactive debugging in their Emacs configuration. Dape is a lightweight DAP client already installed in the config (core-projects/cfg.el) with shared `C-c d` keybindings. The current `prog-elixir` module uses `dap-mode` with `dap-elixir`, which needs to be replaced with a dape configuration using the ElixirLS debug adapter.

## Current State

1. **Dape already installed**: `core-projects/cfg.el` has dape configured with shared keybindings:
   - `C-c d d` → dape (start debugging)
   - `C-c d l` → dape-last
   - `C-c d b` → dape-breakpoint-toggle
   - `C-c d n` → dape-next
   - `C-c d s` → dape-step-in
   - `C-c d o` → dape-step-out
   - `C-c d c` → dape-continue
   - `C-c d q` → dape-quit

2. **Current Elixir debugging**: `prog-elixir/cfg.el` (lines 65-72) uses dap-mode:
   ```elisp
   (use-package dap-mode
     :after transient
     :config
     (require 'dap-elixir)
     :ensure nil)
   ```

3. **ElixirLS debug adapter**: Provides DAP support with `mix_task` debug adapter type, supporting:
   - Mix tasks (test, phx.server, run, etc.)
   - Breakpoints, variable inspection, stack traces
   - Automatic module interpretation for debugging
   - Remote debugging capabilities

## Implementation Plan

### Step 1: Update `prog-elixir/cfg.el`

**File**: `/home/agooch/devel/repos/github.com/mojochao/myde.emacs/modules/prog-elixir/cfg.el`

**Action**: Replace the dap-mode configuration (lines 65-72) with dape configuration.

**New configuration**:
```elisp
;; -----------------------------------------------------------------------------
;; Debugging via dape + elixir-ls
;;
;; ElixirLS includes a DAP debug adapter that supports Mix tasks, breakpoints,
;; variable inspection, and stack traces. The debug adapter automatically
;; interprets all modules in the Mix project and dependencies.
;;
;; For debugging tests, use the 'mix-test' configuration which includes
;; required test files.
;; -----------------------------------------------------------------------------

(use-package dape
  :after transient
  :config
  ;; Default mix task configuration
  (add-to-list 'dape-configs
               '(elixir-debug
                 modes (elixir-ts-mode heex-ts-mode)
                 ensure (lambda (config)
                          (if (executable-find "elixir-ls")
                              t
                            (message "elixir-ls not found on PATH")
                            nil))
                 command "elixir-ls"
                 :type "mix_task"
                 :request "launch"
                 :task "run"
                 :projectDir dape-buffer-default
                 :startApps t
                 :debugAutoInterpretAllModules t
                 :exitAfterTaskReturns t
                 :breakOnDbg t))

  ;; Mix test configuration
  (add-to-list 'dape-configs
               '(elixir-mix-test
                 modes (elixir-ts-mode)
                 ensure (lambda (config)
                          (if (executable-find "elixir-ls")
                              t
                            (message "elixir-ls not found on PATH")
                            nil))
                 command "elixir-ls"
                 :type "mix_task"
                 :request "launch"
                 :task "test"
                 :taskArgs ("--trace")
                 :projectDir dape-buffer-default
                 :startApps t
                 :debugAutoInterpretAllModules t
                 :requireFiles ("test/**/test_helper.exs" "test/**/*_test.exs")
                 :exitAfterTaskReturns t
                 :breakOnDbg t))

  ;; Phoenix server configuration
  (add-to-list 'dape-configs
               '(elixir-phoenix
                 modes (elixir-ts-mode heex-ts-mode)
                 ensure (lambda (config)
                          (if (executable-find "elixir-ls")
                              t
                            (message "elixir-ls not found on PATH")
                            nil))
                 command "elixir-ls"
                 :type "mix_task"
                 :request "launch"
                 :task "phx.server"
                 :projectDir dape-buffer-default
                 :startApps t
                 :debugAutoInterpretAllModules t
                 :exitAfterTaskReturns nil
                 :breakOnDbg t))

  ;; Remote debugging configuration
  (add-to-list 'dape-configs
               '(elixir-remote
                 modes (elixir-ts-mode heex-ts-mode)
                 ensure (lambda (config)
                          (if (executable-find "elixir-ls")
                              t
                            (message "elixir-ls not found on PATH")
                            nil))
                 command "elixir-ls"
                 :type "mix_task"
                 :request "attach"
                 :remoteNode "your-node@host"
                 :projectDir dape-buffer-default))
  :ensure nil)
```

**Rationale**:
- Uses ElixirLS debug adapter (`elixir-ls` executable)
- Provides three common configurations:
  - `elixir-debug`: Default mix task debugging
  - `elixir-mix-test`: Test debugging with required files
  - `elixir-phoenix`: Phoenix server debugging
- `ensure` lambda checks if `elixir-ls` is available before attempting to debug
- Follows the pattern from prog-bash and prog-cpp modules
- Uses `dape-buffer-default` for project directory (resolves to current buffer's directory)
- Configures ElixirLS-specific options for optimal debugging experience

### Step 2: Update Comments in `prog-elixir/cfg.el`

**Action**: Update the file header comments to reflect the change from dap-mode to dape.

**Change line 25**:
```elisp
;;;   elixir-ls             — LSP (completions, types, code actions)
;;;   dape + elixir-ls      — DAP debugging adapter
```

### Step 3: Verify Keybindings

No changes needed - the shared `C-c d` keybindings from `core-projects/cfg.el` will automatically work with the dape configuration.

## Verification

1. **Check elixir-ls availability**:
   ```elisp
   (executable-find "elixir-ls")
   ```

2. **Test dape configuration**:
   - Open an Elixir file (`.ex` or `.exs`)
   - Run `M-x dape` and select `elixir-debug` or `elixir-mix-test`
   - Set breakpoints with `C-c d b`
   - Start debugging with `C-c d d`
   - Use `C-c d n/s/o/c` to step through code

3. **Verify keybindings work**:
   - `C-c d d` → Start debugging session
   - `C-c d b` → Toggle breakpoint
   - `C-c d n` → Next line
   - `C-c d s` → Step in
   - `C-c d o` → Step out
   - `C-c d c` → Continue
   - `C-c d q` → Quit debugging

## Dependencies

- **ElixirLS**: Must be installed and available on PATH (already required for LSP)
- **Dape**: Already installed in core-projects/cfg.el
- **elixir-ts-mode**: Already configured in prog-elixir module

## Notes

- The `ensure` lambda provides a helpful error message if elixir-ls is not found
- ElixirLS automatically interprets all modules in the project for debugging
- For test debugging, `requireFiles` ensures test helpers are loaded
- Remote debugging requires additional configuration for node names and cookies
- The configuration follows the same pattern as other language modules (bash, cpp)
