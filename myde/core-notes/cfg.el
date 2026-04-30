;;; cfg.el --- Notes package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for denote note-taking support.
;;; Entry point for the core-notes module; loads lib.el automatically.


;;; Code:

(unless (featurep 'myde-core-notes)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Denote note-taking
;; -----------------------------------------------------------------------------

(use-package denote  ;; https://protesilaos.com/emacs/denote
  :bind
  (("C-c n n" . denote)
   ("C-c n l" . denote-link)
   ("C-c n b" . denote-backlinks)
   ("C-c n f" . denote-open-or-create)
   ("C-c n s" . denote-search))
  :custom
  (denote-directory myde/denote-directory)
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

(provide 'myde-core-notes-cfg)
;;; cfg.el ends here
