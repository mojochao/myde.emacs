;;; lib.el --- Nushell support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Library functions for Nushell script development support.
;;; Loaded by myde-prog-nushell/cfg.el before package configuration.
;;;
;;; External dependencies:
;;;   - Nushell >= 0.87.0 (LSP built-in via `nu --lsp`)
;;;   - nufmt (optional, pre-alpha): cargo install --git https://github.com/nushell/nufmt
;;;
;;; NOTE: nufmt is pre-alpha and can corrupt scripts.  It is registered in
;;; apheleia but not auto-enabled on save.  Users can invoke M-x
;;; apheleia-format-buffer manually or opt-in per-project via .dir-locals.el.


;;; Code:

(defun myde-nushell-mode-setup ()
  "Set buffer-local settings for nushell-mode buffers."
  (setq-local tab-width 2
              indent-tabs-mode nil
              fill-column 100))

(defun myde-nushell-open-repl ()
  "Open or switch to the *nu* REPL buffer."
  (interactive)
  (let ((buf (get-buffer "*nu*")))
    (if buf
        (pop-to-buffer buf)
      (run-program-in-buffer "nu" "*nu*"))))

(defun run-program-in-buffer (program buffer-name)
  "Run PROGRAM in a comint buffer named BUFFER-NAME."
  (let ((buffer (get-buffer-create buffer-name)))
    (with-current-buffer buffer
      (unless (comint-check-proc (current-buffer))
        (make-comint-in-buffer program buffer-name program)))
    (pop-to-buffer buffer)))

(defun myde-nushell-send-region (start end)
  "Send region between START and END to the *nu* REPL buffer.
Opens the REPL buffer if it does not already exist."
  (interactive "r")
  (let ((text (buffer-substring-no-properties start end)))
    (myde-nushell-open-repl)
    (process-send-string
     (get-buffer-process (get-buffer "*nu*"))
     (concat text "\n"))))

(defun myde-nushell-send-buffer ()
  "Send the entire buffer contents to the *nu* REPL buffer."
  (interactive)
  (myde-nushell-send-region (point-min) (point-max)))

(defun myde-nushell-run-buffer ()
  "Save the current buffer and execute it with nu in a *compilation* buffer."
  (interactive)
  (save-buffer)
  (compile (concat "nu " (shell-quote-argument (buffer-file-name)))))

(provide 'myde-prog-nushell)
;;; lib.el ends here
