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
;; in the correct order via `myde-load-module'.  Modules live under
;; `modules/<category>-<name>/' and consist of two files:
;;
;;   lib.el  --  pure definitions (defun, defvar, defcustom),
;;               provides `myde-<category>-<name>'.
;;   cfg.el  --  side effects (use-package, hooks, keybindings),
;;               provides `myde-<category>-<name>-cfg'.
;;
;; `myde-load-module' is idempotent: it checks the cfg feature symbol
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
;;   4. data-*    --  csv, json, terraform, toml, xml, yaml.
;;   5. prog-*    --  base then language modules.  `prog-base' MUST
;;                    load before any language module.
;;   6. text-*    --  asciidoc, markdown.
;;   7. ebook-*   --  epub, pdf.
;;
;; After all modules load, the Emacs server is started if not already
;; running, so `emacsclient' can connect from the command line.
;;
;; MODULE ENABLE SYSTEM
;; --------------------
;; Non-core, non-base modules each have a `defcustom' boolean variable
;; of the form `myde-module-<category>-<name>-enabled' (default: t).
;; Users can toggle modules off via `M-x customize-group myde-modules'
;; or by setting variables in `custom.el'.
;;
;; Loading rules applied by `myde-load-module':
;;
;;   core-*    Always loaded; no enable variable.
;;   *-base    Loaded automatically iff any sibling module in the same
;;             category is enabled; no enable variable.
;;   others    Loaded iff their `myde-module-NAME-enabled' var is non-nil.
;;
;; To add a new module: create `modules/<category>-<name>/{lib,cfg}.el'
;; following the conventions in AGENTS.md, add a `defcustom' below if
;; the module is non-core and non-base, then add a single
;; `(myde-load-module "<category>-<name>")' line in the appropriate section.

;;; Code:

;;;; Customization groups

(defgroup myde nil
  "MyDE Emacs configuration."
  :prefix "myde-")

(defgroup myde-modules nil
  "Toggle individual MyDE modules on or off.
Core modules (core-*) and base modules (*-base) are not listed here;
they are controlled automatically."
  :group 'myde
  :prefix "myde-module-")

;;;; Module enable variables

;; ai-* modules
(defcustom myde-module-ai-gptel-enabled t
  "When non-nil, load the ai-gptel module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-ai-agents-enabled t
  "When non-nil, load the ai-agents module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-ai-claude-enabled t
  "When non-nil, load the ai-claude module."
  :type 'boolean
  :group 'myde-modules)

;; auth-* modules
(defcustom myde-module-auth-1password-enabled t
  "When non-nil, load the auth-1password module."
  :type 'boolean
  :group 'myde-modules)

;; data-* modules
(defcustom myde-module-data-csv-enabled t
  "When non-nil, load the data-csv module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-data-json-enabled t
  "When non-nil, load the data-json module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-data-terraform-enabled t
  "When non-nil, load the data-terraform module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-data-toml-enabled t
  "When non-nil, load the data-toml module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-data-xml-enabled t
  "When non-nil, load the data-xml module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-data-yaml-enabled t
  "When non-nil, load the data-yaml module."
  :type 'boolean
  :group 'myde-modules)

;; ebook-* modules
(defcustom myde-module-ebook-epub-enabled t
  "When non-nil, load the ebook-epub module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-ebook-pdf-enabled t
  "When non-nil, load the ebook-pdf module."
  :type 'boolean
  :group 'myde-modules)

;; prog-* modules
(defcustom myde-module-prog-elisp-enabled t
  "When non-nil, load the prog-elisp module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-clisp-enabled t
  "When non-nil, load the prog-clisp module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-scheme-enabled t
  "When non-nil, load the prog-scheme module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-clojure-enabled t
  "When non-nil, load the prog-clojure module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-erlang-enabled t
  "When non-nil, load the prog-erlang module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-elixir-enabled t
  "When non-nil, load the prog-elixir module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-cpp-enabled t
  "When non-nil, load the prog-cpp module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-go-enabled t
  "When non-nil, load the prog-go module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-rust-enabled t
  "When non-nil, load the prog-rust module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-zig-enabled t
  "When non-nil, load the prog-zig module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-python-enabled t
  "When non-nil, load the prog-python module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-ruby-enabled t
  "When non-nil, load the prog-ruby module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-lua-enabled t
  "When non-nil, load the prog-lua module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-javascript-enabled t
  "When non-nil, load the prog-javascript module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-typescript-enabled t
  "When non-nil, load the prog-typescript module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-bash-enabled t
  "When non-nil, load the prog-bash module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-fish-enabled t
  "When non-nil, load the prog-fish module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-prog-nushell-enabled t
  "When non-nil, load the prog-nushell module."
  :type 'boolean
  :group 'myde-modules)

;; text-* modules
(defcustom myde-module-text-asciidoc-enabled t
  "When non-nil, load the text-asciidoc module."
  :type 'boolean
  :group 'myde-modules)

(defcustom myde-module-text-markdown-enabled t
  "When non-nil, load the text-markdown module."
  :type 'boolean
  :group 'myde-modules)

;;;; Module loader

(defun myde-module-category-enabled-p (category)
  "Return non-nil if any non-base module in CATEGORY has its enable var non-nil.
Used to auto-load *-base modules when at least one sibling is enabled."
  (let ((prefix (concat "myde-module-" category "-"))
        (result nil))
    (mapatoms
     (lambda (sym)
       (when (and (boundp sym)
                  (string-prefix-p prefix (symbol-name sym))
                  (string-suffix-p "-enabled" (symbol-name sym))
                  (symbol-value sym))
         (setq result t))))
    result))

(defun myde-load-module (name)
  "Load the module NAME (without modules/ prefix), if not already loaded.
Idempotent: re-evaluating `init.el' will not re-run module side effects.

Loading rules:
- core-* modules are always loaded.
- *-base modules (non-core) are loaded iff any sibling in the same
  category has its enable variable non-nil.
- All other modules are loaded iff their `myde-module-NAME-enabled'
  variable is non-nil."
  (let* ((feature     (intern (concat "myde-" name "-cfg")))
         (core-p      (string-prefix-p "core-" name))
         (base-p      (and (not core-p) (string-suffix-p "-base" name)))
         (enabled-var (intern (concat "myde-module-" name "-enabled")))
         (enabled-p   (cond
                       (core-p t)
                       (base-p (myde-module-category-enabled-p
                                (car (split-string name "-"))))
                       (t (and (boundp enabled-var)
                               (symbol-value enabled-var))))))
    (when enabled-p
      (unless (featurep feature)
        (load-file (expand-file-name (concat "modules/" name "/cfg.el")
                                     user-emacs-directory))))))

;;;; Modules to be loaded in order

;; Core modules
(myde-load-module "core-base")
(myde-load-module "core-ui")
(myde-load-module "core-ux")
(myde-load-module "core-org")
(myde-load-module "core-help")
(myde-load-module "core-terminals")
(myde-load-module "core-dashboard")
(myde-load-module "core-complete")
(myde-load-module "core-notes")
(myde-load-module "core-snippets")
(myde-load-module "core-projects")
(myde-load-module "core-spell")

;; AI modules
(myde-load-module "ai-base")
(myde-load-module "ai-gptel")
(myde-load-module "ai-agents")
(myde-load-module "ai-claude")

;; Auth modules
(myde-load-module "auth-1password")

;; Data language modules
(myde-load-module "data-csv")
(myde-load-module "data-json")
(myde-load-module "data-terraform")
(myde-load-module "data-toml")
(myde-load-module "data-xml")
(myde-load-module "data-yaml")

;; Programming language modules
(myde-load-module "prog-base")
(myde-load-module "prog-elisp")
(myde-load-module "prog-clisp")
(myde-load-module "prog-scheme")
(myde-load-module "prog-clojure")
(myde-load-module "prog-erlang")
(myde-load-module "prog-elixir")
(myde-load-module "prog-cpp")
(myde-load-module "prog-go")
(myde-load-module "prog-rust")
(myde-load-module "prog-zig")
(myde-load-module "prog-python")
(myde-load-module "prog-ruby")
(myde-load-module "prog-lua")
(myde-load-module "prog-javascript")
(myde-load-module "prog-typescript")

;; Shell language modules
(myde-load-module "prog-bash")
(myde-load-module "prog-fish")
(myde-load-module "prog-nushell")

;; Text format modules
(myde-load-module "text-asciidoc")
(myde-load-module "text-markdown")

;; Ebook modules
(myde-load-module "ebook-epub")
(myde-load-module "ebook-pdf")

;; Start emacs server if not already running
(require 'server)
(unless (server-running-p) (server-start))

;; That's all Folks!
(provide 'init)
;;; init.el ends here
