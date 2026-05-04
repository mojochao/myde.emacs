;;; cfg.el --- JavaScript package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for JavaScript/JSX development support.
;;; Entry point for the prog-javascript module; loads lib.el automatically.
;;;
;;; Requires rass (npm install -g @rass/cli) and @vscode/js-debug for debugging.
;;;
;;; LSP is multiplexed via rass tslint, which combines typescript-language-server
;;; (completions, JSDoc types, inlay hints, code actions) with vscode-eslint-language-server
;;; (ESLint diagnostics) into a single stdio endpoint eglot treats as one server.
;;; :checkJs t enables JSDoc-based type inference in plain JS projects.
;;;
;;; js-ts-mode covers both .js and .jsx — the JavaScript tree-sitter grammar
;;; has native JSX node types; no separate grammar or mode is needed.
;;;
;;; Configures:
;;;   eglot + rass tslint    — multiplexed LSP
;;;   add-node-modules-path  — project-local node_modules/.bin on exec-path
;;;   apheleia + prettier    — format-on-save
;;;   jest-test-mode         — Jest test runner (C-c t prefix)
;;;   nodejs-repl            — Node.js REPL (C-c i prefix)
;;;   dape + @vscode/js-debug — DAP debugging (node-script and node-jest configs)


;;; Code:

(unless (featurep 'myde-prog-javascript)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(javascript "https://github.com/tree-sitter/tree-sitter-javascript"
                            "master" "src"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + rass tslint
;;
;; rass tslint multiplexes:
;;   - typescript-language-server  (completions, JSDoc types, inlay hints, code actions)
;;   - vscode-eslint-language-server (lint diagnostics via ESLint)
;;
;; :checkJs t enables type-checking of JS files via JSDoc annotations.
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((js-ts-mode . eglot-ensure)
         (js-ts-mode . myde-javascript-mode-hook))
  :config
  (add-to-list 'eglot-server-programs
               `((js-ts-mode)
                 . ("rass" "tslint"
                    :initializationOptions
                    (:preferences
                     (:checkJs t
                      :includeInlayParameterNameHints "all"
                      :includeInlayParameterNameHintsWhenArgumentMatchesName t
                      :includeInlayFunctionParameterTypeHints t
                      :includeInlayVariableTypeHints t
                      :includeInlayVariableTypeHintsWhenTypeMatchesName nil
                      :includeInlayPropertyDeclarationTypeHints t
                      :includeInlayFunctionLikeReturnTypeHints t
                      :includeInlayEnumMemberValueHints t
                      :importModuleSpecifierPreference "non-relative"
                      :includeCompletionsForModuleExports t
                      :includeCompletionsWithSnippetText t
                      :completeFunctionCalls t
                      :includeAutomaticOptionalChainCompletions t)))))
  :bind (:map eglot-mode-map
              ("C-c e r" . eglot-rename)
              ("C-c e a" . eglot-code-actions)
              ("C-c e f" . eglot-format-buffer))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; JavaScript / JSX major mode (built-in, Emacs 29+)
;;
;; js-ts-mode uses the javascript tree-sitter grammar which has native JSX
;; node support — no separate tsx grammar or mode needed for .jsx files.
;; -----------------------------------------------------------------------------

(use-package js
  :hook ((js-ts-mode . myde-js-ts-mode-setup)
         (js-ts-mode . myde-javascript-format-on-save-setup))
  :mode (("\\.js\\'"  . js-ts-mode)
         ("\\.jsx\\'" . js-ts-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Local node_modules tool resolution
;;
;; Prepends node_modules/.bin to exec-path so that project-local eslint,
;; prettier etc. shadow global installations.
;; -----------------------------------------------------------------------------

(use-package add-node-modules-path
  :hook (js-ts-mode . add-node-modules-path)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Formatting via apheleia + prettier
;;
;; apheleia itself is configured in prog-base.  Here we register prettier as
;; the formatter for JavaScript/JSX buffers.
;; -----------------------------------------------------------------------------

(use-package apheleia
  :config
  (setf (alist-get 'js-ts-mode apheleia-mode-alist) 'prettier)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Test runner: jest-test-mode
;; -----------------------------------------------------------------------------

(use-package jest-test-mode
  :hook (js-ts-mode . jest-test-mode)
  :bind (:map jest-test-mode-map
              ;; Remap from default C-c C-t prefix to module-standard C-c t
              ("C-c C-t t" . nil)
              ("C-c C-t n" . nil)
              ("C-c C-t p" . nil)
              ("C-c C-t a" . nil)
              ("C-c t t"   . jest-test-run-at-point)
              ("C-c t f"   . jest-test-run)
              ("C-c t p"   . jest-test-run-all-tests)
              ("C-c t r"   . jest-test-rerun-test))
  :custom
  (jest-test-options '("--no-coverage"))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Node.js REPL via nodejs-repl
;; -----------------------------------------------------------------------------

(use-package nodejs-repl
  :after js
  :bind (:map js-ts-mode-map
              ("C-c i i" . nodejs-repl)
              ("C-c i r" . nodejs-repl-send-region)
              ("C-c i b" . nodejs-repl-send-buffer)
              ("C-c i s" . nodejs-repl-switch-to-repl))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugging via dape + @vscode/js-debug
;;
;; Requires: npm install -g @vscode/js-debug
;; -----------------------------------------------------------------------------

(use-package dape
  :after transient
  :config
  (add-to-list 'dape-configs
               '(node-script
                 modes (js-ts-mode)
                 command "node"
                 command-args ("${userHome}/node_modules/@vscode/js-debug/src/dapDebugServer.js" "0")
                 :type "pwa-node"
                 :request "launch"
                 :program dape-buffer-default
                 :cwd "${workspaceFolder}"
                 :sourceMaps t
                 :console "integratedTerminal"))
  (add-to-list 'dape-configs
               '(node-jest
                 modes (js-ts-mode)
                 command "node"
                 command-args ("${userHome}/node_modules/@vscode/js-debug/src/dapDebugServer.js" "0")
                 :type "pwa-node"
                 :request "launch"
                 :runtimeExecutable "npx"
                 :runtimeArgs ["jest" "--testPathPattern" "${relativeFile}" "--no-coverage" "--runInBand"]
                 :cwd "${workspaceFolder}"
                 :sourceMaps t
                 :console "integratedTerminal"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((js . t))))
  :ensure nil)

(use-package indent-bars
  :hook (js-ts-mode . indent-bars-mode))

(provide 'myde-prog-javascript-cfg)
;;; cfg.el ends here
