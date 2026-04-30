;;; cfg.el --- Org mode configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

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
