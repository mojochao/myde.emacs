;;; myde/prog-scheme/lib.el --- Scheme development environment definitions -*- lexical-binding: t; -*-

;;; Commentary:

;; Pure definitions for Scheme development: project setup, LSP server detection,
;; and formatter guards. See cfg.el for side effects.

;;; Code:

(defun myde/prog-scheme-setup ()
  "Setup Scheme development environment.

Adds project root markers for various Scheme toolchains and registers
the tree-sitter grammar for future compatibility."
  ;; Add Scheme-specific project root markers
  ;; .guile — Guile-specific configuration
  ;; guix.scm — Guix package definition (uses Guile)
  ;; akku.manifest — Akku package manager manifest
  ;; .akku/ — Akku directory
  ;; chicken-install.log — CHICKEN package installation log
  (add-to-list 'project-vc-extra-root-markers ".guile")
  (add-to-list 'project-vc-extra-root-markers "guix.scm")
  (add-to-list 'project-vc-extra-root-markers "akku.manifest")
  (add-to-list 'project-vc-extra-root-markers ".akku")
  (add-to-list 'project-vc-extra-root-markers "chicken-install.log")

  ;; Register tree-sitter grammar for Scheme
  ;; No scheme-ts-mode remap yet (not on MELPA), but grammar is available for future use
  (when (treesit-available-p)
    (add-to-list 'treesit-language-source-alist
      '(scheme "https://github.com/6cdh/tree-sitter-scheme"))))

(defun myde/prog-scheme-lsp-server ()
  "Detect and return appropriate LSP server command for Scheme.

Returns the first available LSP server from:
1. scheme-langserver (general, R6RS/R7RS, Chez-based)
2. guile-lsp-server (Guile-specific)
3. chicken-lsp-server (CHICKEN-specific)

Returns nil if none are available (eglot gracefully skips LSP)."
  (cond
    ((executable-find "scheme-langserver")
     '("scheme-langserver"))
    ((executable-find "guile-lsp-server")
     '("guile-lsp-server"))
    ((executable-find "chicken-lsp-server")
     '("chicken-lsp-server"))
    (t nil)))

(defun myde/prog-scheme-format-buffer-maybe ()
  "Guard function for schemat before-save formatting.

Only formats if:
1. Current major mode is scheme-mode
2. schemat binary is on PATH
3. eglot is managing the buffer (LSP is active)

This allows schemat to be optional; formatting silently skips if binary is absent."
  (and (eq major-mode 'scheme-mode)
       (executable-find "schemat")
       (bound-and-true-p eglot--managed-mode)))

(provide 'myde-prog-scheme)

;;; myde/prog-scheme/lib.el ends here
