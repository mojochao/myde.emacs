;;; lib.el --- Spell checking library for myde -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Pure definitions for the core-spell module.
;;; No side effects — see cfg.el for package configuration, hooks, and keybindings.


;;; Code:

(defun myde/jinx-text-mode-setup ()
  "Enable jinx for full text checking in text-mode buffers."
  (jinx-mode))

(defun myde/jinx-prog-mode-setup ()
  "Enable jinx restricted to comment and doc faces in prog-mode buffers."
  ;; jinx-include-faces is an alist of (mode-or-t face...).  Using t as the
  ;; key matches any mode, which is correct for a buffer-local override.
  (setq-local jinx-include-faces
              '((t font-lock-comment-face
                   font-lock-doc-face)))
  (jinx-mode))

(provide 'myde-core-spell)
;;; lib.el ends here
