;;; cfg.el --- Go package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for Go development support.
;;; Entry point for the prog-go module; loads lib.el automatically.
;;;
;;; Requires gopls and dlv on PATH:
;;;   go install golang.org/x/tools/gopls@latest
;;;   go install github.com/go-delve/delve/cmd/dlv@latest
;;;
;;; Configures:
;;;   treesit grammar          — go tree-sitter grammar (auto-installed)
;;;   eglot + gopls            — LSP with staticcheck, gofumpt, inlay hints
;;;   go-mode                  — mode launcher; gofmt runs on save
;;;   gotest-ts                — test runner (C-c t t/f/p/r)
;;;   dape + dlv               — DAP debugging (go-debug and go-test configs)


;;; Code:

(unless (featurep 'myde-prog-go)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(go "https://github.com/tree-sitter-grammars/tree-sitter-go"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + gopls
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((go-ts-mode . eglot-ensure)
         (go-mode    . eglot-ensure))
  :config
  (myde/eglot-add-workspace-config
   :gopls '(:staticcheck t
            :gofumpt t
            :usePlaceholders t
            :completeUnimported t
            :semanticTokens t
            :hints (:assignVariableTypes t
                    :compositeLiteralFields t
                    :compositeLiteralTypes t
                    :constantValues t
                    :functionTypeParameters t
                    :parameterNames t
                    :rangeVariableTypes t)))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Go mode
;; -----------------------------------------------------------------------------

(use-package go-mode  ;; https://github.com/dominikh/go-mode.el
  :custom
  (go-ts-mode-indent-offset 4)
  :hook
  ((go-ts-mode . myde/go-ts-mode-setup)
   (go-ts-mode . myde/go-format-on-save-setup))
  :mode
  (("\\.go\\'" . myde/go-ts-or-plain-mode))
  :ensure t)

(use-package gotest-ts  ;; https://github.com/chmouel/gotest-ts.el
  :vc (:url "https://github.com/chmouel/gotest-ts.el" :rev :newest)
  :after go-mode
  :hook (go-ts-mode . gotest-ts-setup)
  :bind (:map go-ts-mode-map
              ("C-c t t" . gotest-ts-run-dwim)
              ("C-c t f" . gotest-ts-run-file)
              ("C-c t p" . gotest-ts-run-package)
              ("C-c t r" . gotest-ts-repeat))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugging via dape + dlv
;; -----------------------------------------------------------------------------

(use-package dape
  :after transient
  :config
  (add-to-list 'dape-configs
               '(go-debug
                 modes (go-ts-mode go-mode)
                 command "dlv"
                 command-args ("dap")
                 :type "go"
                 :request "launch"
                 :mode "debug"
                 :program "."))
  (add-to-list 'dape-configs
               '(go-test
                 modes (go-ts-mode go-mode)
                 command "dlv"
                 command-args ("dap")
                 :type "go"
                 :request "launch"
                 :mode "test"
                 :program "."))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package ob-go  ;; https://github.com/pope/ob-go
  :after org
  :ensure t)

(provide 'myde-prog-go-cfg)
;;; cfg.el ends here
