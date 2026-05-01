;;; lib.el --- GPtel AI assistant support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Library for GPtel AI assistant integration with OpenRouter and other providers.
;;; Loaded by myde-ai-gptel/cfg.el before package configuration.


;;; Code:

(defun myde-gptel-api-key-from-environment (&optional var)
  "Get API key from environment variable.
If VAR is provided, use that environment variable.
Otherwise, derive the variable name from the current gptel-backend type."
  (lambda ()
    (getenv (or var                     ;provided key
                (thread-first           ;or fall back to <TYPE>_API_KEY
                  (type-of gptel-backend)
                  (symbol-name)
                  (substring 6)
                  (upcase)
                  (concat "_API_KEY"))))))

(provide 'myde-ai-gptel)
;;; lib.el ends here
