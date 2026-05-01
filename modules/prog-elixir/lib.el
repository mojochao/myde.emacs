;;; lib.el --- Elixir support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
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

(provide 'myde-prog-elixir)
;;; lib.el ends here
