;;; MyDE is *My* Development Environment. YMMV :-)

;; Store custom settings in separate file.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file)

;; Store backups in separate directory.
(setq backup-directory (expand-file-name "backup" user-emacs-directory)
      backup-directory-alist `(("." . ,backup-directory)))
(make-directory backup-directory :parents)

;; Start of by disabling the splash screen and scratch buffer message.
(setq inhibit-startup-message t
      inhibit-startup-echo-area-message t
      initial-scratch-message nil)

;; Get rid of the scollbar and toolbar in GUI. They take up precious space
;; and one of my goals is to keep my hands on the keyboard, not the mouse.
(when (display-graphic-p)
  (scroll-bar-mode -1)
  (tool-bar-mode -1))

;; Get rid of the menubar in TUI.
(when (not window-system)
  (menu-bar-mode -1))

;; If running on something else other than macOS, get rid of the menubar
;; as well. One thing I like about macOS is that it uses a global app
;; menu that changes with the app.  I wish Linux and Windows did that.
(when (not (string-equal system-type "darwin"))
  (menu-bar-mode -1))

;; Enable display of column numbers in buffer modeline.
(setq column-number-mode t)

;; Highlight current line everywhere.
(global-hl-line-mode 1)

;; Delete region selected when overwriting it.
(delete-selection-mode 1)

;; Enable consistent use of 'y' or 'n' in prompts, never 'yes' or 'no'.
(defalias 'yes-or-no-p 'y-or-n-p)

;; Squelch annoying confirmation if a file or buffer does not exist.
(setq confirm-nonexistent-file-or-buffer nil)

;; Squelch prompt to kill buffer with process attached to it.
(setq kill-buffer-query-functions
      (remq 'process-kill-buffer-query-function kill-buffer-query-functions))

;; Squelch annoying audible bell. Briefly flash the mode line instead.
(defun myde/flash-mode-line ()
  (invert-face 'mode-line)
  (run-with-timer 0.1 nil #'invert-face 'mode-line))

(setq visible-bell nil
      ring-bell-function 'myde/flash-mode-line)

;; Configure terminals.
(set-terminal-coding-system 'utf-8-unix)
(add-hook 'shell-mode-hook (lambda ()
			     (display-line-numbers-mode nil)))

;; Configure recent files.
(require 'recentf)
(recentf-mode t)
(setq recentf-max-saved-items 50)

;; Start emacs server if not running.
(load "server")
(unless (server-running-p) (server-start))

;; Add generic programming language support.
(add-hook 'prog-mode-hook (lambda ()
			    (display-line-numbers-mode t)))

;; Configure package management.
(defvar bootstrap-version)
(let ((bootstrap-file
       (expand-file-name "straight/repos/straight.el/bootstrap.el" user-emacs-directory))
      (bootstrap-version 5))
  (unless (file-exists-p bootstrap-file)
    (with-current-buffer
        (url-retrieve-synchronously
         "https://raw.githubusercontent.com/raxod502/straight.el/develop/install.el"
         'silent 'inhibit-cookies)
      (goto-char (point-max))
      (eval-print-last-sexp)))
  (load bootstrap-file nil 'nomessage))

(straight-use-package 'use-package)
(setq straight-use-package-by-default t)

;; Load theme.
(use-package color-theme-sanityinc-tomorrow
  :config
  (load-theme 'sanityinc-tomorrow-eighties t))

;; Use diminish to squelch excessive noise in the modeline.
(use-package diminish
  :defer 5
  :config
  (diminish 'org-indent-mode))

;; Use which-key for improved discoverability.
(use-package which-key
  :init
  (which-key-mode))

;; Use vterm for terminal sessions.
(use-package vterm)

;; Use vertico for completion support.
(use-package vertico
  :custom
  (vertico-cycle t)
  :init
  (vertico-mode))

;; Use marginalia for richer completion lists.
(use-package marginalia
  :after vertico
  :custom
  (marginalia-annotators (marginalia-annotators-heavy marginalia-annotators-light nil))
  :init
  (marginalia-mode))

;; Save history.
(use-package savehist
  :init
  (savehist-mode))

;; Use magit for git support.
(use-package magit)

;; Use projectile for project support.
(use-package projectile
  :bind-keymap ("C-c p" . projectile-command-map)
  :config
  (projectile-mode 1))

;; Add markdown support.
(use-package markdown-mode
  :commands(markdown-mode gfm-mode)
  :mode (("README\\.md\\'" . gfm-mode)
	 ("\\.md\\'" . markdown-mode)
	 ("\\.markdown\\'" . markdown-mode))
  :init (setq markdown-command "multimarkdown"))

;; ;; Add LSP support.
;; (use-package eglot
;;   :ensure t)
	  
;; Add Golang support.
(use-package go-mode
  :commands go-mode)
  
;; Add REST client support.
(use-package restclient
  :mode (("\\.http\\'" . restclient-mode)))
