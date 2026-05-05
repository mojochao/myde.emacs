;;; lib.el --- MCP server support library  -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Library for MCP (Model Context Protocol) server support.
;;; Loaded by myde-ai-mcp/cfg.el before package configuration.


;;; Code:

(defun myde/mcp-server-startup-hook ()
  "Start the Emacs MCP server on Emacs startup."
  (mcp-server-start-unix))

(provide 'myde-ai-mcp)
;;; lib.el ends here
