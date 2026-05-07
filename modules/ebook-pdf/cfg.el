;;; cfg.el --- Ebook PDF configuration -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; PDF viewing and annotation via pdf-tools.
;; Entry point for the ebook-pdf module; loads lib.el automatically.
;;
;; Compiles and installs the epdfinfo server automatically on first load.
;; Configures fit-width display, 1.1× zoom steps, and continuous scrolling.
;; Extra keybindings in pdf-view-mode-map:
;;   C-s — isearch within the PDF text layer
;;   h   — add highlight markup annotation
;;   t   — add text annotation


;;; Code:

(unless (featurep 'myde-ebook-pdf)
  (load-file (expand-file-name "modules/ebook-pdf/lib.el" user-emacs-directory)))

(use-package pdf-tools  ;; https://github.com/vedang/pdf-tools
  :init
  (setq pdf-view-display-size 'fit-width
        pdf-view-resize-factor 1.1)
  :config
  (pdf-tools-install)                 ;; Compile/install epdfinfo server automatically
  (setq pdf-view-use-scaling t        ;; Improve rendering responsiveness
        pdf-view-use-imagemagick nil
	pdf-view-continuous t)        ;; Continuous scrolling
  (define-key pdf-view-mode-map (kbd "C-s") #'isearch-forward)
  (define-key pdf-view-mode-map (kbd "h") #'pdf-annot-add-highlight-markup-annotation)
  (define-key pdf-view-mode-map (kbd "t") #'pdf-annot-add-text-annotation)
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :ensure t)

(provide 'myde-ebook-pdf-cfg)
;;; cfg.el ends here
