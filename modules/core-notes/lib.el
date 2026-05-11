;;; lib.el --- Notes support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Library functions for denote note-taking support.
;;; Loaded by myde-core-notes/cfg.el before package configuration.


;;; Code:


(require 'myde-core-org)

(defvar myde-denote-directory myde-org-notes-directory
  "Root directory for denote notes.")

(defun myde-denote-capture-from-protocol ()
  "Wrap `denote-org-capture' seeding the title from the org-protocol payload.
Reads `:description' (falling back to `:title') from
`org-store-link-plist' so the capture flow does not re-prompt the user
for a title when invoked from a browser bookmarklet."
  (let ((title (or (plist-get org-store-link-plist :description)
                   (plist-get org-store-link-plist :title))))
    (when (and (boundp 'denote-use-title)
               (stringp title)
               (not (string-empty-p title)))
      (setq denote-use-title title))
    (denote-org-capture)))

(provide 'myde-core-notes)
;;; lib.el ends here
