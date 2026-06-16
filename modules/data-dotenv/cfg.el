;;; cfg.el --- dotenv editing configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; dotenv editing via dotenv-mode for .env, .envrc, and .env.* files.
;;; Entry point for the data-dotenv module; loads lib.el automatically.
;;;
;;; dotenv-mode provides syntax highlighting for KEY=value environment files.
;;; Activates for .env, .envrc, and dotted variants such as .env.local.


;;; Code:

(unless (featurep 'myde-data-dotenv)
  (load-file (expand-file-name "modules/data-dotenv/lib.el" user-emacs-directory)))

;; dotenv editing support
(use-package dotenv-mode  ;; https://github.com/preetpalS/emacs-dotenv-mode
  :mode
  (("\\.env\\'" . dotenv-mode)
   ("\\.envrc\\'" . dotenv-mode)
   ("\\.env\\.[^/]*\\'" . dotenv-mode))
  :ensure t)

(provide 'myde-data-dotenv-cfg)
;;; cfg.el ends here
