;;; lib.el --- Programming base library -*- coding: utf-8; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(defun myde/prog-mode-hook-function ()
  "Configure display of line numbers and current line highlighting."
  (display-line-numbers-mode t)
  (hl-line-mode t))

(defun myde/delete-trailing-whitespace-setup ()
  "Delete trailing whitespace on save."
  (add-hook 'before-save-hook #'delete-trailing-whitespace nil t))

(defun myde/mise-exec-which (dir exe)
  "Resolve EXE path via mise exec for project in DIR."
  (let ((default-directory (or dir
                               (and (buffer-file-name (buffer-base-buffer))
                                    (file-name-directory (buffer-file-name (buffer-base-buffer))))
                               default-directory)))
    (list (string-trim
           (shell-command-to-string
            (concat mise-executable " exec -- which " exe))))))

(provide 'myde-prog-base)
;;; lib.el ends here
