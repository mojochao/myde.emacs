;;; cfg.el --- CSV editing configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; CSV and TSV editing via csv-mode.
;;; Entry point for the data-csv module; loads lib.el automatically.
;;;
;;; csv-mode activates for .csv and .tsv files and provides column-aligned
;;; display, field navigation, and sort/reverse-sort operations.


;;; Code:

(unless (featurep 'myde-data-csv)
  (load-file (expand-file-name "modules/data-csv/lib.el" user-emacs-directory)))

(use-package csv-mode  ;; https://elpa.gnu.org/packages/csv-mode.html
  :mode (("\\.csv\\'" . csv-mode)
         ("\\.tsv\\'" . csv-mode))
  :ensure t)

(use-package indent-bars
  :hook (csv-mode . indent-bars-mode))

(provide 'myde-data-csv-cfg)
;;; cfg.el ends here
