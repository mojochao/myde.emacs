;;; cfg.el --- Dashboard package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for startup dashboard and session management:
;;;   dashboard + recentf + buffer-guardian
;;;
;;; Entry point for the core-dashboard module; loads lib.el automatically.


;;; Code:

(unless (featurep 'myde-core-dashboard)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Startup dashboard
;; -----------------------------------------------------------------------------

(use-package dashboard  ;; https://github.com/emacs-dashboard/emacs-dashboard
  :hook (after-init . dashboard-setup-startup-hook)
  :config
  (setq dashboard-startup-banner (cons myde/banner-image-file myde/banner-text-file))
  (setq dashboard-banner-logo-title "Welcome to MyDE -- *MY* Development Environment!")
  (setq dashboard-display-icons-p t)
  (setq dashboard-icon-type 'nerd-icons)
  (setq dashboard-set-heading-icons t)
  (setq dashboard-set-file-icons t)
  :custom
  (dashboard-projects-backend 'projectile)
  (dashboard-items '((recents   . 5)
                     (projects  . 5)
                     (bookmarks . 5)
                     (agenda    . 5)))
  :ensure t)

(provide 'myde-core-dashboard-cfg)
;;; cfg.el ends here
