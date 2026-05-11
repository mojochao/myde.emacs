;;; lib.el --- Org mode support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
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

(defvar myde-org-tasks-file
  (expand-file-name "tasks.org" myde-org-directory)
  "Path to the top-level tasks capture file.")

(defvar myde-org-bookmarks-file
  (expand-file-name "bookmarks.org" myde-org-directory)
  "Path to the top-level bookmarks capture file.")

(defvar myde-org-notes-directory
  (file-name-as-directory (expand-file-name "notes" myde-org-directory))
  "Directory for denote notes, under `myde-org-directory'.")

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

(defun myde-org-mode-disable-flycheck ()
  "Disable `flycheck-mode' in org buffers.
Flycheck's bundled `org-lint' checker crashes with `Wrong type argument:
number-or-marker-p' on propertized strings from newer org versions.
Flycheck is unnecessary in org buffers — use `M-x org-lint' on demand."
  (when (bound-and-true-p flycheck-mode)
    (flycheck-mode -1)))

(defvar myde-org-project-history nil
  "Minibuffer history for `myde-org-capture-project-line' prompts.")

(defun myde-org-known-projects ()
  "Return a sorted, de-duplicated list of known project names.
Candidates come from subdirectories of `myde-projects-directory' and
from previously entered values in `myde-org-project-history'."
  (let* ((subdirs (when (file-directory-p myde-projects-directory)
                    (mapcar #'file-name-nondirectory
                            (seq-filter
                             #'file-directory-p
                             (directory-files
                              myde-projects-directory t
                              directory-files-no-dot-files-regexp)))))
         (all (append subdirs myde-org-project-history)))
    (sort (delete-dups all) #'string<)))

(defun myde-org-capture-scheduled-line ()
  "Return a `SCHEDULED: <ts>' planning line for a capture template.
Prompts y/n; if declined returns the empty string so the planning line
is omitted entirely.  Intended for use inside an org-capture template
body via `%(...)', placed between the headline and the `:PROPERTIES:'
drawer per org convention."
  (if (y-or-n-p "Schedule this task? ")
      (format "  SCHEDULED: <%s>\n"
              (org-read-date nil nil nil "Scheduled date: "))
    ""))

(defun myde-org-capture-deadline-line ()
  "Return a `DEADLINE: <ts>' planning line for a capture template.
Same conventions as `myde-org-capture-scheduled-line'."
  (if (y-or-n-p "Set a deadline? ")
      (format "  DEADLINE: <%s>\n"
              (org-read-date nil nil nil "Deadline: "))
    ""))

(defun myde-org-capture-project-line ()
  "Return a `:PROJECT: <name>' line for an org-capture PROPERTIES drawer.
Prompts with completion over `myde-org-known-projects'.  Returns the
empty string when the user enters no value, so the property is omitted
entirely.  Intended for use inside a capture template via `%(...)':

  :PROPERTIES:
  :CREATED: %U
%(myde-org-capture-project-line)  :END:"
  (let ((val (string-trim
              (completing-read "Project (RET to skip): "
                               (myde-org-known-projects)
                               nil nil nil
                               'myde-org-project-history))))
    (if (string-empty-p val)
        ""
      (concat "  :PROJECT: " val "\n"))))

;; That's all Folks!
(provide 'myde-core-org)
;;; lib.el ends here
