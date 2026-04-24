;;; cfg.el --- Python package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Package configuration for Python development support.
;;; Entry point for the prog-python module; loads lib.el automatically.
;;;
;;; Requires per-project mise.toml with Python version and venv activation.
;;; See python-ide-plan.md for full setup instructions.

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
  (myde/eglot-add-workspace-config
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
  :hook ((python-ts-mode . myde/python-ts-mode-setup)
         (python-ts-mode . myde/delete-trailing-whitespace-setup)
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

(provide 'myde-prog-python-cfg)
;;; cfg.el ends here
