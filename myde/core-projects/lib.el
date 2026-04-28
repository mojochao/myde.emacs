;;; lib.el --- Projects support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Library functions for project and project tree support.
;;; Loaded by myde/core-projects/cfg.el before package configuration.

;;; Code:

(defun myde/eglot-add-workspace-config (server-key config)
  "Upsert CONFIG for SERVER-KEY in `eglot-workspace-configuration'.
Safe to call from multiple language modules independently; replaces
any existing entry for SERVER-KEY without clobbering other languages."
  (setq-default eglot-workspace-configuration
                (cons (cons server-key config)
                      (assq-delete-all server-key
                                       (default-value
                                         'eglot-workspace-configuration)))))

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
