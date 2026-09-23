;;; core-help.el --- Tests for the core-help module -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; ERT checks for `core-help'.  These cover logic that fails silently
;;; rather than loudly:
;;;
;;;   - `myde-help-which-key-align-docstrings' finds each docstring by its
;;;     face.  If it stops finding them, which-key still draws the popup,
;;;     just with ragged docstrings again.
;;;
;;; Run with `mise run test'.

;;; Code:

(require 'ert)

(defvar myde-test-root
  (expand-file-name
   ".." (file-name-directory (or load-file-name buffer-file-name)))
  "Repository root, derived from this file's location.")

(load (expand-file-name "user-lisp/myde.el" myde-test-root))

(defun myde-test--which-key-cell (key name &optional doc)
  "Return a which-key cell for KEY bound to NAME, with DOC appended as which-key does."
  (list key " → "
        (if doc
            (format "%s %s" name (propertize doc 'face 'which-key-docstring-face))
          name)))

(ert-deftest myde-help-which-key-align-docstrings-lines-up-docstrings ()
  "Docstrings start at one column; cells without a docstring are untouched."
  (let* ((cells (list (myde-test--which-key-cell "a" "org-agenda" "Dispatch agenda.")
                      (myde-test--which-key-cell "p" "myde-org-visit-project-tasks" "Visit tasks.")
                      (myde-test--which-key-cell "n" "+prefix")))
         (result (myde-help-which-key-align-docstrings (list cells 80)))
         (out (car result)))
    (should (equal (cdr result) '(80)))
    (should (= (myde-help--which-key-docstring-start (nth 0 out))
               (myde-help--which-key-docstring-start (nth 1 out))))
    (should (equal (substring-no-properties (nth 2 (nth 0 out)))
                   "org-agenda                   Dispatch agenda."))
    (should (equal (nth 2 out) (nth 2 cells)))))

;;; core-help.el ends here
