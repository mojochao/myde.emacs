;;; cfg.el --- AI agents configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; Package configuration for AI agent tools.
;;; Entry point for the ai-agents module; loads lib.el automatically.

;;; Code:

(unless (featurep 'myde-ai-agents)
  (load-file (expand-file-name "myde/ai-agents/lib.el" user-emacs-directory)))

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
