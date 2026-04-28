;;; lib.el --- Core base library -*- coding: utf-8; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

;; Startup configuration
(setq warning-minimum-level :error)
(save-place-mode)
(savehist-mode)
(setq recentf-max-saved-items 50)

;; Create missing directories automatically
(defun myde/auto-create-missing-dirs ()
  (let ((target-dir (file-name-directory buffer-file-name)))
    (unless (file-exists-p target-dir)
      (make-directory target-dir t))))
(add-to-list 'find-file-not-found-functions #'myde/auto-create-missing-dirs)

;; Delete trailing whitespace on save (shared utility)
(defun myde/delete-trailing-whitespace-setup ()
  "Delete trailing whitespace on save."
  (add-hook 'before-save-hook #'delete-trailing-whitespace nil t))

(provide 'myde-core-base)
;;; lib.el ends here
