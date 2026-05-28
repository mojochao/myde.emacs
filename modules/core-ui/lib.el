;;; lib.el --- Core UI library -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Pure definitions (defun, defvar, defcustom) for the
;; `myde-core-ui' module.  No side effects — see cfg.el for
;; package configuration, hooks, and keybindings.


;;; Code:

;; Cursor configuration
(setq-default cursor-type 'bar)

;; Highlight current line globally
(global-hl-line-mode)

;; Window divider and layout restoration
(window-divider-mode)
(winner-mode)

;; Clear informational startup noise from the echo area after all hooks run.
;; emacs-startup-hook fires after after-init-hook, so this erases whatever
;; informational message (e.g. yasnippet JIT-loading notice) was last written.
(defun myde/clear-echo-area ()
  "Clear the echo area / minibuffer after startup."
  (message nil))

;; Visual bell instead of audible bell
(defun myde-flash-mode-line ()
  (invert-face 'mode-line)
  (run-with-timer 0.1 nil #'invert-face 'mode-line))
(setq visible-bell nil
      ring-bell-function 'myde-flash-mode-line)

(defun myde/frame-title ()
  "Return a frame title string.
In a project: '<project> - <relative/path/to/file>'.
Outside a project: full path, or buffer name for non-file buffers."
  (if-let ((proj (project-current))
           (file buffer-file-name))
      (concat (project-name proj) " - "
              (file-relative-name file (project-root proj)))
    (or buffer-file-name (buffer-name))))

(provide 'myde-core-ui)
;;; lib.el ends here
