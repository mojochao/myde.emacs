;;; cfg.el --- Markdown package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for Markdown editing via markdown-mode.
;;; Entry point for the text-markdown module; loads lib.el automatically.
;;;
;;; Activates gfm-mode for .md and README.md files.  Provides:
;;;
;;;   Writing    -- markdown-mode syntax highlighting, outline navigation,
;;;                 visual-line-mode + visual-fill-column-mode wrap at
;;;                 column 80.  C-c v toggles visual-fill-column-mode to
;;;                 switch between fixed-column wrap and full-width wrap.
;;;   Previewing -- C-c C-p toggles markdown-preview-mode (primary): pandoc-
;;;                 rendered live preview in the browser, with mermaid.js
;;;                 injected so ```mermaid fences render as diagrams.
;;;                 C-c C-g toggles grip-mode (secondary): GitHub-rendered
;;;                 GFM via the GitHub API -- highest GFM fidelity for
;;;                 tables, alerts, task lists, but mermaid blocks stay as
;;;                 plain code (the API does not run client-side JS).
;;;   Publishing -- C-c C-e h exports HTML; C-c C-e p exports PDF
;;;                 (requires pandoc, plus a TeX engine for PDF).
;;;
;;; Install external tools:
;;;   brew install pandoc                 -- HTML/PDF export + preview render
;;;   pip install grip                    -- GitHub-rendered preview server
;;;   brew install --cask basictex        -- TeX engine for PDF export
;;;
;;; For unrate-limited grip-mode preview, store a GitHub personal access
;;; token in ~/.authinfo for machine api.github.com, or set grip-github-user
;;; and grip-github-password via Customize.


;;; Code:

(unless (featurep 'myde-text-markdown)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Markdown mode
;; -----------------------------------------------------------------------------

(use-package markdown-mode  ;; https://github.com/jrblevin/markdown-mode
  :init
  (setq markdown-command "pandoc")
  :mode (("\\.md\\'"        . gfm-mode)
         ("README\\.md\\'"  . gfm-mode))
  :hook ((markdown-mode . myde-markdown-mode-setup)
         (markdown-mode . visual-line-mode)
         (markdown-mode . visual-wrap-prefix-mode)
         (markdown-mode . visual-fill-column-mode)
         (markdown-mode . myde-delete-trailing-whitespace-setup))
  :bind (:map markdown-mode-map
              ;; Free C-c C-e (markdown-do) to use as an export prefix.
              ;; markdown-do remains available at its default C-c C-d binding.
              ("C-c C-e"   . nil)
              ("C-c C-e h" . myde-markdown-export-html)
              ("C-c C-e p" . myde-markdown-export-pdf)
              ("C-c v"     . visual-fill-column-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Visual fill column -- wrap long lines at fill-column (not window width)
;; -----------------------------------------------------------------------------

(use-package visual-fill-column
  :ensure t)

;; -----------------------------------------------------------------------------
;; Live preview via markdown-preview-mode (primary; renders mermaid)
;; -----------------------------------------------------------------------------

(use-package markdown-preview-mode  ;; https://github.com/ancane/markdown-preview-mode
  :ensure t
  :after markdown-mode
  :custom
  ;; markdown-preview-script-onupdate is a defcustom -- :custom works.
  (markdown-preview-script-onupdate
   "window.mydeMermaidRender && window.mydeMermaidRender();")
  :config
  ;; Both markdown-preview-javascript and markdown-preview-stylesheets are
  ;; plain defvars, not defcustoms, so use-package :custom silently no-ops
  ;; on them.  Use setq.
  (setq markdown-preview-javascript
        (list "https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"
              (myde-markdown-preview-script-tag "preview/mermaid-init.js")))
  (setq markdown-preview-stylesheets
        (list
         ;; GitHub's own dark stylesheet -- targets .markdown-body, which
         ;; the preview template already applies to its content article.
         "https://cdn.jsdelivr.net/npm/github-markdown-css@5/github-markdown-dark.css"
         ;; Body chrome + container sizing + mermaid background harmony.
         "<style>
            body { background-color: #0d1117; margin: 0; padding: 0; }
            .markdown-body {
              box-sizing: border-box;
              min-width: 200px;
              max-width: 980px;
              margin: 0 auto;
              padding: 45px;
            }
            .mermaid { background: transparent; text-align: center; }
            @media (max-width: 767px) { .markdown-body { padding: 15px; } }
          </style>"))
  :bind (:map markdown-mode-map
              ("C-c C-p" . markdown-preview-mode)))

;; -----------------------------------------------------------------------------
;; Live preview via grip-mode (secondary; GitHub-rendered, no mermaid)
;; -----------------------------------------------------------------------------

(use-package grip-mode  ;; https://github.com/seagle0128/grip-mode
  :ensure t
  :after markdown-mode
  :custom
  (grip-real-time-refresh t)
  :bind (:map markdown-mode-map
              ("C-c C-g" . grip-mode)))

(provide 'myde-text-markdown-cfg)
;;; cfg.el ends here
