;;; lib.el --- JavaScript support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Library functions for JavaScript/JSX development support.
;;; Loaded by myde-prog-javascript/cfg.el before package configuration.
;;;
;;; All external dependencies are shared with myde-prog-typescript — no
;;; additional global installs are required beyond what that module needs:
;;;
;;;   npm install -g typescript-language-server typescript
;;;   npm install -g vscode-langservers-extracted
;;;   npm install -g prettier
;;;   npm install -g @vscode/js-debug
;;;   pip install rassumfrassum
;;;
;;; LSP is multiplexed via rassumfrassum's tslint preset:
;;;   rass tslint -> typescript-language-server + vscode-eslint-language-server
;;;
;;; typescript-language-server handles JS natively.  :checkJs t is passed in
;;; initializationOptions to enable JSDoc-based type inference for plain JS.
;;;
;;; js-ts-mode handles both .js and .jsx — the javascript tree-sitter grammar
;;; has native JSX node types; no separate mode or grammar is needed for JSX.


;;; Code:

(defun myde-js-ts-mode-setup ()
  "Set buffer-local settings for js-ts-mode buffers."
  (setq-local indent-tabs-mode nil
              tab-width 2
              fill-column 100))

(defun myde-javascript-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde-javascript-format-on-save-setup ()
  "Install buffer-local before-save formatting for js-ts-mode."
  (add-hook 'before-save-hook #'myde-javascript-eglot-format-buffer nil t))

(defun myde-javascript-mode-hook ()
  "Hook for js-ts-mode buffers.
Enables inlay hints when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-inlay-hints-mode 1)))

(provide 'myde-prog-javascript)
;;; lib.el ends here
