;;; lib.el --- TypeScript support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Library functions for TypeScript/TSX development support.
;;; Loaded by myde-prog-typescript/cfg.el before package configuration.
;;;
;;; External dependencies (install once, globally):
;;;   npm install -g typescript-language-server typescript
;;;   npm install -g vscode-langservers-extracted
;;;   npm install -g prettier
;;;   npm install -g ts-node
;;;   npm install -g @vscode/js-debug
;;;   pip install rassumfrassum
;;;
;;; LSP is multiplexed via rassumfrassum's tslint preset:
;;;   rass tslint -> typescript-language-server + vscode-eslint-language-server


;;; Code:

(defun myde-typescript-ts-mode-setup ()
  "Set buffer-local settings for typescript-ts-mode buffers."
  (setq-local indent-tabs-mode nil
              tab-width 2
              fill-column 100))

(defun myde-tsx-ts-mode-setup ()
  "Set buffer-local settings for tsx-ts-mode buffers."
  (setq-local indent-tabs-mode nil
              tab-width 2
              fill-column 100))

(defun myde-typescript-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde-typescript-format-on-save-setup ()
  "Install buffer-local before-save formatting for TypeScript/TSX modes."
  (add-hook 'before-save-hook #'myde-typescript-eglot-format-buffer nil t))

(defun myde-typescript-mode-hook ()
  "Shared hook for typescript-ts-mode and tsx-ts-mode buffers.
Enables inlay hints when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-inlay-hints-mode 1)))

(provide 'myde-prog-typescript)
;;; lib.el ends here
