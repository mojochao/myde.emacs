;;; cfg.el --- CSV editing configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; CSV and TSV editing setup.

;;; Code:

(unless (featurep 'myde-data-csv)
  (load-file (expand-file-name "myde/data-csv/lib.el" user-emacs-directory)))

(use-package csv-mode  ;; https://elpa.gnu.org/packages/csv-mode.html
  :mode (("\\.csv\\'" . csv-mode)
         ("\\.tsv\\'" . csv-mode))
  :ensure t)

(provide 'myde-data-csv-cfg)
;;; cfg.el ends here
