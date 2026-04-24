;;; lib.el --- Elixir support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Library functions for Elixir development support.
;;; Loaded by myde/prog-elixir/cfg.el before package configuration.

;;; Code:

(require 'myde)

(defun myde/elixir-ts-ensure-grammars ()
  "Ensure Elixir and HEEx tree-sitter grammars are installed."
  (dolist (lang '(elixir heex))
    (unless (treesit-ready-p lang t)
      (message "Installing %s tree-sitter grammar..." lang)
      (treesit-install-language-grammar lang))))

(provide 'myde-prog-elixir)
;;; lib.el ends here
