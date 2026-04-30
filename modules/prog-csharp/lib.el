;;; lib.el --- C# support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Pure definitions (defun, defvar, defcustom) for the
;; `myde-prog-csharp' module.  No side effects — see cfg.el for
;; package configuration, hooks, and keybindings.


;;; Code:

(defun myde/csharp-ts-or-plain-mode ()
  "Use `csharp-ts-mode' if tree-sitter is available, otherwise fall back to `csharp-mode'."
  (if (treesit-ready-p 'c-sharp)
      (csharp-ts-mode)
    (csharp-mode)))

(defun myde/csharp-mode-setup ()
  "Set buffer-local settings for csharp-mode and csharp-ts-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 120
              compile-command "dotnet build"))

(defun myde/csharp-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde/csharp-format-on-save-setup ()
  "Install buffer-local before-save formatting for csharp buffers."
  (add-hook 'before-save-hook #'myde/csharp-eglot-format-buffer nil t))

(defun myde/csharp-run-tests ()
  "Run dotnet tests for the current project."
  (interactive)
  (compile "dotnet test --logger \"console;verbosity=normal\""))

(defun myde/csharp-dape-binary ()
  "Prompt for the .NET debug assembly (DLL) for netcoredbg."
  (read-file-name "Assembly: "
                  (expand-file-name "bin/" (or (when (fboundp 'project-root)
                                                 (when-let ((proj (project-current)))
                                                   (project-root proj)))
                                               default-directory))))

(provide 'myde-prog-csharp)
;;; lib.el ends here
