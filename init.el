;;; MyDE is *my* Development Environment. YMMV :-)

;; Start off by disabling the splash screen and scratch buffer message.
(setq inhibit-startup-message t
      inhibit-startup-echo-area-message t
      initial-scratch-message nil)

;; Get rid of the scollbar and toolbar in GUI. They take up precious space
;; and one of my goals is to keep my hands on the keyboard, not the mouse.
(when (display-graphic-p)
  (scroll-bar-mode -1)
  (tool-bar-mode -1))

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

;; Store custom settings in separate file.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file)

;; Store backups in separate directory.
(setq backup-directory (expand-file-name "backup" user-emacs-directory)
      backup-directory-alist `(("." . ,backup-directory)))
(make-directory backup-directory :parents)

;; Enable consistent use of 'y' or 'n' in prompts, never 'yes' or 'no'.
(defalias 'yes-or-no-p 'y-or-n-p)

;; Automatically follow links to version controlled files when opening them.
(setq vc-follow-symlinks t)

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

;; Configure display of line numbers.
(add-hook 'prog-mode-hook (lambda () (display-line-numbers-mode t)))

;; Create missing dirs as needed.
(defun mc/auto-create-missing-dirs ()
  (let ((target-dir (file-name-directory buffer-file-name)))
    (unless (file-exists-p target-dir)
      (make-directory target-dir t))))

(add-to-list 'find-file-not-found-functions #'mc/auto-create-missing-dirs)

;; Enable clickable/selectable links for URLs in buffers.
(goto-address-mode 1)

;; Start emacs server if not running.
(load "server")
(unless (server-running-p) (server-start))

;; Configure package management.
(require 'package)
(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/"))
(package-initialize)
(require 'use-package)

;; Configure recent files.
(use-package recentf
  :init
  (recentf-mode t)
  (setq recentf-max-saved-items 50))

;; Persist history over Emacs restarts. Vertico sorts by history position.
(use-package savehist
  :init
  (savehist-mode))

;; Add shell PATH to exec-path on macOS.
;; https://github.com/purcell/exec-path-from-shell
(use-package exec-path-from-shell
  :ensure t
  :if (string-equal system-type "darwin")
  :config
  (exec-path-from-shell-initialize))

;; Load theme.
;; https://github.com/purcell/color-theme-sanityinc-tomorrow
(use-package color-theme-sanityinc-tomorrow
  :ensure t
  :config
  (load-theme 'sanityinc-tomorrow-eighties t))

;; Add support for fast search with ripgrep.
;; https://github.com/Wilfred/deadgrep
(use-package deadgrep
  :ensure t
  :bind ("<f5>" . deadgrep))

;; Add support for region expansion/shrinking.
;; https://github.com/magnars/expand-region.el
(use-package expand-region
  :ensure t
  :bind ("C-=" . er/expand-region))

;; Add multiple cursor support.
;; https://github.com/magnars/multiple-cursors.el
(use-package multiple-cursors
  :ensure t
  :bind
  (("C-S-c C-S-c" . mc/edit-line)
   ("C->" . mc/mark-next-like-this)
   ("C-<" . mc/mark-previous-like-this)
   ("C-c C-<" . mc/mark-all-like-this)))

;;; Configure completion

;; Use vertico for vertical completion support.
;; https://github.com/minad/vertico
(use-package vertico
  :ensure t
  :custom
  (vertico-cycle t)
  :init
  (vertico-mode))

;; Configure consult for completing reads.
;; https://github.com/minad/consult
(use-package consult
  :ensure t
  ;; Replace bindings. Lazily loaded due by `use-package'.
  :bind
  (("C-c M-x" . consult-mode-command)
   ("C-c h" . consult-history)
   ("C-c k" . consult-kmacro)
   ("C-c m" . consult-man)
   ("C-c i" . consult-info)
   ([remap Info-search] . consult-info)
   ;; C-x bindings (ctl-x-map)
   ("C-x M-:" . consult-complex-command)     ;; orig. repeat-complex-command
   ("C-x b" . consult-buffer)                ;; orig. switch-to-buffer
   ("C-x 4 b" . consult-buffer-other-window) ;; orig. switch-to-buffer-other-window
   ("C-x 5 b" . consult-buffer-other-frame)  ;; orig. switch-to-buffer-other-frame
   ("C-x r b" . consult-bookmark)            ;; orig. bookmark-jump
   ("C-x p b" . consult-project-buffer)      ;; orig. project-switch-to-buffer
   ;; Custom M-# bindings for fast register access
   ("M-#" . consult-register-load)
   ("M-'" . consult-register-store)          ;; orig. abbrev-prefix-mark (unrelated)
   ("C-M-#" . consult-register)
   ;; Other custom bindings
   ("M-y" . consult-yank-pop)                ;; orig. yank-pop
   ;; M-g bindings (goto-map)
   ("M-g e" . consult-compile-error)
   ("M-g f" . consult-flymake)               ;; Alternative: consult-flycheck
   ("M-g g" . consult-goto-line)             ;; orig. goto-line
   ("M-g M-g" . consult-goto-line)           ;; orig. goto-line
   ("M-g o" . consult-outline)               ;; Alternative: consult-org-heading
   ("M-g m" . consult-mark)
   ("M-g k" . consult-global-mark)
   ("M-g i" . consult-imenu)
   ("M-g I" . consult-imenu-multi)
   ;; M-s bindings (search-map)
   ("M-s d" . consult-find)
   ("M-s D" . consult-locate)
   ("M-s g" . consult-grep)
   ("M-s G" . consult-git-grep)
   ("M-s r" . consult-ripgrep)
   ("M-s l" . consult-line)
   ("M-s L" . consult-line-multi)
   ("M-s k" . consult-keep-lines)
   ("M-s u" . consult-focus-lines)
   ;; Isearch integration
   ("M-s e" . consult-isearch-history)
   :map isearch-mode-map
   ("M-e" . consult-isearch-history)         ;; orig. isearch-edit-string
   ("M-s e" . consult-isearch-history)       ;; orig. isearch-edit-string
   ("M-s l" . consult-line)                  ;; needed by consult-line to detect isearch
   ("M-s L" . consult-line-multi)            ;; needed by consult-line to detect isearch
   ;; Minibuffer history
   :map minibuffer-local-map
   ("M-s" . consult-history)                 ;; orig. next-matching-history-element
   ("M-r" . consult-history))                ;; orig. previous-matching-history-element

  ;; Enable automatic preview at point in the *Completions* buffer. This is
  ;; relevant when you use the default completion UI.
  :hook (completion-list-mode . consult-preview-at-point-mode)

  ;; The :init configuration is always executed (Not lazy)
  :init

  ;; Optionally configure the register formatting. This improves the register
  ;; preview for `consult-register', `consult-register-load',
  ;; `consult-register-store' and the Emacs built-ins.
  (setq register-preview-delay 0.5
        register-preview-function #'consult-register-format)

  ;; Optionally tweak the register preview window.
  ;; This adds thin lines, sorting and hides the mode line of the window.
  (advice-add #'register-preview :override #'consult-register-window)

  ;; Use Consult to select xref locations with preview
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)

  ;; Configure other variables and modes in the :config section,
  ;; after lazily loading the package.
  :config

  ;; Optionally configure preview. The default value
  ;; is 'any, such that any key triggers the preview.
  ;; (setq consult-preview-key 'any)
  ;; (setq consult-preview-key "M-.")
  ;; (setq consult-preview-key '("S-<down>" "S-<up>"))
  ;; For some commands and buffer sources it is useful to configure the
  ;; :preview-key on a per-command basis using the `consult-customize' macro.
  (consult-customize
   consult-theme :preview-key '(:debounce 0.2 any)
   consult-ripgrep consult-git-grep consult-grep
   consult-bookmark consult-recent-file consult-xref
   consult--source-bookmark consult--source-file-register
   consult--source-recent-file consult--source-project-recent-file
   ;; :preview-key "M-."
   :preview-key '(:debounce 0.4 any))

  ;; Optionally configure the narrowing key.
  ;; Both < and C-+ work reasonably well.
  (setq consult-narrow-key "<") ;; "C-+"

  ;; Optionally make narrowing help available in the minibuffer.
  ;; You may want to use `embark-prefix-help-command' or which-key instead.
  ;; (define-key consult-narrow-map (vconcat consult-narrow-key "?") #'consult-narrow-help)

  ;; By default `consult-project-function' uses `project-root' from project.el.
  ;; Optionally configure a different project root function.
  ;;;; 1. project.el (the default)
  ;; (setq consult-project-function #'consult--default-project--function)
  ;;;; 2. vc.el (vc-root-dir)
  ;; (setq consult-project-function (lambda (_) (vc-root-dir)))
  ;;;; 3. locate-dominating-file
  ;; (setq consult-project-function (lambda (_) (locate-dominating-file "." ".git")))
  ;;;; 4. projectile.el (projectile-project-root)
  ;; (autoload 'projectile-project-root "projectile")
  ;; (setq consult-project-function (lambda (_) (projectile-project-root)))
  ;;;; 5. No project support
  ;; (setq consult-project-function nil)
  )

;; ;; Configure actions on completing reads.
;; ;; https://github.com/oantolin/embark
;; (use-package embark
;;   :ensure t
;;   :bind
;;   (("C-." . embark-act)         ;; pick some comfortable binding
;;    ("C-;" . embark-dwim)        ;; good alternative: M-.
;;    ("C-h B" . embark-bindings)) ;; alternative for `describe-bindings'
;;   :init
;;   ;; Optionally replace the key help with a completing-read interface
;;   (setq prefix-help-command #'embark-prefix-help-command)
;;   ;; Show the Embark target at point via Eldoc.  You may adjust the Eldoc
;;   ;; strategy, if you want to see the documentation from multiple providers.
;;   (add-hook 'eldoc-documentation-functions #'embark-eldoc-first-target)
;;   ;; (setq eldoc-documentation-strategy #'eldoc-documentation-compose-eagerly)
;;   :config
;;   ;; Hide the mode line of the Embark live/completions buffers
;;   (add-to-list 'display-buffer-alist
;;                '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
;;                  nil
;;                  (window-parameters (mode-line-format . none)))))

;; (use-package embark-consult
;;   :ensure t ; only need to install it, embark loads it after consult if found
;;   :hook
;;   (embark-collect-mode . consult-preview-at-point-mode))

;; Use marginalia for richer completion lists.
;; https://github.com/minad/marginalia
(use-package marginalia
  :ensure t
  :after vertico
  :custom
  (marginalia-annotators (marginalia-annotators-heavy marginalia-annotators-light nil))
  (marginalia-max-relative-age 0)
;  (marginalia-align 'right)
  :init
  (marginalia-mode))

(use-package all-the-icons-completion
  :ensure t
  :after (marginalia all-the-icons)
  :if (display-graphic-p)
  :hook (marginalia-mode . all-the-icons-completion-marginalia-setup)
  :init
  (all-the-icons-completion-mode))

;; Use orderless for configuring completion styles.
;; https://github.com/oantolin/orderless
(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

;; Use diminish to squelch excessive noise in the modeline.
;; https://github.com/myrjola/diminish.el
(use-package diminish
  :ensure t
  :defer 5
  :config
  (diminish 'org-indent-mode)
  (diminish 'which-key-mode)
  (diminish 'highlight-indent-guides-mode))

;; Use which-key for improved discoverability.
;; https://github.com/justbur/emacs-which-key
(use-package which-key
  :ensure t
  :init
  (diminish 'which-key-mode)
  (which-key-mode))

;; Provide better help buffers.
;; https://github.com/Wilfred/helpful
(use-package helpful
  :ensure t
  :bind
  (("C-c C-d" . helpful-at-point)
   ("C-h f" . helpful-callable)
   ("C-h F" . helpful-function)
   ("C-h k" . helpful-key)
   ("C-h v" . helpful-variable)))

;; Use vterm for a fast, richer terminal emulator.
;; https://github.com/akermu/emacs-libvterm
(use-package vterm
  :demand t
  :commands vterm)

;; Configure git support.
;; https://github.com/magit/magit
(use-package magit
  :demand t
  :commands magit-status)

;; Add markdown support.
;; https://github.com/jrblevin/markdown-mode
(use-package markdown-mode
  :ensure t
  :demand t
  :commands (markdown-mode gfm-mode)
  :mode
  (("README\\.md\\'" . gfm-mode)
   ("\\.md\\'" . markdown-mode)
   ("\\.markdown\\'" . markdown-mode))
  :init (setq markdown-command "multimarkdown"))

;; Add REST client support.
;; https://github.com/pashky/restclient.el
(use-package restclient
  :ensure t
  :demand t
  :commands restclient-mode
  :mode
  (("\\.http\\'" . restclient-mode)))

;; Add auto installation of treesitter major modes.
;; https://github.com/renzmann/treesit-auto
(use-package treesit-auto
  :ensure t
  :demand t
  :config
  (global-treesit-auto-mode))

;; Add snippets support.
;; https://github.com/joaotavora/yasnippet
(use-package yasnippet
  :ensure t
  :demand t
  :config
  (yas-global-mode 1))

;; https://github.com/AndreaCrotti/yasnippet-snippets
(use-package yasnippet-snippets
  :ensure t
  :demand t)

;; Add Golang support.
(use-package go-mode
  :ensure t
  :demand t
  :commands go-mode
  :config
  (setq myde/gobin-path (expand-file-name "~/go/bin")
	exec-path (append exec-path `(,myde/gobin-path)))
  :init
  (add-hook 'go-mode-hook #'yas-minor-mode)
  (add-hook 'go-mode-hook (lambda ()
    (setq tab-width 2))))

;; Add Python support.
(use-package python
  :demand t
  :commands python-mode
  :init
  (add-hook 'python-mode-hook #'yas-minor-mode))

;; Add REST client support.
(use-package restclient
  :ensure t
  :demand t
  :commands restclient-mode
  :mode
  (("\\.http\\'" . restclient-mode)))
