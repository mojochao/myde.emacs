;;; lib.el --- Terraform support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; Terraform and HCL editing utilities.

;;; Code:

(require 'myde)

(defun myde/treesit-remap-terraform ()
  "Enable tree-sitter mode for terraform if grammar is available."
  (when (and (fboundp 'treesit-available-p)
             (treesit-available-p)
             (treesit-language-available-p 'hcl))
    (add-to-list 'major-mode-remap-alist
                 '(terraform-mode . terraform-ts-mode))))

(provide 'myde-data-terraform)
;;; lib.el ends here
