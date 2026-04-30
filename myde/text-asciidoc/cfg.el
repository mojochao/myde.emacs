;;; cfg.el --- AsciiDoc package configuration for myde -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for AsciiDoc editing via adoc-mode.
;;; Entry point for the text-asciidoc module; loads lib.el automatically.
;;;
;;; Activates for .adoc, .asciidoc, and .asc files.  Provides:
;;;
;;;   Writing    -- adoc-mode syntax highlighting, outline navigation,
;;;                 visual-line-mode soft-wrap, auto-fill at column 80.
;;;   Linting    -- flycheck with the built-in asciidoctor checker flags
;;;                 document errors and warnings as you type.
;;;   Previewing -- C-c C-p renders to a temp HTML file and opens the
;;;                 browser (requires asciidoctor on PATH).
;;;   Publishing -- C-c C-e h exports HTML; C-c C-e p exports PDF
;;;                 (requires asciidoctor / asciidoctor-pdf on PATH).
;;;
;;; Install external tools:
;;;   brew install asciidoctor          -- core renderer and flycheck linter
;;;   gem install asciidoctor-pdf       -- PDF export via C-c C-e p
;;;
;;; If you process files through an XML stage (a2x, manpage generation),
;;; add to your shell rc:
;;;   export XML_CATALOG_FILES=/opt/homebrew/etc/xml/catalog


;;; Code:

(unless (featurep 'myde-text-asciidoc)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; AsciiDoc major mode
;; -----------------------------------------------------------------------------

(use-package adoc-mode  ;; https://github.com/bbatsov/adoc-mode
  :mode (("\\.adoc\\'"     . adoc-mode)
         ("\\.asciidoc\\'" . adoc-mode)
         ("\\.asc\\'"      . adoc-mode))
  :hook ((adoc-mode . myde/adoc-mode-setup)
         (adoc-mode . display-line-numbers-mode)
         (adoc-mode . visual-line-mode)
         (adoc-mode . flycheck-mode)
         (adoc-mode . myde/delete-trailing-whitespace-setup))
  :bind (:map adoc-mode-map
              ("C-c C-p"   . myde/adoc-preview)
              ("C-c C-e h" . myde/adoc-export-html)
              ("C-c C-e p" . myde/adoc-export-pdf))
  :ensure t)

(provide 'myde-text-asciidoc-cfg)
;;; cfg.el ends here
