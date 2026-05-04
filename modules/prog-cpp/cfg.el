;;; cfg.el --- C/C++ package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; C/C++ and CMake development via tree-sitter modes, clangd LSP, and codelldb debugger.
;; Entry point for the prog-cpp module; loads lib.el automatically.
;;
;; Requires clangd on PATH (brew install llvm or mise install).
;; Debugging requires codelldb on PATH (mason or manual install).
;;
;; Configures:
;;   treesit grammars         — c, cpp, cmake (auto-installed via treesit-auto)
;;   eglot + clangd           — LSP with --clang-tidy and detailed completion style
;;   c++-ts-mode              — .cpp/.cc/.cxx/.hpp/.hh/.hxx/.h files
;;   c-ts-mode                — .c files
;;   cmake-ts-mode            — CMakeLists.txt and .cmake files
;;   C-c t p                  — run tests (myde-cpp-run-tests)
;;   C-c o                    — toggle between header and implementation (ff-find-other-file)
;;   dape + codelldb          — DAP native debugging (cpp-debug config)


;;; Code:

(unless (featurep 'myde-prog-cpp)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammars
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(c     "https://github.com/tree-sitter/tree-sitter-c"))
  (add-to-list 'treesit-language-source-alist
               '(cpp   "https://github.com/tree-sitter/tree-sitter-cpp"))
  (add-to-list 'treesit-language-source-alist
               '(cmake "https://github.com/uyha/tree-sitter-cmake"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + clangd
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((c++-ts-mode . eglot-ensure)
         (c-ts-mode   . eglot-ensure)
         (c++-mode    . eglot-ensure)
         (c-mode      . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '((c++-ts-mode c-ts-mode c++-mode c-mode)
                 "clangd"
                 "--header-insertion=never"
                 "--clang-tidy"
                 "--completion-style=detailed"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; C/C++ mode
;; -----------------------------------------------------------------------------

(use-package c-ts-mode
  :hook ((c++-ts-mode . myde-cpp-ts-mode-setup)
         (c++-ts-mode . myde-cpp-format-on-save-setup)
         (c-ts-mode   . myde-c-ts-mode-setup)
         (c-ts-mode   . myde-cpp-format-on-save-setup))
  :bind ((:map c++-ts-mode-map
               ("C-c t p" . myde-cpp-run-tests)
               ("C-c o"   . ff-find-other-file))
         (:map c-ts-mode-map
               ("C-c t p" . myde-cpp-run-tests)
               ("C-c o"   . ff-find-other-file)))
  :mode (("\\.cpp\\'" . c++-ts-mode)
         ("\\.cc\\'"  . c++-ts-mode)
         ("\\.cxx\\'" . c++-ts-mode)
         ("\\.hpp\\'" . c++-ts-mode)
         ("\\.hh\\'"  . c++-ts-mode)
         ("\\.hxx\\'" . c++-ts-mode)
         ("\\.h\\'"   . c++-ts-mode)
         ("\\.c\\'"   . c-ts-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; CMake mode
;; -----------------------------------------------------------------------------

(use-package cmake-ts-mode
  :mode (("CMakeLists\\.txt\\'" . cmake-ts-mode)
         ("\\.cmake\\'"         . cmake-ts-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Debugging via dape + codelldb
;; -----------------------------------------------------------------------------

(use-package dape
  :config
  (add-to-list 'dape-configs
               '(cpp-debug
                 modes (c++-ts-mode c-ts-mode c++-mode c-mode)
                 command "codelldb"
                 command-args ("--port" :port)
                 port :autoport
                 :type "lldb"
                 :request "launch"
                 :program myde-cpp-dape-binary))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((C . t))))
  :ensure nil)

(use-package indent-bars
  :hook ((c++-ts-mode c-ts-mode cmake-ts-mode) . indent-bars-mode))

(provide 'myde-prog-cpp-cfg)
;;; cfg.el ends here
