;;; init.el --- Loaded after early-init.el -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(defun myde/load-module (name)
  "Load the cfg.el for module NAME (without myde/ prefix)."
  (load-file (expand-file-name (concat "myde/" name "/cfg.el") user-emacs-directory)))

;; Core modules
(myde/load-module "core-base")
(myde/load-module "core-ui")
(myde/load-module "core-ux")
(myde/load-module "core-org")
(myde/load-module "core-help")
(myde/load-module "core-terminals")
(myde/load-module "core-dashboard")
(myde/load-module "core-complete")
(myde/load-module "core-notes")
(myde/load-module "core-snippets")
(myde/load-module "core-projects")

;; AI modules
(myde/load-module "ai-base")
(myde/load-module "ai-gptel")
(myde/load-module "ai-agents")
(myde/load-module "ai-claude")

;; Auth modules
(myde/load-module "auth-1password")

;; Data language modules
(myde/load-module "data-csv")
(myde/load-module "data-json")
(myde/load-module "data-terraform")
(myde/load-module "data-toml")
(myde/load-module "data-yaml")

;; Programming language modules
(myde/load-module "prog-base")
(myde/load-module "prog-elisp")
(myde/load-module "prog-elixir")
(myde/load-module "prog-fish")
(myde/load-module "prog-go")
(myde/load-module "prog-python")
(myde/load-module "prog-rust")
(myde/load-module "prog-cpp")

;; Text format modules
(myde/load-module "text-markdown")

;; Ebook modules
(myde/load-module "ebook-epub")
(myde/load-module "ebook-pdf")

(provide 'init)
;;; init.el ends here
