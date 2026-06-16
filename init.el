;;; init.el --- Loaded after early-init.el -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
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

;; Start by loading the modules support library.
(load-file (expand-file-name "modules.el" user-emacs-directory))

;; Next, define the modules to be available for loading.
(defconst myde-modules
  (list
   ;; Core functionality ------------------------------------------------
   (myde/m "core-base"        "Package system, XDG paths, and shared fundamentals.")
   (myde/m "core-ui"          "Editor UI: theme, fonts, modeline, and frame appearance, etc.")
   (myde/m "core-ux"          "Editor UX: minibuffer, navigation, window management, etc.")
   (myde/m "core-org"         "Org-mode authoring, agenda, and capture templates.")
   (myde/m "core-help"        "Help and documentation support.")
   (myde/m "core-terminals"   "Terminal emulators.")
   (myde/m "core-dashboard"   "Startup dashboard.")
   (myde/m "core-complete"    "Completion support.")
   (myde/m "core-notes"       "Notes support.")
   (myde/m "core-snippets"    "Snippets support.")
   (myde/m "core-projects"    "Project management support.")
   (myde/m "core-spell"       "Spell check support.")
   ;; AI tools ----------------------------------------------------------
   (myde/m "ai-base"          "Shared AI configuration.")
   (myde/m "ai-gptel"         "Gptel chat client integration.")
   (myde/m "ai-agents"        "General agent clients integrations.")
   (myde/m "ai-claude"        "Claude agent-specific integration.")
   (myde/m "ai-mcp"           "MCP server exposing live Emacs state to AI agents.")
   ;; Auth source backends ----------------------------------------------
   (myde/m "auth-1password"   "1Password auth-source integration.")
   ;; Data formats ------------------------------------------------------
   (myde/m "data-csv"         "CSV editing.")
   (myde/m "data-hcl"         "HCL editing (Terraform, OpenTofu).")
   (myde/m "data-json"        "JSON editing.")
   (myde/m "data-pkl"         "Pkl editing.")
   (myde/m "data-toml"        "TOML editing.")
   (myde/m "data-xml"         "XML editing.")
   (myde/m "data-yaml"        "YAML editing.")
   ;; Containers --------------------------------------------------------
   (myde/m "containers-kubernetes" "Kubernetes cluster management (kubed).")
   ;; Programming languages --------------------------------------------
   (myde/m "prog-base"        "Base shared programming language support.")
   (myde/m "prog-bash"        "Bash shell IDE.")
   (myde/m "prog-fish"        "Fish shell IDE.")
   (myde/m "prog-nushell"     "Nu shell IDE.")
   (myde/m "prog-elisp"       "Emacs Lisp IDE.")
   (myde/m "prog-clisp"       "Common Lisp IDE.")
   (myde/m "prog-scheme"      "Scheme IDE.")
   (myde/m "prog-clojure"     "Clojure IDE.")
   (myde/m "prog-erlang"      "Erlang IDE.")
   (myde/m "prog-elixir"      "Elixir IDE.")
   (myde/m "prog-cpp"         "C/C++ IDE.")
   (myde/m "prog-go"          "Go IDE.")
   (myde/m "prog-rust"        "Rust IDE.")
   (myde/m "prog-zig"         "Zig IDE.")
   (myde/m "prog-python"      "Python IDE.")
   (myde/m "prog-ruby"        "Ruby IDE.")
   (myde/m "prog-lua"         "Lua IDE.")
   (myde/m "prog-javascript"  "JavaScript IDE.")
   (myde/m "prog-typescript"  "TypeScript IDE.")
   ;; Text formats ------------------------------------------------------
   (myde/m "text-base"        "Shared text-mode infrastructure.")
   (myde/m "text-asciidoc"    "AsciiDoc document authoring environment.")
   (myde/m "text-markdown"    "Markdown document authoring environment.")
   ;; Ebook formats -----------------------------------------------------
   (myde/m "ebook-epub"       "EPUB ebook reading environment.")
   (myde/m "ebook-pdf"        "PDF ebook reading environment.")))

;; Next, generate the customize config for enabling the modules defined above.
(myde-customize myde-modules)

;; Finally, initialize the config using the modules defined above.
(myde-initialize myde-modules)

;;;; Start server as needed.

(require 'server)
(unless (server-running-p) (server-start))

;; That's all Folks!
(provide 'init)
;;; init.el ends here
