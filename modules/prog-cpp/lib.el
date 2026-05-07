;;; lib.el --- C/C++ support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Pure definitions (defun, defvar, defcustom) for the
;; `myde-prog-cpp' module.  No side effects — see cfg.el for
;; package configuration, hooks, and keybindings.


;;; Code:

(defun myde-cpp-ts-mode-setup ()
  "Set buffer-local settings for c++-ts-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "cmake --build build"))

(defun myde-c-ts-mode-setup ()
  "Set buffer-local settings for c-ts-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "cmake --build build"))

(defun myde-cpp-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde-cpp-format-on-save-setup ()
  "Install buffer-local before-save formatting for C/C++ ts modes."
  (add-hook 'before-save-hook #'myde-cpp-eglot-format-buffer nil t))

(defun myde-cpp-run-tests ()
  "Build and run CTest tests for the current project."
  (interactive)
  (compile "cmake --build build && ctest --test-dir build --output-on-failure"))

(defun myde-cpp-dape-binary ()
  "Prompt for the C++ debug binary, defaulting to the project build/ directory."
  (read-file-name "Binary: "
                  (expand-file-name "build/" (or (projectile-project-root)
                                                  default-directory))))

(provide 'myde-prog-cpp)
;;; lib.el ends here
