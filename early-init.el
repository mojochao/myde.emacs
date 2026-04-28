;;; early-init.el --- Emacs early initialization -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; Loaded before init.el; used for critical setup like XDG directory paths.

;;; Code:

;; Must be set here — Emacs creates this directory from the default value
;; (user-emacs-directory/auto-save-list/) before init.el runs.
(let ((state-home (or (getenv "XDG_STATE_HOME")
                      (expand-file-name ".local/state" "~"))))
  (setq auto-save-list-file-prefix
        (expand-file-name "emacs/auto-save-list/.saves-" state-home)))

(provide 'early-init)
;;; early-init.el ends here
