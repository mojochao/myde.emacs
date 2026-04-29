;;; myde/prog-scheme/cfg.el --- Scheme development environment configuration -*- lexical-binding: t; -*-

;;; Commentary:

;; Side-effect configuration for Scheme development via geiser (REPL),
;; implementation-specific LSP servers (eglot), schemat formatting (apheleia),
;; and structural editing (paredit + rainbow-delimiters via prog-base).
;;
;; Supports standard Scheme (.scm, .ss, .sls). Racket (.rkt) is deferred to prog-racket.
;;
;; Key design decisions:
;;
;; 1. scheme-mode (built-in) — base mode for all Scheme code
;; 2. geiser + backends (guile, chicken, chez) — REPL/interactive evaluation
;; 3. LSP via implementation-specific detection — scheme-langserver, guile-lsp-server, or chicken-lsp-server
;; 4. schemat (opt-in) — cross-implementation formatter via apheleia
;; 5. paredit + rainbow-delimiters (via prog-base) — structural S-expression editing
;; 6. No DAP — debugging via Geiser's REPL-integrated debugger
;;
;; See myde/prog-scheme/lib.el for pure definitions.

;;; Code:

(unless (featurep 'myde-prog-scheme)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; Tree-sitter grammar registration for Scheme
(use-package treesit
  :after myde-prog-scheme
  :config
  ;; Register Scheme grammar for future tree-sitter-based major mode
  ;; Currently no stable scheme-ts-mode on MELPA, but grammar is available
  (when (treesit-available-p)
    (add-to-list 'treesit-language-source-alist
      '(scheme "https://github.com/6cdh/tree-sitter-scheme"))))

;; Project root detection for Scheme toolchains
(use-package project
  :after myde-prog-scheme
  :config
  ;; Add Scheme-specific project markers
  (myde/prog-scheme-setup))

;; Built-in Scheme major mode
(use-package scheme
  :ensure nil  ;; Built-in to Emacs
  :mode (("\\.scm\\'" . scheme-mode)
         ("\\.ss\\'" . scheme-mode)
         ("\\.sls\\'" . scheme-mode))
  :hook (scheme-mode . eglot-ensure))

;; LSP support for Scheme via implementation-specific servers
;; scheme-langserver (general, R6RS/R7RS) or guile-lsp-server or chicken-lsp-server
(use-package eglot
  :ensure nil  ;; Built-in to Emacs 29+
  :config
  ;; Register dynamic LSP server detection
  ;; myde/prog-scheme-lsp-server returns the first available server
  (add-to-list 'eglot-server-programs
    `(scheme-mode . ,(lambda () (myde/prog-scheme-lsp-server)))))

;; Geiser: Interactive Scheme evaluation and REPL
;; Provides evaluation, debugging, documentation, macro expansion, etc.
(use-package geiser
  :ensure t
  :config
  ;; Make all installed Scheme backends available in M-x geiser prompt
  ;; User can choose implementation at runtime
  (setq geiser-active-implementations '(guile chicken chez)))

;; Geiser backend: GNU Guile
;; Best Emacs integration, debugger support, used by Guix
(use-package geiser-guile
  :ensure t)

;; Geiser backend: CHICKEN Scheme
;; Excellent C FFI, practical systems programming
(use-package geiser-chicken
  :ensure t)

;; Geiser backend: Chez Scheme
;; Highest performance native-compile implementation
(use-package geiser-chez
  :ensure t)

;; Formatting support: schemat (opt-in)
(use-package apheleia
  :after scheme
  :ensure t
  :config
  ;; Register schemat as Scheme formatter
  ;; schemat is cross-implementation (R5RS/R6RS/R7RS)
  ;; Install: cargo install schemat
  (add-to-list 'apheleia-formatters
    '(schemat . ("schemat")))
  (add-to-list 'apheleia-mode-alist
    '(scheme-mode . schemat))

  ;; Before-save guard: Only format if schemat is on PATH and eglot is active
  ;; This allows schemat to be optional; skips silently if absent
  (defun myde/prog-scheme-before-save-hook ()
    "Guard hook for schemat formatting in Scheme buffers."
    (when (myde/prog-scheme-format-buffer-maybe)
      (apheleia-format-buffer 'schemat)))
  (add-hook 'scheme-mode-hook
    (lambda () (add-hook 'before-save-hook #'myde/prog-scheme-before-save-hook nil t))))

;; Standard keybindings for geiser (C-c i prefix)
;; These are defaults from geiser but can be customized here if needed
(use-package geiser
  :after scheme
  :config
  ;; C-c i i — geiser (open REPL, prompts for implementation)
  ;; C-c i r — geiser-eval-region
  ;; C-c i b — geiser-eval-buffer
  ;; C-c i m — geiser-expand-last-sexp
  ;; C-c i z — geiser-switch-to-repl
  ;; C-c i d — geiser-doc
  ;; (Most are already bound by geiser; this is for documentation)
  nil)

;; Known Limitations
;;
;; 1. LSP is implementation-specific
;;    - scheme-langserver (Chez-based) is the best general option but requires Chez
;;    - guile-lsp-server and chicken-lsp-server are native alternatives
;;    - myde/prog-scheme-lsp-server auto-detects; user may need one installed
;;
;; 2. No scheme-ts-mode tree-sitter integration yet
;;    - Grammar is registered for future use
;;    - A stable scheme-ts-mode on MELPA would enable major-mode remapping
;;    - Until then, scheme-mode (regex-based) is used
;;
;; 3. schemat formatter is opt-in
;;    - Registered in apheleia but only runs if binary is on PATH
;;    - Install: cargo install schemat
;;    - Silent skip if absent (no error)
;;
;; 4. No structured test runner
;;    - Scheme lacks universal test framework integration (unlike CIDER or racket-mode)
;;    - Tests run via: C-c i b (eval buffer), M-x compile, or manual REPL
;;
;; 5. Geiser backend must match installed Scheme implementation
;;    - At least one of guile, chicken, chez must be installed
;;    - Geiser will prompt at M-x geiser to pick one
;;
;; 6. No DAP debugging
;;    - Scheme debugging is REPL-integrated via Geiser
;;    - When an error occurs (esp. Guile), Geiser shows *Geiser Dbg* buffer
;;    - Includes backtrace, frame inspection, breakpoints (not visual step-through)

(provide 'myde-prog-scheme-cfg)

;;; myde/prog-scheme/cfg.el ends here
