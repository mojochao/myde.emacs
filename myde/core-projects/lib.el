;;; lib.el --- Projects support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Library functions for project and project tree support.
;;; Loaded by myde/core-projects/cfg.el before package configuration.

;;; Code:

(require 'myde)

(defun myde/neotree-project-root-toggle ()
  "Toggle NeoTree.  If opening, set the root to the current project root."
  (interactive)
  (if (and (fboundp 'neo-global--window-exists-p)
           (neo-global--window-exists-p))
      (neotree-hide)
    (let ((project (project-current)))
      (if project
          (neotree-dir (project-root project))
        (neotree-show)))))

(defun myde/neotree-refresh ()
  "Refresh neotree if visible."
  (when (neo-global--window-exists-p)
    (neo-buffer--refresh)))

(defun myde/neotree-window-size-change-function (frame)
  "Sync `neo-window-width' when FRAME is resized."
  (let ((neo-window (neo-global--get-window)))
    (unless (null neo-window)
      (setq neo-window-width (window-width neo-window)))))

(provide 'myde-core-projects)
;;; lib.el ends here
