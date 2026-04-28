;;; cfg.el --- Projects support configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Package configuration for project management and project tree support:
;;;   projectile + neotree
;;;
;;; Entry point for the core-projects module; loads lib.el automatically.

;;; Code:

(unless (featurep 'myde-core-projects)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Project management
;; -----------------------------------------------------------------------------

(use-package projectile  ;; https://github.com/bbatsov/projectile
  :config
  (projectile-mode +1)
  (setq projectile-project-search-path '("~/Projects/"))
  (setq projectile-known-projects-file
        (expand-file-name "emacs/projectile-bookmarks.eld" (xdg-data-home)))
  :bind (:map projectile-mode-map
              ("s-p"   . projectile-command-map)
              ("C-c p" . projectile-command-map))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Project tree explorer
;; -----------------------------------------------------------------------------

(use-package neotree  ;; https://github.com/jaypei/emacs-neotree
  :bind ([f8] . myde/neotree-project-root-toggle)
  :commands (neotree-toggle)
  :config
  (setq neo-theme (if (display-graphic-p) 'icons 'arrow))
  (setq neo-window-fixed-size nil)
  (add-to-list 'window-size-change-functions #'myde/neotree-window-size-change-function)
  (add-hook 'after-save-hook        #'myde/neotree-refresh)
  (add-hook 'after-delete-file-hook #'myde/neotree-refresh)
  (add-hook 'after-create-file-hook #'myde/neotree-refresh)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Tree-sitter setup
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (setq treesit-extra-load-path
        (list (expand-file-name "emacs/tree-sitter" (xdg-data-home))))
  ;; Language grammar sources are registered by each language module in myde/.
  :ensure nil)

(use-package treesit-auto  ;; https://github.com/renzmann/treesit-auto
  :config
  (setq treesit-auto-install t) ; install grammars automatically, if missing
  (global-treesit-auto-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; LSP support
;; -----------------------------------------------------------------------------

(use-package eglot
  ;; Hooks, server programs, and workspace config are registered by each
  ;; language module in myde/.  Only shared keybindings and performance
  ;; settings live here.
  :bind (:map eglot-mode-map
              ("C-c e a" . eglot-code-actions)
              ("C-c e r" . eglot-rename)
              ("C-c e f" . eglot-format)
              ("C-c e i" . eglot-find-implementation)
              ("C-c e t" . eglot-find-typeDefinition)
              ("C-c e h" . eldoc-box-help-at-point)
              ("C-c e q" . eldoc-box-quit-frame))
  :config
  (setq eglot-autoshutdown t
        eglot-events-buffer-size 0)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Problems reporting support
;; -----------------------------------------------------------------------------

;; Flycheck (on-the-fly syntax checking)
(use-package flycheck  ;; https://github.com/flycheck/flycheck
  :init
  (global-flycheck-mode)
  :config
  (setq flycheck-check-syntax-automatically '(save mode-enabled))
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
  :init
  (setq mason-dir
        (expand-file-name "emacs/mason" (xdg-data-home)))
  :config
  (mason-setup)
  :ensure t)

(use-package mise  ;; https://github.com/eki3z/mise.el
  :ensure t
  :hook (after-init . global-mise-mode))

;; -----------------------------------------------------------------------------
;; Debugger support
;; -----------------------------------------------------------------------------

(use-package dap-mode  ;; https://github.com/emacs-lsp/dap-mode
  :after eglot
  :config
  (dap-auto-configure-mode)  ;; Language-specific DAP adapters are loaded by each language module in myde/prog-*/ module dirs.
  :ensure t)

(use-package dape  ;; https://github.com/svaante/dape
  ;; Lightweight DAP client; debug configs are registered by each language
  ;; module in myde/.  Only shared keybindings and layout settings live here.
  :ensure t
  :config
  (setq dape-buffer-window-arrangement 'right)
  :bind (("C-c d d" . dape)
         ("C-c d l" . dape-last)
         ("C-c d b" . dape-breakpoint-toggle)
         ("C-c d n" . dape-next)
         ("C-c d s" . dape-step-in)
         ("C-c d o" . dape-step-out)
         ("C-c d c" . dape-continue)
         ("C-c d q" . dape-quit)))

;; -----------------------------------------------------------------------------
;; Git version control setup
;; -----------------------------------------------------------------------------

(use-package magit  ;; https://github.com/magit/magit
  :commands (magit-status)
  :ensure t)

(use-package forge  ;; https://github.com/magit/forge
  :after magit
  :ensure t)


(provide 'myde-core-projects-cfg)
;;; cfg.el ends here
