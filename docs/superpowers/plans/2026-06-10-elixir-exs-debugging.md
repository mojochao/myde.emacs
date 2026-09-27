# Plan: Add .exs Script Debugging Support

## Context

The user wants to debug `.exs` scripts (standalone Elixir scripts) in addition to Mix project tasks. ElixirLS can debug `.exs` scripts, but requires specific configuration and has limitations due to how the OTP debugger works.

## Key Findings

1. **ElixirLS can debug .exs scripts** using the `mix_task` adapter type with `task: "run"` and `taskArgs: ["--no-mix-exs", "script.exs"]`
2. **Critical limitation**: `.exs` scripts execute immediately upon compilation, creating a race condition where the debugger may not have time to interpret modules and set breakpoints
3. **Workaround**: Scripts must be wrapped in module functions and use `Task.start/1` with a sleep delay to give the debugger time to initialize
4. **`requireFiles` is essential**: Without specifying `.exs` files in `requireFiles`, breakpoints won't be hit because the files won't be interpreted
5. **`exitAfterTaskReturns` must be `nil`**: For scripts that use `Task.start`, the mix task returns immediately but the debugged code continues running asynchronously

## Current State

The existing `elixir-debug` configuration in `prog-elixir/cfg.el` (lines 81-97) is configured for `mix run` but:
- Missing `:taskArgs` for `--no-mix-exs` flag
- Missing `:requireFiles` for the script file
- Has `:exitAfterTaskReturns t` which will end the session too early for async scripts

## Implementation Plan

### Step 1: Update `prog-elixir/cfg.el`

**File**: `/home/agooch/devel/repos/github.com/mojochao/myde.emacs/modules/prog-elixir/cfg.el`

**Action**: Add a new dape configuration for `.exs` script debugging.

**New configuration** (add after the existing `elixir-debug` configuration):

```elisp
;; .exs script debugging configuration
;;
;; Note: .exs scripts must be structured to work around a race condition:
;; 1. Wrap main logic in a module function
;; 2. Use Task.start with a sleep delay to give the debugger time to interpret
;; 3. Example structure:
;;
;;    defmodule MyScript do
;;      def run do
;;        # Your code here
;;        IO.puts("done")
;;      end
;;    end
;;
;;    Task.start(fn ->
;;      Process.sleep(4000)  ; Give debugger time to interpret
;;      MyScript.run()
;;    end)
;;
;; Alternatively, use Kernel.dbg/2 for simpler debugging without breakpoints.
;; The breakOnDbg setting enables automatic breaking on dbg() calls.
(add-to-list 'dape-configs
             '(elixir-exs-script
               modes (elixir-ts-mode)
               ensure (lambda (config)
                        (if (executable-find "elixir-ls")
                            t
                          (message "elixir-ls not found on PATH")
                          nil))
               command "elixir-ls"
               :type "mix_task"
               :request "launch"
               :task "run"
               :taskArgs ("--no-mix-exs" dape-buffer-default)
               :projectDir dape-buffer-default
               :requireFiles (dape-buffer-default)
               :startApps nil
               :debugAutoInterpretAllModules t
               :exitAfterTaskReturns nil
               :breakOnDbg t))
```

**Rationale**:
- Uses `task: "run"` with `--no-mix-exs` flag to run standalone scripts
- `requireFiles` ensures the script is interpreted for breakpoint support
- `exitAfterTaskReturns: nil` prevents premature session termination for async scripts
- `startApps: nil` for standalone scripts (no Mix project context)
- Includes detailed documentation about the race condition workaround

### Step 2: Update File Header Comments

**Action**: Update the file header comments to mention `.exs` script debugging support.

**Change line 25**:
```elisp
;;;   dape + elixir-ls              — DAP debugging adapter (mix tasks & .exs scripts)
```

### Step 3: Update Documentation in `prog-elixir/lib.el`

**Action**: Add a section to `lib.el` with examples of how to structure `.exs` scripts for debugging.

**Add after the `myde-elixir-ts-ensure-grammars` function**:

```elisp
(defun myde-elixir-exs-debug-example ()
  "Return an example of how to structure an .exs script for debugging.

This is for documentation purposes only - not meant to be called interactively.

Example structure for debugging .exs scripts with dape:

    defmodule MyScript do
      def run do
        a = [1, 2, 3]
        b = Enum.map(a, &(&1 + 1))
        IO.inspect(b, label: \"result\")
        b
      end
    end

    Task.start(fn ->
      Process.sleep(4000)  # Give debugger time to interpret
      MyScript.run()
    end)

Key points:
1. Wrap main logic in a module function
2. Use Task.start with a sleep delay to work around race condition
3. The script will be interpreted when debugging starts
4. Set breakpoints in the module functions, not top-level code

Alternative: Use Kernel.dbg/2 for simpler debugging without breakpoints.
Set breakOnDbg: true in the dape configuration to enable automatic breaking."
  nil)
```

## Verification

1. **Check elixir-ls availability**:
   ```elisp
   (executable-find "elixir-ls")
   ```

2. **Test with a simple .exs script**:
   Create a test file `test_debug.exs`:
   ```elixir
   defmodule TestDebug do
     def run do
       a = [1, 2, 3]
       b = Enum.map(a, &(&1 + 1))
       IO.inspect(b, label: "result")
       b
     end
   end

   Task.start(fn ->
     Process.sleep(4000)
     TestDebug.run()
   end)
   ```

3. **Test dape configuration**:
   - Open the `.exs` file
   - Run `M-x dape` and select `elixir-exs-script`
   - Set breakpoints in the module functions
   - Start debugging with `C-c d d`
   - Wait for the debugger to interpret modules and hit breakpoints

4. **Verify keybindings work**:
   - `C-c d d` → Start debugging session
   - `C-c d b` → Toggle breakpoint
   - `C-c d n` → Next line
   - `C-c d s` → Step in
   - `C-c d o` → Step out
   - `C-c d c` → Continue
   - `C-c d q` → Quit debugging

## Limitations (to document)

1. **Race condition**: `.exs` scripts execute immediately upon compilation. The debugger may not have time to interpret modules and set breakpoints before code runs. Requires wrapping in `Task.start` with a sleep delay.

2. **Modules must be in functions**: OTP debugger requires code to be in module functions, not top-level script code. Bare script code cannot be interpreted.

3. **Need `requireFiles`**: Without specifying `.exs` files in `requireFiles`, they won't be interpreted and breakpoints won't work.

4. **Need a `mix.exs` context**: Even with `--no-mix-exs`, the debug adapter needs to be initialized in a directory structure it recognizes. A dummy `mix.exs` may be needed for completely standalone scripts.

5. **Expression evaluator limitations**: The `:int`-based evaluator uses SSA form, so variable scoping in conditional breakpoints can be incorrect. Module attributes are not accessible.

6. **No exception breakpoints**: Elixir's debugger does not support exception breakpoints.

7. **Conditional breakpoint limit**: Maximum 100 conditional breakpoints (plain breakpoints are unlimited).

8. **NIF modules cannot be interpreted**: NIFs must be excluded via `excludeModules`.

## Alternative: Use Kernel.dbg/2

For simpler debugging without the complexity of breakpoints, users can use `Kernel.dbg/2`:

```elixir
defmodule MyScript do
  def run do
    a = [1, 2, 3]
    dbg(a)  # Automatically breaks here when breakOnDbg is true
    b = Enum.map(a, &(&1 + 1))
    dbg(b)
    b
  end
end
```

This approach:
- No need for `requireFiles` or module interpretation
- Works with any script structure
- Automatic breakpoint on `dbg()` calls
- Simpler than setting up breakpoints manually

The `breakOnDbg: t` setting in the dape configuration enables this behavior.

## Dependencies

- **ElixirLS**: Must be installed and available on PATH (already required for LSP)
- **Dape**: Already installed in core-projects/cfg.el
- **elixir-ts-mode**: Already configured in prog-elixir module

## Notes

- The `command "elixir-ls"` works because ElixirLS ships both `language_server.sh` and `debug_adapter.sh` in the same release directory
- The `elixir-ls` wrapper script dispatches to the appropriate component based on the DAP protocol handshake
- If debugging fails, try using the explicit `debug_adapter.sh` path
- The configuration follows the same pattern as other dape configurations in the module
