;;; cfg.el --- JSON editing configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; JSON and jq editing via json-ts-mode and jq-mode.
;;; Entry point for the data-json module; loads lib.el automatically.
;;;
;;; Requires vscode-json-language-server on PATH (npm install -g vscode-langservers-extracted).
;;; .json and .jsonl files use json-ts-mode; jsonl-mode is a derived mode defined in lib.el.
;;; .jq files use jq-mode for jq query authoring.


;;; Code:

(unless (featurep 'myde-data-json)
  (load-file (expand-file-name "modules/data-json/lib.el" user-emacs-directory)))

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
