;;; cfg.el --- Terraform configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; Terraform and HCL editing setup.

;;; Code:

(unless (featurep 'myde-data-terraform)
  (load-file (expand-file-name "myde/data-terraform/lib.el" user-emacs-directory)))

;; Terraform mode for .tf, .tfvars, .hcl, and .tofu files
(use-package terraform-mode  ;; https://github.com/hcl-emacs/terraform-mode
  :mode ("\\.tf\\'" "\\.tfvars\\'" "\\.hcl\\'" "\\.tofu\\'")
  :hook ((terraform-mode . terraform-format-on-save-mode))
  :config
  (myde/treesit-remap-terraform)
  :ensure t)

(provide 'myde-data-terraform-cfg)
;;; cfg.el ends here
