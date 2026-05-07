;;; lib.el --- Core base library -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Pure definitions (defun, defvar, defcustom) for the
;; `myde-core-base' module.  No side effects — see cfg.el for
;; package configuration, hooks, and keybindings.


;;; Code:

;; Startup configuration
(setq warning-minimum-level :error)
(setq recentf-max-saved-items 50)

;; Create missing directories automatically
(defun myde-auto-create-missing-dirs ()
  (let ((target-dir (file-name-directory buffer-file-name)))
    (unless (file-exists-p target-dir)
      (make-directory target-dir t))))
(add-to-list 'find-file-not-found-functions #'myde-auto-create-missing-dirs)

;; Delete trailing whitespace on save (shared utility)
(defun myde-delete-trailing-whitespace-setup ()
  "Delete trailing whitespace on save."
  (add-hook 'before-save-hook #'delete-trailing-whitespace nil t))

(defun myde-exec-path-from-shell-startup-hook ()
  "Install exec-path-from-shell if needed and import shell environment.
Runs after init so neither the package download nor the shell subprocess
can block startup."
  (condition-case err
      (progn
        (unless (package-installed-p 'exec-path-from-shell)
          (package-install 'exec-path-from-shell))
        (require 'exec-path-from-shell)
        (exec-path-from-shell-initialize))
    (error (message "myde: exec-path-from-shell setup failed: %s"
                    (error-message-string err)))))

(defun myde-treesit-install-language-grammar-advice (orig-fn lang &optional out-dir)
  "Redirect tree-sitter grammar installation to the XDG data directory.

Advises `treesit-install-language-grammar' so that callers which omit OUT-DIR
(e.g. `treesit-auto') write grammars to `$XDG_DATA_HOME/emacs/tree-sitter/'
instead of the default `user-emacs-directory/tree-sitter/'."
  (funcall orig-fn lang
           (or out-dir (expand-file-name "emacs/tree-sitter" (xdg-data-home)))))

(defun myde-treesit-install-language-grammar (lang)
  "Interactively install a tree-sitter grammar for LANG into the XDG data directory.

The XDG redirection is handled globally by
`myde-treesit-install-language-grammar-advice'; this command is a convenient
interactive entry point."
  (interactive
   (list (intern (completing-read "Language: "
                                  (mapcar #'car treesit-language-source-alist)))))
  (treesit-install-language-grammar lang))

(provide 'myde-core-base)
;;; lib.el ends here
