;;; myde/prog-clisp/lib.el --- Common Lisp development environment definitions -*- lexical-binding: t; -*-

;;; Commentary:

;; Pure definitions for Common Lisp development: project setup, SLY/SLIME
;; initialization, and optional LSP detection. See cfg.el for side effects.

;;; Code:

(defun myde/prog-clisp-setup ()
  "Setup Common Lisp development environment.

Adds project root markers for various CL toolchains and registers the
tree-sitter grammar for future commonlisp-ts-mode compatibility."
  ;; Add Common Lisp-specific project root markers
  ;; .sbclrc — SBCL-specific configuration
  ;; .ccl/init.lisp — Clozure Common Lisp initialization
  ;; project.asd — ASDF (Another System Definition Facility) project definition
  ;; quicklisp/ — Local Quicklisp directory
  ;; .roswell/ — Roswell tool configuration
  (add-to-list 'project-vc-extra-root-markers ".sbclrc")
  (add-to-list 'project-vc-extra-root-markers ".ccl")
  (add-to-list 'project-vc-extra-root-markers "project.asd")
  (add-to-list 'project-vc-extra-root-markers "quicklisp")
  (add-to-list 'project-vc-extra-root-markers ".roswell")

  ;; Register tree-sitter grammar for Common Lisp
  ;; No commonlisp-ts-mode exists yet, but grammar is available for future
  (when (treesit-available-p)
    (add-to-list 'treesit-language-source-alist
      '(commonlisp "https://github.com/tree-sitter/tree-sitter-commonlisp"))))

(defun myde/prog-clisp-lisp-mode-setup ()
  "Buffer-local setup for `lisp-mode': initialize SLY and disable hard tabs."
  (myde/prog-clisp-sly-init)
  (setq indent-tabs-mode nil))

(defun myde/prog-clisp-sly-init ()
  "Configure SLY for interactive Common Lisp development.

Sets up the modern REPL with stickers (live feedback), autodoc, and SLDB
integrated debugger. SLY is the primary REPL choice for myde."
  ;; Set default Lisp implementation to SBCL
  ;; SLY will auto-detect available implementations at runtime
  (setq sly-default-lisp 'sbcl)

  ;; Enable stickers for live feedback (SLY-specific feature)
  ;; Shows results inline as you type
  (setq sly-stickers-default-action 'sly-stickers-fetch))

(defun myde/prog-clisp-slime-init ()
  "Configure SLIME for Common Lisp development (fallback REPL).

SLIME is the fallback when SLY is unavailable. It has larger ecosystem
but less modern UX. Both SLY and SLIME work with all CL implementations."
  ;; Set inferior Lisp program to SBCL
  ;; SLIME will use this as the default REPL backend
  (cond
    ((executable-find "sbcl")
     (setq inferior-lisp-program "sbcl"))
    ((executable-find "ccl")
     (setq inferior-lisp-program "ccl"))
    ((executable-find "ecl")
     (setq inferior-lisp-program "ecl"))
    (t
     (message "Warning: No Common Lisp implementation found on PATH"))))

(defun myde/prog-clisp-lsp-server ()
  "Optional LSP server detection via Roswell.

Returns ('cl-lsp') if Roswell is installed, nil otherwise.
cl-lsp requires Roswell (CL tool manager) to be set up.

LSP is optional; SLIME/SLY are superior for interactive CL development."
  (when (executable-find "ros")
    '("cl-lsp")))

(provide 'myde-prog-clisp)

;;; myde/prog-clisp/lib.el ends here
