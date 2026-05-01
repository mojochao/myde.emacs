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
;; optimizations.  This file is intentionally declarative:
;;
;;   1. Load `modules.el', which defines the module system machinery.
;;   2. Declare the ordered list of module descriptors.
;;   3. Generate `defcustom' toggles via `myde-customize'.
;;   4. Load enabled modules in order via `myde-initialize'.
;;   5. Start the Emacs server.
;;
;; To add a module: create `modules/<category>-<name>/{lib,cfg}.el'
;; (see AGENTS.md) and add a `(myde/m "<category>-<name>" "...")' line
;; to `myde-modules' below in the desired load position.
;;
;; Loading rules (implemented in `modules.el'):
;;
;;   core-*    Always loaded; no toggle.
;;   *-base    Loaded iff any sibling in the same category is enabled;
;;             no toggle.
;;   others    Loaded iff `myde-module-<name>-enabled' is non-nil.
;;             Generated toggles default to nil; users opt in via
;;             `M-x customize-group RET myde-modules' or `custom.el'.

;;; Code:

;;;; Initialize MyDE modules

(load-file (expand-file-name "modules.el" user-emacs-directory))

(defconst myde-modules
  (list
   ;; Core functionality ------------------------------------------------
   (myde/m "core-base"        "Package system, XDG paths, and shared fundamentals.")
   (myde/m "core-ui"          "Theme, fonts, modeline, and frame appearance.")
   (myde/m "core-ux"          "Editing UX: minibuffer, navigation, window management.")
   (myde/m "core-org"         "Org-mode setup and capture templates.")
   (myde/m "core-help"        "Discoverability: which-key, helpful, embark.")
   (myde/m "core-terminals"   "Terminal emulators (vterm, eat).")
   (myde/m "core-dashboard"   "Startup dashboard.")
   (myde/m "core-complete"    "Completion stack: vertico, corfu, consult, marginalia, orderless.")
   (myde/m "core-notes"       "Note-taking (denote, org-roam).")
   (myde/m "core-snippets"    "yasnippet integration.")
   (myde/m "core-projects"    "Project management and LSP workspace helpers.")
   (myde/m "core-spell"       "Spell checking (jinx / ispell).")
   ;; AI tools ----------------------------------------------------------
   (myde/m "ai-base"          "Shared AI infrastructure.")
   (myde/m "ai-gptel"         "gptel client for LLM chat.")
   (myde/m "ai-agents"        "Agent integrations.")
   (myde/m "ai-claude"        "Claude-specific bindings.")
   ;; Auth source backends ----------------------------------------------
   (myde/m "auth-1password"   "1Password CLI integration.")
   ;; Data formats ------------------------------------------------------
   (myde/m "data-csv"         "CSV editing.")
   (myde/m "data-json"        "JSON editing.")
   (myde/m "data-terraform"   "Terraform / HCL.")
   (myde/m "data-toml"        "TOML editing.")
   (myde/m "data-xml"         "XML editing.")
   (myde/m "data-yaml"        "YAML editing.")
   ;; Programming languages --------------------------------------------
   (myde/m "prog-base"        "Shared prog-mode infrastructure (eglot, dape, treesit).")
   (myde/m "prog-elisp"       "Emacs Lisp.")
   (myde/m "prog-clisp"       "Common Lisp (SLY/SLIME).")
   (myde/m "prog-scheme"      "Scheme (Geiser).")
   (myde/m "prog-clojure"     "Clojure (CIDER).")
   (myde/m "prog-erlang"      "Erlang.")
   (myde/m "prog-elixir"      "Elixir.")
   (myde/m "prog-cpp"         "C / C++.")
   (myde/m "prog-go"          "Go.")
   (myde/m "prog-rust"        "Rust.")
   (myde/m "prog-zig"         "Zig.")
   (myde/m "prog-python"      "Python.")
   (myde/m "prog-ruby"        "Ruby.")
   (myde/m "prog-lua"         "Lua.")
   (myde/m "prog-javascript"  "JavaScript.")
   (myde/m "prog-typescript"  "TypeScript.")
   ;; Shell languages ---------------------------------------------------
   (myde/m "prog-bash"        "Bash shell scripting.")
   (myde/m "prog-fish"        "Fish shell scripting.")
   (myde/m "prog-nushell"     "Nushell scripting.")
   ;; Text formats ------------------------------------------------------
   (myde/m "text-asciidoc"    "AsciiDoc.")
   (myde/m "text-markdown"    "Markdown.")
   ;; Ebook formats -----------------------------------------------------
   (myde/m "ebook-epub"       "EPUB reader (nov.el).")
    (myde/m "ebook-pdf"        "PDF tools.")))

(myde-customize myde-modules)
(myde-initialize myde-modules)

;;;; Start server as needed.

(require 'server)
(unless (server-running-p) (server-start))

;; That's all Folks!
(provide 'init)
;;; init.el ends here
