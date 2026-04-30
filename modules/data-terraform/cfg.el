;;; cfg.el --- Terraform configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Terraform, HCL, and OpenTofu editing via terraform-mode.
;;; Entry point for the data-terraform module; loads lib.el automatically.
;;;
;;; terraform-format-on-save-mode runs `terraform fmt` automatically on save.
;;; Activates for .tf, .tfvars, .hcl, and .tofu files.
;;; myde/treesit-remap-terraform enables tree-sitter parsing when grammars are available.


;;; Code:

(unless (featurep 'myde-data-terraform)
  (load-file (expand-file-name "modules/data-terraform/lib.el" user-emacs-directory)))

;; Terraform mode for .tf, .tfvars, .hcl, and .tofu files
(use-package terraform-mode  ;; https://github.com/hcl-emacs/terraform-mode
  :mode ("\\.tf\\'" "\\.tfvars\\'" "\\.hcl\\'" "\\.tofu\\'")
  :hook ((terraform-mode . terraform-format-on-save-mode))
  :config
  (myde/treesit-remap-terraform)
  :ensure t)

(provide 'myde-data-terraform-cfg)
;;; cfg.el ends here
