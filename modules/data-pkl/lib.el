;;; lib.el --- Pkl editing support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Pkl configuration language editing utilities.


;;; Code:


(defun myde-data-pkl-mode-setup ()
  "Set buffer-local settings for `pkl-mode' buffers."
  (setq-local fill-column 100
              tab-width 2
              indent-tabs-mode nil))

(provide 'myde-data-pkl)
;;; lib.el ends here
