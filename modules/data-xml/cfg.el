;;; cfg.el --- XML editing configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; XML, XSD, XSLT, SVG, and XQuery editing via nxml-mode and xml-ts-mode.
;;; Entry point for the data-xml module; loads lib.el automatically.
;;;
;;; Requires lemminx wrapper at ~/.local/bin/lemminx (JAR at ~/.local/share/lemminx/).
;;; Install: download org.eclipse.lemminx-uber.jar from download.eclipse.org/lemminx/releases/
;;; Requires xmllint on PATH (ships with macOS; brew install libxml2) for formatting.
;;; .xml, .xsd, .xsl, .xslt, .svg, and .xhtml files use xml-ts-mode when the
;;; tree-sitter XML grammar is installed, otherwise nxml-mode.
;;; .xq and .xquery files use xquery-tool for XQuery authoring.


;;; Code:

(unless (featurep 'myde-data-xml)
  (load-file (expand-file-name "modules/data-xml/lib.el" user-emacs-directory)))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(xml "https://github.com/tree-sitter/tree-sitter-xml" "master" "xml/src"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; nxml-mode — built-in, used as fallback when tree-sitter grammar is absent
;; -----------------------------------------------------------------------------

(use-package nxml-mode  ;; built-in
  :mode (("\\.xml\\'"   . myde-xml-ts-or-nxml-mode)
         ("\\.xsd\\'"   . myde-xml-ts-or-nxml-mode)
         ("\\.xsl\\'"   . myde-xml-ts-or-nxml-mode)
         ("\\.xslt\\'"  . myde-xml-ts-or-nxml-mode)
         ("\\.svg\\'"   . myde-xml-ts-or-nxml-mode)
         ("\\.xhtml\\'" . myde-xml-ts-or-nxml-mode))
  :hook (nxml-mode . myde-nxml-mode-hook)
  :custom
  (nxml-slash-auto-complete-flag t)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; xml-ts-mode — built-in (Emacs 29+), primary when XML grammar is installed
;; -----------------------------------------------------------------------------

(use-package xml-ts-mode  ;; built-in (Emacs 29+)
  :hook (xml-ts-mode . myde-xml-ts-mode-hook)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + lemminx
;; -----------------------------------------------------------------------------

(use-package eglot
  :after nxml-mode
  :config
  (add-to-list 'eglot-server-programs
               `((nxml-mode xml-ts-mode) . (,(expand-file-name "~/.local/bin/lemminx"))))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; XML formatting via xmllint
;; -----------------------------------------------------------------------------

(use-package xml-format  ;; https://github.com/wbolster/emacs-xml-format
  :hook ((nxml-mode xml-ts-mode) . myde-xml-format-on-save-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; emmet-mode — rapid markup expansion via C-j
;; -----------------------------------------------------------------------------

(use-package emmet-mode  ;; https://github.com/smihica/emmet-mode
  :hook ((nxml-mode xml-ts-mode) . emmet-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; xquery-tool — XQuery file authoring
;; -----------------------------------------------------------------------------

(use-package xquery-tool  ;; https://github.com/paddymcall/xquery-tool.el
  :mode (("\\.xq\\'"     . nxml-mode)
         ("\\.xquery\\'" . nxml-mode))
  :ensure t)

(use-package indent-bars
  :hook ((xml-ts-mode nxml-mode) . indent-bars-mode))

(provide 'myde-data-xml-cfg)
;;; cfg.el ends here
