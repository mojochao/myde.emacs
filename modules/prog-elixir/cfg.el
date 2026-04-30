;;; cfg.el --- Elixir package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for Elixir and Phoenix (HEEx) development support.
;;; Entry point for the prog-elixir module; loads lib.el automatically.
;;;
;;; Depends on: prog-erlang (elixir-ts-mode :after erlang)
;;; elixir-ls is resolved per-project via mise (myde/mise-exec-which).
;;;
;;; Configures:
;;;   elixir-ts-mode + heex-ts-mode — tree-sitter modes for .ex/.exs/.heex files
;;;   eglot + elixir-ls             — LSP (completions, types, code actions)
;;;   dap-mode dap-elixir           — DAP debugging adapter
;;;   exunit                        — ExUnit test runner (C-c t prefix)
;;;   elixir-iex                    — IEx REPL via eat (C-c i prefix)
;;;   mix                           — Mix task dispatch minor mode
;;;   flycheck-credo                — Credo style linting
;;;   flycheck-dialyxir             — Dialyzer type analysis


;;; Code:

(unless (featurep 'myde-prog-elixir)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammars
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(elixir "https://github.com/elixir-lang/tree-sitter-elixir"))
  (add-to-list 'treesit-language-source-alist
               '(heex "https://github.com/phoenixframework/tree-sitter-heex"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + elixir-ls
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((elixir-ts-mode . eglot-ensure)
         (heex-ts-mode   . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '(elixir-ts-mode . (lambda (dir) (myde/mise-exec-which dir "elixir-ls"))))
  (add-to-list 'eglot-server-programs
               '(heex-ts-mode . (lambda (dir) (myde/mise-exec-which dir "elixir-ls"))))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; DAP debugger (Elixir adapter loaded from dap-mode)
;; -----------------------------------------------------------------------------

(use-package dap-mode
  :after transient
  :config
  (require 'dap-elixir)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Elixir and HEEx modes
;; -----------------------------------------------------------------------------

(use-package elixir-ts-mode
  :after erlang
  :mode (("\\.ex\\'"   . elixir-ts-mode)
         ("\\.exs\\'"  . elixir-ts-mode)
         ("\\.heex\\'" . elixir-ts-mode))
  :hook ((elixir-ts-mode . myde/elixir-ts-ensure-grammars)
         (elixir-ts-mode . flycheck-mode)
         (elixir-ts-mode . myde/delete-trailing-whitespace-setup)
         (elixir-ts-mode . yas-minor-mode))
  :ensure nil)

(use-package heex-ts-mode  ;; https://github.com/wkirschbaum/heex-ts-mode
  :after elixir-ts-mode
  :mode ("\\.heex\\'" . heex-ts-mode)
  :hook ((heex-ts-mode . myde/delete-trailing-whitespace-setup)
         (heex-ts-mode . yas-minor-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Testing
;; -----------------------------------------------------------------------------

(use-package exunit  ;; https://github.com/ananthakumaran/exunit.el
  :after elixir-ts-mode
  :hook (elixir-ts-mode . exunit-mode)
  :bind (:map exunit-mode-map
              ("C-c t a" . exunit-verify-all)
              ("C-c t s" . exunit-verify-single)
              ("C-c t t" . exunit-toggle-file-and-test))
  :ensure t)

;; -----------------------------------------------------------------------------
;; REPL
;; -----------------------------------------------------------------------------

(use-package elixir-iex  ;; https://github.com/mojochao/elixir-iex
  :after (elixir-ts-mode eat)
  :hook (elixir-ts-mode . elixir-iex-minor-mode)
  :bind (:map elixir-iex-minor-mode-map
              ("C-c i i" . elixir-iex)
              ("C-c i p" . elixir-iex-project)
              ("C-c i l" . elixir-iex-send-line)
              ("C-c i r" . elixir-iex-send-region)
              ("C-c i b" . elixir-iex-send-buffer)
              ("C-c i m" . elixir-iex-reload-module)
              ("C-c i s" . elixir-iex-set-repl))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Linting
;; -----------------------------------------------------------------------------

(use-package flycheck-credo  ;; https://github.com/aaronjensen/flycheck-credo
  :after flycheck
  :config
  (flycheck-credo-setup)
  (setq flycheck-elixir-credo-strict t)
  :ensure t)

(use-package flycheck-dialyxir  ;; https://github.com/aaronjensen/flycheck-dialyxir
  :after flycheck
  :config
  (flycheck-dialyxir-setup)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Mix task runner
;; -----------------------------------------------------------------------------

(use-package mix  ;; https://github.com/ayrat555/mix.el
  :after elixir-ts-mode
  :hook (elixir-ts-mode . mix-minor-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package ob-elixir  ;; https://github.com/zweifisch/ob-elixir
  :after org
  :ensure t)

(provide 'myde-prog-elixir-cfg)
;;; cfg.el ends here
