;;; lib.el --- Projects support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Library functions for project and project tree support.
;;; Loaded by myde-core-projects/cfg.el before package configuration.


;;; Code:

(require 'cl-generic)

(defun myde/project-try-override-dir (dir)
  "Return DIR as project root when it matches `project-current-directory-override'.
Ensures `project-switch-project' \"choose dir\" uses the chosen directory
as the project root, preventing VCS discovery from walking up to a
parent git repo (e.g. ~/devel) when an intermediate directory is selected."
  (when (and (boundp 'project-current-directory-override)
             project-current-directory-override
             (file-equal-p dir project-current-directory-override))
    (list 'myde-dir dir)))

(cl-defmethod project-root ((project (head myde-dir)))
  "Return the root directory of a myde-dir PROJECT."
  (cadr project))

(defun myde-eglot-add-workspace-config (server-key config)
  "Upsert CONFIG for SERVER-KEY in `eglot-workspace-configuration'.
Safe to call from multiple language modules independently; replaces
any existing entry for SERVER-KEY without clobbering other languages."
  (setq-default eglot-workspace-configuration
                (cons (cons server-key config)
                      (assq-delete-all server-key
                                       (default-value
                                         'eglot-workspace-configuration)))))

(defun myde--project-frame-title ()
  "Compute a frame title for the current buffer and frame.
Project frames show \"<project> - <relative-file>\" for file buffers
and \"<project> - <buffer-name>\" for non-file buffers.
Non-project frames show the buffer name."
  (let ((root (frame-parameter nil 'myde-project-root)))
    (if (not root)
        (buffer-name)
      (let* ((proj-name (file-name-nondirectory (directory-file-name root)))
             (file      (buffer-file-name))
             (truefile  (when file (file-truename file)))
             (suffix    (if (and truefile (string-prefix-p root truefile))
                            (file-relative-name truefile root)
                          (buffer-name))))
        (format "%s - %s" proj-name suffix)))))

(defun myde--buffer-in-project-p (buffer root)
  "Return non-nil if BUFFER's directory is under ROOT."
  (when-let ((dir (buffer-local-value 'default-directory buffer)))
    (string-prefix-p root (file-truename dir))))

(defun myde/project-buffer-list-advice (orig-fn &optional frame)
  "Sort project-local buffers to the front of the buffer list.
Around advice for `buffer-list'.  When the selected frame has a
`myde-project-root' parameter, buffers under that root appear first."
  (let* ((buffers (funcall orig-fn frame))
         (root (frame-parameter (or frame (selected-frame))
                                'myde-project-root)))
    (if (not root)
        buffers
      (let ((proj  (seq-filter (lambda (b) (myde--buffer-in-project-p b root)) buffers))
            (other (seq-remove (lambda (b) (myde--buffer-in-project-p b root)) buffers)))
        (append proj other)))))

(defun myde--project-find-frame (root)
  "Return live frame whose `myde-project-root' parameter equals ROOT, or nil."
  (cl-find root (frame-list)
           :key (lambda (f) (frame-parameter f 'myde-project-root))
           :test #'equal))

(defun myde/project-switch-to-frame-advice (orig-fn dir)
  "Open each project in its own frame; reuse the frame if already open.
Around advice for `project-switch-project'."
  (let* ((project  (project-current nil dir))
         (root     (file-truename (if project (project-root project) dir)))
         (existing (myde--project-find-frame root)))
    (if existing
        (select-frame-set-input-focus existing)
      (let* ((proj-name (file-name-nondirectory (directory-file-name root)))
             (frame (make-frame)))
        (set-frame-parameter frame 'myde-project-root root)
        (with-selected-frame frame
          (switch-to-buffer (get-buffer-create (format "*scratch<%s>*" proj-name)))
          (select-frame-set-input-focus frame)
          (funcall orig-fn dir))))))

(defun myde-neotree-project-root-toggle ()
  "Toggle NeoTree.  If opening, set the root to the current project root."
  (interactive)
  (if (and (fboundp 'neo-global--window-exists-p)
           (neo-global--window-exists-p))
      (neotree-hide)
    (let ((project (project-current)))
      (if project
          (neotree-dir (project-root project))
        (neotree-show)))))

(defun myde-neotree-refresh ()
  "Refresh neotree if visible."
  (when (and (fboundp 'neo-global--window-exists-p)
             (neo-global--window-exists-p))
    (neo-buffer--refresh)))

(defun myde-neotree-window-size-change-function (frame)
  "Sync `neo-window-width' when FRAME is resized."
  (when (fboundp 'neo-global--get-window)
    (let ((neo-window (neo-global--get-window)))
      (unless (null neo-window)
        (setq neo-window-width (window-width neo-window))))))

(provide 'myde-core-projects)
;;; lib.el ends here
