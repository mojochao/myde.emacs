;;; lib.el --- Org mode support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Org mode configuration and utilities.


;;; Code:

;; Org mode directories and files
(defvar myde-org-directory "~/org/"
  "Main org mode directory.")

(defvar myde-reading-notes "~/org/reading/"
  "Directory for reading notes.")

(defvar myde-highlight-file "~/org/highlights.org"
  "File for storing highlights.")

(defcustom myde-projects-directory (expand-file-name "~/org/projects/")
  "Root directory under which per-project `tasks.org' files are discovered."
  :type 'directory
  :group 'myde)

(defun myde-find-org-agenda-files (&optional root-dir)
  "Return list of `tasks.org' files under ROOT-DIR.
ROOT-DIR defaults to `myde-projects-directory'.  Returns nil if the
directory does not exist."
  (let ((dir (or root-dir myde-projects-directory)))
    (when (file-directory-p dir)
      (directory-files-recursively dir "\\`tasks\\.org\\'"))))

;; Org-related utility functions
(defun myde-delete-trailing-whitespace-setup ()
  "Delete trailing whitespace on save in `org-mode`."
  (add-hook 'before-save-hook #'delete-trailing-whitespace nil t))

;; That's all Folks!
(provide 'myde-core-org)
;;; lib.el ends here
