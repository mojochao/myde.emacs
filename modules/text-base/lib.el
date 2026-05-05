;;; lib.el --- Text base library -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Pure definitions for the `myde-text-base' module.  No side effects —
;; see cfg.el for hooks and configuration.


;;; Code:

(defun myde-text-mode-hook-function ()
  "Configure display of line numbers on all text-mode buffers."
  (display-line-numbers-mode t))

(provide 'myde-text-base)
;;; lib.el ends here
