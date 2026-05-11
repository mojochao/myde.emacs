;;; cfg.el --- Kubernetes packages configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacsk
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for Kubernetes management.

;;; Entry point for the containers-kubernetes module; loads lib.el automatically.
;;;
;;; Provides kubed, a Kubernetes management interface for Emacs.
;;; The kubed-prefix-map is bound to C-c k for convenient access.
;;; Use M-x kubed-transient to explore all available commands.


;;; Code:

(unless (featurep 'myde-containers-kubernetes)
  (load (expand-file-name "lib" (file-name-directory load-file-name))))

(use-package kubed  ;; https://github.com/eshelyaron/kubed
  :bind-keymap
  ("C-c k" . kubed-prefix-map)
  :ensure t)

(provide 'myde-containers-kubernetes-cfg)
;;; cfg.el ends here
