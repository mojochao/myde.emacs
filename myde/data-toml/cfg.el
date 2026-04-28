;;; cfg.el --- TOML editing configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; TOML mode setup with tree-sitter parsing and LSP support via eglot.

;;; Code:

(unless (featurep 'myde-data-toml)
  (load-file (expand-file-name "myde/data-toml/lib.el" user-emacs-directory)))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(toml "https://github.com/tree-sitter-grammars/tree-sitter-toml"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + taplo
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((toml-ts-mode . eglot-ensure)
         (toml-mode    . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '(toml-ts-mode . ("taplo" "lsp" "stdio")))
  (add-to-list 'eglot-server-programs
               '(toml-mode . ("taplo" "lsp" "stdio")))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; TOML mode
;; -----------------------------------------------------------------------------

(use-package toml-mode  ;; https://github.com/dryman/toml-mode.el
  :config
  :hook
  ((toml-ts-mode . myde/toml-ts-mode-setup)
   (toml-ts-mode . display-line-numbers-mode)
   (toml-ts-mode . myde/delete-trailing-whitespace-setup))
  :mode
  (("\\.toml\\'" . myde/toml-ts-or-plain-mode)
   ("Cargo\\.lock\\'" . myde/toml-ts-or-plain-mode))
  :ensure t)

(provide 'myde-data-toml-cfg)
;;; cfg.el ends here
