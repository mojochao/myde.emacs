;;; myde/prog-clojure/cfg.el --- Clojure development environment configuration -*- lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:

;; Clojure development via clojure-ts-mode, clojure-lsp (eglot), CIDER, and apheleia.
;; Entry point for the prog-clojure module; loads lib.el automatically.
;;
;; Requires clojure-lsp on PATH (brew install clojure-lsp).
;; paredit and rainbow-delimiters are activated via prog-base (shared across all
;; Lisp-family languages); only Clojure-specific packages are added here.
;;
;; Design decisions:
;;   clojure-ts-mode (primary) — tree-sitter mode for .clj/.cljs/.cljc
;;   clojure-mode (dependency) — loaded silently; required by CIDER
;;   eglot + clojure-lsp       — static analysis LSP
;;   CIDER + nREPL             — dynamic evaluation and interactive testing
;;   apheleia + cljfmt         — format-on-save via clojure-lsp (zero extra install)
;;   zprint (opt-in)           — commented alternative formatter; enable per-project
;;
;; CIDER test keybindings (C-c t prefix): t=at-point, f=ns-tests, p=project, r=rerun.


;;; Code:

(unless (featurep 'myde-prog-clojure)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

(use-package treesit
  :after myde-prog-clojure
  :config
  ;; Register Clojure grammar for system-wide availability
  (when (treesit-available-p)
    (add-to-list 'treesit-language-source-alist
      '(clojure "https://github.com/tree-sitter/tree-sitter-clojure"))))

(use-package project
  :after myde-prog-clojure
  :config
  ;; Add Clojure-specific project root markers
  (myde/prog-clojure-setup))

;; Load clojure-mode silently (required as CIDER's undeclared dependency)
;; Future: clojure-ts-mode will subsume clojure-mode (Emacs 32+)
(use-package clojure-mode
  :ensure t
  :init
  ;; Don't show clojure-mode in mode-line; clojure-ts-mode is primary
  (setq auto-mode-alist (rassq-delete-all 'clojure-mode auto-mode-alist)))

(use-package clojure-ts-mode
  :ensure t
  :defer t
  :mode (("\\.clj\\'" . clojure-ts-mode)
         ("\\.cljs\\'" . clojure-ts-mode)
         ("\\.cljc\\'" . clojure-ts-mode))
  :init
  ;; Prefer clojure-ts-mode when available
  (add-to-list 'major-mode-remap-alist '(clojure-mode . clojure-ts-mode)))

(use-package eglot
  :ensure nil  ;; Built-in to Emacs 29+
  :hook ((clojure-ts-mode . eglot-ensure)
         (clojure-mode . eglot-ensure))
  :config
  ;; Register clojure-lsp server for Clojure modes
  ;; Requires: brew install clojure-lsp
  (add-to-list 'eglot-server-programs
    '(clojure-ts-mode . ("clojure-lsp")))
  (add-to-list 'eglot-server-programs
    '(clojure-mode . ("clojure-lsp")))
  (add-to-list 'eglot-server-programs
    '(clojurescript-mode . ("clojure-lsp"))))

(use-package cider
  :ensure t
  :after clojure-ts-mode
  :defer t
  :hook (clojure-ts-mode . cider-mode)
  :config
  ;; Setup CIDER configuration
  (myde/prog-clojure-cider-setup)

  ;; Disable CIDER's eldoc display for symbol-at-point to let CIDER's
  ;; eldoc (arglists, docstrings) take precedence when active
  (setq cider-eldoc-display-for-symbol-at-point nil)

  ;; CIDER test runner keybindings (standard myde pattern)
  ;; C-c t t = test at point
  ;; C-c t f = test file
  ;; C-c t p = test project
  ;; C-c t r = rerun last test
  (define-key cider-mode-map (kbd "C-c t t") 'cider-test-run-test)
  (define-key cider-mode-map (kbd "C-c t f") 'cider-test-run-ns-tests)
  (define-key cider-mode-map (kbd "C-c t p") 'cider-test-run-project-tests)
  (define-key cider-mode-map (kbd "C-c t r") 'cider-test-run-loaded-tests))

(use-package apheleia
  :after clojure-ts-mode
  :ensure t
  :config
  ;; Register cljfmt (built into clojure-lsp) as default formatter
  (add-to-list 'apheleia-formatters
    '(cljfmt . ("clojure-lsp" "format" "-")))
  (add-to-list 'apheleia-mode-alist
    '(clojure-ts-mode . cljfmt))
  (add-to-list 'apheleia-mode-alist
    '(clojure-mode . cljfmt))

  ;; ALTERNATIVE: zprint formatter (opt-in)
  ;; Requires: brew install zprint
  ;; More aggressive formatting than cljfmt; highly customizable via .dir-locals.el
  ;;
  ;; Uncomment to enable:
  ;; (add-to-list 'apheleia-formatters
  ;;   '(zprint . ("zprint" "-")))
  ;; (add-to-list 'apheleia-mode-alist
  ;;   '(clojure-ts-mode . zprint))
  ;; (add-to-list 'apheleia-mode-alist
  ;;   '(clojure-mode . zprint))
  ;;
  ;; Then configure CIDER formatter in myde/prog-clojure-cider-setup:
  ;; (setq cider-format-code-options {:style :community})
  ;;
  ;; Or via .dir-locals.el in project root:
  ;; ((clojure-ts-mode
  ;;   (apheleia-formatter . zprint)
  ;;   (cider-format-code-options . {:style :community})))
  )

;; paredit and rainbow-delimiters are configured in prog-base
;; (shared across all Lisp-family languages)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

;; ob-clojure uses CIDER automatically when it is loaded
(use-package org
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((clojure . t))))
  :ensure nil)

(provide 'myde-prog-clojure-cfg)

;;; myde/prog-clojure/cfg.el ends here
