;;; lib.el --- Rust support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Code:

(defun myde/rust-mode-setup ()
  "Set buffer-local settings for rustic-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "cargo test"))

(provide 'myde-prog-rust)
;;; lib.el ends here
