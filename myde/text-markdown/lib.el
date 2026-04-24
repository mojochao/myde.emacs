;;; lib.el --- Markdown support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Library functions for Markdown editing support.
;;; Loaded by myde/text-markdown/cfg.el before package configuration.

;;; Code:

(require 'myde)

(defun myde/markdown-mode-setup ()
  "Set buffer-local settings for markdown-mode buffers."
  (setq-local fill-column 80
              tab-width 2
              indent-tabs-mode nil))

(provide 'myde-text-markdown)
;;; lib.el ends here
