;;; lib.el --- XML editing support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; XML, XSD, XSLT, SVG, and XQuery editing utilities.


;;; Code:

(defun myde-xml-mode-setup ()
  "Set buffer-local settings for XML buffers."
  (setq-local fill-column 100
              tab-width 2
              indent-tabs-mode nil))

(defun myde-xml-format-buffer ()
  "Reformat the current XML buffer in-place via xmllint."
  (interactive)
  (when (executable-find "xmllint")
    (let ((point (point)))
      (call-process-region (point-min) (point-max) "xmllint" t t nil "--format" "-")
      (goto-char point))))

(define-minor-mode myde-xml-format-on-save-mode
  "Auto-format XML buffer on save using xmllint."
  :lighter " fmt"
  (if myde-xml-format-on-save-mode
      (add-hook 'before-save-hook #'myde-xml-format-buffer nil t)
    (remove-hook 'before-save-hook #'myde-xml-format-buffer t)))

(defun myde-xml-ts-mode-hook ()
  "Set up xml-ts-mode buffers."
  (myde-xml-mode-setup)
  (eglot-ensure))

(defun myde-nxml-mode-hook ()
  "Set up nxml-mode buffers."
  (myde-xml-mode-setup)
  (eglot-ensure))

(defun myde-xml-ts-or-nxml-mode ()
  "Use `xml-ts-mode' if tree-sitter is available, otherwise fall back to `nxml-mode'."
  (if (treesit-ready-p 'xml)
      (xml-ts-mode)
    (nxml-mode)))

(provide 'myde-data-xml)
;;; lib.el ends here
