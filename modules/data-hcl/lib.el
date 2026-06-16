;;; lib.el --- HCL support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; HCL editing utilities (Terraform, OpenTofu, and other HCL dialects).


;;; Code:

(defun myde-treesit-remap-hcl ()
  "Enable tree-sitter mode for terraform if grammar is available."
  (when (and (fboundp 'treesit-available-p)
             (treesit-available-p)
             (treesit-language-available-p 'hcl))
    (add-to-list 'major-mode-remap-alist
                 '(terraform-mode . terraform-ts-mode))))

(provide 'myde-data-hcl)
;;; lib.el ends here
