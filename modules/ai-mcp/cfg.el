;;; cfg.el --- MCP server configuration  -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Package configuration for the Emacs MCP (Model Context Protocol) server.
;;; Entry point for the ai-mcp module; loads lib.el automatically.
;;;
;;; mcp-server exposes live Emacs state to AI agents via a Unix domain socket.
;;; Agents connect through a socat stdio bridge — see README for claude mcp add.
;;; Exposed tools: eval-elisp, get-diagnostics, buffer read/write, Org suite.
;;; Installed from git via :vc — not available on MELPA.


;;; Code:

(unless (featurep 'myde-ai-mcp)
  (load-file (expand-file-name "modules/ai-mcp/lib.el" user-emacs-directory)))

;; -----------------------------------------------------------------------------
;; Emacs MCP server
;; -----------------------------------------------------------------------------

(use-package mcp-server  ;; https://github.com/rhblind/emacs-mcp-server
  :demand t
  :init
  (setq mcp-server-socket-directory (expand-file-name "emacs/" (xdg-cache-home))
        mcp-server-socket-name nil)
  :hook (emacs-startup . myde/mcp-server-startup-hook)
  :vc (:url "https://github.com/rhblind/emacs-mcp-server" :rev :newest)
  :ensure t)

(provide 'myde-ai-mcp-cfg)
;;; cfg.el ends here
