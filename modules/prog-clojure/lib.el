;;; myde-prog-clojure/lib.el --- Clojure development environment definitions -*- lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:

;; Pure definitions for Clojure development: setup hooks, formatter guards,
;; and CIDER configuration. See cfg.el for side effects.


;;; Code:

(defun myde-prog-clojure-setup ()
  "Setup Clojure development environment.

Raises eglot timeout for clojure-lsp (first initialization can exceed 30s),
adds project root markers for mono-repos, and registers tree-sitter grammar."
  ;; Raise timeout for clojure-lsp initialization
  ;; First-time indexing on large projects can exceed 30s
  (setq eglot-connect-timeout 60)

  ;; Add Clojure-specific project root markers
  (add-to-list 'project-vc-extra-root-markers "deps.edn")
  (add-to-list 'project-vc-extra-root-markers "project.clj")
  (add-to-list 'project-vc-extra-root-markers "shadow-cljs.edn")
  (add-to-list 'project-vc-extra-root-markers "bb.edn")

  ;; Register tree-sitter grammar for Clojure
  ;; Already bundled in clojure-ts-mode, but register system-wide for completeness
  (when (treesit-available-p)
    (add-to-list 'treesit-language-source-alist
      '(clojure "https://github.com/tree-sitter/tree-sitter-clojure"))))

(defun myde-prog-clojure-cider-setup ()
  "Configure CIDER for Clojure development.

Disables CIDER's auto-format (apheleia handles formatting via cljfmt).
Users who prefer zprint can override `cider-format-code-options' via
.dir-locals.el — see prog-clojure/cfg.el for a worked example."
  (setq cider-auto-mode nil))

(provide 'myde-prog-clojure)

;;; myde-prog-clojure/lib.el ends here
