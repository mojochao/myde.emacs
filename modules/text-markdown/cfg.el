;;; cfg.el --- Markdown package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for Markdown editing via markdown-mode.
;;; Entry point for the text-markdown module; loads lib.el automatically.
;;;
;;; .md and README.md files activate gfm-mode (GitHub-Flavored Markdown variant).
;;; Requires multimarkdown on PATH for C-c C-e (markdown-do) rendering/export.
;;; Line numbers and trailing-whitespace cleanup activate on all markdown buffers.


;;; Code:

(unless (featurep 'myde-text-markdown)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Markdown mode
;; -----------------------------------------------------------------------------

(use-package markdown-mode  ;; https://github.com/jrblevin/markdown-mode
  :init
  (setq markdown-command "multimarkdown")
  :mode (("\\.md\\'"        . gfm-mode)
         ("README\\.md\\'"  . gfm-mode))
  :hook ((markdown-mode . myde-markdown-mode-setup)
         (markdown-mode . display-line-numbers-mode)
         (markdown-mode . myde-delete-trailing-whitespace-setup))
  :bind (:map markdown-mode-map
              ("C-c C-e" . markdown-do))
  :ensure t)

(provide 'myde-text-markdown-cfg)
;;; cfg.el ends here
