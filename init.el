;;; init.el --- Loaded after early-init.el -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

;; Load myde.el functions
(load-file (expand-file-name "myde.el" user-emacs-directory))

;; Core modules
(load-file (expand-file-name "myde/core-base/cfg.el"      user-emacs-directory))
(load-file (expand-file-name "myde/core-ui/cfg.el"        user-emacs-directory))
(load-file (expand-file-name "myde/core-ux/cfg.el"        user-emacs-directory))
(load-file (expand-file-name "myde/core-org/cfg.el"       user-emacs-directory))
(load-file (expand-file-name "myde/core-help/cfg.el"      user-emacs-directory))
(load-file (expand-file-name "myde/core-terminals/cfg.el" user-emacs-directory))
(load-file (expand-file-name "myde/core-dashboard/cfg.el" user-emacs-directory))
(load-file (expand-file-name "myde/core-complete/cfg.el"  user-emacs-directory))
(load-file (expand-file-name "myde/core-notes/cfg.el"     user-emacs-directory))
(load-file (expand-file-name "myde/core-snippets/cfg.el"  user-emacs-directory))
(load-file (expand-file-name "myde/core-projects/cfg.el"  user-emacs-directory))

;; Auth modules
(load-file (expand-file-name "myde/auth-1password/cfg.el" user-emacs-directory))

;; Ebook modules
(load-file (expand-file-name "myde/ebook-pdf/cfg.el"      user-emacs-directory))
(load-file (expand-file-name "myde/ebook-epub/cfg.el"     user-emacs-directory))

;; Data format modules
(load-file (expand-file-name "myde/data-terraform/cfg.el" user-emacs-directory))
(load-file (expand-file-name "myde/data-toml/cfg.el"      user-emacs-directory))
(load-file (expand-file-name "myde/data-yaml/cfg.el"      user-emacs-directory))

;; Programming base + language modules
(load-file (expand-file-name "myde/prog-base/cfg.el"      user-emacs-directory))
(load-file (expand-file-name "myde/prog-fish/cfg.el"      user-emacs-directory))
(load-file (expand-file-name "myde/prog-elisp/cfg.el"     user-emacs-directory))
(load-file (expand-file-name "myde/prog-go/cfg.el"        user-emacs-directory))
(load-file (expand-file-name "myde/prog-python/cfg.el"    user-emacs-directory))
(load-file (expand-file-name "myde/prog-elixir/cfg.el"    user-emacs-directory))

;; Text format modules
(load-file (expand-file-name "myde/text-markdown/cfg.el"  user-emacs-directory))

;; AI modules
(load-file (expand-file-name "myde/ai-gptel/cfg.el"       user-emacs-directory))
(load-file (expand-file-name "myde/ai-agents/cfg.el"      user-emacs-directory))
(load-file (expand-file-name "myde/ai-claude/cfg.el"      user-emacs-directory))

(provide 'init)
;;; init.el ends here
