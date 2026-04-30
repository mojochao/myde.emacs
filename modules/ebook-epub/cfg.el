;;; cfg.el --- Ebook ePub configuration -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; ePub reading via nov.el.
;; Entry point for the ebook-epub module; loads lib.el automatically.
;;
;; .epub files open in nov-mode.  Text width is capped at 80 columns.
;; visual-line-mode and variable-pitch-mode activate for comfortable prose display.
;; Reading position is persisted to $XDG_STATE_HOME/emacs/nov-places.


;;; Code:

(unless (featurep 'myde-ebook-epub)
  (load-file (expand-file-name "modules/ebook-epub/lib.el" user-emacs-directory)))

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
