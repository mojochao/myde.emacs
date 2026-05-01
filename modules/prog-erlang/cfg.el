;;; cfg.el --- Erlang package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Erlang development via erlang-mode, ELP LSP, and erlang-shell REPL.
;; Entry point for the prog-erlang module; loads lib.el automatically.
;;
;; Requires ELP (elp) on PATH (brew install erlang-ls/tap/elp).
;; erlang-mode ships with the Erlang/OTP distribution (tools/emacs).
;; This module is a dependency of prog-elixir (elixir-ts-mode :after erlang).
;;
;; Configures:
;;   treesit grammar          — Erlang grammar (registered for future ts-mode)
;;   eglot + elp              — LSP (completions, types, cross-references)
;;   erlang-mode              — .erl, .hrl, .escript files with flycheck
;;   C-c i i / C-c i s        — erlang-shell REPL; C-c i r for region send
;;   C-c t p                  — project test runner (myde-erlang-run-tests)


;;; Code:

(unless (featurep 'myde-prog-erlang)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(erlang "https://github.com/WhatsApp/tree-sitter-erlang"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + ELP
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook (erlang-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '(erlang-mode . ("elp" "server")))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Erlang mode
;; -----------------------------------------------------------------------------

(use-package erlang  ;; https://github.com/erlang/otp (tools/emacs)
  :hook ((erlang-mode . myde-erlang-mode-setup)
         (erlang-mode . myde-delete-trailing-whitespace-setup)
         (erlang-mode . flycheck-mode))
  :bind (:map erlang-mode-map
              ("C-c i i" . erlang-shell)
              ("C-c i s" . erlang-shell-buffer)
              ("C-c i r" . inferior-erlang-send-region)
              ("C-c t p" . myde-erlang-run-tests))
  :mode (("\\.erl\\'"     . erlang-mode)
         ("\\.hrl\\'"     . erlang-mode)
         ("\\.escript\\'" . erlang-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package ob-erlang  ;; https://github.com/xfwduke/ob-erlang
  :vc (:url "https://github.com/xfwduke/ob-erlang" :rev :newest)
  :after org
  :ensure t)

(provide 'myde-prog-erlang-cfg)
;;; cfg.el ends here
