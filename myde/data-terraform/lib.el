;;; lib.el --- Terraform support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; Terraform and HCL editing utilities.

;;; Code:

(defcustom myde/terraform-exe "terraform"
  "Path to the terraform or tofu executable."
  :type 'string
  :group 'terraform)

(defun myde/terraform-format-buffer ()
  "Format the current buffer with terraform executable fmt subcommand."
  (interactive)
  (when (or (executable-find "terraform") (executable-find "tofu"))
    (call-process-region (point-min) (point-max) myde/terraform-exe t t nil "fmt" "-")))

(define-minor-mode myde/terraform-format-on-save-mode
  "Auto-format Terraform buffer on save using terraform fmt."
  :lighter " fmt"
  (if terraform-format-on-save-mode
      (add-hook 'before-save-hook #'myde/terraform-format-buffer nil t)
    (remove-hook 'before-save-hook #'myde/terraform-format-buffer t)))

(defun myde/treesit-remap-terraform ()
  "Enable tree-sitter mode for terraform if grammar is available."
  (when (and (fboundp 'treesit-available-p)
             (treesit-available-p)
             (treesit-language-available-p 'hcl))
    (add-to-list 'major-mode-remap-alist
                 '(terraform-mode . terraform-ts-mode))))

(provide 'myde-data-terraform)
;;; lib.el ends here
