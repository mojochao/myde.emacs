;;; cfg.el --- Lua package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Lua development via lua-mode, lua-ts-mode, lua-language-server LSP,
;; inf-lua REPL, and ob-lua Org Babel integration.
;; Entry point for the prog-lua module; loads lib.el automatically.
;;
;; Requires lua-language-server on PATH (brew install lua-language-server
;; or mise use lua-language-server).
;; Requires lua on PATH for REPL and org-babel execution.
;;
;; Configures:
;;   treesit grammar          — lua grammar (auto-installed via treesit-auto)
;;   eglot + lua-ls           — LSP with inlay hints
;;   lua-mode                 — fallback major mode for .lua files
;;   lua-ts-mode              — tree-sitter major mode for .lua files
;;   inf-lua                  — interactive Lua REPL (C-c i prefix)
;;   ob-lua                   — Org Babel Lua block evaluation


;;; Code:

(unless (featurep 'myde-prog-lua)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(lua "https://github.com/tree-sitter-grammars/tree-sitter-lua"
                     "master" "lua/src"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + lua-language-server
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((lua-ts-mode . eglot-ensure)
         (lua-mode    . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '((lua-ts-mode lua-mode) . ("lua-language-server")))
  (myde-eglot-add-workspace-config
   :Lua '(:hint (:enable t
                 :arrayIndex "Enable"
                 :await t
                 :paramName "All"
                 :setType t)
          :diagnostics (:enable t)
          :completion (:callSnippet "Replace")))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Lua mode (fallback, no tree-sitter)
;; -----------------------------------------------------------------------------

(use-package lua-mode  ;; https://github.com/immerrr/lua-mode
  :hook ((lua-mode . myde-lua-mode-setup)
         (lua-mode . myde-lua-format-on-save-setup))
  :bind (:map lua-mode-map
              ("C-c i i" . inf-lua)
              ("C-c i r" . lua-send-region)
              ("C-c i b" . lua-send-buffer)
              ("C-c i s" . lua-show-process-buffer))
  :mode ("\\.lua\\'" . myde-lua-ts-or-plain-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Lua tree-sitter mode
;; -----------------------------------------------------------------------------

(use-package lua-ts-mode  ;; built-in Emacs 29+
  :hook ((lua-ts-mode . myde-lua-mode-setup)
         (lua-ts-mode . myde-lua-format-on-save-setup))
  :bind (:map lua-ts-mode-map
              ("C-c i i" . inf-lua)
              ("C-c i r" . inf-lua-send-region)
              ("C-c i b" . inf-lua-send-buffer)
              ("C-c i s" . inf-lua-switch-to-repl))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Interactive Lua REPL via inf-lua
;; -----------------------------------------------------------------------------

(use-package inf-lua  ;; https://github.com/nverno/inf-lua
  :vc (:url "https://github.com/nverno/inf-lua" :rev :newest)
  :hook ((lua-mode    . inf-lua-minor-mode)
         (lua-ts-mode . inf-lua-minor-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((lua . t))))
  :ensure nil)

(use-package indent-bars
  :hook ((lua-ts-mode lua-mode) . indent-bars-mode))

(provide 'myde-prog-lua-cfg)
;;; cfg.el ends here
