;;; lib.el --- JSON editing support library -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; JSON and jq file editing utilities.


;;; Code:

(define-derived-mode jsonl-mode json-ts-mode "JSONL"
  "Major mode for JSON Lines files.")

(defun myde-json-ts-mode-hook ()
  "Enable eglot for JSON buffers, but not JSONL."
  (unless (derived-mode-p 'jsonl-mode)
    (eglot-ensure)))

(provide 'myde-data-json)
;;; lib.el ends here
