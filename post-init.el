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
      make-backup-files nil)

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

;; ;; Swap option and command keys on macOS to match Linux keyboard layout.
;; (unless (and (display-graphic-p) (string-equal system-type "darwin"))
;;    (setq mac-command-modifier 'meta
;;         mac-option-modifier 'super))

;; Blink cursor.
(blink-cursor-mode 1)

;; Enable display of column numbers in buffer modeline.
(setq column-number-mode t)

;; Auto-revert buffer on changes to files on disk.
(global-auto-revert-mode 1)

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
;; Project.el setup
;; -----------------------------------------------------------------------------
(use-package project
  :ensure nil ; part of emacs since v29
  :config
  (setq project-switch-use-ido 'both))

;; -----------------------------------------------------------------------------
;; Visual setup
;; -----------------------------------------------------------------------------

;; https://github.com/myrjola/diminish.el
(use-package diminish
  ;; Keep modeline noise to a minimum
  :ensure t)

;; https://github.com/jaypei/emacs-neotree
(use-package neotree
  :ensure t
  :commands (neotree-toggle)
  :config
  (setq neo-window-width 40)
  :bind
  ([f8] . neotree-toggle))

;; https://github.com/rainstormstudio/nerd-icons.el
(use-package nerd-icons
  :ensure t
  ;; :custom
  ;; The Nerd Font you want to use in GUI
  ;; "Symbols Nerd Font Mono" is the default and is recommended
  ;; but you can use any other Nerd Font if you want
  ;; (nerd-icons-font-family "Symbols Nerd Font Mono")
  )

;; https://github.com/purcell/color-theme-sanityinc-tomorrow
(use-package color-theme-sanityinc-tomorrow
  :ensure t)

;; ;; https://github.com/ianyepan/jetbrains-darcula-emacs-theme
;; (use-package jetbrains-darcula-theme
;;   :config
;;   (load-theme 'jetbrains-darcula t))

(use-package ef-themes
  :config
  (load-theme 'ef-owl))

;; https://github.com/doomemacs/themes
;; (use-package doom-themes
;;   :ensure t
;;   :config
;;   ;; Global settings (defaults)
;;   (setq doom-themes-enable-bold t    ; if nil, bold is universally disabled
;;         doom-themes-enable-italic t) ; if nil, italics is universally disabled
;;   (load-theme 'doom-vibrant t)
;; 
;;   ;; Enable flashing mode-line on errors
;;   (doom-themes-visual-bell-config)
;;   ;; Enable custom neotree theme (nerd-icons must be installed!)
;;   (doom-themes-neotree-config)
;;   ;; or for treemacs users
;;   (setq doom-themes-treemacs-theme "doom-atom") ; use "doom-colors" for less minimal icon theme
;;   (doom-themes-treemacs-config)
;;   ;; Corrects (and improves) org-mode's native fontification.
;;   (doom-themes-org-config))

;; https://github.com/protesilaos/spacious-padding
(use-package spacious-padding
  :ensure t
  :config
  (spacious-padding-mode 1))

;; -----------------------------------------------------------------------------
;; Miscellaneous quality-of-life improvements
;; -----------------------------------------------------------------------------

(global-set-key [remap keyboard-quit] #'myde/keyboard-quit)

;; https://github.com/magnars/expand-region.el
(use-package expand-region
  :bind ("C-=" . er/expand-region))

;; -----------------------------------------------------------------------------
;; Discoverability setup
;; -----------------------------------------------------------------------------
(use-package which-key
  :ensure nil ; part of emacs since v29
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
  (vterm))

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

;; ;; -----------------------------------------------------------------------------
;; ;; gptel llm client integration
;; ;; -----------------------------------------------------------------------------

;; ;; https://github.com/karthink/gptel
;; (use-package gptel
;;   :ensure t
;;   :defer t)
