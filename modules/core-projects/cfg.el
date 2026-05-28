;;; cfg.el --- Projects support configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Central infrastructure module for developer tooling.
;;; Entry point for the core-projects module; loads lib.el automatically.
;;;
;;; Language modules register their LSP servers, DAP configs, and formatters into
;;; the frameworks configured here — only shared settings and keybindings live here.
;;;
;;; Configures:
;;;   project.el — project discovery and navigation (C-c p / s-p / C-x p)
;;;   neotree                 — file-tree sidebar toggled with F8
;;;   editorconfig            — project-wide formatting rules from .editorconfig
;;;   treesit + treesit-auto  — tree-sitter grammar auto-install for all languages
;;;   eglot                   — LSP client with shared C-c e keybindings
;;;   flycheck + flymake      — diagnostics (flycheck global; flymake for eglot, C-c !)
;;;   dotenv-mode             — .env and .envrc file editing
;;;   mason + mise            — tool and runtime version management
;;;   dap-mode + dape         — DAP debugger with shared C-c d keybindings
;;;   magit + forge + git-modes — Git and GitHub/GitLab workflow (C-c g prefix)
;;;   diff-hl + blamer          — Git gutter and inline blame (C-c g prefix)


;;; Code:

(unless (featurep 'myde-core-projects)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Project management
;; -----------------------------------------------------------------------------

;; Built-in project management
(use-package project
  :config
  (keymap-global-set "C-c p" project-prefix-map)
  (keymap-global-set "s-p" project-prefix-map)
  (when (file-directory-p (expand-file-name "~/Projects/"))
    (project-remember-projects-under "~/Projects/" t))
  :custom
  (project-list-file
   (expand-file-name "emacs/projects.eld" (xdg-state-home)))
  :ensure nil)

;; EditorConfig support for project-wide formatting rules
(use-package editorconfig
  :hook (after-init . editorconfig-mode)
  :diminish editorconfig-mode
  :ensure nil)

;; Declare optional functions referenced by neotree to suppress native compiler warnings
(eval-when-compile
  (defvar nerd-icons-icon-for-file nil)
  (defvar nerd-icons-icon-for-dir nil)
  (defvar nerd-icons-octicon nil)
  (declare-function nerd-icons-icon-for-file "nerd-icons" (file &rest _))
  (declare-function nerd-icons-icon-for-dir "nerd-icons" (dir &rest _))
  (declare-function nerd-icons-octicon "nerd-icons" (name &rest _))
  (declare-function linum-mode "linum" (&optional _)))

;; -----------------------------------------------------------------------------
;; Project tree explorer
;; -----------------------------------------------------------------------------

(use-package neotree  ;; https://github.com/jaypei/emacs-neotree
  :after nerd-icons
  :bind ([f8] . myde-neotree-project-root-toggle)
  :commands (neotree-toggle)
  :config
  (setq neo-theme (if (display-graphic-p) 'nerd-icons 'arrow))
  (setq neo-window-fixed-size nil)
  (setq neo-show-hidden-files t)
  (add-to-list 'window-size-change-functions #'myde-neotree-window-size-change-function)
  (add-hook 'after-save-hook        #'myde-neotree-refresh)
  (add-hook 'after-delete-file-hook #'myde-neotree-refresh)
  (add-hook 'after-create-file-hook #'myde-neotree-refresh)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Tree-sitter setup
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (setq treesit-extra-load-path
        (list (expand-file-name "emacs/tree-sitter" (xdg-data-home))))
  ;; Language grammar sources are registered by each language module in myde-.
  :ensure nil)

(use-package treesit-auto  ;; https://github.com/renzmann/treesit-auto
  :hook (after-init . global-treesit-auto-mode)
  :config
  (setq treesit-auto-install t) ; install grammars automatically, if missing
  :diminish treesit-auto-mode
  :ensure t)

;; -----------------------------------------------------------------------------
;; LSP support
;; -----------------------------------------------------------------------------

(use-package eglot
  ;; Hooks, server programs, and workspace config are registered by each
  ;; language module in myde-.  Only shared keybindings and performance
  ;; settings live here.
  :bind (:map eglot-mode-map
              ("C-c e a" . eglot-code-actions)
              ("C-c e r" . eglot-rename)
              ("C-c e f" . eglot-format)
              ("C-c e i" . eglot-find-implementation)
              ("C-c e t" . eglot-find-typeDefinition))
  :config
  ;; Performance optimizations
  (setq eglot-autoshutdown t
        eglot-sync-connect 0                               ;; non-blocking LSP connect
        eglot-report-progress nil                          ;; no progress messages
        eglot-events-buffer-config '(:size 0 :format short) ;; no event logging
        jsonrpc-event-hook nil)                            ;; no per-message hooks
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Problems reporting support
;; -----------------------------------------------------------------------------

;; Flycheck (on-the-fly syntax checking)
(use-package flycheck  ;; https://github.com/flycheck/flycheck
  :hook (after-init . global-flycheck-mode)
  :config
  (setq flycheck-check-syntax-automatically '(save mode-enabled))
  :diminish (flycheck-mode . " ✓")
  :ensure t)

;; flymake is used by eglot for LSP diagnostics.  Provide navigation bindings
;; alongside the global flycheck setup so eglot errors are easy to navigate.
(use-package flymake
  :bind (("C-c ! n" . flymake-goto-next-error)
         ("C-c ! p" . flymake-goto-prev-error)
         ("C-c ! l" . flymake-show-buffer-diagnostics))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Project specific environment configuration files
;; -----------------------------------------------------------------------------

(use-package dotenv-mode
  :mode (("\\.env\\'" . dotenv-mode)
         ("\\.envrc\\'" . dotenv-mode))
  :ensure t)

;; (use-package direnv  ;; https://github.com/wbolster/emacs-direnv
;;   :config
;;   (direnv-mode)
;;   :ensure t )

;; -----------------------------------------------------------------------------
;; Tools support
;; -----------------------------------------------------------------------------

(use-package mason  ;; https://github.com/mason-org/mason.el
  :custom
  (mason-dir (expand-file-name "emacs/mason" (xdg-data-home)))
  :ensure t)

(use-package mise  ;; https://github.com/eki3z/mise.el
  :hook (after-init . global-mise-mode)
  :diminish mise-mode
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugger support
;; -----------------------------------------------------------------------------

(use-package dap-mode  ;; https://github.com/emacs-lsp/dap-mode
  :after (transient eglot)
  :custom
  (dap-breakpoints-file (expand-file-name "emacs/.dap-breakpoints" (xdg-state-home)))
  :config
  (dap-auto-configure-mode)  ;; Language-specific DAP adapters are loaded by each language module in myde-prog-*/ module dirs.
  :ensure t)

(use-package dape  ;; https://github.com/svaante/dape
  ;; Lightweight DAP client; debug configs are registered by each language
  ;; module in myde-.  Only shared keybindings and layout settings live here.
  :after transient
  :config
  (setq dape-buffer-window-arrangement 'right)
  :bind (("C-c d d" . dape)
         ("C-c d l" . dape-last)
         ("C-c d b" . dape-breakpoint-toggle)
         ("C-c d n" . dape-next)
         ("C-c d s" . dape-step-in)
         ("C-c d o" . dape-step-out)
         ("C-c d c" . dape-continue)
         ("C-c d q" . dape-quit))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Git version control setup (C-c g prefix)
;; -----------------------------------------------------------------------------

(use-package magit  ;; https://github.com/magit/magit
  :after transient
  :bind (("C-c g s" . magit-status))
  :commands (magit-status)
  :ensure t)

(use-package forge  ;; https://github.com/magit/forge
  :after (transient magit)
  :custom
  (forge-database-file
   (expand-file-name "emacs/forge-database.sqlite" (xdg-data-home)))
  :ensure t)

(use-package git-modes  ;; https://github.com/magit/git-modes
  :ensure t)

(use-package diff-hl  ;; https://github.com/dgutov/diff-hl
  :hook (after-init . global-diff-hl-mode)
  :config
  (add-hook 'magit-pre-refresh-hook  #'diff-hl-magit-pre-refresh)
  (add-hook 'magit-post-refresh-hook #'diff-hl-magit-post-refresh)
  :ensure t)

(use-package blamer
  :bind (("C-c g b" . blamer-mode))
  :config
  (setq blamer-idle-time 0.05)
  (setq blamer-author-formatter "%s ")
  (setq blamer-datetime-formatter "[%s]")
  (setq blamer-commit-formatter ": %s")
  (setq blamer-max-commit-message-length 100)
  (setq blamer-min-offset 70)
  :ensure t)

(provide 'myde-core-projects-cfg)
;;; cfg.el ends here
