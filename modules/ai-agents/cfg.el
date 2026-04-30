;;; cfg.el --- AI agents configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Package configuration for AI agent tools (acp, agent-shell).
;;; Entry point for the ai-agents module; loads lib.el automatically.
;;;
;;; Both packages require transient for their UI:
;;;   acp         — AI command palette for code-related tasks
;;;   agent-shell — AI-powered shell command assistant


;;; Code:

(unless (featurep 'myde-ai-agents)
  (load-file (expand-file-name "modules/ai-agents/lib.el" user-emacs-directory)))

;; -----------------------------------------------------------------------------
;; AI completion provider
;; -----------------------------------------------------------------------------

(use-package acp  ;; https://github.com/xenodium/acp.el
  :after transient
  :ensure t)

;; -----------------------------------------------------------------------------
;; AI shell agent
;; -----------------------------------------------------------------------------

(use-package agent-shell  ;; https://github.com/xenodium/agent-shell
  :after transient
  :ensure t)

(provide 'myde-ai-agents-cfg)
;;; cfg.el ends here
