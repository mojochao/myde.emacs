;;; cfg.el --- Org mode configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; Org mode package setup and keybindings.

;;; Code:

(unless (featurep 'myde-core-org)
  (load-file (expand-file-name "myde/core-org/lib.el" user-emacs-directory)))

;; I use org to manage my thoughts and actions.
(use-package org  ;; https://orgmode.org
  :hook
  (org-mode . visual-line-mode)
  (org-mode . myde/delete-trailing-whitespace-setup)
  :custom
  (org-directory myde/org-directory)
  (org-return-follows-link t)
  :ensure nil)

(provide 'myde-core-org-cfg)
;;; cfg.el ends here
