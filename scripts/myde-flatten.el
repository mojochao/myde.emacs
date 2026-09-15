;;; myde-flatten.el --- One-shot module flattener -*- lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;;; Commentary:
;; Concatenates modules/<name>/{lib,cfg}.el into user-lisp/myde.el in the order
;; declared by `myde-modules' in init.el.  Strips per-file headers, `featurep'
;; guards, and `provide' forms.  Run once during phase 1 of the migration, then
;; deleted -- myde.el becomes the source of truth (and later, myde.org does).
;;
;; Usage: MYDE_ROOT=<repo> emacs -Q --batch -l scripts/myde-flatten.el

;;; Code:

(require 'subr-x)

(defconst myde-flatten-root
  (or (getenv "MYDE_ROOT") default-directory))

(defun myde-flatten--module-names ()
  "Return module names in declared order by parsing `myde-modules' in init.el."
  (let ((names '()))
    (with-temp-buffer
      (insert-file-contents (expand-file-name "init.el" myde-flatten-root))
      (goto-char (point-min))
      (while (re-search-forward "(myde/m +\"\\([^\"]+\\)\"" nil t)
        (push (match-string 1) names)))
    (nreverse names)))

(defun myde-flatten--body (file)
  "Return the meaningful body of FILE: no header, no guard, no provide."
  (with-temp-buffer
    (insert-file-contents file)
    ;; Drop everything through the ";;; Code:" marker.
    (goto-char (point-min))
    (when (re-search-forward "^;;; Code:[ \t]*\n" nil t)
      (delete-region (point-min) (point)))
    ;; Drop the trailing provide form and the "ends here" line.
    (goto-char (point-min))
    (when (re-search-forward "^(provide '[^)]+)" nil t)
      (delete-region (match-beginning 0) (point-max)))
    ;; Drop the lib.el-loading featurep guard (one form in the tree uses `load'
    ;; rather than `load-file'; both are matched).  Every guard in the tree is
    ;; two lines; verified before writing this.
    (goto-char (point-min))
    (while (re-search-forward "^(unless (featurep '[^)]+)\n[ \t]*(load\\(?:-file\\)? .*\n" nil t)
      (replace-match ""))
    (string-trim (buffer-string))))

(defun myde-flatten-run ()
  "Generate user-lisp/myde.el from the module tree."
  (let* ((names (myde-flatten--module-names))
         (out (expand-file-name "user-lisp/myde.el" myde-flatten-root)))
    (make-directory (file-name-directory out) t)
    (with-temp-file out
      (insert ";;; myde.el --- MyDE configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-\n\n")
      (insert ";; Copyright (C) 2020-2026  Allen Gooch\n\n")
      (insert ";; Author:   Allen Gooch <allen.gooch@gmail.com>\n")
      (insert ";; URL:      https://github.com/mojochao/myde.emacs\n")
      (insert ";; Keywords: convenience, configuration\n")
      (insert ";; Package-Requires: ((emacs \"31.1\"))\n\n")
      (insert ";; This file is not part of GNU Emacs.\n\n")
      (insert ";; Released under the MIT License; see the LICENSE file at the repository\n")
      (insert ";; root for the full text.\n\n")
      (insert ";;; Commentary:\n;;\n;; The whole of MyDE.  Loaded from init.el via (require 'myde).\n\n")
      (insert ";;; Code:\n\n")
      (dolist (name names)
        (let* ((dir (expand-file-name (concat "modules/" name) myde-flatten-root))
               (lib (expand-file-name "lib.el" dir))
               (cfg (expand-file-name "cfg.el" dir)))
          (insert (format "\n;;;; %s\n;;;; %s\n\n"
                          name (make-string (max 8 (length name)) ?-)))
          (when (file-exists-p lib)
            (insert (myde-flatten--body lib) "\n\n"))
          (when (file-exists-p cfg)
            (insert (myde-flatten--body cfg) "\n\n"))))
      (insert "\n(provide 'myde)\n;;; myde.el ends here\n"))
    (message "wrote %s" out)))

(myde-flatten-run)
;;; myde-flatten.el ends here
