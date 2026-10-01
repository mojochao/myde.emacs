;;; prog-elixir.el --- Tests for the prog-elixir module -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; ERT checks for `prog-elixir'.  These cover logic that fails silently
;;; rather than loudly:
;;;
;;;   - `myde-prog-elixir-flycheck-setup' turns flycheck on only in a
;;;     project with credo in deps/.  Wrong one way, and the first Elixir
;;;     buffer of every session announces that flycheck has no checker.
;;;     Wrong the other way, and credo quietly never runs.
;;;
;;; Run with `mise run test'.

;;; Code:

(require 'ert)

(defvar myde-test-root
  (expand-file-name
   ".." (file-name-directory (or load-file-name buffer-file-name)))
  "Repository root, derived from this file's location.")

(load (expand-file-name "user-lisp/myde.el" myde-test-root))

(defun myde-test--elixir-flycheck-arg (deps)
  "Return the argument `myde-prog-elixir-flycheck-setup' passes `flycheck-mode'.
The setup runs from lib/ in a throwaway project holding DEPS under deps/."
  (let* ((root (file-name-as-directory (make-temp-file "myde-elixir" t)))
         (default-directory (expand-file-name "lib/" root))
         arg)
    (unwind-protect
        (progn
          (make-directory default-directory)
          (dolist (dep deps)
            (make-directory (expand-file-name dep (expand-file-name "deps" root)) t))
          (cl-letf (((symbol-function 'flycheck-mode) (lambda (a) (setq arg a))))
            (myde-prog-elixir-flycheck-setup))
          arg)
      (delete-directory root t))))

(ert-deftest myde-prog-elixir-flycheck-setup-follows-credo ()
  "Flycheck is on where credo is a dependency and off everywhere else."
  (should (equal (myde-test--elixir-flycheck-arg '("credo")) 1))
  (should (equal (myde-test--elixir-flycheck-arg '("jason")) -1))
  (should (equal (myde-test--elixir-flycheck-arg nil) -1)))

;;; prog-elixir.el ends here
