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

(defcustom myde-hcl-exe "terraform"
  "Path to the terraform or tofu executable."
  :type 'string
  :group 'terraform)

(defun myde-hcl-format-buffer ()
  "Format the current buffer with the terraform or tofu fmt subcommand."
  (interactive)
  (when (or (executable-find "terraform") (executable-find "tofu"))
    (call-process-region (point-min) (point-max) myde-hcl-exe t t nil "fmt" "-")))

(define-minor-mode myde-hcl-format-on-save-mode
  "Auto-format HCL buffer on save using terraform fmt."
  :lighter " fmt"
  (if terraform-format-on-save-mode
      (add-hook 'before-save-hook #'myde-hcl-format-buffer nil t)
    (remove-hook 'before-save-hook #'myde-hcl-format-buffer t)))

(defun myde-treesit-remap-hcl ()
  "Enable tree-sitter mode for terraform if grammar is available."
  (when (and (fboundp 'treesit-available-p)
             (treesit-available-p)
             (treesit-language-available-p 'hcl))
    (add-to-list 'major-mode-remap-alist
                 '(terraform-mode . terraform-ts-mode))))

(provide 'myde-data-hcl)
;;; lib.el ends here
