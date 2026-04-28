;;; init.el --- Loaded after init.el -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

;; Load customizations
(let* ((path (expand-file-name "custom.el" user-emacs-directory))
       (exists (file-exists-p path)))
  (setq custom-file path)
  (when exists
    (load-file custom-file)))

;; Load myde.el functions
(load-file (expand-file-name "myde.el" user-emacs-directory))

;; XDG directory support and built-in configuration
;; It is important that this is loaded early before we set locations
;; for the various state files written by emacs and external packages.
(use-package xdg
  :ensure nil)

(use-package emacs
  :after xdg
  :config
  ;; Store backups in XDG state directory
  (setq backup-directory (expand-file-name "emacs/backup" (xdg-state-home))
        backup-directory-alist `(("." . ,backup-directory)))
  (make-directory backup-directory :parents)

  ;; Package initialization
  (require 'package)
  (setq package-user-dir
        (expand-file-name "emacs/elpa" (xdg-data-home)))

  ;; Redirect native compilation cache (Emacs 29+)
  (when (fboundp 'startup-redirect-eln-cache)
    (startup-redirect-eln-cache
     (expand-file-name "emacs/eln-cache" (xdg-cache-home))))
  
  (setq package-archives
        '(("melpa"  . "https://melpa.org/packages/")
          ("gnu"    . "https://elpa.gnu.org/packages/")
          ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
  (setq package-install-upgrade-built-in t)
  (unless package-archive-contents
    (package-refresh-contents))
  (package-initialize)

  ;; Auto-save list file (crash recovery index)
  (setq auto-save-list-file-prefix
        (expand-file-name "emacs/auto-save-list/.saves-" (xdg-state-home)))

  ;; TRAMP connection cache
  (setq tramp-persistency-file-name
        (expand-file-name "emacs/tramp" (xdg-state-home)))

  ;; URL library configuration (cookies, cache)
  (setq url-configuration-directory
        (expand-file-name "emacs/url/" (xdg-cache-home))))

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

;; Suppress native compilation warnings for undefined functions in third-party packages.
;; These warnings don't affect runtime functionality; the functions are available at runtime.
(setq native-comp-warning-on-missing-defs nil)

;; Squelch prompt to kill buffer with process attached to it.
(setq kill-buffer-query-functions
      (remq 'process-kill-buffer-query-function kill-buffer-query-functions))

;; Configure display of line numbers.
(add-hook 'prog-mode-hook (lambda ()
                            (display-line-numbers-mode t)
                            (hl-line-mode t)))
(add-hook 'prog-mode-hook #'myde/delete-trailing-whitespace-setup)

;; Increase subprocess read buffer size for LSP throughput (default is 4096).
(setq read-process-output-max (* 1024 1024))  ; 1 MiB

;; Auto-detect shebang comments and use shell-script-mode appropriately.
(dolist (interp '("bash" "sh" "zsh"))
  (add-to-list 'interpreter-mode-alist (cons interp 'shell-script-mode)))

;; -----------------------------------------------------------------------------
;; macOS-specific setup
;; -----------------------------------------------------------------------------

(use-package emacs
  :if (string= system-type "darwin")
  :config
  (setq dired-use-ls-dired t)
  (setq insert-directory-program "/usr/local/bin/gls")
  (setq dired-listing-switches "-aBhl --group-directories-first")
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Shell support
;; -----------------------------------------------------------------------------

(use-package exec-path-from-shell  ;; https://github.com/purcell/exec-path-from-shell
  :config
  (exec-path-from-shell-initialize)
  :ensure t)

(use-package fish-mode  ;; https://github.com/emacsmirror/fish-mode
  :custom
  (fish-indent-offset 2)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Editorconfig support
;; -----------------------------------------------------------------------------

(use-package editorconfig
	:config
	(editorconfig-mode 1)
	:ensure nil)



;; -----------------------------------------------------------------------------
;; Splash screen/Dashboard support
;; -----------------------------------------------------------------------------

(use-package recentf
  :init
  (setq recentf-save-file
        (expand-file-name "emacs/recentf.eld" (xdg-state-home)))
  :config
  (recentf-mode t)
  (setq recentf-auto-cleanup (if (daemonp) 300 'never))
  (setq recentf-exclude
        '("^/tmp/" "^/ssh:" "/COMMIT_EDITMSG\\'"
          "/bookmarks" "/info/" "/diary$" "/\\.elpa/"))
  (add-hook 'kill-emacs-hook #'recentf-cleanup -90)
  :commands (recentf-mode recentf-cleanup)
  :ensure nil)

(use-package transient
  :init
  (setq transient-base-dir
        (expand-file-name "emacs/transient" (xdg-data-home)))
  :ensure nil)

(use-package buffer-guardian  ;; https://github.com/jamescherti/buffer-guardian.el
  :custom
  (buffer-guardian-inhibit-saving-remote-files t)         ;; When non-nil, include remote files in the auto-save process
  (buffer-guardian-inhibit-saving-nonexistent-files nil)  ;; When non-nil, buffers visiting nonexistent files are not saved
  (buffer-guardian-save-on-same-buffer-window-change t)   ;; Save the buffer even if the window change results in the same buffer
  (buffer-guardian-verbose nil)                           ;; Non-nil to enable verbose mode to log when a buffer is automatically saved
  ;; (buffer-guardian-save-all-buffers-idle 30)           ;; Save all buffers after N seconds of user idle time. (Disabled by default)
  :hook
  (after-init . buffer-guardian-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; UI quality of life improvements
;; -----------------------------------------------------------------------------

(use-package spacious-padding  ;; https://github.com/protesilaos/spacious-padding
  :config
  (spacious-padding-mode 1)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Icons support
;; -----------------------------------------------------------------------------

(use-package all-the-icons  ;; https://github.com/domtronn/all-the-icons.el
  :if (display-graphic-p)
  :ensure t)

(use-package nerd-icons  ;; https://github.com/rainstormstudio/nerd-icons.el
  :ensure t)

;; -----------------------------------------------------------------------------
;; Fonts support
;; -----------------------------------------------------------------------------

(use-package show-font  ;; https://github.com/protesilaos/show-font
  :bind
  (("C-c s f" . show-font-select-preview)
   ("C-c s t" . show-font-tabulated))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Themes support
;; -----------------------------------------------------------------------------

(use-package easy-theme-preview  ;; https://github.com/ayys/easy-theme-preview.el
  :ensure t)

(use-package color-theme-sanityinc-tomorrow  ;; https://github.com/purcell/color-theme-sanityinc-tomorrow
  :ensure t)

(use-package doom-themes ;; https://github.com/doomemacs/themes
  :custom
  (doom-themes-enable-bold t)   ; if nil, bold is universally disabled
  (doom-themes-enable-italic t) ; if nil, italics is universally disabled
  (doom-themes-treemacs-theme "doom-atom") ; use "doom-colors" for less minimal icon theme
  :config
  (doom-themes-visual-bell-config)  ;; Enable flashing mode-line on errors
  (doom-themes-neotree-config)      ;; Enable custom neotree theme (nerd-icons must be installed!)
  (doom-themes-treemacs-config)     ;; or for treemacs users
  (doom-themes-org-config)          ;; Corrects (and improves) org-mode's native fontification.
  :ensure t)

(use-package ef-themes  ;; https://github.com/protesilaos/ef-themes
  :ensure t)

(use-package jetbrains-darcula-theme  ;; https://github.com/ianyepan/jetbrains-darcula-emacs-theme
  :ensure t)

(use-package batppuccin
  :config
  (load-theme 'batppuccin-frappe t)
  :ensure t)

(use-package auto-dark
  :after (batppuccin-latte-theme batppuccin-mocha-theme)
  :if (string= system-type "linux")
  :custom
  (auto-dark-themes '((batppuccin-frappe) (batppuccin-latte)))
  :init
  (auto-dark-mode t)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Secrets support
;; -----------------------------------------------------------------------------

(use-package auth-source-1password  ;; https://github.com/dlobraico/auth-source-1password
  :init
  (setq auth-source-1password-construct-secret-reference
        #'myde/auth-source-1password-construct-secret-reference)
  :config
  (auth-source-1password-enable)
  :custom
  (auth-source-1password-vault "My API credentials")
  :ensure t)



;; -----------------------------------------------------------------------------
;; Miscellaneous quality-of-life improvements
;; -----------------------------------------------------------------------------

(global-set-key [remap keyboard-quit] #'myde/keyboard-quit)

(use-package expreg  ;; https://github.com/casouri/expreg
  :bind (("C-=" . expreg-expand)
         ("C--" . expreg-contract))
  :ensure t)

;; https://emacsredux.com/blog/2026/03/17/surround-el-vim-style-pair-editing-comes-to-emacs/

(use-package surround  ;; https://github.com/mkleehammer/surround
  :bind-keymap ("M-'" . surround-keymap)
  :ensure t)

(use-package multiple-cursors  ;; https://github.com/magnars/multiple-cursors.el
  :bind (("C-S-c C-S-c" . mc/edit-lines)               ;; edit multiple lines
         ("C->"         . mc/mark-next-like-this)      ;; add next match
         ("C-<"         . mc/mark-previous-like-this)  ;; add previous match
         ("C-c C-<"     . mc/mark-all-like-this))      ;; mark all matches
  :config
  (setq mc/list-file
        (expand-file-name "emacs/mc-lists.el" (xdg-state-home)))
  (setq mc/always-run-for-all t)   ;; Make cursor movement more predictable
  :ensure t)

(use-package whole-line-or-region  ;; https://github.com/purcell/whole-line-or-region
  :config
  (whole-line-or-region-global-mode)
  :ensure t)

(use-package pathaction  ;; https://www.jamescherti.com/pathaction-el-emacs-package-universal-makefile/
  :config
  (add-to-list 'display-buffer-alist '("\\*pathaction:"
                                       (display-buffer-at-bottom)
                                       (window-height . 0.33)))
  :ensure t)



;; =============================================================================
;; External brain support.
;; =============================================================================

;; -----------------------------------------------------------------------------
;; I use org to manage my thoughts and actions.
;; -----------------------------------------------------------------------------

(use-package org  ;; https://orgmode.org
  :hook
  (org-mode . visual-line-mode)
  :custom
  (org-directory myde/org-directory)
  (org-return-follows-link t)
  :ensure nil)

;; Project list (project.el)
(setq project-list-file
      (expand-file-name "emacs/projects.eld" (xdg-state-home)))

;; Ebook reading state
(use-package nov
  :custom
  (nov-place-file
   (expand-file-name "emacs/nov-places" (xdg-state-home)))
  :ensure nil)

;; Forge database
(use-package forge
  :after transient
  :custom
  (forge-database-file
   (expand-file-name "emacs/forge-database.sqlite" (xdg-data-home)))
  :ensure nil)

;; DAP debugger breakpoints
(use-package dap-mode
  :after transient
  :custom
  (dap-breakpoints-file
   (expand-file-name "emacs/.dap-breakpoints" (xdg-state-home)))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Reading and research support.
;;
;; Ebook formats supported include PDF and ePub files.
;; Reading notes and highlighting are captured as org files.
;; -----------------------------------------------------------------------------

(use-package pdf-tools  ;; https://github.com/vedang/pdf-tools
  :init
  (setq pdf-view-display-size 'fit-width
        pdf-view-resize-factor 1.1)
  :config
  (pdf-tools-install)                 ;; Compile/install epdfinfo server automatically
  (setq pdf-view-use-scaling t        ;; Improve rendering responsiveness
        pdf-view-use-imagemagick nil
	pdf-view-continuous t)        ;; Continuous scrolling
  (define-key pdf-view-mode-map (kbd "C-s") #'isearch-forward)
  (define-key pdf-view-mode-map (kbd "h") #'pdf-annot-add-highlight-markup-annotation)
  (define-key pdf-view-mode-map (kbd "t") #'pdf-annot-add-text-annotation)
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :ensure t)

(use-package nov  ;; https://depp.brause.cc/nov.el
  :init
  (setq nov-text-width 80)
  :hook
  ((nov-mode . visual-line-mode)
   (nov-mode . variable-pitch-mode))
  :mode
  ("\\.epub\\'" . nov-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Snippets setup
;; -----------------------------------------------------------------------------

;; -----------------------------------------------------------------------------
;; Language modules
;; -----------------------------------------------------------------------------

(load-file (expand-file-name "myde/core-terminals/cfg.el"  user-emacs-directory))
(load-file (expand-file-name "myde/core-dashboard/cfg.el"  user-emacs-directory))
(load-file (expand-file-name "myde/core-complete/cfg.el"   user-emacs-directory))
(load-file (expand-file-name "myde/core-notes/cfg.el"      user-emacs-directory))
(load-file (expand-file-name "myde/core-snippets/cfg.el"   user-emacs-directory))
(load-file (expand-file-name "myde/core-projects/cfg.el"   user-emacs-directory))
(load-file (expand-file-name "myde/prog-elisp/cfg.el"      user-emacs-directory))
(load-file (expand-file-name "myde/prog-go/cfg.el"         user-emacs-directory))
(load-file (expand-file-name "myde/prog-python/cfg.el"     user-emacs-directory))
(load-file (expand-file-name "myde/prog-elixir/cfg.el"     user-emacs-directory))
(load-file (expand-file-name "myde/text-markdown/cfg.el"   user-emacs-directory))



;; -----------------------------------------------------------------------------
;; Terraform support
;; -----------------------------------------------------------------------------

(use-package terraform-mode  ;; https://github.com/hcl-emacs/terraform-mode
  :mode ("\\.tf\\'" "\\.tfvars\\'" "\\.hcl\\'"  "\\.tofu\\'")
  :hook ((terraform-mode . terraform-format-on-save-mode))
  :ensure t)

;; Tree-sitter remap: only after HCL grammar is installed
(when (and (fboundp 'treesit-available-p)
           (treesit-available-p)
           (treesit-language-available-p 'hcl))
  (add-to-list 'major-mode-remap-alist
               '(terraform-mode . terraform-ts-mode)))

;; -----------------------------------------------------------------------------
;; YAML editing setup
;; -----------------------------------------------------------------------------

(use-package yaml-mode  ;; https://github.com/yoshiki/yaml-mode
  :mode
  (("\\.yaml\\'" . yaml-mode)
   ("\\.yml\\'" . yaml-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Claude code integration
;; -----------------------------------------------------------------------------

(use-package claude-code-ide  ;; https://github.com/manzaltu/claude-code-ide.el
  :bind
  ("C-c c" . claude-code-ide-menu) ; Set your favorite keybinding
  :config
  (claude-code-ide-emacs-tools-setup)
  :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :rev :newest))

(defvar myde/openrouter-models
  '(anthropic/claude-haiku-4.5
    anthropic/claude-opus-4.5
    anthropic/claude-opus-4.6
    anthropic/claude-opus-4.7
    anthropic/claude-sonnet-4.5
    anthropic/claude-sonnet-4.6
    deepseek/deepseek-v3.2
    google/gemini-2.5-flash
    google/gemini-2.5-flash-lite
    google/gemini-3-flash-preview
    google/gemini-3-pro-image-preview
    google/gemini-3-pro-preview
    google/gemma-4-26b-a4b-it:free
    google/gemma-4-31b-it:free
    minimax/minimax-m2.1
    minimax/minimax-m2.5
    minimax/minimax-m2.5:free
    minimax/minimax-m2.7
    mistralai/codestral-embed-2505
    mistralai/devstral-2512
    mistralai/ministral-14b-2512
    mistralai/mistral-large-2512
    mistralai/mistral-nemo             ; roleplay, translation, trivia
    moonshotai/kimi-k2
    moonshotai/kimi-k2-0905            ; roleplay, trivia
    moonshotai/kimi-k2-thinking
    moonshotai/kimi-k2.5
    moonshotai/kimi-k2.6
    nvidia/nemotron-3-super-120b-a12b:free
    nvidia/nemotron-nano-12b-v2-vl:free
    nvidia/nemotron-nano-9b-v2:free
    openai/gpt-5.2
    openai/gpt-5.2-codex
    openai/gpt-5.2-pro
    openai/gpt-5.3-codex
    openai/gpt-5.4
    openai/gpt-5.4-mini
    openai/gpt-oss-120b
    openai/gpt-oss-120b:free
    openrouter/free
    qwen/qwen3-coder-next
    qwen/qwen3-coder:free
    qwen/qwen3-max-thinking
    qwen/qwen3.6-plus:free
    x-ai/grok-4
    x-ai/grok-4-fast
    x-ai/grok-4.20
    x-ai/grok-4.20-multi-agent
    x-ai/grok-code-fast-1
    z-ai/glm-4.5-air:free
    z-ai/glm-4.7
    z-ai/glm-4.7-flash
    z-ai/glm-5
    z-ai/glm-5.1))

(use-package gptel  ;; https://github.com/karthink/gptel
  :after transient
  :config
  (gptel-make-openai "OpenRouter"
    :host "openrouter.ai"
    :endpoint "/api/v1/chat/completions"
    :stream t
    :key (auth-source-pick-first-password :host "OPENROUTER_API_KEY")
    :models myde/openrouter-models)
  (setq gptel-model 'moonshotai/kimi-k2.6
        gptel-backend (gptel-get-backend "OpenRouter"))
  :ensure t)

(use-package gptel-forge-prs  ;; https://github.com/ArthurHeymans/gptel-forge-prs
  :after forge
  :config
  (gptel-forge-prs-install)
  :ensure t)

(use-package gptel-magit  ;; https://github.com/ragnard/gptel-magit
  :after (magit markdown-mode)
  :hook (magit-mode . gptel-magit-install)
  :ensure t)

(use-package minuet  ;; https://github.com/milanglacier/minuet-ai.el
  :after gptel
  ;; :init
  ;; ;; if you want to enable auto suggestion.
  ;; ;; Note that you can manually invoke completions without enable minuet-auto-suggestion-mode
  ;; (add-hook 'prog-mode-hook #'minuet-auto-suggestion-mode)
  :config
  (setq minuet-provider 'codestral)  ;; Use Codestral FIM completions via the Mistral API.
  (plist-put minuet-codestral-options :api-key (auth-source-pick-first-password :host "MISTRAL_API_KEY"))
  (plist-put minuet-codestral-options :end-point "https://api.mistral.ai/v1/fim/completions")
  (plist-put minuet-codestral-options :model "codestral-latest")
  (minuet-set-optional-options minuet-codestral-options :max_tokens 128)
  (minuet-set-optional-options minuet-codestral-options :stop ["\n\n"])
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
  :ensure t)

(use-package acp  ;; https://github.com/xenodium/acp.el
  :after transient
  :ensure t)

(use-package agent-shell  ;; https://github.com/xenodium/agent-shell
  :after transient
  :ensure t)

;; TODO: move this where it belongs in use-package config
;; Delete trailing whitespace for org-mode
(add-hook 'org-mode-hook #'myde/delete-trailing-whitespace-setup)

;; -----------------------------------------------------------------------------
;; That's all folks!!!
;; -----------------------------------------------------------------------------

(provide 'init)
;;; init.el ends here
