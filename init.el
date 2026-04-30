;;; init.el --- Loaded after early-init.el -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration
;; Package-Requires: ((emacs "30.1"))

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;
;; Main initialization file for MyDE — *MY* Development Environment.
;;
;; Loaded by Emacs after `early-init.el' has set up startup-time
;; optimizations (GC, file-name-handler-alist, package archives, frame
;; parameters) and XDG path redirection.
;;
;; This file is intentionally thin: its only job is to load each module
;; in the correct order via `myde/load-module'.  Modules live under
;; `myde/<category>-<name>/' and consist of two files:
;;
;;   lib.el  --  pure definitions (defun, defvar, defcustom),
;;               provides `myde-<category>-<name>'.
;;   cfg.el  --  side effects (use-package, hooks, keybindings),
;;               provides `myde-<category>-<name>-cfg'.
;;
;; `myde/load-module' is idempotent: it checks the cfg feature symbol
;; before loading, so re-evaluating this file will not re-run module
;; side effects.
;;
;; Module load order matters.  Categories are loaded in this sequence:
;;
;;   1. core-*    --  base, UI, UX, org, help, terminals, dashboard,
;;                    completion, notes, snippets, projects.
;;                    `core-base' MUST load first; it initializes the
;;                    package system that every other module relies on.
;;   2. ai-*      --  base, gptel, agents, claude.
;;   3. auth-*    --  1password.
;;   4. data-*    --  csv, json, terraform, toml, yaml.
;;   5. prog-*    --  base then language modules.  `prog-base' MUST
;;                    load before any language module.
;;   6. text-*    --  markdown.
;;   7. ebook-*   --  epub, pdf.
;;
;; After all modules load, the Emacs server is started if not already
;; running, so `emacsclient' can connect from the command line.
;;
;; To add a new module: create `myde/<category>-<name>/{lib,cfg}.el'
;; following the conventions in CLAUDE.md, then add a single
;; `(myde/load-module "<category>-<name>")' line below in the
;; appropriate section.

;;; Code:

(defun myde/load-module (name)
  "Load the module NAME (without myde/ prefix), if not already loaded.
Idempotent: re-evaluating `init.el' will not re-run module side effects."
  (let ((feature (intern (concat "myde-" name "-cfg"))))
    (unless (featurep feature)
      (load-file (expand-file-name (concat "myde/" name "/cfg.el")
                                   user-emacs-directory)))))

;; Core modules
(myde/load-module "core-base")
(myde/load-module "core-ui")
(myde/load-module "core-ux")
(myde/load-module "core-org")
(myde/load-module "core-help")
(myde/load-module "core-terminals")
(myde/load-module "core-dashboard")
(myde/load-module "core-complete")
(myde/load-module "core-notes")
(myde/load-module "core-snippets")
(myde/load-module "core-projects")

;; AI modules
(myde/load-module "ai-base")
(myde/load-module "ai-gptel")
(myde/load-module "ai-agents")
(myde/load-module "ai-claude")

;; Auth modules
(myde/load-module "auth-1password")

;; Data language modules
(myde/load-module "data-csv")
(myde/load-module "data-json")
(myde/load-module "data-terraform")
(myde/load-module "data-toml")
(myde/load-module "data-yaml")

;; Programming language modules
(myde/load-module "prog-base")
(myde/load-module "prog-elisp")
(myde/load-module "prog-clojure")
(myde/load-module "prog-scheme")
(myde/load-module "prog-clisp")
(myde/load-module "prog-erlang")
(myde/load-module "prog-elixir")
(myde/load-module "prog-cpp")
(myde/load-module "prog-go")
(myde/load-module "prog-rust")
(myde/load-module "prog-python")
(myde/load-module "prog-javascript")
(myde/load-module "prog-typescript")

;; Shell language modules
(myde/load-module "prog-bash")
(myde/load-module "prog-fish")
(myde/load-module "prog-nushell")

;; Text format modules
(myde/load-module "text-markdown")

;; Ebook modules
(myde/load-module "ebook-epub")
(myde/load-module "ebook-pdf")

;; Start emacs server if not already running
(require 'server)
(unless (server-running-p) (server-start))

;; That's all Folks!
(provide 'init)
;;; init.el ends here
