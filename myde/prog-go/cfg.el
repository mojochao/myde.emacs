;;; cfg.el --- Go package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Package configuration for Go development support.
;;; Entry point for the prog-go module; loads lib.el automatically.

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
  :ensure nil)

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

(provide 'myde-prog-go-cfg)
;;; cfg.el ends here
