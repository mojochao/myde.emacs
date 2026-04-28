;;; lib.el --- Python support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Library functions for Python development support.
;;; Loaded by myde/prog-python/cfg.el before package configuration.

;;; Code:


(defun myde/python-ts-mode-setup ()
  "Set buffer-local settings for python-ts-mode buffers.
Runs after mise-mode has applied the project environment, so
`executable-find' resolves against the project venv."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 88  ; ruff/black default line length
              python-shell-interpreter (or (executable-find "python3")
                                           (executable-find "python")
                                           "python3")
              compile-command "python -m pytest"))

(provide 'myde-prog-python)
;;; lib.el ends here
