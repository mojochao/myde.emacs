;;; lib.el --- TOML editing support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; TOML file editing utilities with tree-sitter and LSP support.

;;; Code:


(defun myde/toml-ts-or-plain-mode ()
  "Use `toml-ts-mode' if tree-sitter is available, otherwise fall back to `toml-mode'."
  (if (treesit-ready-p 'toml)
      (toml-ts-mode)
    (toml-mode)))

(defun myde/toml-ts-mode-setup ()
  "Set buffer-local settings for toml-ts-mode buffers."
  (setq-local fill-column 100
              tab-width 2
              indent-tabs-mode nil))

(provide 'myde-data-toml)
;;; lib.el ends here
