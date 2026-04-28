;;; early-init.el --- Emacs early initialization -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; Loaded before init.el; used for critical setup like XDG directory paths.

;;; Code:

(require 'xdg)

;; Redirect package installation directory (must be before package-initialize)
(setq package-user-dir
      (expand-file-name "emacs/elpa" (xdg-data-home)))

;; Redirect native compilation cache (Emacs 29+)
(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (expand-file-name "emacs/eln-cache" (xdg-cache-home))))

(provide 'early-init)
;;; early-init.el ends here
