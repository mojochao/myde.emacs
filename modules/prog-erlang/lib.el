;;; lib.el --- Erlang support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Pure definitions (defun, defvar, defcustom) for the
;; `myde-prog-erlang' module.  No side effects — see cfg.el for
;; package configuration, hooks, and keybindings.


;;; Code:

(defun myde-erlang-mode-setup ()
  "Set buffer-local settings for erlang-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "rebar3 compile"))

(defun myde-erlang-run-tests ()
  "Run Common Test suite via rebar3."
  (interactive)
  (compile "rebar3 ct"))

(provide 'myde-prog-erlang)
;;; lib.el ends here
