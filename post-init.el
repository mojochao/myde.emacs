;;; post-init.el --- Loaded after init.el -*- no-byte-compile: t; lexical-binding: t; -*-

;; Load customizations
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file)(when (file-exists-p (custom-file))
  (load-file (custom-file)))

;; Load myde.el functions
(load-file (expand-file-name "myde.el" user-emacs-directory))

;; -------------------------------
;; Basic UI settings
;; -------------------------------
(setq inhibit-startup-message t
      inhibit-startup-echo-area-message t
      initial-scratch-message nil
      make-backup-files nil)

;; Enable smooth scrolling in GUI.
;; Get rid of the scrollbar and toolbar in GUI. They take up precious space
;; and one of my goals is to keep my hands on the keyboard, not the mouse.
(when (display-graphic-p)
  (pixel-scroll-precision-mode 1)
  (scroll-bar-mode -1)
  (tool-bar-mode -1)
  (set-frame-size (selected-frame) 120 50))

;; Get rid of the menubar in TUI.
(unless (window-system)
  (menu-bar-mode -1))

;; If running on something else other than macOS, get rid of the menubar
;; as well. One thing I like about macOS is that it uses a global app
;; menu that changes with the app.  I wish Linux and Windows did that.
(unless (string-equal system-type "darwin")
  (menu-bar-mode -1))

;; Enable display of column numbers in buffer modeline.
(setq column-number-mode t)

;; Highlight current line everywhere.
(global-hl-line-mode 1)

;; Delete region selected when overwriting it.
(delete-selection-mode 1)

;; Automatically follow links to version controlled files when opening them.
(setq vc-follow-symlinks t)

;; Squelch annoying confirmation if a file or buffer does not exist.
(setq confirm-nonexistent-file-or-buffer nil)

;; Squelch prompt to kill buffer with process attached to it.
(setq kill-buffer-query-functions
      (remq 'process-kill-buffer-query-function kill-buffer-query-functions))

;; Configure terminals.
(set-terminal-coding-system 'utf-8-unix)

;; Configure display of line numbers.
(add-hook 'prog-mode-hook (lambda () (display-line-numbers-mode t)))

;; Store custom settings in separate file.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file)

;; Store backups in separate directory.
(setq backup-directory (expand-file-name "backup" user-emacs-directory)
      backup-directory-alist `(("." . ,backup-directory)))
(make-directory backup-directory :parents)

;; Auto-detect shebang comments and use shell-script-mode appropriately.
(dolist (interp '("bash" "sh" "zsh"))
  (add-to-list 'interpreter-mode-alist (cons interp 'shell-script-mode)))

;; -------------------------------
;; Server setup
;; -------------------------------
(use-package server
  :ensure nil ;; server is built-in, no need to install it
  :hook (after-init . myde/start-server))

;; -------------------------------
;; Package setup
;; -------------------------------
(require 'package)
(setq package-archives
      '(("melpa" . "https://melpa.org/packages/")
        ("gnu"   . "https://elpa.gnu.org/packages/")))
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

;; -------------------------------
;; macOS setup
;; -------------------------------
(use-package emacs
  :if (string= system-type "darwin")
  :ensure nil ; built-in packages are always installed
  :config
  ;; Use GNU version of ls on macOS.
  (setq dired-use-ls-dired t
        insert-directory-program "/usr/local/bin/gls"
        dired-listing-switches "-aBhl --group-directories-first"))

(use-package exec-path-from-shell
  ;; Add shell PATH to exec-path on macOS.
  ;; https://github.com/purcell/exec-path-from-shell
  :if (string-equal system-type "darwin")
  :ensure t
  :config
  (exec-path-from-shell-initialize))

;; -------------------------------
;; Project.el setup
;; -------------------------------
(use-package project
  :ensure nil ; part of emacs now
  :config
  (setq project-switch-use-ido 'both))  ;; Switch to `ido`-style completion for project switching

;; -------------------------------
;; Theme setup
;; -------------------------------
(use-package color-theme-sanityinc-tomorrow
  ;; Configure theme.
  ;; https://github.com/purcell/color-theme-sanityinc-tomorrow
  :ensure t
  :config
  (load-theme 'sanityinc-tomorrow-eighties t))

(use-package diminish
  ;; Keep modeline noise to a minimum
  :ensure t)

;; -------------------------------
;; Discoverability setup
;; -------------------------------
(use-package which-key
  :ensure nil ; part of emacs now
  :init
  (diminish 'which-key-mode)
  (which-key-mode))

(use-package helpful
  ;; Provide better help buffers.
  ;; https://github.com/Wilfred/helpful
  :ensure t
  :bind
  (("C-c C-d" . helpful-at-point)
   ("C-h f" . helpful-callable)
   ("C-h F" . helpful-function)
   ("C-h k" . helpful-key)
   ("C-h v" . helpful-variable)))

;; -------------------------------
;; Terminals setup
;; -------------------------------
(use-package vterm
  ;; Use vterm for a fast, richer terminal emulator.
  ;; https://github.com/akermu/emacs-libvterm
  :ensure t
  :commands vterm)

;; -------------------------------
;; Magit (git) setup
;; -------------------------------
(use-package magit
  :ensure t
  :defer t)

;; -------------------------------
;; Direnv integration
;; -------------------------------
(use-package direnv
  :ensure t
  :config
  (direnv-mode))

;; -------------------------------
;; In-buffer completion (Corfu)
;; -------------------------------
(use-package corfu
  :ensure t
  :custom
  (corfu-auto t)
  (corfu-cycle t)
  :init
  (global-corfu-mode))

;; -------------------------------
;; Minibuffer completion stack
;; -------------------------------
(use-package vertico
  :ensure t
  :init (vertico-mode))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles . (partial-completion))))))

(use-package marginalia
  :ensure t
  :init (marginalia-mode))

(use-package consult
  :ensure t
  :bind (("C-s" . consult-line)
         ("C-x b" . consult-buffer)
         ("M-y" . consult-yank-pop)))

(use-package embark
  :ensure t
  :bind (("C-." . embark-act)
         ("C-h B" . embark-bindings))
  :init
  (setq prefix-help-command #'embark-prefix-help-command))

;; -------------------------------
;; treesit-auto for Tree-sitter setup
;; -------------------------------
(use-package treesit-auto
  :ensure t
  :config
  (setq treesit-auto-install 'prompt) ; install grammars interactively if missing
  (global-treesit-auto-mode))

;; -------------------------------
;; Go programming setup (Tree-sitter)
;; -------------------------------
(use-package go-mode
  :ensure t
  :mode (("\\.go\\'" . go-ts-or-plain-mode))
  :hook ((go-ts-mode . eglot-ensure)
         (go-mode . eglot-ensure)
         (go-mode . goimports-setup))
  :config
  (setq gofmt-command "goimports"))  ;; Use goimports for formatting

(defun go-ts-or-plain-mode ()
  "Use go-ts-mode if Tree-sitter is available, otherwise fall back to go-mode."
  (if (treesit-ready-p 'go)
      (go-ts-mode)
    (go-mode)))

(defun goimports-setup ()
  "Set up `goimports` to run on save for Go files."
  (add-hook 'before-save-hook 'gofmt-before-save nil t))

;; -------------------------------
;; Enable `gopls` (LSP for Go) via Eglot
;; -------------------------------
(use-package eglot
  :ensure t
  :hook ((go-ts-mode . eglot-ensure)
         (go-mode . eglot-ensure)))

;; -------------------------------
;; Markdown editing setup
;; -------------------------------
(use-package markdown-mode
  :ensure t
  :mode("README\\.md\\'" . gfm-mode)
  :init (setq markdown-command "multimarkdown")
  :bind (:map markdown-mode-map ("C-c C-e" . markdown-do)))

;; -------------------------------
;; YAML editing setup
;; -------------------------------
(use-package yaml-mode
  :ensure t
  :defer t)
