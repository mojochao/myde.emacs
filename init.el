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

;; If running on something else other than macOS, get rid of the menubar
;; as well. One thing I like about macOS is that it uses a global app
;; menu that changes with the app.  I wish Linux and Windows did that.
(when (not (string-equal system-type "darwin"))
  (menu-bar-mode -1))

;; Enable display of column numbers in buffer modeline.
(setq column-number-mode t)

;; Highlight current line everywhere.
(global-hl-line-mode 1)

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

;; Configure package management.
(require 'package)
(setq package-enable-at-startup nil)
(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))
(add-to-list 'package-archives '("gnu" . "http://elpa.gnu.org/packages/"))
(package-initialize)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(eval-when-compile
  (require 'use-package))

;; Load theme.
(use-package color-theme-sanityinc-tomorrow
  :ensure t
  :config
  (load-theme 'sanityinc-tomorrow-eighties t))

;; Do not show some common modes in the modeline, to save space.
(use-package diminish
  :defer 5
  :config
  (diminish 'org-indent-mode))

;; Add completion support.
(use-package helm
  :ensure t
  :bind (("M-x" . helm-M-x)
	 ("C-x C-b" . helm-buffers-list)
	 ("C-x C-f" . helm-find-files)
	 ("C-x C-r" . helm-recentf)
	 ("C-x C-m" . helm-mini))
  :config
  (helm-mode 1)
  (setq helm-completion-style 'helm-fuzzy))

;; Add project support.
(use-package projectile
  :ensure t
  :bind-keymap ("C-c p" . projectile-command-map)
  :config
  (projectile-mode 1))

;; Add LSP support.
(use-package eglot
  :ensure t)

;; Add generic programming language support.
(add-hook 'prog-mode-hook (lambda ()
			    (display-line-numbers-mode t)))
	  
;; Add Golang support.
(use-package go-mode
  :commands go-mode
  :ensure t)
  
