;;; lib.el --- Go support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Library functions for Go development support.
;;; Loaded by myde/prog-go/cfg.el before package configuration.

;;; Code:

(require 'myde)

(defun myde/go-ts-or-plain-mode ()
  "Use `go-ts-mode' if tree-sitter is available, otherwise fall back to `go-mode'."
  (if (treesit-ready-p 'go)
      (go-ts-mode)
    (go-mode)))

(defun myde/go-ts-mode-setup ()
  "Set buffer-local settings for go-ts-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode t
              fill-column 100
              compile-command "go test ./..."))

(defun myde/go-eglot-format-buffer ()
  "Format buffer via eglot when in go-ts-mode and eglot is active.
Safe to add to `before-save-hook' globally; it is a no-op outside
of go-ts-mode buffers and buffers where eglot is not managing."
  (when (and (eq major-mode 'go-ts-mode)
             (bound-and-true-p eglot--managed-mode))
    (eglot-format-buffer)))

(provide 'myde-prog-go)
;;; lib.el ends here
