;;; lib.el --- Core UX library -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Pure definitions (defun, defvar, defcustom) for the
;; `myde-core-ux' module.  No side effects — see cfg.el for
;; package configuration, hooks, and keybindings.


;;; Code:

;; Exit confirmation
(setq confirm-kill-emacs 'y-or-n-p)

;; Enable clickable links
(goto-address-mode 1)

;; Improve search display
(setq isearch-lazy-count t
      lazy-count-prefix-format nil
      lazy-count-suffix-format "   (%s/%s)")

;; Smart keyboard quit that closes minibuffer
;; https://emacsredux.com/blog/2025/06/01/let-s-make-keyboard-quit-smarter/
(defun myde/keyboard-quit ()
  "A smarter version of the built-in `keyboard-quit'.

The generic `keyboard-quit' does not do the expected thing when
the minibuffer is open.  Whereas we want it to close the
minibuffer, even without explicitly focusing it."
  (interactive)
  (if (active-minibuffer-window)
      (if (minibufferp)
          (minibuffer-keyboard-quit)
        (abort-recursive-edit))
    (keyboard-quit)))

(provide 'myde-core-ux)
;;; lib.el ends here
