;;; lib.el --- Core base library -*- coding: utf-8; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

;; Startup configuration
(setq warning-minimum-level :error)
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

(defun myde/exec-path-from-shell-startup-hook ()
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

(provide 'myde-core-base)
;;; lib.el ends here
