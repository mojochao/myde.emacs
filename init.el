;;; init.el --- Loaded after early-init.el -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration
;; Package-Requires: ((emacs "31.1"))

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;
;; Entry point for MyDE -- *MY* Development Environment.
;;
;; All configuration lives in user-lisp/myde.el, which Emacs 31 places on
;; `load-path' automatically via `user-lisp-directory'.

;;; Code:

(require 'myde)

;; A daemon starts its own server from startup.el after init; only GUI and
;; TTY sessions need one here.  (`server-name' is still "server" at this
;; point even under --daemon=NAME, so an unguarded start would grab the
;; user's default socket.)
(unless (daemonp)
  (require 'server)
  (unless (server-running-p) (server-start)))

;; That's all Folks!
(provide 'init)
;;; init.el ends here
