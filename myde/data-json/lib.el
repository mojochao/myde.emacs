;;; lib.el --- JSON editing support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; JSON and jq file editing utilities.

;;; Code:

(define-derived-mode jsonl-mode json-ts-mode "JSONL"
  "Major mode for JSON Lines files.")

(defun myde/json-ts-mode-hook ()
  "Enable eglot for JSON buffers, but not JSONL."
  (unless (derived-mode-p 'jsonl-mode)
    (eglot-ensure)))

(provide 'myde-data-json)
;;; lib.el ends here
