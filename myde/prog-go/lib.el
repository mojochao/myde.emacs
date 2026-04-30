;;; lib.el --- Go support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Library functions for Go development support.
;;; Loaded by myde/prog-go/cfg.el before package configuration.

;;; Code:


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
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde/go-format-on-save-setup ()
  "Install buffer-local before-save formatting for go-ts-mode."
  (add-hook 'before-save-hook #'myde/go-eglot-format-buffer nil t))

(provide 'myde-prog-go)
;;; lib.el ends here
