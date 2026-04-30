;;; cfg.el --- Org mode configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Org mode configuration for task management, notes, and agenda.
;;; Entry point for the core-org module; loads lib.el automatically.
;;;
;;; org-directory is set from myde/org-directory (defined in lib.el).
;;; org-return-follows-link is enabled so RET opens links without C-c C-o.
;;; visual-line-mode and trailing-whitespace cleanup activate on every org buffer.


;;; Code:

(unless (featurep 'myde-core-org)
  (load-file (expand-file-name "modules/core-org/lib.el" user-emacs-directory)))

;; I use org to manage my thoughts and actions.
(use-package org  ;; https://orgmode.org
  :hook
  (org-mode . visual-line-mode)
  (org-mode . myde/delete-trailing-whitespace-setup)
  :custom
  (org-directory myde/org-directory)
  (org-return-follows-link t)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :config
  (setq org-confirm-babel-evaluate nil)
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((emacs-lisp . t))))
  :ensure nil)

(use-package ob-async  ;; https://github.com/astahlman/ob-async
  :after org
  :ensure t)

(provide 'myde-core-org-cfg)
;;; cfg.el ends here
