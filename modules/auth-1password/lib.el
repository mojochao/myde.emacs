;;; lib.el --- 1Password authentication support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Library functions for 1Password secret management integration.
;;; Loaded by myde/auth-1password/cfg.el before package configuration.


;;; Code:


(defun myde/auth-source-1password-construct-secret-reference
    (_backend _type host &optional user _port)
  "Construct 1Password entry path as vault/host/password (or vault/host/user/password if user provided)."
  (if user
      (mapconcat #'identity (list auth-source-1password-vault host user "password") "/")
    (mapconcat #'identity (list auth-source-1password-vault host "password") "/")))

(provide 'myde-auth-1password)
;;; lib.el ends here
