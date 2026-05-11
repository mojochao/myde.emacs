;;; cfg.el --- Notes package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for Denote note-taking support.
;;; Entry point for the core-notes module; loads lib.el automatically.
;;;
;;; Notes are stored in the directory defined by myde-denote-directory (lib.el).
;;; Keywords are inferred and sorted automatically.
;;; Keybindings under C-c o n: new (n), link (l), backlinks (b), find/create (f), search (s).


;;; Code:

(unless (featurep 'myde-core-notes)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Denote note-taking
;; -----------------------------------------------------------------------------

(use-package denote  ;; https://protesilaos.com/emacs/denote
  :bind
  (("C-c o n n" . denote)
   ("C-c o n l" . denote-link)
   ("C-c o n b" . denote-backlinks)
   ("C-c o n f" . denote-open-or-create)
   ("C-c o n s" . denote-search))
  :custom
  (denote-directory myde-denote-directory)
  (denote-infer-keywords t)
  (denote-sort-keywords t)
  (denote-known-keywords
   '("paper"
     "book"
     "research"
     "distributed-systems"
     "kubernetes"
     "consensus"
     "raft"))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Denote-backed org-capture templates
;; -----------------------------------------------------------------------------
;; Appends `n' (plain denote note) and `N' (note from web via org-protocol)
;; to the org-capture templates list defined by core-org.  Lives here so
;; core-org does not take a hard dependency on denote.

(use-package org-capture
  :after (org denote)
  :config
  (add-to-list 'org-capture-templates
               '("n" "Note (denote)" plain
                 (function denote-org-capture)
                 nil
                 :no-save t
                 :immediate-finish nil
                 :kill-buffer t
                 :jump-to-captured t)
               t)
  (add-to-list 'org-capture-templates
               '("N" "Note from web (org-protocol)" plain
                 (function myde-denote-capture-from-protocol)
                 "Source: %:link\n\n%i\n%?"
                 :no-save nil
                 :immediate-finish nil
                 :kill-buffer t
                 :jump-to-captured t)
               t)
  :ensure nil)

(provide 'myde-core-notes-cfg)
;;; cfg.el ends here
