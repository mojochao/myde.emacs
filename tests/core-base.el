;;; core-base.el --- Tests for the core-base module -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; ERT checks for `core-base'.  These cover logic that fails silently
;;; rather than loudly:
;;;
;;;   - `myde-tangle-source-on-save' compares `buffer-file-name' against
;;;     `myde-source-file'.  ~/.config/emacs is a symlink to the repository,
;;;     so a literal string comparison would make the hook a no-op for
;;;     whichever of the two paths the file was not opened by -- you would
;;;     save myde.org, see no error, and find the drift at commit time.
;;;
;;; Run with `mise run test'.

;;; Code:

(require 'ert)
(require 'org)

(defvar myde-test-root
  (expand-file-name
   ".." (file-name-directory (or load-file-name buffer-file-name)))
  "Repository root, derived from this file's location.")

(load (expand-file-name "user-lisp/myde.el" myde-test-root))

(defun myde-test--write (path contents)
  "Write CONTENTS to PATH, making parent directories as needed."
  (make-directory (file-name-directory path) :parents)
  (write-region contents nil path nil 'silent))

(ert-deftest myde-tangle-source-on-save/fires-through-either-path ()
  "Saving the literate source tangles it, by real path or by symlink.
Also asserts the hook ignores every other file, so it does not tangle
on every save in the session."
  (let* ((tmp (file-name-as-directory (make-temp-file "myde-base-test" :dir)))
         (real (file-name-as-directory (expand-file-name "repo" tmp)))
         (link (file-name-as-directory (expand-file-name "link" tmp)))
         (source (expand-file-name "myde.org" real))
         (output (expand-file-name "out.el" real))
         (myde-source-file (progn
                             (myde-test--write
                              source
                              "#+begin_src emacs-lisp :tangle out.el\n(ignore)\n#+end_src\n")
                             (file-truename source)))
         (other (expand-file-name "other.org" real)))
    (myde-test--write other "nothing to tangle\n")
    (make-symbolic-link real (directory-file-name link))
    (add-hook 'after-save-hook #'myde-tangle-source-on-save)
    (unwind-protect
        (dolist (path (list source (expand-file-name "myde.org" link)))
          (when (file-exists-p output) (delete-file output))
          ;; The file is reached by PATH, but `myde-source-file' names only
          ;; the true name -- the hook has to resolve one to the other.
          (should-not (file-exists-p output))
          (save-current-buffer
            (find-file path)
            (should (equal buffer-file-name path))
            (goto-char (point-max))
            (insert ";; touched\n")
            (let ((inhibit-message t)) (save-buffer))
            (kill-buffer))
          (should (file-exists-p output))
          ;; An unrelated save in the same directory tangles nothing.
          (delete-file output)
          (save-current-buffer
            (find-file other)
            (goto-char (point-max))
            (insert "more\n")
            (let ((inhibit-message t)) (save-buffer))
            (kill-buffer))
          (should-not (file-exists-p output)))
      (remove-hook 'after-save-hook #'myde-tangle-source-on-save)
      (delete-directory tmp :recursive))))

;;; core-base.el ends here
