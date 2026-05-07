;;; myde-prog-clisp/cfg.el --- Common Lisp development environment configuration -*- lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:

;; Common Lisp development via SLY (primary REPL), SLIME (fallback), and optional LSP.
;; Entry point for the prog-clisp module; loads lib.el automatically.
;;
;; paredit and rainbow-delimiters are activated via prog-base (shared across all
;; Lisp-family languages); only CL-specific packages are added here.
;;
;; Design decisions:
;;   lisp-mode (built-in)     — base mode for .lisp, .cl, .asd files
;;   SLY (primary REPL)       — modern interactive evaluation with stickers
;;   SLIME (fallback REPL)    — activated only when SLY is absent
;;   FiveAM                   — CL test framework; run via REPL or asdf:test-system
;;   cl-indent.el (built-in)  — CL indentation with &body macro support; zero deps
;;   eglot + cl-lsp (opt-in)  — LSP via Roswell; skipped when `ros` is not on PATH
;;   SLDB (integrated)        — debugger built into SLY/SLIME; no DAP needed
;;
;; Keybindings (C-c i prefix): i=start REPL, r=eval-region, b=eval-buffer,
;;   e=eval-last-expression, d=documentation, z=switch-to-repl.


;;; Code:

(unless (featurep 'myde-prog-clisp)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; Tree-sitter grammar registration for Common Lisp
(use-package treesit
  :after myde-prog-clisp
  :config
  ;; Register Common Lisp grammar for future tree-sitter-based major mode
  ;; Currently no stable commonlisp-ts-mode on MELPA, but grammar is available
  (when (treesit-available-p)
    (add-to-list 'treesit-language-source-alist
      '(commonlisp "https://github.com/tree-sitter/tree-sitter-commonlisp"))))

;; Project root detection for CL toolchains
(use-package project
  :after myde-prog-clisp
  :config
  ;; Add Common Lisp-specific project markers
  (myde-prog-clisp-setup))

;; Built-in Common Lisp major mode
(use-package lisp-mode
  :ensure nil  ;; Built-in to Emacs
  :mode (("\\.lisp\\'" . lisp-mode)
         ("\\.cl\\'" . lisp-mode)
         ("\\.asd\\'" . lisp-mode))
  :hook (lisp-mode . myde-prog-clisp-lisp-mode-setup))

;; SLY: Primary REPL for interactive Common Lisp development
;; Modern UX, stickers (live feedback), excellent debugger integration
(use-package sly
  :defer t
  :config
  ;; Initialize SLY configuration
  (myde-prog-clisp-sly-init)

  ;; Enable multiple simultaneous REPLs
  (setq sly-mrepl-history-file-name nil)

  ;; SLY test runner keybindings (standard myde pattern)
  ;; Note: These are aspirational; SLY doesn't have built-in FiveAM test runner
  ;; Tests are run via: C-c i b (eval buffer), manual REPL, or asdf:test-system
  ;; Documented for future integration with SLY test framework enhancements
  (define-key sly-mode-map (kbd "C-c t b") 'sly-eval-buffer)
  (define-key sly-mode-map (kbd "C-c i i") 'sly)
  (define-key sly-mode-map (kbd "C-c i r") 'sly-eval-region)
  (define-key sly-mode-map (kbd "C-c i b") 'sly-eval-buffer)
  (define-key sly-mode-map (kbd "C-c i e") 'sly-eval-last-expression)
  (define-key sly-mode-map (kbd "C-c i d") 'sly-documentation)
  (define-key sly-mode-map (kbd "C-c i z") 'sly-switch-to-repl)
  :ensure t)

;; SLIME: Fallback REPL for Common Lisp (larger ecosystem if SLY unavailable)
;; Battle-tested stability (20+ years), excellent debugging (SLDB)
(use-package slime
  :defer t
  :config
  ;; Only initialize if SLY is not available
  ;; Both can coexist but SLY is primary
  (unless (featurep 'sly)
    (myde-prog-clisp-slime-init)

    ;; SLIME keybindings (same C-c i prefix for consistency)
    (define-key slime-mode-map (kbd "C-c i i") 'slime)
    (define-key slime-mode-map (kbd "C-c i r") 'slime-eval-region)
    (define-key slime-mode-map (kbd "C-c i b") 'slime-eval-buffer)
    (define-key slime-mode-map (kbd "C-c i e") 'slime-eval-last-expression)
    (define-key slime-mode-map (kbd "C-c i d") 'slime-documentation)
    (define-key slime-mode-map (kbd "C-c i z") 'slime-switch-to-repl))
  :ensure t)

;; FiveAM: Test framework documentation
;; FiveAM is a Common Lisp package (not an Emacs package), so it's not managed via MELPA
;; It's typically loaded in test files via ASDF or manually in REPL
;;
;; Example in REPL:
;;   (asdf:test-system 'my-system)
;;   (fiveam:run! 'my-test-suite)
;;
;; Install in your CL project:
;;   (ql:quickload "fiveam")
;;
;; Documented alternative: Rove (v0.10 BETA)
;; Modern syntax but not recommended until stable version 1.0
;; Install via: (ql:quickload "rove")
;; Usage: (rove:run #'test-function)

;; cl-indent.el: Built-in Common Lisp indentation (zero dependencies)
;; Handles &body and other macro indentation patterns excellently
(use-package cl-indent
  :ensure nil  ;; Built-in to Emacs
  :config
  ;; cl-indent.el provides optimal indentation for CL
  ;; No external dependencies required
  ;;
  ;; ALTERNATIVE: nice-lisp formatter (commented below)
  ;; Requires: (ql:quickload "trivial-formatter") in your CL system
  ;; Then: (nice-lisp:format-string code)
  ;; Uncomment if you install nice-lisp:
  ;;
  ;; (use-package apheleia
  ;;   :config
  ;;   (add-to-list 'apheleia-formatters
  ;;     '(nice-lisp . ("sbcl" "--noinform" "--load" "format.lisp" "--eval" 
  ;;                    "(nice-lisp:format-string (read-file-as-string 0))")))
  ;;   (add-to-list 'apheleia-mode-alist
  ;;     '(lisp-mode . nice-lisp)))
  nil)

;; Eglot: LSP support (optional, requires Roswell + cl-lsp)
(use-package eglot
  :ensure nil  ;; Built-in to Emacs 29+
  :config
  ;; cl-lsp is optional; only setup if Roswell is available
  ;; SLIME/SLY provide superior interactive feedback anyway
  (when (executable-find "ros")
    (let ((lsp-cmd (myde-prog-clisp-lsp-server)))
      (when lsp-cmd
        (add-to-list 'eglot-server-programs
          `(lisp-mode . ,lsp-cmd))
        (add-hook 'lisp-mode-hook 'eglot-ensure)))))

;; Known Limitations
;;
;; 1. No Structured Test Runner in Emacs
;;    - FiveAM/Rove don't have Emacs-side runners like CIDER (Clojure)
;;    - Tests run via: C-c i b (eval buffer), manual REPL, or (asdf:test-system ...)
;;
;; 2. LSP is Optional, Not Primary
;;    - SLIME/SLY provide better interactive feedback (REPL paradigm > LSP)
;;    - cl-lsp requires Roswell; gracefully skipped if unavailable
;;
;; 3. No Standard Common Lisp Formatter
;;    - CL community lacks agreement (unlike Python's black, Rust's rustfmt)
;;    - cl-indent.el (built-in) is sufficient for most users
;;    - nice-lisp available as commented alternative
;;
;; 4. No commonlisp-ts-mode Yet
;;    - tree-sitter-commonlisp exists but no corresponding Emacs mode on MELPA
;;    - Grammar registered for future compatibility
;;    - lisp-mode (regex-based) sufficient for now
;;
;; 5. SLY vs SLIME Coexistence
;;    - Both can be installed; myde prioritizes SLY (modern)
;;    - Falls back to SLIME via (unless (featurep 'sly) ...) guard
;;    - User picks implementation at M-x sly / M-x slime runtime
;;
;; 6. SLDB Debugging Model
;;    - SLDB is integrated into REPL (Lisp Machine paradigm)
;;    - Superior to DAP for interactive Lisp development
;;    - Not a GUI step-through debugger like dape
;;
;; 7. Multiple CL Implementations
;;    - SBCL is primary (most popular, best ecosystem)
;;    - SLY/SLIME auto-detect available implementations
;;    - User picks at M-x sly / M-x slime startup

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

;; ob-lisp uses sly-eval when SLY is loaded (preferred over the SLIME default)
(use-package org
  :config
  (setq org-babel-lisp-eval-fn #'sly-eval)
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((lisp . t))))
  :ensure nil)

(use-package indent-bars
  :hook (lisp-mode . indent-bars-mode))

(provide 'myde-prog-clisp-cfg)

;;; myde-prog-clisp/cfg.el ends here
