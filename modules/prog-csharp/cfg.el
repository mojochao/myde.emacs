;;; cfg.el --- C# package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; C# development via csharp-mode, csharp-ts-mode, csharp-ls LSP, and netcoredbg debugger.
;; Entry point for the prog-csharp module; loads lib.el automatically.
;;
;; Requires csharp-ls on PATH (dotnet tool install -g csharp-ls).
;; Debugging requires netcoredbg on PATH (https://github.com/Samsung/netcoredbg).
;; Org Babel evaluation requires Mono (brew install mono) for ob-csharp.
;;
;; Configures:
;;   treesit grammar          — c-sharp grammar (auto-installed via treesit-auto)
;;   eglot + csharp-ls        — LSP with formatting and inlay hints
;;   csharp-mode              — fallback major mode for .cs/.csproj/.sln files
;;   csharp-ts-mode           — tree-sitter major mode for .cs/.csproj/.sln files
;;   C-c t p                  — run project tests (dotnet test)
;;   dape + netcoredbg        — DAP debugging (csharp-debug config)
;;   ob-csharp                — Org Babel C# block evaluation


;;; Code:

(unless (featurep 'myde-prog-csharp)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(c-sharp "https://github.com/tree-sitter/tree-sitter-c-sharp"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + csharp-ls
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((csharp-ts-mode . eglot-ensure)
         (csharp-mode    . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '((csharp-ts-mode csharp-mode) . ("csharp-ls")))
  (myde/eglot-add-workspace-config
   :csharp '(:inlayHints (:parameterNames t
                          :types t)
             :formatting (:enable t)))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; C# mode (fallback, no tree-sitter)
;; -----------------------------------------------------------------------------

(use-package csharp-mode
  :hook ((csharp-mode . myde/csharp-mode-setup)
         (csharp-mode . myde/delete-trailing-whitespace-setup)
         (csharp-mode . myde/csharp-format-on-save-setup))
  :bind (:map csharp-mode-map
              ("C-c t p" . myde/csharp-run-tests))
  :mode (("\\.cs\\'"     . myde/csharp-ts-or-plain-mode)
         ("\\.csproj\\'" . myde/csharp-ts-or-plain-mode)
         ("\\.sln\\'"    . myde/csharp-ts-or-plain-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; C# tree-sitter mode
;; -----------------------------------------------------------------------------

(use-package csharp-ts-mode
  :hook ((csharp-ts-mode . myde/csharp-mode-setup)
         (csharp-ts-mode . myde/delete-trailing-whitespace-setup)
         (csharp-ts-mode . myde/csharp-format-on-save-setup))
  :bind (:map csharp-ts-mode-map
              ("C-c t p" . myde/csharp-run-tests))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Debugging via dape + netcoredbg
;; -----------------------------------------------------------------------------

(use-package dape
  :config
  (add-to-list 'dape-configs
               `(csharp-debug
                 modes (csharp-ts-mode csharp-mode)
                 command "netcoredbg"
                 command-args ("--interpreter=vscode")
                 :type "coreclr"
                 :request "launch"
                 :program ,#'myde/csharp-dape-binary
                 :stopAtEntry nil))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package ob-csharp  ;; https://github.com/thomas-villagers/ob-csharp
  :vc (:url "https://github.com/thomas-villagers/ob-csharp" :rev :newest :lisp-dir "src")
  :load-path "elpa/ob-csharp/src"
  :after org
  :ensure t)

(provide 'myde-prog-csharp-cfg)
;;; cfg.el ends here
