;;; cfg.el --- Elisp package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Package configuration for Emacs Lisp development support.
;;; Entry point for the prog-elisp module; loads lib.el automatically.

;;; Code:

(unless (featurep 'myde-prog-elisp)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Emacs Lisp mode setup
;; -----------------------------------------------------------------------------

(use-package emacs
  :hook ((emacs-lisp-mode . myde/emacs-lisp-mode-setup)
         (emacs-lisp-mode . myde/delete-trailing-whitespace-setup)
         (emacs-lisp-mode . flycheck-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Testing
;; -----------------------------------------------------------------------------

(use-package buttercup  ;; https://github.com/jorgenschaefer/emacs-buttercup
  :defer t
  :ensure t)

;; -----------------------------------------------------------------------------
;; Package development tools
;; -----------------------------------------------------------------------------

(use-package package-lint  ;; https://github.com/purcell/package-lint
  :defer t
  :ensure t)

(use-package cask-mode  ;; https://github.com/Wilfred/cask-mode
  :defer t
  :ensure t)

(use-package eask-mode  ;; https://github.com/emacs-eask/eask-mode
  :defer t
  :ensure t)

;; -----------------------------------------------------------------------------
;; Elisp utility libraries
;; -----------------------------------------------------------------------------

(use-package dash  ;; https://github.com/magnars/dash.el
  :defer t
  :ensure t)

(use-package s  ;; https://github.com/magnars/s.el
  :defer t
  :ensure t)

(use-package seq  ;; https://elpa.gnu.org/packages/seq.html
  :defer t
  :ensure t)

(use-package plz  ;; https://github.com/alphapapa/plz.el
  :defer t
  :ensure t)

(provide 'myde-prog-elisp-cfg)
;;; cfg.el ends here
