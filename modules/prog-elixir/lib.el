;;; lib.el --- Elixir support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Library functions for Elixir development support.
;;; Loaded by myde-prog-elixir/cfg.el before package configuration.


;;; Code:


(defun myde-elixir-ts-ensure-grammars ()
  "Ensure Elixir and HEEx tree-sitter grammars are installed."
  (dolist (lang '(elixir heex))
    (unless (treesit-ready-p lang t)
      (message "Installing %s tree-sitter grammar..." lang)
      (treesit-install-language-grammar lang))))

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

(provide 'myde-prog-elixir)
;;; lib.el ends here
