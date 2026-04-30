;;; lib.el --- Rust support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Code:

(defun myde/rust-mode-setup ()
  "Set buffer-local settings for rustic-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "cargo test"))

(declare-function dape-cwd "dape")

(defun myde/rust-dape-debug-program ()
  "Resolve the debug binary path for the current Rust project.
Used as the `:program' callback for dape Rust debug configurations."
  (expand-file-name
   (concat "target/debug/"
           (file-name-nondirectory (directory-file-name (dape-cwd))))
   (dape-cwd)))

(provide 'myde-prog-rust)
;;; lib.el ends here
