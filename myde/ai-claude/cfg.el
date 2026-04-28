;;; cfg.el --- Claude AI integration configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; Package configuration for Claude AI integration via claude-code-ide.
;;; Entry point for the ai-claude module; loads lib.el automatically.

;;; Code:

(unless (featurep 'myde-ai-claude)
  (load-file (expand-file-name "myde/ai-claude/lib.el" user-emacs-directory)))

;; -----------------------------------------------------------------------------
;; Claude code IDE integration
;; -----------------------------------------------------------------------------

(use-package claude-code-ide  ;; https://github.com/manzaltu/claude-code-ide.el
  :bind
  ("C-c c" . claude-code-ide-menu) ; Set your favorite keybinding
  :config
  (claude-code-ide-emacs-tools-setup)
  :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :rev :newest))

(provide 'myde-ai-claude-cfg)
;;; cfg.el ends here
