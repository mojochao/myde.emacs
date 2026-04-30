;;; cfg.el --- C/C++ package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

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
  :hook ((c++-ts-mode . myde/cpp-ts-mode-setup)
         (c++-ts-mode . myde/delete-trailing-whitespace-setup)
         (c++-ts-mode . myde/cpp-format-on-save-setup)
         (c-ts-mode   . myde/c-ts-mode-setup)
         (c-ts-mode   . myde/delete-trailing-whitespace-setup)
         (c-ts-mode   . myde/cpp-format-on-save-setup))
  :bind ((:map c++-ts-mode-map
               ("C-c t p" . myde/cpp-run-tests)
               ("C-c o"   . ff-find-other-file))
         (:map c-ts-mode-map
               ("C-c t p" . myde/cpp-run-tests)
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
                 :program myde/cpp-dape-binary))
  :ensure nil)

(provide 'myde-prog-cpp-cfg)
;;; cfg.el ends here
