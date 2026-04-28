;;; cfg.el --- Ebook ePub configuration -*- coding: utf-8; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(unless (featurep 'myde-ebook-epub)
  (load-file (expand-file-name "myde/ebook-epub/lib.el" user-emacs-directory)))

(use-package nov  ;; https://depp.brause.cc/nov.el
  :after xdg
  :init
  (setq nov-text-width 80
        nov-place-file
        (expand-file-name "emacs/nov-places" (xdg-state-home)))
  :hook
  ((nov-mode . visual-line-mode)
   (nov-mode . variable-pitch-mode))
  :mode
  ("\\.epub\\'" . nov-mode)
  :ensure t)

(provide 'myde-ebook-epub-cfg)
;;; cfg.el ends here
