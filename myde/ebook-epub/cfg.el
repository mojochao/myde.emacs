;;; cfg.el --- Ebook ePub configuration -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Side-effect configuration for the `myde-ebook-epub-cfg' module:
;; use-package declarations, hooks, and keybindings.  Loads the
;; sister lib.el for definitions.


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
