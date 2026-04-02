;;; post-init.el --- Loaded after init.el -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; I like cleaner diffs so my `use-package` macro practice here is to place the
;;; closing paren of the form on its own line.

;;; Code:

;; Load customizations
(let* ((path (expand-file-name "custom.el" user-emacs-directory))
       (exists (file-exists-p path)))
  (setq custom-file path)
  (when exists
    (load-file custom-file)))

;; Load myde.el functions
(load-file (expand-file-name "myde.el" user-emacs-directory))

;; -----------------------------------------------------------------------------
;; Basic UI settings
;; -----------------------------------------------------------------------------
(setq inhibit-startup-message t
      inhibit-startup-echo-area-message t
      initial-scratch-message nil
      make-backup-files nil
      mode-line-collapse-minor-modes t)

;; Enable smooth scrolling in GUI.
;; Get rid of the scrollbar and toolbar in GUI. They take up precious space
;; and one of my goals is to keep my hands on the keyboard, not the mouse.
(when (display-graphic-p)
  (pixel-scroll-precision-mode 1)
  (scroll-bar-mode -1)
  (tool-bar-mode -1)
  (set-frame-size (selected-frame) 120 50))

;; Disable the menubar in TUI (on any OS) or GUI (only on macOS).
;; One thing I like about Emacs GUI app on macOS is that it uses a global app
;; menu that changes with the app, so leave it alone in that case.
(unless (and (display-graphic-p) (string-equal system-type "darwin"))
  (menu-bar-mode -1))

;; Swap option and command keys on macOS to match Linux keyboard layout.
(when (and (display-graphic-p) (string-equal system-type "darwin"))
  (setq mac-command-modifier 'meta
        mac-option-modifier 'super))

;; Blink cursor.
(blink-cursor-mode 1)

;; Enable display of column numbers in buffer modeline.
(setq column-number-mode t)

;; Auto-revert buffer on changes to files on disk.
(global-auto-revert-mode 1)

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
(add-hook 'prog-mode-hook (lambda ()
                            (display-line-numbers-mode t)
                            (hl-line-mode t)))
(add-hook 'prog-mode-hook #'myde/delete-trailing-whitespace-setup)

;; Store custom settings in separate file.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file)

;; Store backups in separate directory.
;; TODO: switch to let* form
(setq backup-directory (expand-file-name "backup" user-emacs-directory)
      backup-directory-alist `(("." . ,backup-directory)))
(make-directory backup-directory :parents)

;; Auto-detect shebang comments and use shell-script-mode appropriately.
(dolist (interp '("bash" "sh" "zsh"))
  (add-to-list 'interpreter-mode-alist (cons interp 'shell-script-mode)))

;; -----------------------------------------------------------------------------
;; Package setup
;; -----------------------------------------------------------------------------
(require 'package)
(setq package-archives
      '(("melpa"  . "https://melpa.org/packages/")
        ("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
(unless package-archive-contents
  (package-refresh-contents))

;; -----------------------------------------------------------------------------
;; macOS-specific setup
;; -----------------------------------------------------------------------------

(use-package emacs
  :ensure nil ; built-in packages are always installed
  :if (string= system-type "darwin")
  :config
  ;; Use GNU version of ls on macOS.
  ;; TODO: switch to let* form
  (setq dired-use-ls-dired t
        insert-directory-program "/usr/local/bin/gls"  ; where homebrew install places it on macOS
        dired-listing-switches "-aBhl --group-directories-first")
  ;; end of emacs package config for macOS
  )

(use-package exec-path-from-shell
  ;; https://github.com/purcell/exec-path-from-shell
  ;; Add shell PATH to exec-path.
  :ensure t
  :config
  (exec-path-from-shell-initialize)
  ;; end of exec-path-from-shell package config
  )

;; -----------------------------------------------------------------------------
;; Elisp programming support packages
;; -----------------------------------------------------------------------------

(use-package cask-mode
  ;; https://github.com/Wilfred/cask-mode
  ;; Major mode for editing cask files
  :ensure t
  ;; end of cask-mode package config
  )

(use-package dash
  ;; https://github.com/magnars/dash.el
  ;; A modern list API for Emacs. No 'cl required.
  :ensure t
  ;; end of dash package config
  )

(use-package s
  ;; https://github.com/magnars/s.el
  ;; The long lost Emacs string manipulation library.
  :ensure t
  ;; end of s package config
  )

(use-package seq
  ;; https://elpa.gnu.org/packages/seq.html
  ;; Sequence manipulation functions.
  :ensure t
  ;; end of seq package config
  )

(use-package plz
  ;; https://github.com/alphapapa/plz.el
  ;; An HTTP library for Emacs.
  :ensure t
  ;; end of plz package config
  )

;; -----------------------------------------------------------------------------
;; Splash screen/Dashboard support
;; -----------------------------------------------------------------------------

(use-package dashboard
  ;; https://github.com/emacs-dashboard/emacs-dashboard
  ;; A pretty dashboard buffer.
  :ensure t
  :custom
  (dashboard-projects-backend 'projectile)
  (dashboard-items '((recents . 5)
                    (projects . 5)
                    (bookmarks . 5)
                    (agenda . 5)))
  :config
  (dashboard-setup-startup-hook)
;; TODO: switch to let* form
  (setq myde-banner-image-file (expand-file-name "myde-banner.png" user-emacs-directory))
  (setq myde-banner-text-file (expand-file-name "myde-banner.txt" user-emacs-directory))
  (setq dashboard-startup-banner (cons myde-banner-image-file myde-banner-text-file))
  (setq dashboard-banner-logo-title "Welcome to MyDE -- *MY* Development Environment!")
  (setq dashboard-display-icons-p t)
  (setq dashboard-icon-type 'nerd-icons)
  (setq dashboard-set-heading-icons t)
  (setq dashboard-set-file-icons t)
  ;; end of dashboard package config
  )

(use-package recentf
  ;; Activate recentf to track recently opened files
  :ensure nil
  :commands (recentf-mode recentf-cleanup)
  :config
  (recentf-mode t)
  (setq recentf-auto-cleanup (if (daemonp) 300 'never))
  (setq recentf-exclude
        '("^/tmp/" "^/ssh:" "/COMMIT_EDITMSG\\'"
          "/bookmarks" "/info/" "/diary$" "/\\.elpa/"))
  (add-hook 'kill-emacs-hook #'recentf-cleanup -90)
  ;; end of recentf package config
  )

(use-package buffer-guardian
  ;; https://github.com/jamescherti/buffer-guardian.el
  ;; Save buffers when their focus is lost.
  :ensure t
  :custom
  ;; When non-nil, include remote files in the auto-save process
  (buffer-guardian-inhibit-saving-remote-files t)

  ;; When non-nil, buffers visiting nonexistent files are not saved
  (buffer-guardian-inhibit-saving-nonexistent-files nil)

  ;; Save the buffer even if the window change results in the same buffer
  (buffer-guardian-save-on-same-buffer-window-change t)

  ;; Non-nil to enable verbose mode to log when a buffer is automatically saved
  (buffer-guardian-verbose nil)

  ;; Save all buffers after N seconds of user idle time. (Disabled by default)
  ;; (buffer-guardian-save-all-buffers-idle 30)

  :hook
  (after-init . buffer-guardian-mode)
  ;; end of buffer-guardian package config
  )

;; -----------------------------------------------------------------------------
;; UI quality of life improvements
;; -----------------------------------------------------------------------------

(use-package spacious-padding
  ;; https://github.com/protesilaos/spacious-padding
  ;; Give the UI space to breathe.
  :ensure t
  :config
  (spacious-padding-mode 1)
  ;; end of spacious-padding package config
  )

;; -----------------------------------------------------------------------------
;; Icons support
;; -----------------------------------------------------------------------------

(use-package all-the-icons
  ;; https://github.com/domtronn/all-the-icons.el
  :ensure t
  :if (display-graphic-p)
  ;; end of all-the-icons package config
  )

(use-package nerd-icons
  ;; https://github.com/rainstormstudio/nerd-icons.el
  :ensure t
  ;; :custom
  ;; The Nerd Font you want to use in GUI
  ;; "Symbols Nerd Font Mono" is the default and is recommended
  ;; but you can use any other Nerd Font if you want
  ;; (nerd-icons-font-family "Symbols Nerd Font Mono")

  ;; end of nerd-icons package config
  )

;; -----------------------------------------------------------------------------
;; Fonts support
;; -----------------------------------------------------------------------------

(use-package show-font
  ;; https://github.com/protesilaos/show-font
  ;; Preview fonts.
  :ensure t
  :bind
  (("C-c s f" . show-font-select-preview)
   ("C-c s t" . show-font-tabulated))
  ;; end of show-font package config
  )

;; -----------------------------------------------------------------------------
;; Themes support
;; -----------------------------------------------------------------------------

(use-package easy-theme-preview
  ;; https://github.com/ayys/easy-theme-preview.el
  ;; Preview and manage themes.
  :ensure t
  ;; end of easy-theme-preview package config
  )

(use-package color-theme-sanityinc-tomorrow
  ;; https://github.com/purcell/color-theme-sanityinc-tomorrow
  :ensure t
  ;; end of color-theme-sanityinc-tomorrow package config
  )

(use-package doom-themes
  ;; https://github.com/doomemacs/themes
  :ensure t
  :custom
  ;; Global settings (defaults)
  (doom-themes-enable-bold t)   ; if nil, bold is universally disabled
  (doom-themes-enable-italic t) ; if nil, italics is universally disabled
  ;; for treemacs users
  (doom-themes-treemacs-theme "doom-atom") ; use "doom-colors" for less minimal icon theme
  :config
  ;; Enable flashing mode-line on errors
  (doom-themes-visual-bell-config)
  ;; Enable custom neotree theme (nerd-icons must be installed!)
  (doom-themes-neotree-config)
  ;; or for treemacs users
  (doom-themes-treemacs-config)
  ;; Corrects (and improves) org-mode's native fontification.
  (doom-themes-org-config)
  ;; end of doom-themes package config
  )

(use-package ef-themes
  ;; https://github.com/protesilaos/ef-themes
  :ensure t
  ;; end of ef-themes package config
  )

(use-package jetbrains-darcula-theme
  ;; https://github.com/ianyepan/jetbrains-darcula-emacs-theme
  :ensure t
  ;; end of jetbrains-darcula-theme package config
  )

(use-package gnome-dark-style
  ;; https://github.com/dimagid/gnome-dark-style
  ;; Sync theme with Gnome Desktop on Linux.
  :ensure t
  :if (string-equal system-type "gnu/linux")
  :after doom-themes
  :custom
  (gnome-light-theme 'doom-tomorrow-day)
  (gnome-dark-theme 'doom-spacegrey)
  :config
  (setopt gnome-dark-style-sync t)
  ;; end of gnome-dark-style package config
  )

;; -----------------------------------------------------------------------------
;; Projects support
;; -----------------------------------------------------------------------------

(use-package projectile
  ;; https://github.com/bbatsov/projectile
  ;; A featureful project interaction library.
  :ensure t
  :config
  (projectile-mode +1)
  (setq projectile-project-search-path '("~/Projects/"))
  :bind (:map projectile-mode-map
              ("s-p" . projectile-command-map)
              ("C-c p" . projectile-command-map))
  ;; end of projectile package config
  )

;; -----------------------------------------------------------------------------
;; Project tree explorer support
;; -----------------------------------------------------------------------------

(use-package neotree
  ;; https://github.com/jaypei/emacs-neotree
  :ensure t
  :bind ([f8] . myde/neotree-project-root-toggle)
  :commands (neotree-toggle)
  :config
  (setq neo-theme (if (display-graphic-p) 'icons 'arrow))
  (setq neo-window-fixed-size nil)
  ;; remember mouse-dragged width
  (add-to-list 'window-size-change-functions
               (lambda (frame)
                 (let ((neo-window (neo-global--get-window)))
                   (unless (null neo-window)
                     (setq neo-window-width (window-width neo-window))))))
  (defun myde/neotree-refresh ()
    "Refresh neotree if visible."
    (when (neo-global--window-exists-p)
      (neo-buffer--refresh)))
  (add-hook 'after-save-hook #'myde/neotree-refresh)
  (add-hook 'after-delete-file-hook #'myde/neotree-refresh)
  (add-hook 'after-create-file-hook #'myde/neotree-refresh)
  ;; end of neotree package config
  )

;; -----------------------------------------------------------------------------
;; Miscellaneous quality-of-life improvements
;; -----------------------------------------------------------------------------

(global-set-key [remap keyboard-quit] #'myde/keyboard-quit)

(use-package expreg
  ;; https://github.com/casouri/expreg
  :ensure t
  :bind (("C-=" . expreg-expand)
         ("C--" . expreg-contract))
  ;; end of expreg package config
  )

(use-package surround
  ;; https://github.com/mkleehammer/surround
  ;; https://emacsredux.com/blog/2026/03/17/surround-el-vim-style-pair-editing-comes-to-emacs/
  ;; Insert, change, and delete surrounding pairs.
  :ensure t
  :bind-keymap ("M-'" . surround-keymap)
  ;; end of expreg package config
  )

(use-package multiple-cursors
  ;; https://github.com/magnars/multiple-cursors.el
  :ensure t
  :bind (("C-S-c C-S-c" . mc/edit-lines)        ;; edit multiple lines
         ("C->"         . mc/mark-next-like-this)   ;; add next match
         ("C-<"         . mc/mark-previous-like-this) ;; add previous match
         ("C-c C-<"     . mc/mark-all-like-this))   ;; mark all matches
  :config
  ;; Sensible defaults
  (setq mc/list-file (locate-user-emacs-file "mc-lists.el"))
  ;; Make cursor movement more predictable
  (setq mc/always-run-for-all t)
  ;; end of multiple-cursors package config
  )

(use-package whole-line-or-region
  ;; https://github.com/purcell/whole-line-or-region
  :ensure t
  :config
  (whole-line-or-region-global-mode)
  ;; end of whole-line-or-region package config
  )

(use-package pathaction
  ;; https://www.jamescherti.com/pathaction-el-emacs-package-universal-makefile/
  :ensure t
  :config
  (add-to-list 'display-buffer-alist '("\\*pathaction:"
                                       (display-buffer-at-bottom)
                                       (window-height . 0.33)))
  ;; end of pathaction package config
  )

;; -----------------------------------------------------------------------------
;; Discoverability setup
;; -----------------------------------------------------------------------------

(use-package which-key
  :ensure nil ; part of emacs since v29
  :init
  (diminish 'which-key-mode)
  (which-key-mode)
  ;; end of which-key package config
  )

(use-package helpful
  ;; Provide better help buffers.
  ;; https://github.com/Wilfred/helpful
  :ensure t
  :bind
  (("C-c C-d" . helpful-at-point)
   ("C-h f" . helpful-callable)
   ("C-h F" . helpful-function)
   ("C-h k" . helpful-key)
   ("C-h v" . helpful-variable))
  ;; end of helpful package config
  )

;; -----------------------------------------------------------------------------
;; Terminals setup
;; -----------------------------------------------------------------------------

(use-package eat
  ;; https://codeberg.org/akib/emacs-eat
  :ensure t
  ;; end of eat package config
  )

(use-package vterm
  ;; https://github.com/akermu/emacs-libvterm
  ;; Use vterm for a fast, richer terminal emulator.
  :ensure t
  :commands
  (vterm)
  :config
  ;; Disable hl-line-mode in all terminal-like modes
  (setq global-hl-line-modes
        '(not vterm-mode term-mode eshell-mode ansi-term-mode comint-mode))
  ;; end of vterm package config
  )

;; -----------------------------------------------------------------------------
;; Version control setup
;; -----------------------------------------------------------------------------

(use-package magit
  ;; https://github.com/magit/magit
  :ensure t
  :commands (magit-status)
  ;; end of magit package config
  )

(use-package forge
  ;; https://github.com/magit/forge
  :ensure t
  :after magit
  ;; end of forge package config
  )

(use-package gptel-forge-prs
  ;; https://github.com/ArthurHeymans/gptel-forge-prs
  :ensure t
  :after forge
  :config
  (gptel-forge-prs-install)
  ;; end of gptel-forge-prs package config
  )

(use-package gptel-magit
  ;; https://github.com/ragnard/gptel-magit
  :ensure t
  :after magit
  :hook (magit-mode . gptel-magit-install)
  ;; end of gptel-magit package config
  )

;; -----------------------------------------------------------------------------
;; Direnv integration
;; -----------------------------------------------------------------------------

(use-package direnv
  ;; https://github.com/wbolster/emacs-direnv
  :ensure t
  :config
  (direnv-mode)
  ;; end of direnv package config
  )

;; -----------------------------------------------------------------------------
;; In-buffer completion (Corfu)
;; -----------------------------------------------------------------------------

(use-package corfu
  ;; https://github.com/minad/corfu
  :ensure t
  :custom
  (corfu-auto t)
  (corfu-cycle t)
  :init
  (global-corfu-mode)
  ;; end of corfu package config
  )

;; -----------------------------------------------------------------------------
;; Minibuffer completion stack
;; -----------------------------------------------------------------------------

(use-package vertico
  ;; https://github.com/minad/vertico
  :ensure t
  :init
  (vertico-mode)
  ;; end of vertico package config
  )

(use-package orderless
  ;; https://github.com/oantolin/orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-pcm-leading-wildcard t)
  (completion-category-overrides '((file (styles . (partial-completion)))))
  ;; end of orderless package config
  )

(use-package marginalia
  ;; https://github.com/minad/marginalia
  :ensure t
  :init
  (marginalia-mode)
  ;; end of marginalia package config
  )

(use-package consult
  ;; https://github.com/minad/consult
  :ensure t
  :bind (("C-s" . consult-line)
         ("C-x b" . consult-buffer)
         ("C-x C-b" . consult-buffer)
         ("M-y" . consult-yank-pop))
  ;; end of consult package config
  )

(global-set-key (kbd "C-x C-b") #'consult-buffer)

(use-package embark
  ;; https://github.com/oantolin/embark
  :ensure t
  :bind (("C-." . embark-act)
         ("C-h B" . embark-bindings))
  :init
  (setq prefix-help-command #'embark-prefix-help-command)
  ;; end of embark package config
  )

(use-package embark-consult
  :ensure t ; only need to install it, embark loads it after consult if found
  :hook (embark-collect-mode . consult-preview-at-point-mode)
  ;; end of embark-consult package config
  )

;; -----------------------------------------------------------------------------
;; treesit-auto for Tree-sitter setup
;; -----------------------------------------------------------------------------

;; Install Tree-sitter grammar if missing
(use-package treesit
  :ensure nil ; part of emacs since v29
  :config
  (add-to-list 'treesit-language-source-alist
               '(hcl "https://github.com/tree-sitter-grammars/tree-sitter-hcl")
               '(elixir "https://github.com/elixir-lang/tree-sitter-elixir")
               '(heex "https://github.com/phoenixframework/tree-sitter-heex"))
  )

(use-package treesit-auto
  ;; https://github.com/renzmann/treesit-auto
  :ensure t
  :config
  (setq treesit-auto-install t) ; install grammars automatically, if missing
  (global-treesit-auto-mode)
  ;; end of treesit-auto package config
  )

;; =============================================================================
;; External brain support.
;; =============================================================================

;; -----------------------------------------------------------------------------
;; I use org to manage my thoughts and actions.
;; -----------------------------------------------------------------------------

(defvar myde/org-directory "~/org/")

(use-package org
  ;; https://orgmode.org
  ;; My life in plain text.
  :ensure nil ;; built-in package
  :hook
  (org-mode . visual-line-mode)
  :custom
  (org-directory myde/org-directory)
  (org-return-follows-link t)
  ;; end of org package config
  )

;; -----------------------------------------------------------------------------
;; I capture general thoughts with denote.
;; -----------------------------------------------------------------------------

(defvar myde/denote-directory "~/org/notes/")

(use-package denote
  ;; https://protesilaos.com/emacs/denote
  ;; Simple notes with an efficient file-naming scheme.
  :ensure t
  :bind
  (("C-c d n" . denote)
   ("C-c d l" . denote-link)
   ("C-c d b" . denote-backlinks)
   ("C-c d f" . denote-open-or-create)
   ("C-c d s" . denote-search))
  :custom
  (denote-directory myde/denote-directory)
  (denote-infer-keywords t)
  (denote-sort-keywords t)
  (denote-known-keywords
   '("paper"
     "book"
     "research"
     "distributed-systems"
     "kubernetes"
     "consensus"
     "raft"))
  ;; end of denote package config
  )

;; -----------------------------------------------------------------------------
;; Reading and research support.
;;
;; Ebook formats supported include PDF and ePub files.
;; Reading notes and highlighting are captured as org files.
;; -----------------------------------------------------------------------------

(defvar myde/reading-notes "~/org/reading/")
(defvar myde/highlight-file "~/org/highlights.org")

(defun myde/reading-setup ()
  "Improve readability for long-form documents."
  (visual-line-mode 1)
  (setq-local line-spacing 0.15))

(defun myde/reading-keybindings ()
  "Unified navigation keys across readers."
  (local-set-key (kbd "i") #'org-noter)
  (local-set-key (kbd "n") #'org-noter-insert-note)
  (local-set-key (kbd "h") #'org-remark-mark)
  (local-set-key (kbd "j") #'org-noter-sync-next-note)
  (local-set-key (kbd "k") #'org-noter-sync-prev-note))

(use-package pdf-tools
  ;; https://github.com/vedang/pdf-tools
  ;; PDF reader
  :ensure t
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :init
  ;; Better defaults for large technical PDFs
  (setq pdf-view-display-size 'fit-width
        pdf-view-resize-factor 1.1)
  :config
  ;; Compile/install epdfinfo server automatically
  (pdf-tools-install)
  ;; Improve rendering responsiveness
  (setq pdf-view-use-scaling t
        pdf-view-use-imagemagick nil)
  ;; Keybindings for navigation and annotation
  (define-key pdf-view-mode-map (kbd "C-s") #'isearch-forward)
  (define-key pdf-view-mode-map (kbd "h") #'pdf-annot-add-highlight-markup-annotation)
  (define-key pdf-view-mode-map (kbd "t") #'pdf-annot-add-text-annotation)

  ;; Continuous scrolling
  (setq pdf-view-continuous t)
  ;; end of pdf-tools package config
  )

(use-package nov
  ;; https://depp.brause.cc/nov.el
  ;; Epub reader
  :ensure t
  :mode ("\\.epub\\'" . nov-mode)
  :hook
  ((nov-mode . visual-line-mode)
   (nov-mode . variable-pitch-mode))
  :init
  (setq nov-text-width 80)
  ;; end of nov package config
  )

;; -----------------------------------------------------------------------------
;; LSP support
;; -----------------------------------------------------------------------------

(use-package eglot
  :ensure nil ; part of emacs since v29
  :hook ((go-ts-mode . eglot-ensure)
         (go-mode . eglot-ensure)
         (elixir-ts-mode . eglot-ensure)
         (heex-ts-mode . eglot-ensure))
  :config
  ;; Configure ElixirLS for Elixir and HEEx modes
  ;; TODO move these to the config of their respective packages
  (add-to-list 'eglot-server-programs
               '(elixir-ts-mode "/home/linuxbrew/.linuxbrew/Cellar/elixir-ls/0.30.0/libexec/language_server.sh"))
  (add-to-list 'eglot-server-programs
               '(heex-ts-mode "/home/linuxbrew/.linuxbrew/Cellar/elixir-ls/0.30.0/libexec/language_server.sh"))
  ;; end of eglot package config
  )

;; -----------------------------------------------------------------------------
;; Environment files
;; -----------------------------------------------------------------------------

(use-package dotenv-mode
  :ensure t
  :mode (("\\.env\\'" . dotenv-mode)
         ("\\.envrc\\'" . dotenv-mode))
  ;; end of dotenv-mode package config
  )

;; -----------------------------------------------------------------------------
;; Golang setup
;; -----------------------------------------------------------------------------

(use-package go-mode
  ;; https://github.com/dominikh/go-mode.el
  :ensure t
  :mode (("\\.go\\'" . myde/go-ts-or-plain-mode))
  :hook ((go-ts-mode . eglot-ensure)
         (go-mode . eglot-ensure)
         (go-mode . myde/goimports-setup))
  :config
  (setq gofmt-command "goimports")
  ;; end of go-mode package config
  )

;; -----------------------------------------------------------------------------
;; Flycheck (on-the-fly syntax checking)
;; -----------------------------------------------------------------------------

(use-package flycheck
  ;; https://github.com/flycheck/flycheck
  ;; https://www.flycheck.org/
  :ensure t
  :init
  (global-flycheck-mode)
  :config
  (setq flycheck-check-syntax-automatically '(save mode-enabled))
  ;; end of flycheck package config
  )

;; -----------------------------------------------------------------------------
;; Snippets setup
;; -----------------------------------------------------------------------------

(use-package yasnippet
  ;; https://github.com/joaotavora/yasnippet
  ;; A snippet template system.
  :ensure t
  :diminish yas-minor-mode
  :config
  (setq yas-snippet-dirs (cons (expand-file-name "snippets" user-emacs-directory)
                               yas-snippet-dirs))
  (yas-global-mode 1)
  (setq yas-trigger-key "TAB")
  ;; end of yasnippet package config
  )

(use-package yasnippet-classic-snippets
  ;; https://elpa.gnu.org/packages/yasnippet-classic-snippets.html
  ;; Snippets that were previously shipped with the GNU ELPA yasnippet package.
  :ensure t
  ;; end of yasnippet-classic-snippets package config
  )

;; -----------------------------------------------------------------------------
;; Elixir + Phoenix setup
;; -----------------------------------------------------------------------------

(use-package elixir-ts-mode
  ; Major mode using Treesitter for fontification, navigation and indentation of
  ; Elixir files.
  :ensure nil ; built-in (Emacs 30.1+)
  :mode (("\\.ex\\'" . elixir-ts-mode)
         ("\\.exs\\'" . elixir-ts-mode)
         ("\\.heex\\'" . elixir-ts-mode))
  :hook ((elixir-ts-mode . eglot-ensure)
         (elixir-ts-mode . myde/elixir-ts-ensure-grammars)
         (elixir-ts-mode . flycheck-mode)
         (elixir-ts-mode . myde/delete-trailing-whitespace-setup)
         (elixir-ts-mode . yas-minor-mode))
  :config
  (defun myde/elixir-ts-ensure-grammars ()
    "Ensure Elixir and HEEx tree-sitter grammars are installed."
    (dolist (lang '(elixir heex))
      (unless (treesit-ready-p lang t)
        (message "Installing %s tree-sitter grammar..." lang)
        (treesit-install-language-grammar lang))))
  ;; end of elixir-ts-mode package config
  )

(use-package heex-ts-mode
  ;; https://github.com/wkirschbaum/heex-ts-mode
  ;; Major mode using Treesitter for fontification, navigation and indentation
  ;; of heex files used by Phoenix and LiveView templates.
  :ensure t
  :after elixir-ts-mode
  :mode ("\\.heex\\'" . heex-ts-mode)
  :hook ((heex-ts-mode . eglot-ensure)
         (heex-ts-mode . myde/delete-trailing-whitespace-setup)
         (heex-ts-mode . yas-minor-mode))
  ;; end of heex-ts-mode package config
  )

;; Elixir test runner
(use-package exunit
  ;; https://github.com/ananthakumaran/exunit.el
  ;; Emacs ExUnit test runner.
  :ensure t
  :after elixir-ts-mode
  :hook (elixir-ts-mode . exunit-mode)
  :bind
  (:map exunit-mode-map
              ("C-c t a" . exunit-verify-all)
              ("C-c t s" . exunit-verify-single)
              ("C-c t t" . exunit-toggle-file-and-test))
  ;; end of exunit package config
  )

;; IEx REPL integration
(use-package inf-elixir
  ;; https://github.com/J3RN/inf-elixir
  ;; Emacs plugin for interacting with elixir `ielm` REPLs
  :ensure t
  :after elixir-ts-mode
  :bind (:map elixir-ts-mode-map
              ("C-c i i" . inf-elixir)
              ("C-c i p" . inf-elixir-project)
              ("C-c i l" . inf-elixir-send-line)
              ("C-c i r" . inf-elixir-send-region)
              ("C-c i b" . inf-elixir-send-buffer))
  ;; end of exunit package config
  )

(use-package flycheck-credo
  ;; https://github.com/aaronjensen/flycheck-credo
  ;; Credo linting via Flycheck.
  :ensure t
  :after flycheck
  :config
  (flycheck-credo-setup)
  (setq flycheck-elixir-credo-strict t)
  ;; end of flycheck-credo package config
  )

(use-package flycheck-dialyxir
  ;; https://github.com/aaronjensen/flycheck-dialyxir
  ;; Dialyzer analysis via Flycheck.
  :ensure t
  :after flycheck
  :config
  (flycheck-dialyxir-setup)
  ;; end of flycheck-dialyzer package config
  )

(use-package mix
  ;; https://github.com/ayrat555/mix.el
  :ensure t
  :after elixir-ts-mode
  :hook ((elixir-ts-mode . mix-minor-mode))
  ;; end of mix package config
  )

;; -----------------------------------------------------------------------------
;; DAP debugger support
;; -----------------------------------------------------------------------------

(use-package dap-mode
  ;; https://github.com/emacs-lsp/dap-mode
  ;; Emacs Debug Adapter Protocol (DAP) support
  :ensure t
  :after eglot
  :config
  (dap-auto-configure-mode)
  ;; ElixirLS DAP support
  (require 'dap-elixir)
  ;; end of dap-mode package config
  )

;; -----------------------------------------------------------------------------
;; Markdown editing setup
;; -----------------------------------------------------------------------------

(use-package markdown-mode
  ;; https://github.com/jrblevin/markdown-mode
  ;; Major mode for editing markdown files.
  :ensure t
  :mode (("\\.md\\'" . gfm-mode)
         ("README\\.md\\'" . gfm-mode))
  :hook ((markdown-mode . display-line-numbers-mode)
         (markdown-mode . myde/delete-trailing-whitespace-setup))
  :bind (:map markdown-mode-map ("C-c C-e" . markdown-do))
  :init
  (setq markdown-command "multimarkdown")
  ;; end of markdown-mode package config
  )

;; -----------------------------------------------------------------------------
;; Terraform support
;; -----------------------------------------------------------------------------

(use-package terraform-mode
  ;; https://github.com/hcl-emacs/terraform-mode
  :ensure t
  :mode ("\\.tf\\'" "\\.tfvars\\'")
  :hook ((terraform-mode . terraform-format-on-save-mode))
  :config
  (defun terraform-format-buffer ()
    "Format the current buffer with terraform fmt."
    (interactive)
    (when (executable-find "terraform")
      (call-process-region (point-min) (point-max) "terraform" t t nil "fmt" "-")))

  (define-minor-mode terraform-format-on-save-mode
    "Auto-format Terraform buffer on save using terraform fmt."
    :lighter " fmt"
    (if terraform-format-on-save-mode
        (add-hook 'before-save-hook #'terraform-format-buffer nil t)
      (remove-hook 'before-save-hook #'terraform-format-buffer t)))
  ;; end of terraform-mode package config
  )

;; Tree-sitter remap: only after HCL grammar is installed
(when (and (fboundp 'treesit-available-p)
           (treesit-available-p)
           (treesit-language-available-p 'hcl))
  (add-to-list 'major-mode-remap-alist
               '(terraform-mode . terraform-ts-mode)))

;; -----------------------------------------------------------------------------
;; YAML editing setup
;; -----------------------------------------------------------------------------

(use-package yaml-mode
  ;; https://github.com/yoshiki/yaml-mode
  ;; Major mode for editing yaml documents.
  :ensure t
  :mode (("\\.yaml\\'" . yaml-mode)
         ("\\.yml\\'" . yaml-mode))
  ;; end of yaml-mode package config
  )

;; =============================================================================
;; AI LLM and Agent support.
;; =============================================================================

;; -----------------------------------------------------------------------------
;; Claude code integration
;; -----------------------------------------------------------------------------

(use-package claude-code-ide
  ;; https://github.com/manzaltu/claude-code-ide.el
  ;; Claude Code IDE integration for Emacs.
  :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :rev :newest)
  :bind ("C-c c" . claude-code-ide-menu) ; Set your favorite keybinding
  :config
  (claude-code-ide-emacs-tools-setup) ; Optionally enable Emacs MCP tools
  ;; end of claude-code-ide package config
  )

(defvar myde/openrouter-models
  '(anthropic/claude-haiku-4.5
    anthropic/claude-opus-4.5
    anthropic/claude-opus-4.6
    anthropic/claude-sonnet-4.5
    anthropic/claude-sonnet-4.6
    deepseek/deepseek-v3.2
    google/gemini-2.5-flash
    google/gemini-2.5-flash-lite
    google/gemini-3-flash-preview
    google/gemini-3-pro-image-preview
    google/gemini-3-pro-preview
    minimax/minimax-m2.1
    minimax/minimax-m2.5
    mistralai/codestral-embed-2505
    mistralai/devstral-2512
    mistralai/ministral-14b-2512
    mistralai/mistral-large-2512
    moonshotai/kimi-k2
    moonshotai/kimi-k2-thinking
    moonshotai/kimi-k2.5
    openai/gpt-5.2
    openai/gpt-5.2-codex
    openai/gpt-5.2-pro
    openrouter/free
    qwen/qwen3-coder-next
    qwen/qwen3-max-thinking
    x-ai/grok-4.1-fast
    x-ai/grok-code-fast-1
    z-ai/glm-4.7
    z-ai/glm-4.7-flash
    z-ai/glm-5))

(use-package gptel
  ;; https://github.com/karthink/gptel
  ;; A simple, extensible LLM client for Emacs
  :ensure t
  :config
  (gptel-make-openai "OpenRouter"
    :host "openrouter.ai"
    :endpoint "/api/v1/chat/completions"
    :stream t
    :key (myde/gptel-api-key-from-environment "OPENROUTER_API_KEY")
    :models myde/openrouter-models)
  (setq gptel-model 'moonshotai/kimi-k2.5
        gptel-backend (gptel-get-backend "OpenRouter"))
  ;; end of gptel package config
  )

(use-package minuet
  ;; https://github.com/milanglacier/minuet-ai.el
  ;; Minuet offers code completion as-you-type from popular LLMs.
  :ensure t
  :after gptel
  :bind
  (("M-y" . #'minuet-complete-with-minibuffer) ;; use minibuffer for completion
   ("M-i" . #'minuet-show-suggestion) ;; use overlay for completion
   ("C-c m" . #'minuet-configure-provider)
   :map minuet-active-mode-map
   ;; These keymaps activate only when a minuet suggestion is displayed in the current buffer
   ("M-p" . #'minuet-previous-suggestion) ;; invoke completion or cycle to next completion
   ("M-n" . #'minuet-next-suggestion) ;; invoke completion or cycle to previous completion
   ("M-A" . #'minuet-accept-suggestion) ;; accept whole completion
   ;; Accept the first line of completion, or N lines with a numeric-prefix:
   ;; e.g. C-u 2 M-a will accepts 2 lines of completion.
   ("M-a" . #'minuet-accept-suggestion-line)
   ("M-e" . #'minuet-dismiss-suggestion))
  ;; :init
  ;; ;; if you want to enable auto suggestion.
  ;; ;; Note that you can manually invoke completions without enable minuet-auto-suggestion-mode
  ;; (add-hook 'prog-mode-hook #'minuet-auto-suggestion-mode)
  :config
  ;; Use Codestral FIM completions via the Mistral API.
  ;; Minuet expects the *environment variable name* here, not the key value.
  (setq minuet-provider 'codestral)
  (plist-put minuet-codestral-options :api-key "MISTRAL_API_KEY")
  (plist-put minuet-codestral-options :end-point "https://api.mistral.ai/v1/fim/completions")
  (plist-put minuet-codestral-options :model "codestral-latest")
  (minuet-set-optional-options minuet-codestral-options :max_tokens 128)
  (minuet-set-optional-options minuet-codestral-options :stop ["\n\n"])
  ;; end of minuet package config
  )

(use-package acp
  ;; https://github.com/xenodium/acp.el
  ;; Agent Client Protocol (ACP) implementation in Emacs lisp
  :ensure t
  ;; end of acp package config
  )

(use-package agent-shell
  ;; https://github.com/xenodium/agent-shell
  ;; A native Emacs buffer to interact with LLM agents powered by ACP.
  :ensure t
  ;; end of agent-shell package config
  )

;; TODO: move this where it belongs in use-package config
;; Delete trailing whitespace for org-mode
(add-hook 'org-mode-hook #'myde/delete-trailing-whitespace-setup)

;; -----------------------------------------------------------------------------
;; That's all folks!!!
;; -----------------------------------------------------------------------------

(provide 'post-init)
;;; post-init.el ends here
