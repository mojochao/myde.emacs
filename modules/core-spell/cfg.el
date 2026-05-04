;;; cfg.el --- Spell checking configuration for myde -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Spell checking via jinx (libenchant-2 backend).
;;; Entry point for the core-spell module; loads lib.el automatically.
;;;
;;; text-mode buffers (org, markdown, asciidoc) get full spell checking.
;;; prog-mode buffers get comment/doc-only checking via buffer-local
;;; jinx-include-faces.  org-babel src block code is handled by extending
;;; jinx-exclude-faces for org-mode to cover prog code faces, while leaving
;;; font-lock-comment-face uncovered so comments in src blocks are still checked.
;;;
;;; System prerequisite: enchant-2 must be installed before jinx will compile.
;;;   macOS:  brew install enchant
;;;   Linux:  apt install enchant-2  /  dnf install enchant2
;;;
;;; Keybindings:
;;;   M-$    jinx-correct      (correct word at point)
;;;   C-M-$  jinx-correct-all  (correct all misspellings in buffer)


;;; Code:

(unless (featurep 'myde-core-spell)
  (load-file (expand-file-name "modules/core-spell/lib.el" user-emacs-directory)))

(use-package jinx  ;; https://github.com/minad/jinx
  :hook
  (text-mode . myde-jinx-text-mode-setup)
  (prog-mode . myde-jinx-prog-mode-setup)
  :config
  ;; Replace jinx's default org-mode exclusion list.  The default includes
  ;; org-block, which would exclude the entire content of src blocks (including
  ;; comments).  We drop org-block so src-block text can be reached, then add
  ;; prog code faces so identifiers/keywords inside src blocks are excluded.
  ;; font-lock-comment-face and font-lock-doc-face are intentionally absent so
  ;; comments within src blocks are still spell-checked.
  (setq jinx-exclude-faces
        (cons '(org-mode
                org-block-begin-line org-block-end-line
                org-code org-cite org-cite-key org-date
                org-document-info-keyword org-done org-drawer
                org-footnote org-formula org-latex-and-related org-link
                org-macro org-meta-line org-property-value
                org-special-keyword org-tag org-todo org-verbatim org-warning
                org-modern-tag org-modern-date-active org-modern-date-inactive
                font-lock-keyword-face
                font-lock-builtin-face
                font-lock-function-name-face
                font-lock-variable-name-face
                font-lock-type-face
                font-lock-constant-face
                font-lock-preprocessor-face
                font-lock-number-face
                font-lock-operator-face
                font-lock-punctuation-face)
              (assq-delete-all 'org-mode jinx-exclude-faces)))
  :bind
  (("M-$"   . jinx-correct)
   ("C-M-$" . jinx-correct-all))
  :diminish
  :ensure t)

(provide 'myde-core-spell-cfg)
;;; cfg.el ends here
