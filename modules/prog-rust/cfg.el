;;; cfg.el --- Rust package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Rust development via rustic, rust-analyzer LSP, and codelldb debugger.
;; Entry point for the prog-rust module; loads lib.el automatically.
;;
;; Requires rust-analyzer on PATH (rustup component add rust-analyzer).
;; Debugging requires codelldb on PATH (mason or manual install).
;;
;; Configures:
;;   treesit grammar          — rust grammar (auto-installed via treesit-auto)
;;   eglot + rust-analyzer    — LSP with clippy-on-save, inlay hints, proc-macro support
;;   rustic                   — primary Rust mode (eglot LSP client, rustfmt on save)
;;   C-c t t / C-c t p        — current test and full cargo test via rustic-cargo
;;   dape + codelldb          — DAP debugging (rust-debug and rust-test configs)


;;; Code:

(unless (featurep 'myde-prog-rust)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(rust "https://github.com/tree-sitter/tree-sitter-rust"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + rust-analyzer
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((rustic-mode  . eglot-ensure)
         (rust-ts-mode . eglot-ensure)
         (rust-mode    . eglot-ensure))
  :config
  (myde-eglot-add-workspace-config
   :rust-analyzer '(:checkOnSave (:command "clippy")
                    :inlayHints (:typeHints (:enable t)
                                 :parameterHints (:enable t)
                                 :chainingHints (:enable t)
                                 :closureReturnTypeHints (:enable t))
                    :completion (:callable (:snippets "fill_arguments")
                                 :postfix (:enable t))
                    :cargo (:buildScripts (:enable t)
                           :features "all")
                    :procMacro (:enable t)))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Rust mode via rustic
;; -----------------------------------------------------------------------------

(use-package rustic  ;; https://github.com/emacs-rustic/rustic
  :init
  (setq rustic-lsp-client 'eglot
        rust-mode-treesitter-derive t
        rustic-format-trigger 'on-save)
  :hook ((rustic-mode . myde-rust-mode-setup)
         (rustic-mode . myde-delete-trailing-whitespace-setup))
  :bind (:map rustic-mode-map
              ("C-c t t" . rustic-cargo-current-test)
              ("C-c t p" . rustic-cargo-test))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugging via dape + codelldb
;; -----------------------------------------------------------------------------

(use-package dape
  :config
  (add-to-list 'dape-configs
               `(rust-debug
                 modes (rustic-mode rust-ts-mode rust-mode)
                 command "codelldb"
                 command-args ("--port" :port)
                 port :autoport
                 :type "lldb"
                 :request "launch"
                 :program ,#'myde-rust-dape-debug-program))
  (add-to-list 'dape-configs
               `(rust-test
                 modes (rustic-mode rust-ts-mode rust-mode)
                 command "codelldb"
                 command-args ("--port" :port)
                 port :autoport
                 :type "lldb"
                 :request "launch"
                 :args ["--test"]
                 :program ,#'myde-rust-dape-debug-program))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package ob-rust  ;; https://github.com/micanzhang/ob-rust
  :after org
  :ensure t)

(provide 'myde-prog-rust-cfg)
;;; cfg.el ends here
