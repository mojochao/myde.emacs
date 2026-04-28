;;; lib.el --- Erlang support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Code:

(defun myde/erlang-mode-setup ()
  "Set buffer-local settings for erlang-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "rebar3 compile"))

(defun myde/erlang-run-tests ()
  "Run Common Test suite via rebar3."
  (interactive)
  (compile "rebar3 ct"))

(provide 'myde-prog-erlang)
;;; lib.el ends here
