;;; lib.el --- Core UI library -*- coding: utf-8; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

;; Cursor configuration
(setq-default cursor-type 'bar)

;; Highlight current line globally
(global-hl-line-mode)

;; Window divider and layout restoration
(window-divider-mode)
(winner-mode)

;; Visual bell instead of audible bell
(defun myde/flash-mode-line ()
  (invert-face 'mode-line)
  (run-with-timer 0.1 nil #'invert-face 'mode-line))
(setq visible-bell nil
      ring-bell-function 'myde/flash-mode-line)

(provide 'myde-core-ui)
;;; lib.el ends here
