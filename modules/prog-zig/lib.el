;;; lib.el --- Zig support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Pure definitions (defun, defvar, defcustom) for the
;; `myde-prog-zig' module.  No side effects — see cfg.el for
;; package configuration, hooks, and keybindings.


;;; Code:

(defun myde-zig-ts-or-plain-mode ()
  "Use `zig-ts-mode' if tree-sitter is available, otherwise fall back to `zig-mode'."
  (if (treesit-ready-p 'zig)
      (zig-ts-mode)
    (zig-mode)))

(defun myde-zig-mode-setup ()
  "Set buffer-local settings for zig-ts-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "zig build"))

(defun myde-zig-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde-zig-format-on-save-setup ()
  "Install buffer-local before-save formatting for zig-mode."
  (add-hook 'before-save-hook #'myde-zig-eglot-format-buffer nil t))

(declare-function dape-cwd "dape")

(defun myde-zig-dape-binary ()
  "Resolve the debug binary path for the current Zig project.
Used as the `:program' callback for dape Zig debug configurations."
  (expand-file-name
   (concat "zig-out/bin/"
           (file-name-nondirectory (directory-file-name (dape-cwd))))
   (dape-cwd)))

(provide 'myde-prog-zig)
;;; lib.el ends here
