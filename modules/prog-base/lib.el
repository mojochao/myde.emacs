;;; lib.el --- Programming base library -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Pure definitions (defun, defvar, defcustom) for the
;; `myde-prog-base' module.  No side effects — see cfg.el for
;; package configuration, hooks, and keybindings.


;;; Code:

(defun myde-prog-mode-hook-function ()
  "Configure display of line numbers and current line highlighting."
  (display-line-numbers-mode t)
  (hl-line-mode t))

(defun myde-mise-exec-which (dir exe)
  "Resolve EXE path via mise exec for project in DIR."
  (let ((default-directory (or dir
                               (and (buffer-file-name (buffer-base-buffer))
                                    (file-name-directory (buffer-file-name (buffer-base-buffer))))
                               default-directory)))
    (list (string-trim
           (shell-command-to-string
            (concat mise-executable " exec -- which " exe))))))

(provide 'myde-prog-base)
;;; lib.el ends here
