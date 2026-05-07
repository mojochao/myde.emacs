;;; cfg.el --- Ruby package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Ruby development via ruby-mode, ruby-ts-mode, ruby-lsp LSP, rspec-mode,
;; inf-ruby REPL, robe code navigation, and rdbg debugger.
;; Entry point for the prog-ruby module; loads lib.el automatically.
;;
;; Requires ruby-lsp on PATH (gem install ruby-lsp).
;; Debugging requires rdbg on PATH (gem install debug).
;;
;; Configures:
;;   treesit grammar          — ruby grammar (auto-installed via treesit-auto)
;;   eglot + ruby-lsp         — LSP with formatting and inlay hints
;;   ruby-mode                — fallback major mode for .rb and related files
;;   ruby-ts-mode             — tree-sitter major mode for .rb and related files
;;   rspec-mode               — RSpec test runner (C-c t prefix)
;;   inf-ruby                 — interactive Ruby REPL (C-c i prefix)
;;   robe                     — REPL-backed code navigation and documentation
;;   dape + rdbg              — DAP debugging (ruby-debug config)
;;   ob-ruby                  — Org Babel Ruby block evaluation


;;; Code:

(unless (featurep 'myde-prog-ruby)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(ruby "https://github.com/tree-sitter/tree-sitter-ruby"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + ruby-lsp
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((ruby-ts-mode . eglot-ensure)
         (ruby-mode    . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '((ruby-ts-mode ruby-mode) . ("ruby-lsp")))
  (myde-eglot-add-workspace-config
   :rubyLsp '(:formatter "rubocop"
              :inlayHints (:implicitRescue t
                           :implicitHashValue t)))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Ruby mode (fallback, no tree-sitter)
;; -----------------------------------------------------------------------------

(use-package ruby-mode
  :hook ((ruby-mode . myde-ruby-mode-setup)
         (ruby-mode . myde-ruby-format-on-save-setup))
  :bind (:map ruby-mode-map
              ("C-c i i" . inf-ruby)
              ("C-c i r" . ruby-send-region)
              ("C-c i b" . ruby-send-buffer)
              ("C-c i s" . ruby-switch-to-inf))
  :mode (("\\.rb\\'"      . myde-ruby-ts-or-plain-mode)
         ("\\.rake\\'"    . myde-ruby-ts-or-plain-mode)
         ("\\.gemspec\\'" . myde-ruby-ts-or-plain-mode)
         ("Gemfile\\'"    . myde-ruby-ts-or-plain-mode)
         ("Rakefile\\'"   . myde-ruby-ts-or-plain-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Ruby tree-sitter mode
;; -----------------------------------------------------------------------------

(use-package ruby-ts-mode
  :hook ((ruby-ts-mode . myde-ruby-mode-setup)
         (ruby-ts-mode . myde-ruby-format-on-save-setup))
  :bind (:map ruby-ts-mode-map
              ("C-c i i" . inf-ruby)
              ("C-c i r" . ruby-send-region)
              ("C-c i b" . ruby-send-buffer)
              ("C-c i s" . ruby-switch-to-inf))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; RSpec test runner
;; -----------------------------------------------------------------------------

(use-package rspec-mode  ;; https://github.com/pezra/rspec-mode
  :hook ((ruby-mode    . rspec-mode)
         (ruby-ts-mode . rspec-mode))
  :bind (:map rspec-mode-map
              ("C-c t t" . rspec-verify-single)
              ("C-c t f" . rspec-verify)
              ("C-c t p" . rspec-verify-all)
              ("C-c t r" . rspec-rerun)
              ("C-c t x" . rspec-verify-failures))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Interactive Ruby REPL via inf-ruby
;; -----------------------------------------------------------------------------

(use-package inf-ruby  ;; https://github.com/nonsequitur/inf-ruby
  :hook ((ruby-mode    . inf-ruby-minor-mode)
         (ruby-ts-mode . inf-ruby-minor-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Code navigation and documentation via robe
;; -----------------------------------------------------------------------------

(use-package robe  ;; https://github.com/dgutov/robe
  :hook ((ruby-mode    . robe-mode)
         (ruby-ts-mode . robe-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugging via dape + rdbg
;; -----------------------------------------------------------------------------

(use-package dape
  :config
  (add-to-list 'dape-configs
               `(ruby-debug
                 modes (ruby-ts-mode ruby-mode)
                 command "rdbg"
                 command-args ("--open" "--host" "127.0.0.1" "--port" :port
                               "-c" "--" "ruby" dape-buffer-default)
                 port :autoport
                 :type "Ruby"
                 :request "launch"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((ruby . t))))
  :ensure nil)

(use-package indent-bars
  :hook ((ruby-ts-mode ruby-mode) . indent-bars-mode))

(provide 'myde-prog-ruby-cfg)
;;; cfg.el ends here
