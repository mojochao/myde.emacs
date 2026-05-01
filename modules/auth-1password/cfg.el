;;; cfg.el --- 1Password authentication configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Package configuration for 1Password secret management via auth-source-1password.
;;; Entry point for the auth-1password module; loads lib.el automatically.
;;;
;;; Bridges Emacs's auth-source system to the 1Password CLI (op).
;;; Secrets are read from the "My API credentials" vault.
;;; Required by ai-gptel for its OpenRouter and Mistral API keys.
;;; Requires the 1Password CLI (op) on PATH with an active session.


;;; Code:

(unless (featurep 'myde-auth-1password)
  (load-file (expand-file-name "modules/auth-1password/lib.el" user-emacs-directory)))

;; -----------------------------------------------------------------------------
;; 1Password authentication
;; -----------------------------------------------------------------------------

(use-package auth-source-1password  ;; https://github.com/dlobraico/auth-source-1password
  :init
  (setq auth-source-1password-construct-secret-reference
        #'myde-auth-source-1password-construct-secret-reference)
  :config
  (auth-source-1password-enable)
  :custom
  (auth-source-1password-vault "My API credentials")
  :ensure t)

(provide 'myde-auth-1password-cfg)
;;; cfg.el ends here
