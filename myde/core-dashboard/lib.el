;;; lib.el --- Dashboard support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Library variables for startup dashboard support.
;;; Loaded by myde/core-dashboard/cfg.el before package configuration.

;;; Code:


(defvar myde/banner-image-file
  (expand-file-name "myde/core-dashboard/myde-banner.png" user-emacs-directory)
  "Path to the dashboard banner image file.")

(defvar myde/banner-text-file
  (expand-file-name "myde/core-dashboard/myde-banner.txt" user-emacs-directory)
  "Path to the dashboard banner text fallback file.")

(provide 'myde-core-dashboard)
;;; lib.el ends here
