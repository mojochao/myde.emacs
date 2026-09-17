;;; myde.el --- MyDE configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration
;; Package-Requires: ((emacs "31.1"))

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;
;; The whole of MyDE.  Loaded from init.el via (require 'myde).

;;; Code:

;;;; core-base
;;;; ---------


;; Create missing directories automatically
(defun myde-auto-create-missing-dirs ()
  (let ((target-dir (file-name-directory buffer-file-name)))
    (unless (file-exists-p target-dir)
      (make-directory target-dir t))))

;; Delete trailing whitespace on save (shared utility)
(defun myde-delete-trailing-whitespace-setup ()
  "Delete trailing whitespace on save."
  (add-hook 'before-save-hook #'delete-trailing-whitespace nil t))

(defun myde-treesit-install-language-grammar-advice (orig-fn lang &optional out-dir)
  "Redirect tree-sitter grammar installation to the XDG data directory.

Advises `treesit-install-language-grammar' so that callers which omit OUT-DIR
(e.g. `treesit-auto') write grammars to `$XDG_DATA_HOME/emacs/tree-sitter/'
instead of the default `user-emacs-directory/tree-sitter/'."
  (funcall orig-fn lang
           (or out-dir (expand-file-name "emacs/tree-sitter" (xdg-data-home)))))

(defun myde-treesit-install-language-grammar (lang)
  "Interactively install a tree-sitter grammar for LANG into the XDG data directory.

The XDG redirection is handled globally by
`myde-treesit-install-language-grammar-advice'; this command is a convenient
interactive entry point."
  (interactive
   (list (intern (completing-read "Language: "
                                  (mapcar #'car treesit-language-source-alist)))))
  (treesit-install-language-grammar lang))

(defun de-dosify ()
  "Remove all Windows/DOS carriage return (^M) characters in the current buffer."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (search-forward "\r" nil t)
      (replace-match ""))))

;;;; core-ui
;;;; --------


;; Clear informational startup noise from the echo area after all hooks run.
;; elpaca-after-init-hook fires once every queued package has been activated,
;; so this erases whatever informational message was last written.
(defun myde/clear-echo-area ()
  "Clear the echo area / minibuffer after startup."
  (message nil))

;; Visual bell instead of audible bell
(defun myde-flash-mode-line ()
  (invert-face 'mode-line)
  (run-with-timer 0.1 nil #'invert-face 'mode-line))

(defun myde/frame-title ()
  "Return a frame title string.
In a project: '<project> - <relative/path/to/file>'.
Outside a project: full path, or buffer name for non-file buffers."
  (if-let ((proj (project-current))
           (file buffer-file-name))
      (concat (project-name proj) " - "
              (file-relative-name file (project-root proj)))
    (or buffer-file-name (buffer-name))))

;;;; core-ux
;;;; --------


;; Smart keyboard quit that closes minibuffer
;; https://emacsredux.com/blog/2025/06/01/let-s-make-keyboard-quit-smarter/
(defun myde-keyboard-quit ()
  "A smarter version of the built-in `keyboard-quit'.

The generic `keyboard-quit' does not do the expected thing when
the minibuffer is open.  Whereas we want it to close the
minibuffer, even without explicitly focusing it."
  (interactive)
  (if (active-minibuffer-window)
      (if (minibufferp)
          (minibuffer-keyboard-quit)
        (abort-recursive-edit))
    (keyboard-quit)))

;;;; core-org
;;;; --------

;; Org mode directories and files
(defvar myde-org-directory "~/org/"
  "Main org mode directory.")

(defvar myde-reading-notes "~/org/reading/"
  "Directory for reading notes.")

(defvar myde-highlight-file "~/org/highlights.org"
  "File for storing highlights.")

(defvar myde-org-tasks-file
  (expand-file-name "tasks.org" myde-org-directory)
  "Path to the top-level tasks capture file.")

(defvar myde-org-bookmarks-file
  (expand-file-name "bookmarks.org" myde-org-directory)
  "Path to the top-level bookmarks capture file.")

(defvar myde-org-notes-directory
  (file-name-as-directory (expand-file-name "notes" myde-org-directory))
  "Directory for denote notes, under `myde-org-directory'.")

(defcustom myde-projects-directory (expand-file-name "~/org/projects/")
  "Root directory under which per-project `tasks.org' files are discovered."
  :type 'directory
  :group 'myde)

(defun myde-find-org-agenda-files (&optional root-dir)
  "Return list of `tasks.org' files under ROOT-DIR.
ROOT-DIR defaults to `myde-projects-directory'.  Returns nil if the
directory does not exist."
  (let ((dir (or root-dir myde-projects-directory)))
    (when (file-directory-p dir)
      (directory-files-recursively dir "\\`tasks\\.org\\'"))))

(defun myde-org-mode-disable-flycheck ()
  "Disable `flycheck-mode' in org buffers.
Flycheck's bundled `org-lint' checker crashes with `Wrong type argument:
number-or-marker-p' on propertized strings from newer org versions.
Flycheck is unnecessary in org buffers — use `M-x org-lint' on demand."
  (when (bound-and-true-p flycheck-mode)
    (flycheck-mode -1)))

(defvar myde-org-project-history nil
  "Minibuffer history for `myde-org-capture-project-line' prompts.")

(defun myde-org-known-projects ()
  "Return a sorted, de-duplicated list of known project names.
Candidates come from subdirectories of `myde-projects-directory' and
from previously entered values in `myde-org-project-history'."
  (let* ((subdirs (when (file-directory-p myde-projects-directory)
                    (mapcar #'file-name-nondirectory
                            (seq-filter
                             #'file-directory-p
                             (directory-files
                              myde-projects-directory t
                              directory-files-no-dot-files-regexp)))))
         (all (append subdirs myde-org-project-history)))
    (sort (delete-dups all) #'string<)))

(defun myde-org-capture-scheduled-line ()
  "Return a `SCHEDULED: <ts>' planning line for a capture template.
Prompts y/n; if declined returns the empty string so the planning line
is omitted entirely.  Intended for use inside an org-capture template
body via `%(...)', placed between the headline and the `:PROPERTIES:'
drawer per org convention."
  (if (y-or-n-p "Schedule this task? ")
      (format "  SCHEDULED: <%s>\n"
              (org-read-date nil nil nil "Scheduled date: "))
    ""))

(defun myde-org-capture-deadline-line ()
  "Return a `DEADLINE: <ts>' planning line for a capture template.
Same conventions as `myde-org-capture-scheduled-line'."
  (if (y-or-n-p "Set a deadline? ")
      (format "  DEADLINE: <%s>\n"
              (org-read-date nil nil nil "Deadline: "))
    ""))

(defun myde-org-capture-project-line ()
  "Return a `:PROJECT: <name>' line for an org-capture PROPERTIES drawer.
Prompts with completion over `myde-org-known-projects'.  Returns the
empty string when the user enters no value, so the property is omitted
entirely.  Intended for use inside a capture template via `%(...)':

  :PROPERTIES:
  :CREATED: %U
%(myde-org-capture-project-line)  :END:"
  (let ((val (string-trim
              (completing-read "Project (RET to skip): "
                               (myde-org-known-projects)
                               nil nil nil
                               'myde-org-project-history))))
    (if (string-empty-p val)
        ""
      (concat "  :PROJECT: " val "\n"))))

;;;; core-terminals
;;;; --------------

(defun myde/project-vterm ()
  "Open vterm at the current project root."
  (interactive)
  (let* ((proj (project-current t))
         (root (project-root proj))
         (default-directory root))
    (vterm (format "*vterm<%s>*" (file-name-nondirectory (directory-file-name root))))))

;;;; core-dashboard
;;;; --------------

(defvar myde-banner-image-file
  (expand-file-name "etc/myde-banner.png" user-emacs-directory)
  "Path to the dashboard banner image file.")

(defvar myde-banner-text-file
  (expand-file-name "etc/myde-banner.txt" user-emacs-directory)
  "Path to the dashboard banner text fallback file.")

;; -----------------------------------------------------------------------------
;; Startup dashboard
;; -----------------------------------------------------------------------------

(defun myde-dashboard-initial-buffer ()
  "Return a freshly rendered dashboard buffer for a new client frame.
This is the `initial-buffer-choice' function for a daemon session.  Rendering
per frame rather than once at daemon startup is deliberate: the daemon has no
frame to size the dashboard against, and `dashboard-vertically-center' needs
one.  Falls back to `*scratch*' because `startup.el' errors on any return
value that is not a live buffer."
  (or (and (fboundp 'dashboard-insert-startupify-lists)
           (progn (dashboard-insert-startupify-lists t)
                  (get-buffer dashboard-buffer-name)))
      (get-scratch-buffer-create)))

;;;; core-notes
;;;; ----------

(defvar myde-denote-directory myde-org-notes-directory
  "Root directory for denote notes.")

(defun myde-denote-capture-from-protocol ()
  "Wrap `denote-org-capture' seeding the title from the org-protocol payload.
Reads `:description' (falling back to `:title') from
`org-store-link-plist' so the capture flow does not re-prompt the user
for a title when invoked from a browser bookmarklet."
  (let ((title (or (plist-get org-store-link-plist :description)
                   (plist-get org-store-link-plist :title))))
    (when (and (boundp 'denote-use-title)
               (stringp title)
               (not (string-empty-p title)))
      (setq denote-use-title title))
    (denote-org-capture)))

;;;; core-snippets
;;;; -------------

(defun myde-register-snippets (dir mode)
  "Register DIR as the flat snippet directory for MODE.
DIR should contain yasnippet snippet files directly with no mode-name subdir.
Safe to call before yasnippet has loaded."
  (with-eval-after-load 'yasnippet
    (when (file-directory-p dir)
      (yas--load-directory-1 dir mode))))

;;;; core-projects
;;;; -------------

(defun myde-eglot-add-workspace-config (server-key config)
  "Upsert CONFIG for SERVER-KEY in `eglot-workspace-configuration'.
Safe to call from multiple language modules independently; replaces
any existing entry for SERVER-KEY without clobbering other languages."
  (setq-default eglot-workspace-configuration
                (cons (cons server-key config)
                      (assq-delete-all server-key
                                       (default-value
                                         'eglot-workspace-configuration)))))

(defun myde-neotree-project-root-toggle ()
  "Toggle NeoTree.  If opening, set the root to the current project root."
  (interactive)
  (if (and (fboundp 'neo-global--window-exists-p)
           (neo-global--window-exists-p))
      (neotree-hide)
    (let ((project (project-current)))
      (if project
          (neotree-dir (project-root project))
        (neotree-show)))))

(defun myde-neotree-refresh ()
  "Refresh neotree if visible."
  (when (and (fboundp 'neo-global--window-exists-p)
             (neo-global--window-exists-p))
    (save-selected-window
      (save-excursion
        (neo-buffer--refresh t)))))

(defun myde-neotree-window-size-change-function (frame)
  "Sync `neo-window-width' when FRAME is resized."
  (when (fboundp 'neo-global--get-window)
    (let ((neo-window (neo-global--get-window)))
      (unless (null neo-window)
        (setq neo-window-width (window-width neo-window))))))

;; Declare optional functions referenced by neotree to suppress native compiler warnings
(eval-when-compile
  (defvar nerd-icons-icon-for-file nil)
  (defvar nerd-icons-icon-for-dir nil)
  (defvar nerd-icons-octicon nil)
  (declare-function nerd-icons-icon-for-file "nerd-icons" (file &rest _))
  (declare-function nerd-icons-icon-for-dir "nerd-icons" (dir &rest _))
  (declare-function nerd-icons-octicon "nerd-icons" (name &rest _))
  (declare-function linum-mode "linum" (&optional _)))

;;;; core-spell
;;;; ----------

(defun myde-jinx-text-mode-setup ()
  "Enable jinx for full text checking in text-mode buffers."
  (jinx-mode))

(defun myde-jinx-prog-mode-setup ()
  "Enable jinx restricted to comment and doc faces in prog-mode buffers."
  ;; jinx-include-faces is an alist of (mode-or-t face...).  Using t as the
  ;; key matches any mode, which is correct for a buffer-local override.
  (setq-local jinx-include-faces
              '((t font-lock-comment-face
                   font-lock-doc-face)))
  (jinx-mode))

;;;; ai-base
;;;; --------

(defvar myde-openrouter-models
  '(anthropic/claude-haiku-4.5
    anthropic/claude-opus-4.5
    anthropic/claude-opus-4.6
    anthropic/claude-opus-4.7
    anthropic/claude-sonnet-4.5
    anthropic/claude-sonnet-4.6
    deepseek/deepseek-v3.2
    deepseek/deepseek-v4-flash
    deepseek/deepseek-v4-pro
    google/gemini-2.5-flash
    google/gemini-2.5-flash-lite
    google/gemini-3-flash-preview
    google/gemini-3-pro-image-preview
    google/gemini-3-pro-preview
    google/gemma-4-26b-a4b-it:free
    google/gemma-4-31b-it:free
    minimax/minimax-m2.1
    minimax/minimax-m2.5
    minimax/minimax-m2.5:free
    minimax/minimax-m2.7
    mistralai/codestral-embed-2505
    mistralai/devstral-2512
    mistralai/ministral-14b-2512
    mistralai/mistral-large-2512
    mistralai/mistral-nemo             ; roleplay, translation, trivia
    moonshotai/kimi-k2
    moonshotai/kimi-k2-0905            ; roleplay, trivia
    moonshotai/kimi-k2-thinking
    moonshotai/kimi-k2.5
    moonshotai/kimi-k2.6
    nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free
    nvidia/nemotron-3-super-120b-a12b:free
    nvidia/nemotron-nano-12b-v2-vl:free
    nvidia/nemotron-nano-9b-v2:free
    openai/gpt-5.2
    openai/gpt-5.2-codex
    openai/gpt-5.2-pro
    openai/gpt-5.3-codex
    openai/gpt-5.4
    openai/gpt-5.4-mini
    openai/gpt-5.5
    openai/gpt-5.5-pro
    openai/gpt-oss-120b
    openai/gpt-oss-120b:free
    openrouter/free
    poolside/laguna-m.1:free
    poolside/laguna-xs.2:free
    qwen/qwen3-coder-next
    qwen/qwen3-coder:free
    qwen/qwen3-max-thinking
    qwen/qwen3.6-27b
    qwen/qwen3.6-35b-a3b
    qwen/qwen3.6-flash
    qwen/qwen3.6-max-preview
    qwen/qwen3.6-plus:free
    x-ai/grok-4
    x-ai/grok-4-fast
    x-ai/grok-4.20
    x-ai/grok-4.20-multi-agent
    x-ai/grok-code-fast-1
    z-ai/glm-4.5-air:free
    z-ai/glm-4.7
    z-ai/glm-4.7-flash
    z-ai/glm-5
    z-ai/glm-5.1))

;;;; ai-gptel
;;;; --------

(defun myde-gptel-api-key-from-environment (&optional var)
  "Get API key from environment variable.
If VAR is provided, use that environment variable.
Otherwise, derive the variable name from the current gptel-backend type."
  (lambda ()
    (getenv (or var                     ;provided key
                (thread-first           ;or fall back to <TYPE>_API_KEY
                  (type-of gptel-backend)
                  (symbol-name)
                  (substring 6)
                  (upcase)
                  (concat "_API_KEY"))))))

;;;; ai-mcp
;;;; --------

(defun myde/mcp-server-startup-hook ()
  "Start the Emacs MCP server on Emacs startup."
  (mcp-server-start-unix))

;;;; auth-1password
;;;; --------------


(defun myde-auth-source-1password-construct-secret-reference
    (_backend _type host &optional user _port)
  "Construct 1Password entry path as vault/host/password (or vault/host/user/password if user provided)."
  (if user
      (mapconcat #'identity (list auth-source-1password-vault host user "password") "/")
    (mapconcat #'identity (list auth-source-1password-vault host "password") "/")))

;;;; data-hcl
;;;; --------

(defun myde-treesit-remap-hcl ()
  "Enable tree-sitter mode for terraform if grammar is available."
  (when (and (fboundp 'treesit-available-p)
             (treesit-available-p)
             (treesit-language-available-p 'hcl))
    (add-to-list 'major-mode-remap-alist
                 '(terraform-mode . terraform-ts-mode))))

;;;; data-json
;;;; ---------

(define-derived-mode jsonl-mode json-ts-mode "JSONL"
  "Major mode for JSON Lines files.")

(defun myde-json-ts-mode-hook ()
  "Enable eglot for JSON buffers, but not JSONL."
  (unless (derived-mode-p 'jsonl-mode)
    (eglot-ensure)))

;;;; data-pkl
;;;; --------

(defun myde-data-pkl-mode-setup ()
  "Set buffer-local settings for `pkl-mode' buffers."
  (setq-local fill-column 100
              tab-width 2
              indent-tabs-mode nil))

;;;; data-toml
;;;; ---------

(defun myde-toml-ts-or-plain-mode ()
  "Use `toml-ts-mode' if tree-sitter is available, otherwise fall back to `toml-mode'."
  (if (treesit-ready-p 'toml)
      (toml-ts-mode)
    (toml-mode)))

(defun myde-toml-ts-mode-setup ()
  "Set buffer-local settings for toml-ts-mode buffers."
  (setq-local fill-column 100
              tab-width 2
              indent-tabs-mode nil))

;;;; data-xml
;;;; --------

(defun myde-xml-mode-setup ()
  "Set buffer-local settings for XML buffers."
  (setq-local fill-column 100
              tab-width 2
              indent-tabs-mode nil))

(defun myde-xml-format-buffer ()
  "Reformat the current XML buffer in-place via xmllint."
  (interactive)
  (when (executable-find "xmllint")
    (let ((point (point)))
      (call-process-region (point-min) (point-max) "xmllint" t t nil "--format" "-")
      (goto-char point))))

(define-minor-mode myde-xml-format-on-save-mode
  "Auto-format XML buffer on save using xmllint."
  :lighter " fmt"
  (if myde-xml-format-on-save-mode
      (add-hook 'before-save-hook #'myde-xml-format-buffer nil t)
    (remove-hook 'before-save-hook #'myde-xml-format-buffer t)))

(defun myde-xml-ts-mode-hook ()
  "Set up xml-ts-mode buffers."
  (myde-xml-mode-setup)
  (eglot-ensure))

(defun myde-nxml-mode-hook ()
  "Set up nxml-mode buffers."
  (myde-xml-mode-setup)
  (eglot-ensure))

(defun myde-xml-ts-or-nxml-mode ()
  "Use `xml-ts-mode' if tree-sitter is available, otherwise fall back to `nxml-mode'."
  (if (treesit-ready-p 'xml)
      (xml-ts-mode)
    (nxml-mode)))

;;;; prog-base
;;;; ---------

(defun myde-prog-mode-hook-function ()
  "Configure display of line numbers and current line highlighting."
  (display-line-numbers-mode t)
  (hl-line-mode t))

(defun myde-mise-exec-which (dir exe)
  "Resolve EXE path via mise exec for project in DIR."
  (let ((default-directory (or dir
                               (and (buffer-file-name (buffer-base-buffer))
                                    (file-name-directory (buffer-file-name (buffer-base-buffer))))
                               default-directory)))
    (list (string-trim
           (shell-command-to-string
            (concat mise-executable " exec -- which " exe))))))

;;;; prog-bash
;;;; ---------

(defun myde-bash-ts-mode-setup ()
  "Set buffer-local settings for bash-ts-mode buffers."
  (setq-local sh-basic-offset 2
              indent-tabs-mode nil
              fill-column 80))

(defun myde-bash-eglot-format-buffer ()
  "Format buffer via eglot when in bash-ts-mode and eglot is active.
Safe to add to `before-save-hook' globally; it is a no-op outside of
bash-ts-mode buffers and buffers where eglot is not managing."
  (when (and (eq major-mode 'bash-ts-mode)
             (bound-and-true-p eglot--managed-mode))
    (eglot-format-buffer)))

(defun myde-bash-open-shell ()
  "Open or switch to the *shell* comint buffer."
  (interactive)
  (let ((buf (get-buffer "*shell*")))
    (if buf
        (pop-to-buffer buf)
      (shell))))

(defun myde-bash-send-region (start end)
  "Send region between START and END to the *shell* buffer.
Opens the shell buffer if it does not already exist."
  (interactive "r")
  (let ((text (buffer-substring-no-properties start end)))
    (myde-bash-open-shell)
    (process-send-string
     (get-buffer-process (get-buffer "*shell*"))
     (concat text "\n"))))

(defun myde-bash-send-buffer ()
  "Send the entire buffer contents to the *shell* buffer."
  (interactive)
  (myde-bash-send-region (point-min) (point-max)))

(defun myde-bash-run-buffer ()
  "Save the current buffer and execute it with bash in a *compilation* buffer."
  (interactive)
  (save-buffer)
  (compile (concat "bash " (shell-quote-argument (buffer-file-name)))))

;;;; prog-nushell
;;;; ------------


(defun myde-nushell-mode-setup ()
  "Set buffer-local settings for nushell-mode buffers."
  (setq-local tab-width 2
              indent-tabs-mode nil
              fill-column 100))

(defun myde-nushell-open-repl ()
  "Open or switch to the *nu* REPL buffer."
  (interactive)
  (let ((buf (get-buffer "*nu*")))
    (if buf
        (pop-to-buffer buf)
      (run-program-in-buffer "nu" "*nu*"))))

(defun run-program-in-buffer (program buffer-name)
  "Run PROGRAM in a comint buffer named BUFFER-NAME."
  (let ((buffer (get-buffer-create buffer-name)))
    (with-current-buffer buffer
      (unless (comint-check-proc (current-buffer))
        (make-comint-in-buffer program buffer-name program)))
    (pop-to-buffer buffer)))

(defun myde-nushell-send-region (start end)
  "Send region between START and END to the *nu* REPL buffer.
Opens the REPL buffer if it does not already exist."
  (interactive "r")
  (let ((text (buffer-substring-no-properties start end)))
    (myde-nushell-open-repl)
    (process-send-string
     (get-buffer-process (get-buffer "*nu*"))
     (concat text "\n"))))

(defun myde-nushell-send-buffer ()
  "Send the entire buffer contents to the *nu* REPL buffer."
  (interactive)
  (myde-nushell-send-region (point-min) (point-max)))

(defun myde-nushell-run-buffer ()
  "Save the current buffer and execute it with nu in a *compilation* buffer."
  (interactive)
  (save-buffer)
  (compile (concat "nu " (shell-quote-argument (buffer-file-name)))))

;;;; prog-elisp
;;;; ----------

(defun myde-emacs-lisp-mode-setup ()
  "Set buffer-local settings for emacs-lisp-mode buffers."
  (setq-local fill-column 80
              tab-width 2
              indent-tabs-mode nil
              compile-command (concat "emacs --batch --eval "
                                      "(byte-compile-file "
                                      (prin1-to-string buffer-file-name)
                                      ")")))

;;;; prog-clisp
;;;; ----------


(defun myde-prog-clisp-setup ()
  "Setup Common Lisp development environment.

Adds project root markers for various CL toolchains and registers the
tree-sitter grammar for future commonlisp-ts-mode compatibility."
  ;; Add Common Lisp-specific project root markers
  ;; .sbclrc — SBCL-specific configuration
  ;; .ccl/init.lisp — Clozure Common Lisp initialization
  ;; project.asd — ASDF (Another System Definition Facility) project definition
  ;; quicklisp/ — Local Quicklisp directory
  ;; .roswell/ — Roswell tool configuration
  (add-to-list 'project-vc-extra-root-markers ".sbclrc")
  (add-to-list 'project-vc-extra-root-markers ".ccl")
  (add-to-list 'project-vc-extra-root-markers "project.asd")
  (add-to-list 'project-vc-extra-root-markers "quicklisp")
  (add-to-list 'project-vc-extra-root-markers ".roswell")

  ;; Register tree-sitter grammar for Common Lisp
  ;; No commonlisp-ts-mode exists yet, but grammar is available for future
  (when (treesit-available-p)
    (add-to-list 'treesit-language-source-alist
      '(commonlisp "https://github.com/tree-sitter/tree-sitter-commonlisp"))))

(defun myde-prog-clisp-lisp-mode-setup ()
  "Buffer-local setup for `lisp-mode': initialize SLY and disable hard tabs."
  (myde-prog-clisp-sly-init)
  (setq indent-tabs-mode nil))

(defun myde-prog-clisp-sly-init ()
  "Configure SLY for interactive Common Lisp development.

Sets up the modern REPL with stickers (live feedback), autodoc, and SLDB
integrated debugger. SLY is the primary REPL choice for myde."
  ;; Set default Lisp implementation to SBCL
  ;; SLY will auto-detect available implementations at runtime
  (setq sly-default-lisp 'sbcl)

  ;; Enable stickers for live feedback (SLY-specific feature)
  ;; Shows results inline as you type
  (setq sly-stickers-default-action 'sly-stickers-fetch))

(defun myde-prog-clisp-slime-init ()
  "Configure SLIME for Common Lisp development (fallback REPL).

SLIME is the fallback when SLY is unavailable. It has larger ecosystem
but less modern UX. Both SLY and SLIME work with all CL implementations."
  ;; Set inferior Lisp program to SBCL
  ;; SLIME will use this as the default REPL backend
  (cond
    ((executable-find "sbcl")
     (setq inferior-lisp-program "sbcl"))
    ((executable-find "ccl")
     (setq inferior-lisp-program "ccl"))
    ((executable-find "ecl")
     (setq inferior-lisp-program "ecl"))
    (t
     (message "Warning: No Common Lisp implementation found on PATH"))))

(defun myde-prog-clisp-lsp-server ()
  "Optional LSP server detection via Roswell.

Returns ('cl-lsp') if Roswell is installed, nil otherwise.
cl-lsp requires Roswell (CL tool manager) to be set up.

LSP is optional; SLIME/SLY are superior for interactive CL development."
  (when (executable-find "ros")
    '("cl-lsp")))

;;;; prog-scheme
;;;; -----------


(defun myde-prog-scheme-setup ()
  "Setup Scheme development environment.

Adds project root markers for various Scheme toolchains and registers
the tree-sitter grammar for future compatibility."
  ;; Add Scheme-specific project root markers
  ;; .guile — Guile-specific configuration
  ;; guix.scm — Guix package definition (uses Guile)
  ;; akku.manifest — Akku package manager manifest
  ;; .akku/ — Akku directory
  ;; chicken-install.log — CHICKEN package installation log
  (add-to-list 'project-vc-extra-root-markers ".guile")
  (add-to-list 'project-vc-extra-root-markers "guix.scm")
  (add-to-list 'project-vc-extra-root-markers "akku.manifest")
  (add-to-list 'project-vc-extra-root-markers ".akku")
  (add-to-list 'project-vc-extra-root-markers "chicken-install.log")

  ;; Register tree-sitter grammar for Scheme
  ;; No scheme-ts-mode remap yet (not on MELPA), but grammar is available for future use
  (when (treesit-available-p)
    (add-to-list 'treesit-language-source-alist
      '(scheme "https://github.com/6cdh/tree-sitter-scheme"))))

(defun myde-prog-scheme-lsp-server ()
  "Detect and return appropriate LSP server command for Scheme.

Returns the first available LSP server from:
1. scheme-langserver (general, R6RS/R7RS, Chez-based)
2. guile-lsp-server (Guile-specific)
3. chicken-lsp-server (CHICKEN-specific)

Returns nil if none are available (eglot gracefully skips LSP)."
  (cond
    ((executable-find "scheme-langserver")
     '("scheme-langserver"))
    ((executable-find "guile-lsp-server")
     '("guile-lsp-server"))
    ((executable-find "chicken-lsp-server")
     '("chicken-lsp-server"))
    (t nil)))

(defun myde-prog-scheme-format-buffer-maybe ()
  "Guard function for schemat before-save formatting.

Only formats if:
1. Current major mode is scheme-mode
2. schemat binary is on PATH
3. eglot is managing the buffer (LSP is active)

This allows schemat to be optional; formatting silently skips if binary is absent."
  (and (eq major-mode 'scheme-mode)
       (executable-find "schemat")
       (bound-and-true-p eglot--managed-mode)))

(defun myde-prog-scheme-before-save-hook ()
  "Guarded schemat formatter for scheme buffers; skips if schemat absent."
  (when (myde-prog-scheme-format-buffer-maybe)
    (apheleia-format-buffer 'schemat)))

(defun myde-prog-scheme-format-on-save-setup ()
  "Install buffer-local before-save formatting for scheme-mode."
  (add-hook 'before-save-hook #'myde-prog-scheme-before-save-hook nil t))

;;;; prog-clojure
;;;; ------------


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

;;;; prog-erlang
;;;; -----------


(defun myde-erlang-mode-setup ()
  "Set buffer-local settings for erlang-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "rebar3 compile"))

(defun myde-erlang-run-tests ()
  "Run Common Test suite via rebar3."
  (interactive)
  (compile "rebar3 ct"))

;;;; prog-elixir
;;;; -----------


(defun myde-elixir-ts-ensure-grammars ()
  "Ensure Elixir and HEEx tree-sitter grammars are installed."
  (dolist (lang '(elixir heex))
    (unless (treesit-ready-p lang t)
      (message "Installing %s tree-sitter grammar..." lang)
      (treesit-install-language-grammar lang))))

(defun myde-elixir-exs-debug-example ()
  "Return an example of how to structure an .exs script for debugging.

This is for documentation purposes only - not meant to be called interactively.

Example structure for debugging .exs scripts with dape:

    defmodule MyScript do
      def run do
        a = [1, 2, 3]
        b = Enum.map(a, &(&1 + 1))
        IO.inspect(b, label: \"result\")
        b
      end
    end

    Task.start(fn ->
      Process.sleep(4000)  # Give debugger time to interpret
      MyScript.run()
    end)

Key points:
1. Wrap main logic in a module function
2. Use Task.start with a sleep delay to work around race condition
3. The script will be interpreted when debugging starts
4. Set breakpoints in the module functions, not top-level code

Alternative: Use Kernel.dbg/2 for simpler debugging without breakpoints.
Set breakOnDbg: true in the dape configuration to enable automatic breaking."
  nil)

;;;; prog-cpp
;;;; --------


(defun myde-cpp-ts-mode-setup ()
  "Set buffer-local settings for c++-ts-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "cmake --build build"))

(defun myde-c-ts-mode-setup ()
  "Set buffer-local settings for c-ts-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "cmake --build build"))

(defun myde-cpp-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde-cpp-format-on-save-setup ()
  "Install buffer-local before-save formatting for C/C++ ts modes."
  (add-hook 'before-save-hook #'myde-cpp-eglot-format-buffer nil t))

(defun myde-cpp-run-tests ()
  "Build and run CTest tests for the current project."
  (interactive)
  (compile "cmake --build build && ctest --test-dir build --output-on-failure"))

(defun myde-cpp-dape-binary ()
  "Prompt for the C++ debug binary, defaulting to the project build/ directory."
  (read-file-name "Binary: "
                  (expand-file-name "build/" (or (when-let ((proj (project-current)))
                                                   (project-root proj))
                                                 default-directory))))

;;;; prog-go
;;;; --------


(defvar myde-go-tab-width 2
  "Tab width for Go buffers.")

(defun myde-go-ts-or-plain-mode ()
  "Use `go-ts-mode' if tree-sitter is available, otherwise fall back to `go-mode'."
  (if (treesit-ready-p 'go)
      (go-ts-mode)
    (go-mode)))

(defun myde-go-mode-setup ()
  "Set buffer-local settings for Go buffers."
  (setq-local tab-width myde-go-tab-width
              indent-tabs-mode t
              fill-column 100
              compile-command "go test ./..."))

(defun myde-go-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde-go-format-on-save-setup ()
  "Install buffer-local before-save formatting for go-ts-mode."
  (add-hook 'before-save-hook #'myde-go-eglot-format-buffer nil t))

;;;; prog-rust
;;;; ---------


(defun myde-rust-mode-setup ()
  "Set buffer-local settings for rustic-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "cargo test"))

(defun myde-rust-dape-debug-program ()
  "Resolve the debug binary path for the current Rust project.
Used as the `:program' callback for dape Rust debug configurations."
  (expand-file-name
   (concat "target/debug/"
           (file-name-nondirectory (directory-file-name (dape-cwd))))
   (dape-cwd)))

;;;; prog-zig
;;;; --------


(defun myde-zig-ts-or-plain-mode ()
  "Use `zig-ts-mode' if tree-sitter is available, otherwise fall back to `zig-mode'."
  (if (treesit-ready-p 'zig)
      (zig-ts-mode)
    (zig-mode)))

(defun myde-zig-mode-setup ()
  "Set buffer-local settings for zig-ts-mode buffers."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 100
              compile-command "zig build"))

(defun myde-zig-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde-zig-format-on-save-setup ()
  "Install buffer-local before-save formatting for zig-mode."
  (add-hook 'before-save-hook #'myde-zig-eglot-format-buffer nil t))

(defun myde-zig-dape-binary ()
  "Resolve the debug binary path for the current Zig project.
Used as the `:program' callback for dape Zig debug configurations."
  (expand-file-name
   (concat "zig-out/bin/"
           (file-name-nondirectory (directory-file-name (dape-cwd))))
   (dape-cwd)))

;;;; prog-python
;;;; -----------


(defun myde-python-ts-mode-setup ()
  "Set buffer-local settings for python-ts-mode buffers.
Runs after mise-mode has applied the project environment, so
`executable-find' resolves against the project venv."
  (setq-local tab-width 4
              indent-tabs-mode nil
              fill-column 88  ; ruff/black default line length
              python-shell-interpreter (or (executable-find "python3")
                                           (executable-find "python")
                                           "python3")
              compile-command "python -m pytest"))

;;;; prog-ruby
;;;; ---------


(defun myde-ruby-ts-or-plain-mode ()
  "Use `ruby-ts-mode' if tree-sitter is available, otherwise fall back to `ruby-mode'."
  (if (treesit-ready-p 'ruby)
      (ruby-ts-mode)
    (ruby-mode)))

(defun myde-ruby-mode-setup ()
  "Set buffer-local settings for ruby-mode and ruby-ts-mode buffers."
  (setq-local tab-width 2
              indent-tabs-mode nil
              fill-column 120
              compile-command "bundle exec rspec"))

(defun myde-ruby-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde-ruby-format-on-save-setup ()
  "Install buffer-local before-save formatting for ruby buffers."
  (add-hook 'before-save-hook #'myde-ruby-eglot-format-buffer nil t))

;;;; prog-lua
;;;; --------


(defun myde-lua-ts-or-plain-mode ()
  "Use `lua-ts-mode' if tree-sitter is available, otherwise fall back to `lua-mode'."
  (if (treesit-ready-p 'lua)
      (lua-ts-mode)
    (lua-mode)))

(defun myde-lua-mode-setup ()
  "Set buffer-local settings for lua-mode and lua-ts-mode buffers."
  (setq-local tab-width 2
              indent-tabs-mode nil
              fill-column 120
              compile-command "lua"))

(defun myde-lua-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde-lua-format-on-save-setup ()
  "Install buffer-local before-save formatting for lua buffers."
  (add-hook 'before-save-hook #'myde-lua-eglot-format-buffer nil t))

;;;; prog-javascript
;;;; ---------------


(defun myde-js-ts-mode-setup ()
  "Set buffer-local settings for js-ts-mode buffers."
  (setq-local indent-tabs-mode nil
              tab-width 2
              fill-column 100))

(defun myde-javascript-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde-javascript-format-on-save-setup ()
  "Install buffer-local before-save formatting for js-ts-mode."
  (add-hook 'before-save-hook #'myde-javascript-eglot-format-buffer nil t))

(defun myde-javascript-mode-hook ()
  "Hook for js-ts-mode buffers.
Enables inlay hints when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-inlay-hints-mode 1)))

;;;; prog-typescript
;;;; ---------------


(defun myde-typescript-ts-mode-setup ()
  "Set buffer-local settings for typescript-ts-mode buffers."
  (setq-local indent-tabs-mode nil
              tab-width 2
              fill-column 100))

(defun myde-tsx-ts-mode-setup ()
  "Set buffer-local settings for tsx-ts-mode buffers."
  (setq-local indent-tabs-mode nil
              tab-width 2
              fill-column 100))

(defun myde-typescript-eglot-format-buffer ()
  "Format buffer via eglot when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-format-buffer)))

(defun myde-typescript-format-on-save-setup ()
  "Install buffer-local before-save formatting for TypeScript/TSX modes."
  (add-hook 'before-save-hook #'myde-typescript-eglot-format-buffer nil t))

(defun myde-typescript-mode-hook ()
  "Shared hook for typescript-ts-mode and tsx-ts-mode buffers.
Enables inlay hints when eglot is managing the buffer."
  (when (bound-and-true-p eglot--managed-mode)
    (eglot-inlay-hints-mode 1)))

;;;; text-base
;;;; ---------

(defun myde-text-mode-hook-function ()
  "Configure display of line numbers on all text-mode buffers."
  (display-line-numbers-mode t))

;;;; text-asciidoc
;;;; -------------

(defun myde-adoc-mode-setup ()
  "Set buffer-local settings for adoc-mode buffers."
  (setq-local fill-column 80
              tab-width 2
              indent-tabs-mode nil))

(defun myde-adoc-preview ()
  "Save buffer, render it to a temp HTML file, and open it in the browser."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer has no file — save it first"))
  (save-buffer)
  (let* ((src (buffer-file-name))
         (html (make-temp-file "adoc-preview" nil ".html")))
    (if (zerop (call-process "asciidoctor" nil nil nil "-o" html src))
        (browse-url (concat "file://" html))
      (message "asciidoctor failed; install with: brew install asciidoctor"))))

(defun myde-adoc-export-html ()
  "Export current AsciiDoc buffer to HTML alongside the source file."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer has no file — save it first"))
  (save-buffer)
  (let* ((src (buffer-file-name))
         (out (concat (file-name-sans-extension src) ".html")))
    (if (zerop (call-process "asciidoctor" nil nil nil "-o" out src))
        (message "Exported: %s" out)
      (message "asciidoctor failed; install with: brew install asciidoctor"))))

(defun myde-adoc-export-pdf ()
  "Export current AsciiDoc buffer to PDF alongside the source file.
Requires asciidoctor-pdf (gem install asciidoctor-pdf)."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer has no file — save it first"))
  (save-buffer)
  (let* ((src (buffer-file-name))
         (out (concat (file-name-sans-extension src) ".pdf")))
    (if (zerop (call-process "asciidoctor-pdf" nil nil nil "-o" out src))
        (message "Exported: %s" out)
      (message "asciidoctor-pdf failed; install with: gem install asciidoctor-pdf"))))

;;;; text-markdown
;;;; -------------

(defconst myde-text-markdown-dir
  (expand-file-name "etc/" user-emacs-directory)
  "Directory containing text-markdown module assets.")

(defun myde-markdown-preview-script-tag (relative-path)
  "Return the contents of RELATIVE-PATH wrapped in a <script> tag.
RELATIVE-PATH is resolved against `myde-text-markdown-dir'.  The
return value is suitable for `markdown-preview-javascript' --
strings beginning with \"<script\" are inlined verbatim by the
package; everything else is wrapped as <script src=\"…\">, which
fails for filesystem paths the preview HTTP server cannot reach."
  (with-temp-buffer
    (insert "<script>\n")
    (insert-file-contents (expand-file-name relative-path myde-text-markdown-dir))
    (goto-char (point-max))
    (insert "\n</script>")
    (buffer-string)))

(defun myde-markdown-mode-setup ()
  "Set buffer-local settings for markdown-mode buffers."
  (setq-local fill-column 80
              tab-width 2
              indent-tabs-mode nil
              sentence-end-double-space nil))

(defun myde-markdown-export-html ()
  "Export current Markdown buffer to HTML alongside the source file."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer has no file — save it first"))
  (save-buffer)
  (let* ((src (buffer-file-name))
         (out (concat (file-name-sans-extension src) ".html")))
    (if (zerop (call-process "pandoc" nil nil nil
                             "-f" "gfm" "-s" "-o" out src))
        (message "Exported: %s" out)
      (message "pandoc failed; install with: brew install pandoc"))))

(defun myde-markdown-export-pdf ()
  "Export current Markdown buffer to PDF alongside the source file.
Requires pandoc and a TeX engine (e.g. brew install --cask basictex)."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer has no file — save it first"))
  (save-buffer)
  (let* ((src (buffer-file-name))
         (out (concat (file-name-sans-extension src) ".pdf")))
    (if (zerop (call-process "pandoc" nil nil nil
                             "-f" "gfm" "-o" out src))
        (message "Exported: %s" out)
      (message "pandoc PDF failed; need pandoc + a TeX engine"))))

;;;; ebook-epub
;;;; ----------

(defun myde-reading-setup ()
  "Improve readability for long-form documents."
  (visual-line-mode 1)
  (setq-local line-spacing 0.15))

(defun myde-reading-keybindings ()
  "Unified navigation keys across readers."
  (local-set-key (kbd "i") #'org-noter)
  (local-set-key (kbd "n") #'org-noter-insert-note)
  (local-set-key (kbd "h") #'org-remark-mark)
  (local-set-key (kbd "j") #'org-noter-sync-next-note)
  (local-set-key (kbd "k") #'org-noter-sync-prev-note))

(provide 'myde)
;;; myde.el ends here
