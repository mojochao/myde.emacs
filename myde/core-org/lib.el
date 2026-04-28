;;; lib.el --- Org mode support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; Org mode configuration and utilities.

;;; Code:

(require 'myde)

;; Org mode directories and files
(defvar myde/org-directory "~/org/"
  "Main org mode directory.")

(defvar myde/reading-notes "~/org/reading/"
  "Directory for reading notes.")

(defvar myde/highlight-file "~/org/highlights.org"
  "File for storing highlights.")

;; Org agenda files
(defun myde/find-org-agenda-files (root-dir)
  "Find org agenda files (currently hardcoded for known projects)."
  '("/home/agooch/Projects/platykus/org/tasks.org"
    "/home/agooch/Projects/myde/org/tasks.org"
    "/home/agooch/Projects/mydc/org/tasks.org"
    "/home/agooch/Projects/playdate/org/tasks.org"
    "/home/agooch/Projects/life/org/tasks.org"
    "/home/agooch/Projects/dayjob/org/tasks.org"))

;; Org-related utility functions
(defun myde/delete-trailing-whitespace-setup ()
  "Delete trailing whitespace on save in org-mode."
  (add-hook 'before-save-hook #'delete-trailing-whitespace nil t))

(provide 'myde-core-org)
;;; lib.el ends here
