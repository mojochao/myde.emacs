;;; lib.el --- Rust support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Pure definitions (defun, defvar, defcustom) for the
;; `myde-prog-rust' module.  No side effects — see cfg.el for
;; package configuration, hooks, and keybindings.


;;; Code:

(defun myde-rust-mode-setup ()
  "Set buffer-local settings for rustic-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "cargo test"))

(declare-function dape-cwd "dape")

(defun myde-rust-dape-debug-program ()
  "Resolve the debug binary path for the current Rust project.
Used as the `:program' callback for dape Rust debug configurations."
  (expand-file-name
   (concat "target/debug/"
           (file-name-nondirectory (directory-file-name (dape-cwd))))
   (dape-cwd)))

(provide 'myde-prog-rust)
;;; lib.el ends here
