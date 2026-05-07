;;; lib.el --- Elisp support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Library functions for Emacs Lisp development support.
;;; Loaded by myde-prog-elisp/cfg.el before package configuration.


;;; Code:


(defun myde-emacs-lisp-mode-setup ()
  "Set buffer-local settings for emacs-lisp-mode buffers."
  (setq-local fill-column 80
              tab-width 2
              indent-tabs-mode nil
              compile-command (concat "emacs --batch --eval "
                                      "(byte-compile-file "
                                      (prin1-to-string buffer-file-name)
                                      ")")))

(provide 'myde-prog-elisp)
;;; lib.el ends here
