;;; lib.el --- AsciiDoc support library for myde -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Library functions for AsciiDoc editing, previewing, and publishing.
;;; Loaded by myde/text-asciidoc/cfg.el before package configuration.
;;;
;;; External tools used (all optional, but install for full experience):
;;;   asciidoctor      -- rendering and linting  (brew install asciidoctor)
;;;   asciidoctor-pdf  -- PDF export             (gem install asciidoctor-pdf)
;;;   vale             -- prose linting          (brew install vale)
;;;
;;; Note: if you process AsciiDoc through an XML stage (a2x, manpage
;;; generation via xmllint), add this to your shell rc file:
;;;   export XML_CATALOG_FILES=/opt/homebrew/etc/xml/catalog


;;; Code:

(defun myde/adoc-mode-setup ()
  "Set buffer-local settings for adoc-mode buffers."
  (setq-local fill-column 80
              tab-width 2
              indent-tabs-mode nil))

(defun myde/adoc-preview ()
  "Save buffer, render it to a temp HTML file, and open it in the browser."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer has no file — save it first"))
  (save-buffer)
  (let* ((src (buffer-file-name))
         (html (make-temp-file "adoc-preview" nil ".html")))
    (if (zerop (call-process "asciidoctor" nil nil nil "-o" html src))
        (browse-url (concat "file://" html))
      (message "asciidoctor failed; install with: brew install asciidoctor"))))

(defun myde/adoc-export-html ()
  "Export current AsciiDoc buffer to HTML alongside the source file."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer has no file — save it first"))
  (save-buffer)
  (let* ((src (buffer-file-name))
         (out (concat (file-name-sans-extension src) ".html")))
    (if (zerop (call-process "asciidoctor" nil nil nil "-o" out src))
        (message "Exported: %s" out)
      (message "asciidoctor failed; install with: brew install asciidoctor"))))

(defun myde/adoc-export-pdf ()
  "Export current AsciiDoc buffer to PDF alongside the source file.
Requires asciidoctor-pdf (gem install asciidoctor-pdf)."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer has no file — save it first"))
  (save-buffer)
  (let* ((src (buffer-file-name))
         (out (concat (file-name-sans-extension src) ".pdf")))
    (if (zerop (call-process "asciidoctor-pdf" nil nil nil "-o" out src))
        (message "Exported: %s" out)
      (message "asciidoctor-pdf failed; install with: gem install asciidoctor-pdf"))))

(provide 'myde-text-asciidoc)
;;; lib.el ends here
