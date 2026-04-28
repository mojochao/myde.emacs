;;; cfg.el --- Ebook PDF configuration -*- coding: utf-8; lexical-binding: t; -*-

;;; Commentary:

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
