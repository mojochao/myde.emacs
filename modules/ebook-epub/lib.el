;;; lib.el --- Ebook ePub library -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Pure definitions (defun, defvar, defcustom) for the
;; `myde-ebook-epub' module.  No side effects — see cfg.el for
;; package configuration, hooks, and keybindings.


;;; Code:

(defun myde-reading-setup ()
  "Improve readability for long-form documents."
  (visual-line-mode 1)
  (setq-local line-spacing 0.15))

(defun myde-reading-keybindings ()
  "Unified navigation keys across readers."
  (local-set-key (kbd "i") #'org-noter)
  (local-set-key (kbd "n") #'org-noter-insert-note)
  (local-set-key (kbd "h") #'org-remark-mark)
  (local-set-key (kbd "j") #'org-noter-sync-next-note)
  (local-set-key (kbd "k") #'org-noter-sync-prev-note))

(provide 'myde-ebook-epub)
;;; lib.el ends here
