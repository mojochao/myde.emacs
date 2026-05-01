;;; cfg.el --- Zig package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Zig development via zig-mode, zig-ts-mode, zls LSP, and codelldb debugger.
;; Entry point for the prog-zig module; loads lib.el automatically.
;;
;; Requires zls on PATH (zig-specific — install via mise or from source).
;; Debugging requires codelldb on PATH (mason or manual install).
;;
;; Configures:
;;   treesit grammar          — zig grammar (auto-installed via treesit-auto)
;;   eglot + zls              — LSP with build-on-save and inlay hints
;;   zig-mode                 — fallback major mode for .zig and .zon files
;;   zig-ts-mode              — tree-sitter major mode for .zig and .zon files
;;   C-c t p                  — run project tests (zig build test)
;;   dape + codelldb          — DAP debugging (zig-debug config)
;;   ob-zig                   — Org Babel Zig block evaluation


;;; Code:

(unless (featurep 'myde-prog-zig)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(zig "https://github.com/maxxmino/tree-sitter-zig"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + zls
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((zig-ts-mode . eglot-ensure)
         (zig-mode    . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '((zig-ts-mode zig-mode) . ("zls")))
  (myde-eglot-add-workspace-config
   :zls '(:enable_build_on_save t
          :inlay_hints_show_builtin t
          :inlay_hints_exclude_single_argument t
          :inlay_hints_show_parameter_name t
          :inlay_hints_show_variable_type_hints t))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Zig mode (fallback, no tree-sitter)
;; -----------------------------------------------------------------------------

(use-package zig-mode  ;; https://github.com/ziglang/zig-mode
  :hook ((zig-mode . myde-zig-mode-setup)
         (zig-mode . myde-zig-format-on-save-setup))
  :bind (:map zig-mode-map
              ("C-c t p" . zig-test-all))
  :mode (("\\.zig\\'" . myde-zig-ts-or-plain-mode)
         ("\\.zon\\'" . myde-zig-ts-or-plain-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Zig tree-sitter mode
;; -----------------------------------------------------------------------------

(use-package zig-ts-mode  ;; https://github.com/emacsmirror/zig-ts-mode
  :vc (:url "https://github.com/emacsmirror/zig-ts-mode" :rev :newest)
  :hook ((zig-ts-mode . myde-zig-mode-setup)
         (zig-ts-mode . myde-zig-format-on-save-setup))
  :bind (:map zig-ts-mode-map
              ("C-c t p" . zig-test-all))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugging via dape + codelldb
;; -----------------------------------------------------------------------------

(use-package dape
  :config
  (add-to-list 'dape-configs
               `(zig-debug
                 modes (zig-ts-mode zig-mode)
                 command "codelldb"
                 command-args ("--port" :port)
                 port :autoport
                 :type "lldb"
                 :request "launch"
                 :program ,#'myde-zig-dape-binary))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package ob-zig  ;; https://github.com/jolby/ob-zig.el
  :vc (:url "https://github.com/jolby/ob-zig.el" :rev :newest)
  :after org
  :ensure t)

(provide 'myde-prog-zig-cfg)
;;; cfg.el ends here
