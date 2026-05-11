;;; cfg.el --- Org mode configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Org mode configuration for task management, notes, and agenda.
;;; Entry point for the core-org module; loads lib.el automatically.
;;;
;;; org-directory is set from myde-org-directory (defined in lib.el).
;;; org-return-follows-link is enabled so RET opens links without C-c C-o.
;;; visual-line-mode and trailing-whitespace cleanup activate on every org buffer.
;;; flycheck is disabled in org buffers — its bundled org-lint checker
;;; signals `Wrong type argument: number-or-marker-p' on newer org
;;; versions.  We set `flycheck-global-modes' to exclude org-mode and
;;; org-agenda-mode so global-flycheck-mode never turns it on there.
;;; Use `M-x org-lint' on demand for the same checks.
;;;
;;; Capture: org-capture (C-c c), org-protocol, and org-agenda (C-c a) are
;;; configured with templates t/b for tasks and bookmarks.  Templates n/N
;;; (denote-backed) are appended from core-notes.  Tasks accept optional
;;; SCHEDULED:/DEADLINE: planning lines and a :PROJECT: property via the
;;; myde-org-capture-{scheduled,deadline,project}-line helpers in lib.el.


;;; Code:

(unless (featurep 'myde-core-org)
  (load-file (expand-file-name "modules/core-org/lib.el" user-emacs-directory)))

;; I use org to manage my thoughts and actions.
(use-package org  ;; https://orgmode.org
  :hook
  (org-mode . visual-line-mode)
  (org-mode . myde-delete-trailing-whitespace-setup)
  (org-mode . myde-org-mode-disable-flycheck)
  :custom
  (org-directory myde-org-directory)
  (org-return-follows-link t)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :config
  (setq org-confirm-babel-evaluate nil)
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((emacs-lisp . t))))
  :ensure nil)

(use-package ob-async  ;; https://github.com/astahlman/ob-async
  :after org
  :ensure t)

;; Flycheck's bundled `org-lint' checker crashes on certain reports from
;; current org versions ("Wrong type argument: number-or-marker-p, …"),
;; firing on save and whenever org-agenda first visits tasks.org from
;; the dashboard.  Flycheck has nothing else useful for org buffers, so
;; we exclude org modes from `global-flycheck-mode' entirely via
;; `flycheck-global-modes'.  `M-x org-lint' remains available on demand.
;; The disabled-checker entry is belt-and-braces in case a user turns
;; flycheck-mode on manually in an org buffer.
(use-package flycheck
  :defer t
  :init
  (setq flycheck-global-modes '(not org-mode org-agenda-mode))
  :config
  (add-to-list 'flycheck-disabled-checkers 'org-lint)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Capture
;; -----------------------------------------------------------------------------

(use-package org-capture
  :after org
  :bind (("C-c c" . org-capture))
  :custom
  (org-capture-templates
   `(("t" "Task" entry
      (file+headline ,myde-org-tasks-file "Inbox")
      ,(string-join
        '("* TODO %?"
          "%(myde-org-capture-scheduled-line)%(myde-org-capture-deadline-line)  :PROPERTIES:"
          "  :CREATED: %U"
          "%(myde-org-capture-project-line)  :END:"
          "  %a")
        "\n")
      :empty-lines 1)

     ("b" "Bookmark (org-protocol)" entry
      (file+headline ,myde-org-bookmarks-file "Inbox")
      ,(string-join
        '("* [[%:link][%:description]]   :bookmark:"
          "  :PROPERTIES:"
          "  :CREATED: %U"
          "%(myde-org-capture-project-line)  :END:"
          "  %i")
        "\n")
      :empty-lines 1)))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Protocol
;; -----------------------------------------------------------------------------

(use-package org-protocol
  :after org
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Agenda
;; -----------------------------------------------------------------------------

(use-package org-agenda
  :after org
  :bind (("C-c a" . org-agenda))
  :custom
  (org-agenda-files
   (delete-dups
    (cons myde-org-tasks-file
          (myde-find-org-agenda-files))))
  (org-refile-targets '((org-agenda-files :maxlevel . 3)))
  (org-refile-use-outline-path 'file)
  (org-outline-path-complete-in-steps nil)
  :ensure nil)

(provide 'myde-core-org-cfg)
;;; cfg.el ends here
