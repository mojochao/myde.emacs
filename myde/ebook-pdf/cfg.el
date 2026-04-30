;;; cfg.el --- Ebook PDF configuration -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Side-effect configuration for the `myde-ebook-pdf-cfg' module:
;; use-package declarations, hooks, and keybindings.  Loads the
;; sister lib.el for definitions.


;;; Code:

(unless (featurep 'myde-ebook-pdf)
  (load-file (expand-file-name "myde/ebook-pdf/lib.el" user-emacs-directory)))

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
