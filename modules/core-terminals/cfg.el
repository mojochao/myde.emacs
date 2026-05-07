;;; cfg.el --- Terminal packages configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for in-Emacs terminal emulators.
;;; Entry point for the core-terminals module; loads lib.el automatically.
;;;
;;; Provides two terminal options (both loaded on demand via M-x):
;;;   eat   — fast terminal using Emacs's built-in terminal emulation
;;;   vterm — libvterm-based full terminal (requires C library at compile time)
;;;
;;; hl-line-mode is disabled in all terminal-like modes (vterm, term, eshell,
;;; ansi-term, comint) to avoid visual noise in interactive shells.


;;; Code:

(unless (featurep 'myde-core-terminals)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

(use-package emacs
  :config
  (set-terminal-coding-system 'utf-8-unix)
  (setq global-hl-line-modes '(not vterm-mode term-mode eshell-mode ansi-term-mode comint-mode))  ;; Disable hl-line-mode in all terminal-like modes
  :ensure nil)

(use-package eat  ;; https://codeberg.org/akib/emacs-eat
  :commands
  (eat)
  :ensure t)

(use-package vterm  ;; https://github.com/akermu/emacs-libvterm
  :commands
  (vterm)
  :ensure t)

(provide 'myde-core-terminals-cfg)
;;; cfg.el ends here
