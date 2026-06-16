;;; cfg.el --- Pkl editing configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Pkl editing via pkl-mode for .pkl files.
;;; Entry point for the data-pkl module; loads lib.el automatically.
;;;
;;; pkl-mode provides syntax highlighting and indentation for Apple's Pkl
;;; configuration language.  No LSP is configured.


;;; Code:

(unless (featurep 'myde-data-pkl)
  (load-file (expand-file-name "modules/data-pkl/lib.el" user-emacs-directory)))

;; Pkl editing support
(use-package pkl-mode  ;; https://github.com/sin-ack/pkl-mode
  :hook
  ((pkl-mode . myde-data-pkl-mode-setup)
   (pkl-mode . myde-delete-trailing-whitespace-setup))
  :mode
  (("\\.pkl\\'" . pkl-mode))
  :ensure t)

(use-package indent-bars
  :hook (pkl-mode . indent-bars-mode))

(provide 'myde-data-pkl-cfg)
;;; cfg.el ends here
