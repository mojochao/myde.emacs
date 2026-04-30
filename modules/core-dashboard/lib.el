;;; lib.el --- Dashboard support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Library variables for startup dashboard support.
;;; Loaded by myde/core-dashboard/cfg.el before package configuration.


;;; Code:


(defvar myde/banner-image-file
  (expand-file-name "modules/core-dashboard/myde-banner.png" user-emacs-directory)
  "Path to the dashboard banner image file.")

(defvar myde/banner-text-file
  (expand-file-name "modules/core-dashboard/myde-banner.txt" user-emacs-directory)
  "Path to the dashboard banner text fallback file.")

(provide 'myde-core-dashboard)
;;; lib.el ends here
