;;; post-init.el --- Loaded after init.el -*- no-byte-compile: t; lexical-binding: t; -*-

;; Load customizations
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load-file custom-file))

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
(unless (and (display-graphic-p) (string-equal system-type "darwin"))
   (setq mac-command-modifier 'meta
        mac-option-modifier 'super))

;; Blink cursor.
(blink-cursor-mode 1)

;; Enable display of column numbers in buffer modeline.
(setq column-number-mode t)

;; Auto-revert buffer on changes to files on disk.
(global-auto-revert-mode 1)

;; ;; Highlight current line everywhere.
;; (global-hl-line-mode 1)

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

;; -----------------------------------------------------------------------------
;; Elisp programming support packages
;; -----------------------------------------------------------------------------

;; https://github.com/magnars/dash.el
;; A modern list API for Emacs. No 'cl required.
(use-package dash
  :ensure t)

;; https://github.com/magnars/s.el
;; The long lost Emacs string manipulation library.
(use-package s
  :ensure t)

;; https://elpa.gnu.org/packages/seq.html
;; Sequence manipulation functions.
(use-package seq
  :ensure t)

;; https://github.com/alphapapa/plz.el
;; An HTTP library for Emacs.
(use-package plz
  :ensure t)

;; -----------------------------------------------------------------------------
;; Package setup
;; -----------------------------------------------------------------------------
(require 'package)
(setq package-archives
      '(("melpa"  . "https://melpa.org/packages/")
        ("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

;; -----------------------------------------------------------------------------
;; macOS setup
;; -----------------------------------------------------------------------------

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

;; -----------------------------------------------------------------------------
;; Splash screen/Dashboard support.
;; -----------------------------------------------------------------------------

;; https://github.com/emacs-dashboard/emacs-dashboard
(use-package dashboard
  :ensure t
  :custom
  (dashboard-projects-backend 'projectile)
  (dashboard-items '((recents . 5)
                    (projects . 5)
                    (bookmarks . 5)
                    (agenda . 5)))
  :config
  (dashboard-setup-startup-hook)
  (setq dashboard-display-icons-p t)
  (setq dashboard-icon-type 'nerd-icons)
  (setq dashboard-set-heading-icons t)
  (setq dashboard-set-file-icons t))

;; Activate recentf to track recently opened files
(use-package recentf
  :ensure nil
  :commands (recentf-mode recentf-cleanup)
  :config
  (recentf-mode t)
  (setq recentf-auto-cleanup (if (daemonp) 300 'never))
  (setq recentf-exclude
        '("^/tmp/" "^/ssh:" "/COMMIT_EDITMSG\\'"
          "/bookmarks" "/info/" "/diary$" "/\\.elpa/"))
  (add-hook 'kill-emacs-hook #'recentf-cleanup -90))

;; -----------------------------------------------------------------------------
;; Projects support
;; -----------------------------------------------------------------------------

(use-package projectile
  :ensure t
  :init
  (projectile-mode +1)
  :bind (:map projectile-mode-map
              ("s-p" . projectile-command-map)
              ("C-c p" . projectile-command-map)))

;; (use-package project
;;   :ensure nil ; part of emacs since v29
;;   :config
;;   (setq project-switch-use-ido 'both))

;; -----------------------------------------------------------------------------
;; Themes support
;; -----------------------------------------------------------------------------

;; Preview and manage themes.
;; https://github.com/ayys/easy-theme-preview.el
(use-package easy-theme-preview
  :ensure t)

(use-package doom-themes
  :ensure t
  :custom
  ;; Global settings (defaults)
  (doom-themes-enable-bold t)   ; if nil, bold is universally disabled
  (doom-themes-enable-italic t) ; if nil, italics is universally disabled
  ;; for treemacs users
  (doom-themes-treemacs-theme "doom-atom") ; use "doom-colors" for less minimal icon theme
  :config
  ;; Load initial theme.
  (load-theme 'doom-badger t)
  ;; Enable flashing mode-line on errors
  (doom-themes-visual-bell-config)
  ;; Enable custom neotree theme (nerd-icons must be installed!)
  (doom-themes-neotree-config)
  ;; or for treemacs users
  (doom-themes-treemacs-config)
  ;; Corrects (and improves) org-mode's native fontification.
  (doom-themes-org-config))

;; ;; https://github.com/purcell/color-theme-sanityinc-tomorrow
;; (use-package color-theme-sanityinc-tomorrow
;;   :ensure t)

;; ;; https://github.com/ianyepan/jetbrains-darcula-emacs-theme
;; (use-package jetbrains-darcula-theme
;;   :ensure t
;;   :config
;;   (load-theme 'jetbrains-darcula t))

;; (use-package ef-themes
;;   :config
;;   (load-theme 'ef-owl))

;; -----------------------------------------------------------------------------
;; Give the UI space to breathe
;; -----------------------------------------------------------------------------

;; https://github.com/protesilaos/spacious-padding
(use-package spacious-padding
  :ensure t
  :config
  (spacious-padding-mode 1))

;; https://github.com/myrjola/diminish.el
(use-package diminish
  ;; Keep modeline noise to a minimum
  :ensure t)

;; -----------------------------------------------------------------------------
;; Project tree explorer support
;; -----------------------------------------------------------------------------

(defun myde/neotree-project-root-toggle ()
  "Toggle NeoTree. If opening, set the root to the current 'project' root."
  (interactive)
  (if (and (fboundp 'neo-global--window-exists-p)
           (neo-global--window-exists-p))
      (neotree-hide)
    (let ((project (project-current)))
      (if project
          (neotree-dir (project-root project))
        (neotree-show)))))

;; https://github.com/jaypei/emacs-neotree
(use-package neotree
  :ensure t
  :commands (neotree-toggle)
  :config
  (setq neo-window-width 40)
  (setq neo-theme (if (display-graphic-p) 'icons 'arrow))
  :bind
  ([f8] . myde/neotree-project-root-toggle))

;; -----------------------------------------------------------------------------
;; Icons support
;; -----------------------------------------------------------------------------

;; https://github.com/domtronn/all-the-icons.el
(use-package all-the-icons
  :if (display-graphic-p))

;; https://github.com/rainstormstudio/nerd-icons.el
(use-package nerd-icons
  :ensure t
  ;; :custom
  ;; The Nerd Font you want to use in GUI
  ;; "Symbols Nerd Font Mono" is the default and is recommended
  ;; but you can use any other Nerd Font if you want
  ;; (nerd-icons-font-family "Symbols Nerd Font Mono")
  )

;; -----------------------------------------------------------------------------
;; Miscellaneous quality-of-life improvements
;; -----------------------------------------------------------------------------

(global-set-key [remap keyboard-quit] #'myde/keyboard-quit)

;; https://github.com/magnars/expand-region.el
(use-package expand-region
  :bind
  ("C-=" . er/expand-region))

;; https://github.com/magnars/multiple-cursors.el
(use-package multiple-cursors
  :ensure t
  :bind (("C-S-c C-S-c" . mc/edit-lines)        ;; edit multiple lines
         ("C->"         . mc/mark-next-like-this)   ;; add next match
         ("C-<"         . mc/mark-previous-like-this) ;; add previous match
         ("C-c C-<"     . mc/mark-all-like-this))   ;; mark all matches
  :config
  ;; Sensible defaults
  (setq mc/list-file (locate-user-emacs-file "mc-lists.el"))

  ;; Make cursor movement more predictable
  (setq mc/always-run-for-all t))

;; https://github.com/purcell/whole-line-or-region
(use-package whole-line-or-region
  :ensure t
  :config
  (whole-line-or-region-global-mode))

;; -----------------------------------------------------------------------------
;; Discoverability setup
;; -----------------------------------------------------------------------------

(use-package which-key
  :ensure nil ; part of emacs since v29
  :init
  (diminish 'which-key-mode)
  (which-key-mode))

;; https://github.com/Wilfred/helpful
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

;; -----------------------------------------------------------------------------
;; Terminals setup
;; -----------------------------------------------------------------------------

;; https://codeberg.org/akib/emacs-eat
(use-package eat
  :ensure t)

;; https://github.com/akermu/emacs-libvterm
(use-package vterm
  ;; Use vterm for a fast, richer terminal emulator.
  :ensure t
  :commands
  (vterm)
  :config
  ;; Disable hl-line-mode in all terminal-like modes
  (setq global-hl-line-modes
        '(not vterm-mode term-mode eshell-mode ansi-term-mode comint-mode)))
           
;; -----------------------------------------------------------------------------
;; Version control setup
;; -----------------------------------------------------------------------------

;; https://github.com/magit/magit
(use-package magit
  :ensure t
  :commands (magit-status))

;; -----------------------------------------------------------------------------
;; Direnv integration
;; -----------------------------------------------------------------------------

;; https://github.com/wbolster/emacs-direnv
(use-package direnv
  :ensure t
  :config
  (direnv-mode))

;; -----------------------------------------------------------------------------
;; In-buffer completion (Corfu)
;; -----------------------------------------------------------------------------

;; https://github.com/minad/corfu
(use-package corfu
  :ensure t
  :custom
  (corfu-auto t)
  (corfu-cycle t)
  :init
  (global-corfu-mode))

;; -----------------------------------------------------------------------------
;; Minibuffer completion stack
;; -----------------------------------------------------------------------------

;; https://github.com/minad/vertico
(use-package vertico
  :ensure t
  :init
  (vertico-mode))

;; https://github.com/oantolin/orderless
(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles . (partial-completion))))))

;; https://github.com/minad/marginalia
(use-package marginalia
  :ensure t
  :init
  (marginalia-mode))

;; https://github.com/minad/consult
(use-package consult
  :ensure t
  :bind (("C-s" . consult-line)
         ("C-x b" . consult-buffer)
         ("M-y" . consult-yank-pop)))

;; https://github.com/oantolin/embark
(use-package embark
  :ensure t
  :bind (("C-." . embark-act)
         ("C-h B" . embark-bindings))
  :init
  (setq prefix-help-command #'embark-prefix-help-command))

(use-package embark-consult
  :ensure t ; only need to install it, embark loads it after consult if found
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

;; -----------------------------------------------------------------------------
;; treesit-auto for Tree-sitter setup
;; -----------------------------------------------------------------------------

;; Install Tree-sitter grammar if missing
(use-package treesit
  :ensure nil ; part of emacs since v29
  :config
  (add-to-list 'treesit-language-source-alist
               '(hcl "https://github.com/tree-sitter-grammars/tree-sitter-hcl")))

;; https://github.com/renzmann/treesit-auto
(use-package treesit-auto
  :ensure t
  :config
  (setq treesit-auto-install t) ; install grammars automatically, if missing
  (global-treesit-auto-mode))


;; -----------------------------------------------------------------------------
;; LSP support
;; -----------------------------------------------------------------------------

(use-package eglot
  :ensure nil ; part of emacs since v29
  :hook ((go-ts-mode . eglot-ensure)
         (go-mode . eglot-ensure)))

;; -----------------------------------------------------------------------------
;; Combobulate setup (tree-sitter based navigation/manipulation)
;; -----------------------------------------------------------------------------

(use-package combobulate
  :ensure t
  :vc (:url "https://github.com/mickeynp/combobulate" :rev :newest)
  :after eglot)

;; -----------------------------------------------------------------------------
;; Environment files
;; -----------------------------------------------------------------------------

(use-package dotenv-mode
  :ensure t
  :mode (("\\.env\\'" . dotenv-mode)
         ("\\.envrc\\'" . dotenv-mode)))
  
;; -----------------------------------------------------------------------------
;; Golang setup
;; -----------------------------------------------------------------------------

;; https://github.com/dominikh/go-mode.el
(use-package go-mode
  :ensure t
  :mode (("\\.go\\'" . myde/go-ts-or-plain-mode))
  :hook ((go-ts-mode . eglot-ensure)
         (go-mode . eglot-ensure)
         (go-mode . myde/goimports-setup))
  :config
  (setq gofmt-command "goimports"))

;; -----------------------------------------------------------------------------
;; Markdown editing setup
;; -----------------------------------------------------------------------------

;; https://github.com/jrblevin/markdown-mode
(use-package markdown-mode
  :ensure t
  :hook (markdown-mode . display-line-numbers-mode)
  :mode (("\\.md\\'" . gfm-mode)
         ("README\\.md\\'" . gfm-mode))
  :init
  (setq markdown-command "multimarkdown")
  :bind (:map markdown-mode-map ("C-c C-e" . markdown-do)))

;; -----------------------------------------------------------------------------
;; Terraform support
;; -----------------------------------------------------------------------------

;; https://github.com/hcl-emacs/terraform-mode
(use-package terraform-mode
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
      (remove-hook 'before-save-hook #'terraform-format-buffer t))))

;; Tree-sitter remap: only after HCL grammar is installed
(when (and (fboundp 'treesit-available-p)
           (treesit-available-p)
           (treesit-language-available-p 'hcl))
  (add-to-list 'major-mode-remap-alist
               '(terraform-mode . terraform-ts-mode)))

;; -----------------------------------------------------------------------------
;; YAML editing setup
;; -----------------------------------------------------------------------------

;; https://github.com/yoshiki/yaml-mode
(use-package yaml-mode
  :ensure t
  :mode (("\\.yaml\\'" . yaml-mode)
         ("\\.yml\\'" . yaml-mode)))

;; ;; -----------------------------------------------------------------------------
;; ;; Aider integration
;; ;; -----------------------------------------------------------------------------

;; ;; https://github.com/MatthewZMD/aidermacs
;; (use-package aidermacs
;;   :ensure t
;;   :bind (("C-c a" . aidermacs-transient-menu))
;;   :custom
;;                                         ; See the Configuration section below
;;   (aidermacs-use-architect-mode t)
;;   (aidermacs-default-model "sonnet"))

;; ;; -----------------------------------------------------------------------------
;; ;; Claude code integration
;; ;; -----------------------------------------------------------------------------

;; ;; ;; https://github.com/stevemolitor/claude-code.el 
;; ;; (use-package claude-code
;; ;;   :vc (:url "https://github.com/stevemolitor/claude-code.el")
;; ;;   :bind ("C-c c" . claude-code-command-map)
;; ;;   :config
;; ;;   (claude-code-mode))

;; ;; https://github.com/yuya373/claude-code-emacs
;; (use-package claude-code-emacs
;;   :ensure t
;;   :vc (:url "https://github.com/yuya373/claude-code-emacs")
;;   :bind ("C-c c" . 'claude-code-emacs-transient))

;; (use-package claude-code-ide
;;   :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :rev :newest)
;;   :bind ("C-c c" . claude-code-ide-menu) ; Set your favorite keybinding
;;   :config
;;   (claude-code-ide-emacs-tools-setup)) ; Optionally enable Emacs MCP tools

;; ;; ;; -------------------------------
;; ;; ;; ChatGPT integration
;; ;; ;; -------------------------------
;; ;; (use-package chatgpt-shell
;; ;;   :ensure t
;; ;;   :custom
;; ;;   ((chatgpt-shell-openai-key
;; ;;     (lambda ()
;; ;;       (auth-source-pass-get 'secret "openai-key")))))

;; gptel LLM client
;; https://github.com/karthink/gptel

(defun myde/gptel-api-key-from-environment (&optional var)
  (lambda ()
    (getenv (or var                     ;provided key
                (thread-first           ;or fall back to <TYPE>_API_KEY
                  (type-of gptel-backend)
                  (symbol-name)
                  (substring 6)
                  (upcase)
                  (concat "_API_KEY"))))))

(use-package gptel
  :ensure t
  :defer t
  :config
  ;; Register backends.
  ;; OpenAI is a reasonable default if it provides all you need.
  (gptel-make-openai "OpenAI"
    :host "api.openai.com"
    :key (myde/gptel-api-key-from-environment "OPENAI_API_KEY"))
  ;; OpenRouter offers an OpenAI compatible API for multiple LLMs covering all your needs.
  (gptel-make-openai "OpenRouter"               ;Any name you want
    :host "openrouter.ai"
    :endpoint "/api/v1/chat/completions"
    :stream t
    :key (myde/gptel-api-key-from-environment "OPENROUTER_API_KEY")
    :models '(openai/gpt-3.5-turbo
              mistralai/mixtral-8x7b-instruct
              meta-llama/codellama-34b-instruct
              codellama/codellama-70b-instruct
              google/palm-2-codechat-bison-32k
              google/gemini-pro))
  ;; Set default backend
  (setq gptel-model 'gpt-4o
        gptel-backend (gptel-get-backend "OpenAI"))
  ;; Enable tool use (optional)
  (gptel-enable-tools))
