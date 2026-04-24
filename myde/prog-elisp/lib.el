;;; lib.el --- Elisp support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Library functions for Emacs Lisp development support.
;;; Loaded by myde/prog-elisp/cfg.el before package configuration.

;;; Code:

(require 'myde)

(defun myde/emacs-lisp-mode-setup ()
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
