;;; cfg.el --- Claude AI integration configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Package configuration for Claude Code IDE integration via claude-code-ide.
;;; Entry point for the ai-claude module; loads lib.el automatically.
;;;
;;; claude-code-ide provides an Emacs interface to the Claude Code CLI.
;;; The transient dispatch menu is bound to C-c c.
;;; claude-code-ide-emacs-tools-setup registers Emacs-side MCP tool handlers.
;;; Installed from git via :vc — not available on MELPA.


;;; Code:

(unless (featurep 'myde-ai-claude)
  (load-file (expand-file-name "modules/ai-claude/lib.el" user-emacs-directory)))

;; -----------------------------------------------------------------------------
;; Claude code IDE integration
;; -----------------------------------------------------------------------------

(use-package claude-code-ide  ;; https://github.com/manzaltu/claude-code-ide.el
  :bind
  ("C-c c" . claude-code-ide-menu) ; Set your favorite keybinding
  :config
  (claude-code-ide-emacs-tools-setup)
  :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :rev :newest)
  :ensure t)

(provide 'myde-ai-claude-cfg)
;;; cfg.el ends here
