;;; cfg.el --- Elisp package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for Emacs Lisp development support.
;;; Entry point for the prog-elisp module; loads lib.el automatically.
;;;
;;; paredit and rainbow-delimiters are activated via prog-base (shared across
;;; all Lisp-family languages); only Elisp-specific packages are added here.
;;;
;;; Configures:
;;;   buttercup    — BDD-style test authoring (deferred)
;;;   package-lint — package metadata and dependency validation (deferred)
;;;   cask-mode    — Cask project file editing (deferred)
;;;   eask-mode    — Eask project file editing (deferred)
;;;   dash, s, seq, plz — common Elisp utility libraries (deferred)


;;; Code:

(unless (featurep 'myde-prog-elisp)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Emacs Lisp mode setup
;; -----------------------------------------------------------------------------

(use-package emacs
  :hook ((emacs-lisp-mode . myde-emacs-lisp-mode-setup)
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

(use-package indent-bars
  :hook (emacs-lisp-mode . indent-bars-mode))

(provide 'myde-prog-elisp-cfg)
;;; cfg.el ends here
