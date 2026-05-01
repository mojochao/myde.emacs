;;; cfg.el --- Bash package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for Bash script development support.
;;; Entry point for the prog-bash module; loads lib.el automatically.
;;;
;;; Requires bash-language-server, shellcheck, and shfmt on PATH.
;;; bash-language-server natively integrates both tools: shellcheck surfaces
;;; SC* diagnostics and code-fix actions; shfmt handles format-document requests.
;;; apheleia runs shfmt directly for format-on-save (async, point-preserving).
;;;
;;; .sh, .bash, and .bats files activate bash-ts-mode (BATS scripts are valid bash).
;;; Overrides the sh → shell-script-mode mapping from core-base so that bash
;;; shebangs activate bash-ts-mode instead.
;;;
;;; Debugging requires the bash-debug DAP adapter vsix (rogalmic/vscode-bash-debug).
;;; See lib.el for one-time installation instructions.


;;; Code:

(unless (featurep 'myde-prog-bash)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(bash "https://github.com/tree-sitter/tree-sitter-bash"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; interpreter-mode-alist override
;;
;; core-base maps bash shebangs to shell-script-mode.  Override that entry so
;; #!/usr/bin/env bash and #!/bin/bash shebangs activate bash-ts-mode instead.
;; -----------------------------------------------------------------------------

(use-package emacs
  :config
  (add-to-list 'interpreter-mode-alist '("bash" . bash-ts-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + bash-language-server
;;
;; bash-language-server automatically:
;;   - calls shellcheck on each file change (500ms debounce) and surfaces
;;     SC* diagnostics and quick-fix code actions through LSP
;;   - calls shfmt on "format document" requests if shfmt is on PATH
;;
;; initializationOptions configure shellcheck behaviour and workspace scanning.
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook (bash-ts-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '((bash-ts-mode) . ("bash-language-server" "start")))
  (myde-eglot-add-workspace-config
   :bashIde '(:shellcheckEnabled t
              :shellcheckArguments []
              :shfmt (:ignoreEditorconfig nil
                      :simplifyCode nil
                      :binaryNextLine nil
                      :switchCaseIndent nil
                      :spaceRedirects nil)
              :includeAllWorkspaceSymbols nil
              :backgroundAnalysisMaxFiles 500))
  :bind (:map eglot-mode-map
              ("C-c e r" . eglot-rename)
              ("C-c e a" . eglot-code-actions)
              ("C-c e f" . eglot-format-buffer))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Bash major mode (built-in, Emacs 30+)
;;
;; bash-ts-mode uses the bash tree-sitter grammar and provides superior syntax
;; highlighting over the regex-based sh-mode, particularly for heredocs, process
;; substitutions, and complex parameter expansions.
;;
;; .bats files are BATS (Bash Automated Testing System) test scripts — they are
;; valid bash and parse correctly under bash-ts-mode.
;; -----------------------------------------------------------------------------

(use-package sh-script
  :hook ((bash-ts-mode . myde-bash-ts-mode-setup))
  :mode (("\\.sh\\'"   . bash-ts-mode)
         ("\\.bash\\'" . bash-ts-mode)
         ("\\.bats\\'" . bash-ts-mode))
  :bind (:map bash-ts-mode-map
              ("C-c i i" . myde-bash-open-shell)
              ("C-c i r" . myde-bash-send-region)
              ("C-c i b" . myde-bash-send-buffer)
              ("C-c i x" . myde-bash-run-buffer))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Formatting via apheleia + shfmt
;;
;; apheleia itself is configured in prog-base.  Here we register shfmt as the
;; formatter for bash-ts-mode buffers.  apheleia's shfmt entry reads sh-shell
;; and sh-basic-offset, so indentation follows the buffer-local settings set
;; by myde-bash-ts-mode-setup.
;; -----------------------------------------------------------------------------

(use-package apheleia
  :config
  (setf (alist-get 'bash-ts-mode apheleia-mode-alist) 'shfmt)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Debugging via dape + bash-debug
;;
;; Requires the bash-debug DAP adapter vsix (rogalmic/vscode-bash-debug).
;; One-time setup:
;;   mkdir -p $XDG_DATA_HOME/emacs/debug-adapters
;;   unzip bash-debug-*.vsix -d $XDG_DATA_HOME/emacs/debug-adapters/bash-debug
;; -----------------------------------------------------------------------------

(use-package dape
  :after transient
  :config
  (add-to-list 'dape-configs
               `(bash-debug
                 modes (bash-ts-mode)
                 command "node"
                 command-args (,(expand-file-name
                                 "emacs/debug-adapters/bash-debug/extension/out/bashDebug.js"
                                 (xdg-data-home)))
                 :type "bashdb"
                 :request "launch"
                 :program dape-buffer-default
                 :pathBashdb "bashdb"
                 :pathBash "bash"
                 :pathCat "cat"
                 :pathMkfifo "mkfifo"
                 :pathPkill "pkill"
                 :showDebugOutput nil
                 :trace nil))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((shell . t))))
  :ensure nil)

(provide 'myde-prog-bash-cfg)
;;; cfg.el ends here
