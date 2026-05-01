;;; lib.el --- Snippets support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Library functions for snippets support.
;;; Loaded by myde-core-snippets/cfg.el before package configuration.


;;; Code:

(defun myde-register-snippets (dir mode)
  "Register DIR as the flat snippet directory for MODE.
DIR should contain yasnippet snippet files directly with no mode-name subdir.
Safe to call before yasnippet has loaded."
  (with-eval-after-load 'yasnippet
    (when (file-directory-p dir)
      (yas--load-directory-1 dir mode))))

(provide 'myde-core-snippets)
;;; lib.el ends here
