;;; cfg.el --- Python package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for Python development support.
;;; Entry point for the prog-python module; loads lib.el automatically.
;;;
;;; Requires basedpyright-langserver on PATH (pip install basedpyright or via mise).
;;; Per-project mise.toml must activate the correct Python version and venv so
;;; that eglot and ruff resolve the right interpreter and installed packages.
;;;
;;; Configures:
;;;   eglot + basedpyright   — LSP with workspace-mode type checking and inlay hints
;;;   python-ts-mode          — tree-sitter mode for .py files; C-c i REPL bindings
;;;   ruff-format             — format-on-save (replaces black + isort)
;;;   python-pytest           — pytest runner (C-c t prefix, dispatch via C-c t m)
;;;   dape + debugpy          — DAP debugging (python-debug and python-test configs)


;;; Code:

(unless (featurep 'myde-prog-python)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(python "https://github.com/tree-sitter/tree-sitter-python"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + basedpyright
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook (python-ts-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode) . ("basedpyright-langserver" "--stdio")))
  (myde-eglot-add-workspace-config
   :basedpyright '(:typeCheckingMode "standard"
                   :useLibraryCodeForTypes t
                   :diagnosticMode "workspace"
                   :inlayHints (:variableTypes t
                                :functionReturnTypes t
                                :callArgumentNames t
                                :genericTypes t)))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Python mode
;; -----------------------------------------------------------------------------

(use-package python
  :hook ((python-ts-mode . myde-python-ts-mode-setup)
         (python-ts-mode . flycheck-mode))
  :bind (:map python-ts-mode-map
              ("C-c i i" . run-python)
              ("C-c i r" . python-shell-send-region)
              ("C-c i b" . python-shell-send-buffer)
              ("C-c i d" . python-shell-send-defun)
              ("C-c i s" . python-shell-switch-to-shell))
  :mode ("\\.py\\'" . python-ts-mode)
  :ensure nil)

(use-package ruff-format  ;; https://github.com/scop/emacs-ruff-format
  :hook (python-ts-mode . ruff-format-on-save-mode)
  :ensure t)

(use-package python-pytest  ;; https://github.com/wbolster/emacs-python-pytest
  :after python
  :bind (:map python-ts-mode-map
              ("C-c t t" . python-pytest-function-dwim)
              ("C-c t f" . python-pytest-file-dwim)
              ("C-c t p" . python-pytest)
              ("C-c t r" . python-pytest-repeat)
              ("C-c t x" . python-pytest-last-failed)
              ("C-c t m" . python-pytest-dispatch))
  :custom
  (python-pytest-unsaved-buffers-behavior 'save-all)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugging via dape + debugpy
;; -----------------------------------------------------------------------------

(use-package dape
  :after transient
  :config
  (add-to-list 'dape-configs
               '(python-debug
                 modes (python-mode python-ts-mode)
                 command "python"
                 command-args ("-m" "debugpy.adapter")
                 :type "python"
                 :request "launch"
                 :program dape-buffer-default
                 :justMyCode nil))
  (add-to-list 'dape-configs
               '(python-test
                 modes (python-mode python-ts-mode)
                 command "python"
                 command-args ("-m" "debugpy.adapter")
                 :type "python"
                 :request "launch"
                 :module "pytest"
                 :args ["-x" "-s"]
                 :justMyCode nil))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((python . t))))
  :ensure nil)

(use-package indent-bars
  :hook (python-ts-mode . indent-bars-mode))

(provide 'myde-prog-python-cfg)
;;; cfg.el ends here
