;;; cfg.el --- JSON editing configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; JSON and jq editing setup.
;;;
;;; Requires vscode-json-language-server on PATH (npm: vscode-langservers-extracted).

;;; Code:

(unless (featurep 'myde-data-json)
  (load-file (expand-file-name "myde/data-json/lib.el" user-emacs-directory)))

;; Built-in tree-sitter JSON mode; jsonl-mode is a derived mode defined in lib.el
(use-package json-ts-mode  ;; built-in (Emacs 29+)
  :mode (("\\.json\\'" . json-ts-mode)
         ("\\.jsonl\\'" . jsonl-mode))
  :hook (json-ts-mode . myde/json-ts-mode-hook)
  :ensure nil)

;; Register vscode-json-language-server for JSON buffers
(use-package eglot
  :after json-ts-mode
  :config
  (add-to-list 'eglot-server-programs
               '(json-ts-mode . ("vscode-json-language-server" "--stdio")))
  :ensure nil)

;; jq query file editing
(use-package jq-mode  ;; https://github.com/ljos/jq-mode
  :mode "\\.jq\\'"
  :ensure t)

(provide 'myde-data-json-cfg)
;;; cfg.el ends here
