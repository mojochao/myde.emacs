;;; cfg.el --- TypeScript package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for TypeScript/TSX development support.
;;; Entry point for the prog-typescript module; loads lib.el automatically.
;;;
;;; Requires rass (npm install -g @rass/cli) and @vscode/js-debug for debugging.
;;;
;;; LSP is multiplexed via rass tslint, which combines typescript-language-server
;;; (completions, types, inlay hints, code actions) with vscode-eslint-language-server
;;; (ESLint diagnostics) into a single stdio endpoint eglot treats as one server.
;;; The tslint preset includes custom ESLint initialization not available in the
;;; manual composition form (rass -- ts-ls -- eslint-ls).
;;;
;;; Configures:
;;;   eglot + rass tslint    — multiplexed LSP for typescript-ts-mode and tsx-ts-mode
;;;   add-node-modules-path  — project-local node_modules/.bin on exec-path
;;;   apheleia + prettier    — format-on-save
;;;   jest-test-mode         — Jest test runner (C-c t prefix)
;;;   ts-comint              — TypeScript REPL (C-c i prefix)
;;;   dape + @vscode/js-debug — DAP debugging (ts-node-script and ts-jest configs)


;;; Code:

(unless (featurep 'myde-prog-typescript)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammars
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(typescript "https://github.com/tree-sitter/tree-sitter-typescript"
                            "master" "typescript/src"))
  (add-to-list 'treesit-language-source-alist
               '(tsx "https://github.com/tree-sitter/tree-sitter-typescript"
                     "master" "tsx/src"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Project root detection
;; -----------------------------------------------------------------------------

;; Ensure eglot and project.el find the project root for node projects that
;; may not have a .git directory at the TS root.
(use-package project
  :config
  (dolist (marker '("tsconfig.json" "jsconfig.json" "package.json"))
    (add-to-list 'project-vc-extra-root-markers marker))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + rass tslint
;;
;; rass tslint multiplexes:
;;   - typescript-language-server  (completions, types, inlay hints, code actions)
;;   - vscode-eslint-language-server (lint diagnostics via ESLint)
;;
;; Eglot's native $/streamDiagnostics support lets both servers' diagnostics
;; appear incrementally without waiting for aggregation.
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((typescript-ts-mode . eglot-ensure)
         (tsx-ts-mode        . eglot-ensure)
         (typescript-ts-mode . myde/typescript-mode-hook)
         (tsx-ts-mode        . myde/typescript-mode-hook))
  :config
  (add-to-list 'eglot-server-programs
               `((typescript-ts-mode tsx-ts-mode)
                 . ("rass" "tslint"
                    :initializationOptions
                    (:preferences
                     (:includeInlayParameterNameHints "all"
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
;; TypeScript / TSX major modes (built-in, Emacs 29+)
;; -----------------------------------------------------------------------------

(use-package typescript-ts-mode
  :hook ((typescript-ts-mode . myde/typescript-ts-mode-setup)
         (tsx-ts-mode        . myde/tsx-ts-mode-setup)
         (typescript-ts-mode . myde/delete-trailing-whitespace-setup)
         (tsx-ts-mode        . myde/delete-trailing-whitespace-setup)
         (typescript-ts-mode . myde/typescript-format-on-save-setup)
         (tsx-ts-mode        . myde/typescript-format-on-save-setup))
  :mode (("\\.ts\\'"  . typescript-ts-mode)
         ("\\.tsx\\'" . tsx-ts-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Local node_modules tool resolution
;;
;; Prepends node_modules/.bin to exec-path so that project-local eslint,
;; prettier, typescript-language-server etc. shadow global installations.
;; -----------------------------------------------------------------------------

(use-package add-node-modules-path
  :hook ((typescript-ts-mode . add-node-modules-path)
         (tsx-ts-mode        . add-node-modules-path))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Formatting via apheleia + prettier
;;
;; apheleia itself is configured in prog-base.  Here we register prettier as
;; the formatter for TypeScript and TSX buffers.
;; -----------------------------------------------------------------------------

(use-package apheleia
  :config
  (setf (alist-get 'typescript-ts-mode apheleia-mode-alist) 'prettier)
  (setf (alist-get 'tsx-ts-mode        apheleia-mode-alist) 'prettier)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Test runner: jest-test-mode
;; -----------------------------------------------------------------------------

(use-package jest-test-mode
  :hook ((typescript-ts-mode . jest-test-mode)
         (tsx-ts-mode        . jest-test-mode))
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
;; TypeScript REPL via ts-comint
;; -----------------------------------------------------------------------------

(use-package ts-comint
  :after typescript-ts-mode
  :bind (:map typescript-ts-mode-map
              ("C-c i i" . run-ts)
              ("C-c i r" . ts-send-region)
              ("C-c i b" . ts-send-buffer)
              ("C-c i s" . ts-send-buffer-and-go))
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
               '(ts-node-script
                 modes (typescript-ts-mode tsx-ts-mode)
                 command "node"
                 command-args ("${userHome}/node_modules/@vscode/js-debug/src/dapDebugServer.js" "0")
                 :type "pwa-node"
                 :request "launch"
                 :runtimeExecutable "ts-node"
                 :program dape-buffer-default
                 :cwd "${workspaceFolder}"
                 :sourceMaps t
                 :console "integratedTerminal"))
  (add-to-list 'dape-configs
               '(ts-jest
                 modes (typescript-ts-mode tsx-ts-mode)
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

(use-package ob-typescript  ;; https://github.com/lurdan/ob-typescript
  :after org
  :ensure t)

(provide 'myde-prog-typescript-cfg)
;;; cfg.el ends here
