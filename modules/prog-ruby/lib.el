;;; lib.el --- Ruby support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Pure definitions (defun, defvar, defcustom) for the
;; `myde-prog-ruby' module.  No side effects — see cfg.el for
;; package configuration, hooks, and keybindings.


;;; Code:

(defun myde/ruby-ts-or-plain-mode ()
  "Use `ruby-ts-mode' if tree-sitter is available, otherwise fall back to `ruby-mode'."
  (if (treesit-ready-p 'ruby)
      (ruby-ts-mode)
    (ruby-mode)))

(defun myde/ruby-mode-setup ()
  "Set buffer-local settings for ruby-mode and ruby-ts-mode buffers."
  (setq-local tab-width 2
              indent-tabs-mode nil
              fill-column 120
              compile-command "bundle exec rspec"))

(defun myde/ruby-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde/ruby-format-on-save-setup ()
  "Install buffer-local before-save formatting for ruby buffers."
  (add-hook 'before-save-hook #'myde/ruby-eglot-format-buffer nil t))

(provide 'myde-prog-ruby)
;;; lib.el ends here
