;;; lib.el --- Bash support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Library functions for Bash script development support.
;;; Loaded by myde-prog-bash/cfg.el before package configuration.
;;;
;;; External dependencies (install once, globally):
;;;   npm install -g bash-language-server
;;;   apt install shellcheck   (or: brew install shellcheck)
;;;   brew install shfmt       (or: go install mvdan.cc/sh/v3/cmd/shfmt@latest)
;;;
;;; Debugging via dape requires the bash-debug DAP adapter vsix:
;;;   https://github.com/rogalmic/vscode-bash-debug/releases
;;;   mkdir -p $XDG_DATA_HOME/emacs/debug-adapters
;;;   unzip bash-debug-*.vsix -d $XDG_DATA_HOME/emacs/debug-adapters/bash-debug
;;;
;;; bash-language-server automatically invokes shellcheck (lint diagnostics and
;;; code actions) and shfmt (format document) when both are on PATH.  No
;;; separate flymake-shellcheck or flycheck-shellcheck is needed.


;;; Code:

(defun myde-bash-ts-mode-setup ()
  "Set buffer-local settings for bash-ts-mode buffers."
  (setq-local sh-basic-offset 2
              indent-tabs-mode nil
              fill-column 80))

(defun myde-bash-eglot-format-buffer ()
  "Format buffer via eglot when in bash-ts-mode and eglot is active.
Safe to add to `before-save-hook' globally; it is a no-op outside of
bash-ts-mode buffers and buffers where eglot is not managing."
  (when (and (eq major-mode 'bash-ts-mode)
             (bound-and-true-p eglot--managed-mode))
    (eglot-format-buffer)))

(defun myde-bash-open-shell ()
  "Open or switch to the *shell* comint buffer."
  (interactive)
  (let ((buf (get-buffer "*shell*")))
    (if buf
        (pop-to-buffer buf)
      (shell))))

(defun myde-bash-send-region (start end)
  "Send region between START and END to the *shell* buffer.
Opens the shell buffer if it does not already exist."
  (interactive "r")
  (let ((text (buffer-substring-no-properties start end)))
    (myde-bash-open-shell)
    (process-send-string
     (get-buffer-process (get-buffer "*shell*"))
     (concat text "\n"))))

(defun myde-bash-send-buffer ()
  "Send the entire buffer contents to the *shell* buffer."
  (interactive)
  (myde-bash-send-region (point-min) (point-max)))

(defun myde-bash-run-buffer ()
  "Save the current buffer and execute it with bash in a *compilation* buffer."
  (interactive)
  (save-buffer)
  (compile (concat "bash " (shell-quote-argument (buffer-file-name)))))

(provide 'myde-prog-bash)
;;; lib.el ends here
