;;; init.el --- Loaded after early-init.el -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

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
;; Entry point for MyDE -- *MY* Development Environment.
;;
;; Bootstraps elpaca, enables its use-package support, then loads all
;; configuration from user-lisp/myde.el, which Emacs 31 places on `load-path'
;; automatically via `user-lisp-directory'.

;;; Code:

;;;; Elpaca bootstrap

(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-sources-directory (expand-file-name "sources/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              ;; :depth nil, not upstream's 1: a shallow clone has no
                              ;; ancestor in common with fetched updates, so elpaca's
                              ;; own `git merge --ff-only' refuses to self-update.
                              :ref nil :depth nil :inherit ignore
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca-activate)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-sources-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil)) (load "./elpaca-autoloads"))))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

;;;; Built-in compat

;; Emacs 31.1 ships a compat.el stub whose autoload pushes
;; (compat 31 1 9999) onto `package--builtin-versions', so the built-in
;; outranks any external compat for a dependency on the current or an older
;; Emacs -- upstream's documented way of not installing compat at all.  Elpaca
;; exempts compat from its built-in ignore list defensively, so it clones a
;; copy anyway; core libraries that require compat during init (python.el,
;; window-tool-bar.el, erc-compat.el) then load the built-in first and elpaca
;; warns "compat loaded before Elpaca activation".  Re-adding it drops the
;; redundant order.  Ceiling: a package needing a compat newer than this Emacs
;; ships -- remove this line if one ever appears.
(add-to-list 'elpaca-ignored-dependencies 'compat)

;;;; Use-package support

;; Every use-package form is :ensure t unless it says :ensure nil.  Built-in
;; forms must say so; elpaca-use-package has no by-default knob of its own.
(setq use-package-always-ensure t)

;; The elpaca-use-package menu recipe carries :wait t, so this blocks until
;; elpaca-use-package is built and `use-package' :ensure support is active --
;; which myde.el depends on from its first form.
(elpaca elpaca-use-package
  (elpaca-use-package-mode))

;;;; Configuration

(require 'myde)

;;;; core-base
;;;; ---------

;; Startup configuration.  A daemon otherwise shows every startup warning on
;; its first client frame, whatever `warning-minimum-level' early-init.el set.
(advice-add 'display-warning :around #'myde-display-warning-advice)
(add-to-list 'find-file-not-found-functions #'myde-auto-create-missing-dirs)

;; Regenerate the tangled elisp whenever myde.org is saved.
(use-package emacs
  :hook (after-save . myde-tangle-source-on-save)
  :ensure nil)

;; XDG directory support — load early so all XDG paths are available immediately.
(require 'xdg)

;; Disable backup files (handled by buffer-guardian)
(setq make-backup-files nil)

;; Store backups in XDG state directory
(let ((backup-dir (expand-file-name "emacs/backup" (xdg-state-home))))
  (setq backup-directory-alist `(("." . ,backup-dir)))
  (make-directory backup-dir :parents))

;; Lockfiles only guard against a second Emacs editing the same file, and this
;; config runs one, the daemon.  Here they would only leave .#file symlinks in
;; repos.  Also covers remote files, so `remote-file-name-inhibit-locks' is moot.
(use-package emacs
  :custom
  (create-lockfiles nil)
  :ensure nil)

;; Ignore `eval:' file-local forms instead of prompting, and make a TLS
;; certificate failure an error instead of a prompt.
(use-package emacs
  :custom
  (enable-local-eval nil)
  :ensure nil)

(use-package gnutls
  :defer t
  :custom
  (gnutls-verify-error t)
  :ensure nil)

;; Themes trusted without a prompt: batppuccin frappe and mocha.  The hashes
;; pin those files' contents, so a batppuccin update prompts again.  Set before
;; custom.el loads so a theme Customize saves as safe there is not overwritten.
(setq custom-safe-themes
      '("68a0201c7bb9dba9c9b6fd6662d1f3daf8865860ba8fc56d0201be859da535fc"
        "b0cedf3c6d8fbbf65934e2045dddacff0a031992f2f389215adcb0ca741347c3"
        default))

;; Load user customizations.
(let* ((path (expand-file-name "custom.el" user-emacs-directory))
       (exists (file-exists-p path)))
  (setq custom-file path)
  (when exists
    (load-file custom-file)))

;; TRAMP: connection cache in XDG state, only errors in *Messages*, and remote
;; file attributes cached for 50 s instead of 10 s.
(use-package tramp
  :defer t
  :init
  ;; Not `:custom'.  tramp-loaddefs.el defvars this to its default when tramp
  ;; loads, which discards a saved custom value.  A setq binds it first.
  (setq tramp-persistency-file-name
        (expand-file-name "emacs/tramp" (xdg-state-home)))
  :custom
  (tramp-verbose 1)
  (remote-file-name-inhibit-cache 50)
  :ensure nil)

;; URL library configuration (cookies, cache)
(setq url-configuration-directory
      (expand-file-name "emacs/url/" (xdg-cache-home)))

;; Recent files management.  `:hook', not `:commands': a deferring keyword
;; with `recentf-mode' down in :config meant recentf was never loaded at all.
(use-package recentf
  :hook (elpaca-after-init . recentf-mode)
  :custom
  (recentf-save-file (expand-file-name "emacs/recentf.eld" (xdg-state-home)))
  (recentf-max-saved-items 50)
  (recentf-auto-cleanup (if (daemonp) 300 'never))
  (recentf-exclude '("^/tmp/" "^/ssh:" "/COMMIT_EDITMSG\\'"
                     "/bookmarks" "/info/" "/diary$" "/\\.elpa/"))
  :config
  ;; `:hook' cannot express a depth, and -90 must run before the savers.
  (add-hook 'kill-emacs-hook #'recentf-cleanup -90)
  :diminish recentf-mode
  :ensure nil)

;; Remember last position within files
(use-package saveplace
  :custom
  (save-place-file (expand-file-name "emacs/places.eld" (xdg-state-home)))
  :config
  (save-place-mode)
  :diminish save-place-mode
  :ensure nil)

;; Remember minibuffer history
(use-package savehist
  :custom
  (savehist-file (expand-file-name "emacs/history" (xdg-state-home)))
  :config
  (savehist-mode)
  :diminish savehist-mode
  :ensure nil)

;; Bookmarks (`M-x bookmark-set' et al.) — `bookmark-default-file' defaults
;; to <user-emacs-directory>/bookmarks, which lands in the repo root since
;; ~/.config/emacs is symlinked there.  Redirect to XDG state.
(use-package bookmark
  :custom
  (bookmark-default-file (expand-file-name "emacs/bookmarks" (xdg-state-home)))
  :ensure nil)

;; Transient menus and popups — XDG-compliant persistence paths.
(use-package transient
  :custom
  (transient-levels-file  (expand-file-name "emacs/transient/levels.el"  (xdg-data-home)))
  (transient-values-file  (expand-file-name "emacs/transient/values.el"  (xdg-data-home)))
  (transient-history-file (expand-file-name "emacs/transient/history.el" (xdg-data-home)))
  :ensure nil)

;; Auto-save buffers on focus loss
(use-package buffer-guardian  ;; https://github.com/jamescherti/buffer-guardian.el
  :custom
  (buffer-guardian-inhibit-saving-remote-files t)         ;; When non-nil, include remote files in the auto-save process
  (buffer-guardian-inhibit-saving-nonexistent-files nil)  ;; When non-nil, buffers visiting nonexistent files are not saved
  (buffer-guardian-save-on-same-buffer-window-change t)   ;; Save the buffer even if the window change results in the same buffer
  (buffer-guardian-verbose nil)                           ;; Non-nil to enable verbose mode to log when a buffer is automatically saved
  ;; (buffer-guardian-save-all-buffers-idle 30)           ;; Save all buffers after N seconds of user idle time. (Disabled by default)
  :hook
  (elpaca-after-init . buffer-guardian-mode)
  :diminish buffer-guardian-mode
  :ensure t)

;; Tree-sitter grammar storage — redirect both load path and install path to
;; the XDG data dir.  `treesit-extra-load-path' tells Emacs where to find
;; compiled grammars.  The `:around' advice on `treesit-install-language-grammar'
;; ensures all callers (including `treesit-auto') write grammars to the same
;; XDG location rather than the default `user-emacs-directory/tree-sitter/'.
(use-package treesit
  :init
  (make-directory (expand-file-name "emacs/tree-sitter" (xdg-data-home)) :parents)
  :custom
  (treesit-extra-load-path (list (expand-file-name "emacs/tree-sitter" (xdg-data-home))))
  :config
  (advice-add 'treesit-install-language-grammar
              :around #'myde-treesit-install-language-grammar-advice)
  :ensure nil)

;; Make URLs and email addresses actionable: fontified, clickable
;; (mouse-2), and openable from the keyboard via C-c RET on the link.
;; `goto-address-prog-mode' restricts activation to comments/strings in
;; code buffers; `goto-address-mode' covers the entirety of text buffers.
;; Browser dispatch uses the built-in `browse-url-default-browser', which
;; defers to `open` on macOS and `xdg-open` on Linux — both honor the
;; user's OS-level default browser, so no override is needed here.
(use-package goto-addr
  ;; macOS trackpads have no native middle-click.  Plain mouse-1 stays
  ;; as point movement; Super+click follows the link (on macOS, Super
  ;; is whichever physical key the user has mapped to it — Cmd by
  ;; default).  Disabling `mouse-1-click-follows-link' is what
  ;; prevents Emacs from translating a quick plain mouse-1 on a
  ;; `follow-link' overlay into a virtual mouse-2 click.
  :custom
  (mouse-1-click-follows-link nil)
  :bind (("C-c u" . browse-url-at-point)
         :map goto-address-highlight-keymap
         ([s-mouse-1] . goto-address-at-point))
  :hook (elpaca-after-init . global-goto-address-mode)
  :ensure nil)

;;;; Environment
;;;; -----------
;; Must precede every `executable-find' gate below.  GUI Emacs on macOS, and
;; Emacs started from a .desktop entry or systemd user unit on Linux, do not
;; inherit the login shell's PATH -- so without this, gates would silently
;; disable modules whose binaries are installed.
;;
;; Sits after core-base rather than first in the file: under package.el a
;; third-party package cannot be required before `package-initialize', which
;; core-base runs.  The position is harmless under elpaca and is kept fixed.
;;
;; Dropping "-i" from the default '("-l" "-i") takes the probe from ~575ms to
;; ~88ms with an identical resulting PATH, and keeps it under
;; `exec-path-from-shell-warn-duration-millis' (500).

(use-package exec-path-from-shell
  :ensure (:wait t)
  :custom
  (exec-path-from-shell-arguments '("-l"))
  :config
  (when (or (daemonp) window-system)
    (exec-path-from-shell-initialize)))

;; macOS ls is BSD and rejects --dired and --group-directories-first; use
;; GNU ls (gls, from coreutils) when installed.  Must follow
;; `exec-path-from-shell', or gls is not on the bare launchd PATH yet.
(when-let* (((string= system-type "darwin"))
            (gls (executable-find "gls")))
  (setq insert-directory-program gls
        dired-use-ls-dired t
        dired-listing-switches "-aBhl --group-directories-first"))

;;;; core-ui
;;;; --------

;; Cursor configuration
(setq-default cursor-type 'bar)

;; Redisplay work this config does not need: right-to-left text analysis,
;; font-lock while keys are still pending, and cursors in unfocused windows.
;; The `setq' names are plain variables, not defcustoms.
(use-package emacs
  :custom
  (bidi-paragraph-direction 'left-to-right)
  (cursor-in-non-selected-windows nil)
  (fast-but-imprecise-scrolling t)
  :config
  (setq bidi-inhibit-bpa t
        redisplay-skip-fontification-on-input t
        auto-window-vscroll nil)
  :ensure nil)

;; Highlight current line globally
(global-hl-line-mode)

;; Window divider and layout restoration
(window-divider-mode)
(winner-mode)
(setq visible-bell nil
      ring-bell-function 'myde-flash-mode-line)

;; Clear echo area after all startup hooks have run (removes last info message).
(use-package emacs
  :hook (elpaca-after-init . myde/clear-echo-area)
  :ensure nil)

;; Disable startup splash screen and initial scratch message
(setq inhibit-startup-message t
      inhibit-startup-echo-area-message t
      initial-scratch-message nil)

;; Collapse minor modes in modeline
(setq mode-line-collapse-minor-modes t)

;; Enable smooth scrolling in GUI.
;; Get rid of the scrollbar and toolbar in GUI. They take up precious space
;; and one of my goals is to keep my hands on the keyboard, not the mouse.
(when (display-graphic-p)
  (pixel-scroll-precision-mode 1)
  (scroll-bar-mode -1)
  (tool-bar-mode -1))

;; Disable the menubar in TUI (on any OS) or GUI (only on macOS).
;; One thing I like about Emacs GUI app on macOS is that it uses a global app
;; menu that changes with the app, so leave it alone in that case.
(unless (and (display-graphic-p) (string-equal system-type "darwin"))
  (menu-bar-mode -1))

;; Blink cursor
(blink-cursor-mode 1)

;; Enable display of column numbers in buffer modeline
(setq column-number-mode t)

;; Show project-relative path in frame title when in a project, full path otherwise
(setq frame-title-format '(:eval (myde/frame-title)))

;; Hide or shorten minor-mode lighters that convey no real-time information
(use-package diminish
  :config
  (diminish 'eldoc-mode)
  (diminish 'auto-revert-mode)
  :ensure t)

;; UI quality of life improvements
(use-package spacious-padding  ;; https://github.com/protesilaos/spacious-padding
  :hook (elpaca-after-init . spacious-padding-mode)
  :ensure t)

;; Indent guides.  This is the only form that ensures indent-bars; the
;; per-language :hook forms below say :ensure nil so elpaca queues the
;; package once (a duplicate order aborts init under elpaca 0.12).
(use-package indent-bars  ;; https://github.com/jdtsmith/indent-bars
  :custom
  ;; The macOS NS/Cocoa build of Emacs has poor stipple support, rendering the
  ;; stipple-based bars as solid black blocks. Draw them with the `│' character
  ;; instead on darwin (no-op in the terminal, which already uses characters).
  (indent-bars-prefer-character (eq system-type 'darwin))
  (indent-bars-treesit-support t)
  (indent-bars-color '(highlight :face-bg t :blend 0.2))
  (indent-bars-pattern ".")
  (indent-bars-width-frac 0.1)
  (indent-bars-pad-frac 0.1)
  (indent-bars-zigzag nil)
  (indent-bars-color-by-depth nil)
  (indent-bars-highlight-current-depth nil)
  (indent-bars-display-on-blank-lines nil)
  :ensure t)

;; Icons support
(use-package nerd-icons  ;; https://github.com/rainstormstudio/nerd-icons.el
  :ensure t)

;; Default font.  A nil frame also sets the default for frames made later,
;; so client frames of the daemon get it.
(set-face-attribute 'default nil
                    :family "JetBrainsMono Nerd Font Mono"
                    :height 120)

;; Fonts support
(use-package show-font  ;; https://github.com/protesilaos/show-font
  :bind
  (("C-c s f" . show-font-select-preview)
   ("C-c s t" . show-font-tabulated))
  :ensure t)

;; Themes support (only active theme and preview are loaded; others defer on demand)
(use-package easy-theme-preview  ;; https://github.com/ayys/easy-theme-preview.el
  :defer t
  :ensure t)

(use-package color-theme-sanityinc-tomorrow  ;; https://github.com/purcell/color-theme-sanityinc-tomorrow
  :defer t
  :ensure t)

(use-package doom-themes ;; https://github.com/doomemacs/themes
  :defer t
  :custom
  (doom-themes-enable-bold t)   ; if nil, bold is universally disabled
  (doom-themes-enable-italic t) ; if nil, italics is universally disabled
  (doom-themes-treemacs-theme "doom-atom") ; use "doom-colors" for less minimal icon theme
  :config
  (doom-themes-visual-bell-config)  ;; Enable flashing mode-line on errors
  (doom-themes-treemacs-config)
  (doom-themes-org-config)          ;; Corrects (and improves) org-mode's native fontification.
  :ensure t)

(use-package ef-themes  ;; https://github.com/protesilaos/ef-themes
  :defer t
  :ensure t)

(use-package jetbrains-darcula-theme  ;; https://github.com/ianyepan/jetbrains-darcula-emacs-theme
  :defer t
  :ensure t)

(use-package batppuccin
  :config
  (load-theme 'batppuccin-frappe t)
  :ensure t)

(use-package auto-dark
  :after batppuccin
  :if (string= system-type "linux")
  :custom
  (auto-dark-themes '((batppuccin-frappe) (batppuccin-latte)))
  :init
  (auto-dark-mode t)
  :ensure t)

(use-package modusregel
  :config
  (setq-default mode-line-format modusregel-format)
  :ensure (:host codeberg :repo "jjba23/modusregel"))

;;;; core-ux
;;;; --------

;; Exit confirmation
(setq confirm-kill-emacs 'y-or-n-p)

;; Improve search display
(setq isearch-lazy-count t
      lazy-count-prefix-format nil
      lazy-count-suffix-format "   (%s/%s)")

;; Swap option and command keys on macOS to match Linux keyboard layout
;; No display-graphic-p guard: under the daemon, init runs with only a tty
;; frame, so the guard never fired and client frames kept the NS defaults.
(when (string-equal system-type "darwin")
  (setq mac-command-modifier 'meta
        mac-option-modifier 'super))

;; Auto-revert buffer on changes to files on disk
(global-auto-revert-mode 1)

;; Delete region selected when overwriting it
(delete-selection-mode 1)

;; Automatically follow links to version controlled files when opening them
(setq vc-follow-symlinks t)

;; Squelch annoying confirmation if a file or buffer does not exist
(setq confirm-nonexistent-file-or-buffer nil)

;; Keep async native-compile warnings out of the way.  At the default
;; `important' level every "function ... is not known to be defined" in a
;; third-party package pops up *Warnings*, burying warnings that need action.
;; `silent' still logs them there, under type `native-compiler'.
(setq native-comp-async-report-warnings-errors 'silent)

;; Squelch prompt to kill buffer with process attached to it
(setq kill-buffer-query-functions
      (remq 'process-kill-buffer-query-function kill-buffer-query-functions))

;; Squelch prompt on exit when active processes (e.g. mcp-server) are running
(setq confirm-kill-processes nil)

;; Use 'y'/n' instead of 'yes'/'no' for confirmations (Emacs 30+)
(setq use-short-answers t)

;; Soft delete files.
(setq delete-by-moving-to-trash t)

;; Global keyboard remap
(use-package emacs
  :bind (([remap keyboard-quit] . myde-keyboard-quit)
         ("M-Z" . zap-up-to-char))
  :ensure nil)

;; Expand/contract region with semantic awareness
(use-package expreg  ;; https://github.com/casouri/expreg
  :bind (("C-=" . expreg-expand)
         ("C--" . expreg-contract))
  :ensure t)

;; Vim-style pair editing (surround)
(use-package surround  ;; https://github.com/mkleehammer/surround
  :bind-keymap ("M-'" . surround-keymap)
  :ensure t)

;; Multiple cursors support
(use-package multiple-cursors  ;; https://github.com/magnars/multiple-cursors.el
  :bind (("C-S-c C-S-c" . mc/edit-lines)               ;; edit multiple lines
         ("C-S-c C->"   . mc/mark-next-like-this)      ;; add next match
         ("C-S-c C-<"   . mc/mark-previous-like-this)  ;; add previous match
         ("C-S-c C-+"   . mc/mark-all-like-this))      ;; mark all matches
  :custom
  (mc/list-file (expand-file-name "emacs/mc-lists.el" (xdg-state-home)))
  (mc/always-run-for-all t)   ;; Make cursor movement more predictable
  :ensure t)

;; Operate on whole line or region
(use-package whole-line-or-region  ;; https://github.com/purcell/whole-line-or-region
  :hook (elpaca-after-init . whole-line-or-region-global-mode)
  :diminish whole-line-or-region-local-mode
  :ensure t)

;; Path action tool configuration
(use-package pathaction  ;; https://www.jamescherti.com/pathaction-el-emacs-package-universal-makefile/
  :config
  (add-to-list 'display-buffer-alist '("\\*pathaction:"
                                       (display-buffer-at-bottom)
                                       (window-height . 0.33)))
  :ensure t)

;; Smooth pixel-precise scrolling.
;;
;; ultra-scroll supports all Emacs builds including emacs-mac (where the
;; built-in pixel-scroll-precision-mode does not work).  It activates
;; pixel-scroll-precision-mode internally and remaps its scroll function with
;; a faster, fully re-implemented algorithm.
;;
;; scroll-conservatively: prevent Emacs from recentering point mid-scroll,
;; which is the primary cause of visible jank.
;; scroll-margin: must be 0 to prevent jitter near buffer edges when using
;; pixel-level vscroll.
(setq scroll-conservatively 101
      scroll-margin 0)

(use-package ultra-scroll  ;; https://github.com/jdtsmith/ultra-scroll
  :config
  (ultra-scroll-mode 1)
  :ensure t)

;; Quick Look-style preview: SPC shows the item at point in another window
;; and keeps focus in the listing.
;; http://yummymelon.com/devnull/binding-the-spc-key-in-dired-and-ibuffer.html
(use-package dired
  :bind (:map dired-mode-map
              ("SPC" . dired-display-file))
  :ensure nil)

(use-package ibuffer
  :bind (:map ibuffer-mode-map
              ("SPC" . ibuffer-visit-buffer-other-window-noselect))
  :ensure nil)

;;;; core-org
;;;; --------

;; I use org to manage my thoughts and actions.
(use-package org  ;; https://orgmode.org
  :hook
  (org-mode . visual-line-mode)
  (org-mode . myde-delete-trailing-whitespace-setup)
  (org-mode . myde-org-mode-disable-flycheck)
  (org-mode . myde-org-font-lock-whole-blocks)
  :bind (("C-c o p" . myde-org-visit-project-tasks)
         ("C-c o P" . myde-org-create-project-tasks)
         ("C-c o t" . myde-org-tag-cloud)
         ("C-c o T" . myde-org-search-tags))
  :custom
  (org-directory myde-org-directory)
  (org-return-follows-link t)
  (org-todo-keywords
   '((sequence "TODO(t)" "NEXT(n)" "WAIT(w@/!)"
               "|" "DONE(d!)" "CANCELLED(c@)")))
  (org-archive-location
   (concat myde-org-archive-directory "%s_archive::"))
  (org-id-locations-file
   (expand-file-name "emacs/org-id-locations" (xdg-state-home)))
  (org-id-link-to-org-use-id 'create-if-interactive)
  :config
  (myde-org-ensure-tree)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

;; emacs-lisp is already the default value of `org-babel-load-languages',
;; so registering it again would only duplicate the alist entry.
(use-package org
  :defer t
  :custom
  (org-confirm-babel-evaluate nil)
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
  :custom
  (flycheck-global-modes '(not org-mode org-agenda-mode))
  :config
  (add-to-list 'flycheck-disabled-checkers 'org-lint)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Capture
;; -----------------------------------------------------------------------------

(use-package org-capture
  :after org
  :bind (("C-c o c" . org-capture))
  :custom
  (org-capture-templates
   `(("t" "Task" entry
      (file+headline ,myde-org-inbox-file "Inbox")
      ,(string-join
        '("* TODO %?"
          "  :PROPERTIES:"
          "  :CREATED: %U"
          "  :END:"
          "  %a")
        "\n")
      :empty-lines 1)

     ;; The file target is a bare symbol on purpose: org calls a capture
     ;; target file given as a function.  Do not comma-splice it.
     ("T" "Task in current project" entry
      (file+headline myde-org-capture-target "Tasks")
      ,(string-join
        '("* TODO %?"
          "  :PROPERTIES:"
          "  :CREATED: %U"
          "  :END:"
          "  %a")
        "\n")
      :empty-lines 1)

     ("h" "Thought" entry
      (file+headline ,myde-org-inbox-file "Inbox")
      ,(string-join
        '("* %^{Thought} %^G"
          "  :PROPERTIES:"
          "  :CREATED: %U"
          "  :END:"
          "  %?")
        "\n")
      :empty-lines 1)

     ;; %^G directly abuts :bookmark: with no space: org's %^G handler
     ;; omits its leading colon when the preceding char is already a
     ;; colon, giving one well-formed group `:bookmark:foo:bar:'.
     ("b" "Bookmark, tagged (org-protocol)" entry
      (file+headline ,myde-org-inbox-file "Inbox")
      ,(string-join
        '("* [[%:link][%:description]]   :bookmark:%^G"
          "  :PROPERTIES:"
          "  :CREATED: %U"
          "  :END:"
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
  :bind (("C-c o a" . org-agenda))
  :custom
  ;; Discovered rather than declared: project tasks files live inside the
  ;; project directories, so there is no single directory for org to expand.
  ;; The advice below rescans before each agenda build.
  (org-agenda-files (myde-org-agenda-files))
  ;; Belt and braces.  `myde-org-ensure-tree' creates the inbox and discovery
  ;; only returns files that exist, but a tasks.org removed between the scan
  ;; and the agenda build would otherwise trigger org's blocking
  ;; [R]emove/[A]bort prompt -- invisible under dashboard's `inhibit-redisplay'.
  (org-agenda-skip-unavailable-files t)
  (org-agenda-custom-commands
   `(("d" "Day"
      ((agenda "" ((org-agenda-span 1)
                   (org-deadline-warning-days 14)))
       (todo "NEXT" ((org-agenda-overriding-header "Next actions")))
       (todo "TODO|NEXT"
             ((org-agenda-files (list ,myde-org-inbox-file))
              (org-agenda-overriding-header "Inbox — needs refiling")))))))
  (org-refile-targets '((org-agenda-files :maxlevel . 3)))
  (org-refile-use-outline-path 'file)
  (org-outline-path-complete-in-steps nil)
  :config
  ;; Rescan before every agenda build so a tasks.org created by hand is
  ;; picked up without a restart.  The pruned scan is sub-millisecond.
  (advice-add 'org-agenda :before #'myde-org-refresh-agenda-files)
  :ensure nil)

;;;; core-help
;;;; ---------



(use-package eldoc
  :custom
  (eldoc-idle-delay most-positive-fixnum)  ;; Disable automatic echo-area display; docs are shown on demand with C-c e h.
  :ensure nil)

;; Stop `C-h o' and the plain describe-* commands loading libraries just to
;; complete a name or render a docstring.  helpful's `C-h f' and `C-h v'
;; complete over obarray and never read these.
(use-package help-fns
  :defer t
  :custom
  (help-enable-autoload nil)
  (help-enable-completion-autoload nil)
  :ensure nil)

(use-package eldoc-box  ;; https://github.com/casouri/eldoc-box
  :bind (("C-c e h" . eldoc-box-help-at-point)
         ("C-c e q" . eldoc-box-quit-frame))
  :ensure t)

(use-package helpful  ;; https://github.com/Wilfred/helpful
  :bind
  (("C-c C-d" . helpful-at-point)
   ("C-h f" . helpful-callable)
   ("C-h F" . helpful-function)
   ("C-h k" . helpful-key)
   ("C-h v" . helpful-variable))
  :ensure t)

(use-package which-key
  :custom
  (which-key-max-display-columns 1)
  (which-key-max-description-length nil)
  (which-key-show-docstrings t)
  (which-key-side-window-max-height 0.35)
  :config
  ;; ponytail: advises a private which-key function; recheck the
  ;; `which-key--pad-column' signature when Emacs is upgraded.
  (advice-add 'which-key--pad-column :filter-args #'myde-help-which-key-align-docstrings)
  :hook (elpaca-after-init . which-key-mode)
  :diminish which-key-mode
  :ensure nil)

;;;; core-terminals
;;;; --------------


(use-package emacs
  :hook ((vterm-mode term-mode eshell-mode comint-mode eat-mode)
         . myde-terminal-disable-hl-line)
  :config
  (set-terminal-coding-system 'utf-8-unix)
  :ensure nil)

(use-package eat  ;; https://codeberg.org/akib/emacs-eat
  :commands
  (eat)
  :custom
  ;; eat's eat-256color and eat-truecolor entries carry `pairs#65536', so tic
  ;; compiles them in the extended 32-bit number format that ncurses before
  ;; 6.1 cannot read.  Apple ships 6.0, so on macOS the default
  ;; `eat-term-get-suitable-term-name' picks an entry `tput' inside eat calls
  ;; \"unknown terminal\".  Linux here is current Fedora, whose ncurses reads
  ;; them, so it keeps eat's own name and its truecolor.
  (eat-term-name (if (string= system-type "darwin")
                     "xterm-256color"
                   #'eat-term-get-suitable-term-name))
  :ensure t)

(use-package ghostel ;; https://github.com/dakra/ghostel
  :custom
  ;; Keep the native module outside elpaca's tree, as the defcustom advises:
  ;; a rebuild of the package would otherwise delete a module Emacs has loaded.
  (ghostel-module-directory (expand-file-name "emacs/ghostel/" (xdg-data-home)))
  :ensure t)

;; Enabling the mode at startup loads consult (~30 ms) rather than on first use,
;; so the `g' narrow key is in `consult-buffer' from the first call.
(use-package consult-ghostel ;; https://github.com/dakra/ghostel
  :hook (elpaca-after-init . consult-ghostel-mode)
  :bind (("C-x m" . consult-ghostel)
         :map project-prefix-map
         ("m" . consult-ghostel-project)
         :map ghostel-semi-char-mode-map
         ("C-c h" . consult-ghostel-history))
  :ensure t)

(use-package vterm ;; https://github.com/akermu/emacs-libvterm
  :commands
  (vterm)
  :ensure t)

(use-package eshell
  :init
  (setq eshell-directory-name
        (expand-file-name "emacs/eshell/" (xdg-state-home)))
  :ensure nil)

(use-package project
  :bind (:map project-prefix-map
              ("t" . myde/project-vterm))
  :ensure nil)

;;;; core-dashboard
;;;; --------------


;; On demand only, via `M-x dashboard-open'.  It is not a startup screen here:
;; `initial-buffer-choice' cannot be relied on under elpaca, which swaps in its
;; own value in `elpaca-log-initial-queues' whenever an order is unbuilt or
;; failed and restores what it captured -- nil, when it captured before this
;; :config ran -- on `elpaca-after-init-hook'.  Installing it also made
;; `command-line-1' draw the dashboard in the frameless daemon at startup, and
;; made every `emacsclient -c' frame pay for a render.
(use-package dashboard  ;; https://github.com/emacs-dashboard/emacs-dashboard
  :defer t
  :custom
  (dashboard-startup-banner (cons myde-banner-image-file myde-banner-text-file))
  (dashboard-banner-logo-title "Welcome to MyDE -- *MY* Development Environment!")
  (dashboard-display-icons-p t)
  (dashboard-icon-type 'nerd-icons)
  (dashboard-set-heading-icons t)
  (dashboard-set-file-icons t)
  (dashboard-projects-backend 'project-el)
  (dashboard-items '((recents   . 5)
                     (projects  . 5)
                     (bookmarks . 5)
                     (agenda    . 5)))
  ;; Keep the agenda buffers alive.  Releasing them makes each `dashboard-open'
  ;; re-visit and re-parse every agenda file: 0.44 s instead of 0.05 s once they
  ;; are warm.
  (dashboard-agenda-release-buffers nil)
  :ensure t)

;;;; core-complete
;;;; -------------



;; -----------------------------------------------------------------------------
;; Minibuffer completion
;; -----------------------------------------------------------------------------

(use-package vertico  ;; https://github.com/minad/vertico
  :hook (elpaca-after-init . vertico-mode)
  :ensure t)

(use-package orderless  ;; https://github.com/oantolin/orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-pcm-leading-wildcard t)
  (completion-category-overrides '((file (styles . (partial-completion)))))
  :ensure t)

(use-package marginalia  ;; https://github.com/minad/marginalia
  :hook (elpaca-after-init . marginalia-mode)
  :ensure t)

(use-package consult  ;; https://github.com/minad/consult
  :bind (("C-s"     . consult-line)
         ("C-x b"   . consult-buffer)
         ("M-y"     . consult-yank-pop))
  :ensure t)

(use-package embark  ;; https://github.com/oantolin/embark
  :bind (("C-."   . embark-act)
         ("C-h B" . embark-bindings))
  :init
  (setq prefix-help-command #'embark-prefix-help-command)
  :ensure t)

(use-package embark-consult
  :hook (embark-collect-mode . consult-preview-at-point-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; In-buffer completion
;; -----------------------------------------------------------------------------

(use-package corfu  ;; https://github.com/minad/corfu
  :hook (elpaca-after-init . global-corfu-mode)
  :custom
  (corfu-auto t)          ;; show popup automatically as you type
  (corfu-auto-delay 0.2)  ;; seconds before popup appears
  (corfu-auto-prefix 2)   ;; minimum prefix length to trigger auto-completion
  (tab-always-indent 'complete)  ;; TAB indents; if already indented, completes
  :config
  (corfu-popupinfo-mode)
  :diminish corfu-mode
  :ensure t)

(use-package nerd-icons-corfu  ;; https://github.com/LuigiPiucco/nerd-icons-corfu
  :after corfu
  :config
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)
  :ensure t)

;;;; core-notes
;;;; ----------


;; -----------------------------------------------------------------------------
;; Denote note-taking
;; -----------------------------------------------------------------------------

(use-package denote  ;; https://protesilaos.com/emacs/denote
  :bind
  (("C-c o n n" . denote)
   ("C-c o n l" . denote-link)
   ("C-c o n b" . denote-backlinks)
   ("C-c o n f" . denote-open-or-create)
   ;; `denote-grep', not `denote-search'.  The standalone denote-search
   ;; package was absorbed into core denote, which renamed the command.
   ;; `:bind' generates an autoload for whatever command it names, so the
   ;; stale name looked bound but failed on use: "Autoloading file
   ;; denote.elc failed to define function denote-search".
   ("C-c o n s" . denote-grep))
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
;;
;; `:after' must NOT include denote.  Every denote entry point is an
;; autoload, so denote never loads on its own — gating on it meant `n' and
;; `N' were absent from `C-c o c' until the user happened to run a denote
;; command first.  Gating on org alone is correct and sufficient: a capture
;; template is inert data, and `denote-org-capture' is autoloaded, so
;; selecting `n' loads denote on demand.  `org-capture' itself requires org,
;; so this `:config' runs before the template menu is built.

(use-package org-capture
  :after org
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

;;;; core-snippets
;;;; -------------


(use-package yasnippet  ;; https://github.com/joaotavora/yasnippet
  :hook (elpaca-after-init . yas-global-mode)
  ;; Do not bind TAB globally for snippet expansion -- it conflicts with
  ;; comint/REPL completion (e.g. inf-elixir).  Snippets can still be
  ;; expanded via `yas-insert-snippet' or the `yas-minor-mode-map' binding.
  :bind (:map yas-minor-mode-map
              ("TAB" . nil)
              ([tab] . nil))
  :diminish yas-minor-mode
  :ensure t)

(use-package yasnippet-classic-snippets  ;; https://elpa.gnu.org/packages/yasnippet-classic-snippets.html
  :after yasnippet
  :ensure t)

;;;; core-projects
;;;; -------------


;; -----------------------------------------------------------------------------
;; Project management
;; -----------------------------------------------------------------------------

;; Built-in project management
(use-package project
  :bind-keymap (("C-c p" . project-prefix-map)
                ("s-p" . project-prefix-map))
  :custom
  (project-list-file
   (expand-file-name "emacs/projects.eld" (xdg-state-home)))
  :config
  (when (file-directory-p (expand-file-name "~/Projects/"))
    (project-remember-projects-under "~/Projects/" t))
  :ensure nil)

;; EditorConfig support for project-wide formatting rules
(use-package editorconfig
  :hook (elpaca-after-init . editorconfig-mode)
  :diminish editorconfig-mode
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Project tree explorer
;; -----------------------------------------------------------------------------

(use-package neotree  ;; https://github.com/jaypei/emacs-neotree
  :after nerd-icons
  :bind ([f8] . myde-neotree-project-root-toggle)
  :commands (neotree-toggle)
  :hook (after-save . myde-neotree-refresh)
  :custom
  (neo-window-fixed-size nil)
  (neo-show-hidden-files t)
  :config
  ;; Stays in :config: this runs when neotree loads from a client frame,
  ;; where `display-graphic-p' is meaningful.  As a :custom value it would
  ;; be evaluated during the frameless daemon's init and always pick arrow.
  (setq neo-theme (if (display-graphic-p) 'nerd-icons 'arrow))
  ;; An abnormal hook: `:hook' would append -hook to the name.
  (add-to-list 'window-size-change-functions #'myde-neotree-window-size-change-function)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Tree-sitter setup
;; -----------------------------------------------------------------------------
;; `treesit-extra-load-path' is set once, in core-base.  Language grammar
;; sources are registered by each language module.

(use-package treesit-auto  ;; https://github.com/renzmann/treesit-auto
  :hook (elpaca-after-init . myde-treesit-auto-setup)
  :custom
  (treesit-auto-install t) ; install grammars automatically, if missing
  :diminish treesit-auto-mode
  :ensure t)

;; -----------------------------------------------------------------------------
;; LSP support
;; -----------------------------------------------------------------------------

(use-package eglot
  ;; Hooks, server programs, and workspace config are registered by each
  ;; language module in myde-.  Only shared keybindings and performance
  ;; settings live here.
  :bind (:map eglot-mode-map
              ("C-c e a" . eglot-code-actions)
              ("C-c e r" . eglot-rename)
              ("C-c e f" . eglot-format)
              ("C-c e i" . eglot-find-implementation)
              ("C-c e t" . eglot-find-typeDefinition))
  :custom
  ;; Performance optimizations
  (eglot-autoshutdown t)
  (eglot-sync-connect 0)                                ;; non-blocking LSP connect
  (eglot-report-progress nil)                           ;; no progress messages
  (eglot-events-buffer-config '(:size 0 :format short)) ;; no event logging
  :config
  (setq jsonrpc-event-hook nil)  ;; no per-message hooks.  A defvar, so not :custom.
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Problems reporting support
;; -----------------------------------------------------------------------------

;; Flycheck (on-the-fly syntax checking).  Its C-c ! map would shadow the global
;; C-c ! keys below in every flycheck buffer, eglot buffers included, so its
;; n/p/l run the same dispatching commands.
(use-package flycheck  ;; https://github.com/flycheck/flycheck
  :hook (elpaca-after-init . global-flycheck-mode)
  :bind (:map flycheck-command-map
              ("n" . myde-diagnostics-next)
              ("p" . myde-diagnostics-prev)
              ("l" . myde-diagnostics-list))
  :custom
  (flycheck-check-syntax-automatically '(save mode-enabled))
  :diminish (flycheck-mode . " ✓")
  :ensure t)

;; flymake is used by eglot for LSP diagnostics.  C-c ! n/p/l dispatch to
;; flymake where it runs, as in eglot buffers, and to flycheck elsewhere.
(use-package flymake
  :bind (("C-c ! n" . myde-diagnostics-next)
         ("C-c ! p" . myde-diagnostics-prev)
         ("C-c ! l" . myde-diagnostics-list))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Project specific environment configuration files
;; -----------------------------------------------------------------------------

;; (use-package direnv  ;; https://github.com/wbolster/emacs-direnv
;;   :config
;;   (direnv-mode)
;;   :ensure t )

;; -----------------------------------------------------------------------------
;; Tools support
;; -----------------------------------------------------------------------------

(use-package mason  ;; https://github.com/mason-org/mason.el
  :custom
  (mason-dir (expand-file-name "emacs/mason" (xdg-data-home)))
  :ensure t)

(use-package mise  ;; https://github.com/eki3z/mise.el
  :hook (elpaca-after-init . global-mise-mode)
  :diminish mise-mode
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugger support
;; -----------------------------------------------------------------------------

(use-package dap-mode  ;; https://github.com/emacs-lsp/dap-mode
  :after (transient eglot)
  :custom
  (dap-breakpoints-file (expand-file-name "emacs/.dap-breakpoints" (xdg-state-home)))
  :config
  (dap-auto-configure-mode)  ;; Language-specific DAP adapters are loaded by each language module in myde-prog-*/ module dirs.
  :ensure t)

(use-package dape  ;; https://github.com/svaante/dape
  ;; Lightweight DAP client; debug configs are registered by each language
  ;; module in myde-.  Only shared keybindings and layout settings live here.
  :after transient
  :custom
  (dape-buffer-window-arrangement 'right)
  :bind (("C-c d d" . dape)
         ("C-c d l" . dape-restart)   ; restart, or re-run the last config
         ("C-c d b" . dape-breakpoint-toggle)
         ("C-c d n" . dape-next)
         ("C-c d s" . dape-step-in)
         ("C-c d o" . dape-step-out)
         ("C-c d c" . dape-continue)
         ("C-c d q" . dape-quit))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Git version control setup (C-c g prefix)
;; -----------------------------------------------------------------------------

(use-package magit  ;; https://github.com/magit/magit
  :after transient
  :commands (magit-status)
  :ensure t)

(use-package forge  ;; https://github.com/magit/forge
  :after (transient magit)
  :custom
  (forge-database-file
   (expand-file-name "emacs/forge-database.sqlite" (xdg-data-home)))
  :ensure t)

(use-package git-modes  ;; https://github.com/magit/git-modes
  :ensure t)

;; Histogram diffs give cleaner hunks.  diff-hl passes this switch through to
;; its own gutter diffs.
(use-package vc-git
  :defer t
  :custom
  (vc-git-diff-switches '("--histogram"))
  :ensure nil)

(use-package diff-hl  ;; https://github.com/dgutov/diff-hl
  :hook ((elpaca-after-init . global-diff-hl-mode)
         (magit-pre-refresh . diff-hl-magit-pre-refresh)
         (magit-post-refresh . diff-hl-magit-post-refresh))
  :ensure t)

(use-package blamer
  :bind (("C-c g b" . blamer-mode))
  :custom
  (blamer-idle-time 0.05)
  (blamer-author-formatter "%s ")
  (blamer-datetime-formatter "[%s]")
  (blamer-commit-formatter ": %s")
  (blamer-max-commit-message-length 100)
  (blamer-min-offset 70)
  :ensure t)

;;;; core-spell
;;;; ----------


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

;;;; ai-gptel
;;;; --------


;; -----------------------------------------------------------------------------
;; GPtel main package
;; -----------------------------------------------------------------------------

(use-package gptel  ;; https://github.com/karthink/gptel
  :after transient
  :config
  (gptel-make-openai "OpenRouter"
    :host "openrouter.ai"
    :endpoint "/api/v1/chat/completions"
    :stream t
    :key (auth-source-pick-first-password :host "OPENROUTER_API_KEY")
    :models myde-openrouter-models)
  (setq gptel-model 'moonshotai/kimi-k2.6
        gptel-backend (gptel-get-backend "OpenRouter"))
  :ensure t)

;; -----------------------------------------------------------------------------
;; GPtel forge integration
;; -----------------------------------------------------------------------------

(use-package gptel-forge-prs  ;; https://github.com/ArthurHeymans/gptel-forge-prs
  :after forge
  :config
  (gptel-forge-prs-install)
  :ensure t)

;; -----------------------------------------------------------------------------
;; GPtel magit integration
;; -----------------------------------------------------------------------------

(use-package gptel-magit  ;; https://github.com/ragnard/gptel-magit
  :after (magit markdown-mode)
  :hook (magit-mode . gptel-magit-install)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Minuet AI completions
;; -----------------------------------------------------------------------------

(use-package minuet  ;; https://github.com/milanglacier/minuet-ai.el
  :after gptel
  ;; :init
  ;; ;; if you want to enable auto suggestion.
  ;; ;; Note that you can manually invoke completions without enable minuet-auto-suggestion-mode
  ;; (add-hook 'prog-mode-hook #'minuet-auto-suggestion-mode)
  :custom
  (minuet-provider 'codestral)  ;; Use Codestral FIM completions via the Mistral API.
  :config
  (plist-put minuet-codestral-options :api-key (auth-source-pick-first-password :host "MISTRAL_API_KEY"))
  (plist-put minuet-codestral-options :end-point "https://api.mistral.ai/v1/fim/completions")
  (plist-put minuet-codestral-options :model "codestral-latest")
  (minuet-set-optional-options minuet-codestral-options :max_tokens 128)
  (minuet-set-optional-options minuet-codestral-options :stop ["\n\n"])
  :bind
  (("M-y" . #'minuet-complete-with-minibuffer) ;; use minibuffer for completion
   ("M-i" . #'minuet-show-suggestion) ;; use overlay for completion
   ("C-c m" . #'minuet-configure-provider)
   :map minuet-active-mode-map
   ;; These keymaps activate only when a minuet suggestion is displayed in the current buffer
   ("M-p" . #'minuet-previous-suggestion) ;; invoke completion or cycle to next completion
   ("M-n" . #'minuet-next-suggestion) ;; invoke completion or cycle to previous completion
   ("M-A" . #'minuet-accept-suggestion) ;; accept whole completion
   ;; Accept the first line of completion, or N lines with a numeric-prefix:
   ;; e.g. C-u 2 M-a will accepts 2 lines of completion.
   ("M-a" . #'minuet-accept-suggestion-line)
   ("M-e" . #'minuet-dismiss-suggestion))
  :ensure t)

;;;; ai-agents
;;;; ---------



;; -----------------------------------------------------------------------------
;; AI completion provider
;; -----------------------------------------------------------------------------

(use-package acp  ;; https://github.com/xenodium/acp.el
  :after transient
  :ensure t)

;; -----------------------------------------------------------------------------
;; AI shell agent
;; -----------------------------------------------------------------------------

(use-package agent-shell  ;; https://github.com/xenodium/agent-shell
  :after transient
  :ensure t)

;;;; ai-claude
;;;; ---------
;; Gate: claude

(when (executable-find "claude")




;; -----------------------------------------------------------------------------
;; Claude code IDE integration
;; -----------------------------------------------------------------------------

(use-package claude-code-ide  ;; https://github.com/manzaltu/claude-code-ide.el
  :bind
  ("C-c C" . claude-code-ide-menu)
  :config
  (claude-code-ide-emacs-tools-setup)
  :ensure (:host github :repo "manzaltu/claude-code-ide.el"))

  )

;;;; ai-mcp
;;;; --------


;; -----------------------------------------------------------------------------
;; Emacs MCP server
;; -----------------------------------------------------------------------------

(use-package mcp-server  ;; https://github.com/rhblind/emacs-mcp-server
  :demand t
  :custom
  ;; `error' keeps the socket path fixed at emacs-mcp-server.sock, which the
  ;; socat bridge registered with `claude mcp add' hardcodes. A socket left by a
  ;; dead daemon has no listener, so mcp-server reclaims it as stale before the
  ;; conflict setting is consulted. The setting only matters when a live Emacs
  ;; holds the path -- Emacs.app launched by mistake, or the probe, which shares
  ;; $XDG_CACHE_HOME. `force' made that Emacs unlink the daemon's socket, leaving
  ;; the daemon listening on a path no client could reach; `warn' strands a
  ;; stray emacs-mcp-server-N.sock. `error' leaves the owner's socket alone.
  (mcp-server-socket-directory (expand-file-name "emacs/" (xdg-cache-home)))
  (mcp-server-socket-name nil)
  (mcp-server-socket-conflict-resolution 'error)
  :hook (elpaca-after-init . myde/mcp-server-startup-hook)
  ;; The tool modules live in tools/, which mcp-server-emacs-tools.el resolves
  ;; relative to itself, so elpaca's default :files would leave them behind.
  ;; ("tools" "tools/*.el") links each file into a real tools/ directory.  A
  ;; bare "tools" links the directory itself, which byte-recompile-directory
  ;; skips as a symlink, so the tools loaded as source and warned on every start.
  :ensure (:host github :repo "rhblind/emacs-mcp-server"
                 :files (:defaults ("tools" "tools/*.el"))))

;;;; auth-1password
;;;; --------------
;; Gate: op

(when (executable-find "op")


;; -----------------------------------------------------------------------------
;; 1Password authentication
;; -----------------------------------------------------------------------------

(use-package auth-source-1password  ;; https://github.com/dlobraico/auth-source-1password
  :custom
  (auth-source-1password-vault "My API credentials")
  (auth-source-1password-construct-secret-reference
   #'myde-auth-source-1password-construct-secret-reference)
  :config
  (auth-source-1password-enable)
  :ensure t)

  )

;;;; data-csv
;;;; --------



(use-package csv-mode  ;; https://elpa.gnu.org/packages/csv-mode.html
  :mode (("\\.csv\\'" . csv-mode)
         ("\\.tsv\\'" . csv-mode))
  :ensure t)

(use-package indent-bars
  :hook (csv-mode . indent-bars-mode)
  :ensure nil)

;;;; data-dotenv
;;;; -----------



;; dotenv editing support
(use-package dotenv-mode  ;; https://github.com/preetpalS/emacs-dotenv-mode
  :mode
  (("\\.env\\'" . dotenv-mode)
   ("\\.envrc\\'" . dotenv-mode)
   ("\\.env\\.[^/]*\\'" . dotenv-mode))
  :ensure t)

;;;; data-hcl
;;;; --------


;; HCL editing for .tf, .tfvars, .hcl, and .tofu files
(use-package terraform-mode  ;; https://github.com/hcl-emacs/terraform-mode
  :mode ("\\.tf\\'" "\\.tfvars\\'" "\\.hcl\\'" "\\.tofu\\'")
  :hook ((terraform-mode . terraform-format-on-save-mode))
  :config
  (myde-treesit-remap-hcl)
  :ensure t)

(use-package indent-bars
  :hook (terraform-mode . indent-bars-mode)
  :ensure nil)

;;;; data-json
;;;; ---------


;; Built-in tree-sitter JSON mode; jsonl-mode is a derived mode defined in lib.el
(use-package json-ts-mode  ;; built-in (Emacs 29+)
  :mode (("\\.json\\'" . json-ts-mode)
         ("\\.jsonl\\'" . jsonl-mode))
  :hook (json-ts-mode . myde-json-ts-mode-hook)
  :ensure nil)

;; Register vscode-json-language-server for JSON buffers
(use-package eglot
  :after json-ts-mode
  :config
  (add-to-list 'eglot-server-programs
               '(json-ts-mode . ("vscode-json-language-server" "--stdio")))
  :ensure nil)

;; jq query file editing
(use-package jq-mode  ;; https://github.com/ljos/jq-mode
  :mode "\\.jq\\'"
  :ensure t)

(use-package indent-bars
  :hook (json-ts-mode . indent-bars-mode)
  :ensure nil)

;;;; data-pkl
;;;; --------


;; Pkl editing support
(use-package pkl-mode  ;; https://github.com/sin-ack/pkl-mode
  :hook
  ((pkl-mode . myde-data-pkl-mode-setup)
   (pkl-mode . myde-delete-trailing-whitespace-setup))
  :mode
  (("\\.pkl\\'" . pkl-mode))
  :ensure t)

(use-package indent-bars
  :hook (pkl-mode . indent-bars-mode)
  :ensure nil)

;;;; data-toml
;;;; ---------


;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(toml "https://github.com/tree-sitter-grammars/tree-sitter-toml"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + taplo
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((toml-ts-mode . eglot-ensure)
         (toml-mode    . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '(toml-ts-mode . ("taplo" "lsp" "stdio")))
  (add-to-list 'eglot-server-programs
               '(toml-mode . ("taplo" "lsp" "stdio")))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; TOML mode
;; -----------------------------------------------------------------------------

(use-package toml-mode  ;; https://github.com/dryman/toml-mode.el
  :config
  :hook
  ((toml-ts-mode . myde-toml-ts-mode-setup)
   (toml-ts-mode . myde-delete-trailing-whitespace-setup))
  :mode
  (("\\.toml\\'" . myde-toml-ts-or-plain-mode)
   ("Cargo\\.lock\\'" . myde-toml-ts-or-plain-mode))
  :ensure t)

(use-package indent-bars
  :hook ((toml-ts-mode toml-mode) . indent-bars-mode)
  :ensure nil)

;;;; data-xml
;;;; --------


;; -----------------------------------------------------------------------------
;; nxml-mode — built-in.  Emacs 31 ships no xml-ts-mode, so there is no
;; tree-sitter mode for XML to prefer over it.
;; -----------------------------------------------------------------------------

(use-package nxml-mode  ;; built-in
  :mode (("\\.xml\\'"   . nxml-mode)
         ("\\.xsd\\'"   . nxml-mode)
         ("\\.xsl\\'"   . nxml-mode)
         ("\\.xslt\\'"  . nxml-mode)
         ("\\.svg\\'"   . nxml-mode)
         ("\\.xhtml\\'" . nxml-mode))
  :hook (nxml-mode . myde-nxml-mode-hook)
  :custom
  (nxml-slash-auto-complete-flag t)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + lemminx
;; -----------------------------------------------------------------------------

(use-package eglot
  :after nxml-mode
  :config
  (add-to-list 'eglot-server-programs
               `(nxml-mode . (,(expand-file-name "~/.local/bin/lemminx"))))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; XML formatting via xmllint
;; -----------------------------------------------------------------------------

(use-package xml-format  ;; https://github.com/wbolster/emacs-xml-format
  :hook (nxml-mode . myde-xml-format-on-save-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; emmet-mode — rapid markup expansion via C-j
;; -----------------------------------------------------------------------------

(use-package emmet-mode  ;; https://github.com/smihica/emmet-mode
  :hook (nxml-mode . emmet-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; xquery-tool — XQuery file authoring
;; -----------------------------------------------------------------------------

(use-package xquery-tool  ;; https://github.com/paddymcall/xquery-tool.el
  :mode (("\\.xq\\'"     . nxml-mode)
         ("\\.xquery\\'" . nxml-mode))
  :ensure t)

(use-package indent-bars
  :hook (nxml-mode . indent-bars-mode)
  :ensure nil)

;;;; data-yaml
;;;; ---------



;; YAML editing support
(use-package yaml-mode  ;; https://github.com/yoshiki/yaml-mode
  :mode
  (("\\.yaml\\'" . yaml-mode)
   ("\\.yml\\'" . yaml-mode))
  :ensure t)

(use-package indent-bars
  :hook (yaml-mode . indent-bars-mode)
  :ensure nil)

;;;; containers-kubernetes
;;;; ---------------------
;; Gate: kubectl

(when (executable-find "kubectl")




(use-package kubed  ;; https://github.com/eshelyaron/kubed
  :bind-keymap
  ("C-c k" . kubed-prefix-map)
  :ensure t)

  )

;;;; prog-base
;;;; ---------


;; Configure display of line numbers and current line highlighting
(use-package prog-mode
  :hook ((prog-mode . myde-prog-mode-hook-function)
         (prog-mode . myde-delete-trailing-whitespace-setup))
  :ensure nil)

;; Consistent multi-language formatter foundation.
;; Individual language modules register their formatter via apheleia-mode-alist.
(use-package apheleia
  :config
  (apheleia-global-mode +1)
  :diminish apheleia-mode
  :ensure t)

;; Structural S-expression editing for Lisp-family languages
(use-package paredit
  :hook ((emacs-lisp-mode . enable-paredit-mode)
         (lisp-mode . enable-paredit-mode)
         (scheme-mode . enable-paredit-mode)
         (clojure-mode . enable-paredit-mode)
         (clojure-ts-mode . enable-paredit-mode)
         (cider-repl-mode . enable-paredit-mode)
         (sly-mode . enable-paredit-mode)
         (slime-repl-mode . enable-paredit-mode))
  :diminish paredit-mode
  ;; The MELPA recipe clones paredit.org, which no longer resolves in DNS.
  :ensure (:host github :repo "emacsmirror/paredit"))

;; Colorize nested parentheses for readability in Lisp-family languages
(use-package rainbow-delimiters
  :hook ((emacs-lisp-mode . rainbow-delimiters-mode)
         (lisp-mode . rainbow-delimiters-mode)
         (scheme-mode . rainbow-delimiters-mode)
         (clojure-mode . rainbow-delimiters-mode)
         (clojure-ts-mode . rainbow-delimiters-mode)
         (cider-repl-mode . rainbow-delimiters-mode)
         (sly-mode . rainbow-delimiters-mode)
         (slime-repl-mode . rainbow-delimiters-mode))
  :diminish rainbow-delimiters-mode
  :ensure t)

;;;; prog-bash
;;;; ---------


;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(bash "https://github.com/tree-sitter/tree-sitter-bash"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + bash-language-server
;;
;; bash-language-server automatically:
;;   - calls shellcheck on each file change (500ms debounce) and surfaces
;;     SC* diagnostics and quick-fix code actions through LSP
;;   - calls shfmt on "format document" requests if shfmt is on PATH
;;
;; initializationOptions configure shellcheck behaviour and workspace scanning.
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook (bash-ts-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '((bash-ts-mode) . ("bash-language-server" "start")))
  (myde-eglot-add-workspace-config
   :bashIde '(:shellcheckEnabled t
              :shellcheckArguments []
              :shfmt (:ignoreEditorconfig nil
                      :simplifyCode nil
                      :binaryNextLine nil
                      :switchCaseIndent nil
                      :spaceRedirects nil)
              :includeAllWorkspaceSymbols nil
              :backgroundAnalysisMaxFiles 500))
  :bind (:map eglot-mode-map
              ("C-c e r" . eglot-rename)
              ("C-c e a" . eglot-code-actions)
              ("C-c e f" . eglot-format-buffer))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Bash major mode (built-in, Emacs 30+)
;;
;; bash-ts-mode uses the bash tree-sitter grammar and provides superior syntax
;; highlighting over the regex-based sh-mode, particularly for heredocs, process
;; substitutions, and complex parameter expansions.
;;
;; .bats files are BATS (Bash Automated Testing System) test scripts — they are
;; valid bash and parse correctly under bash-ts-mode.
;; -----------------------------------------------------------------------------

(use-package sh-script
  :hook ((bash-ts-mode . myde-bash-ts-mode-setup))
  :mode (("\\.sh\\'"   . bash-ts-mode)
         ("\\.bash\\'" . bash-ts-mode)
         ("\\.bats\\'" . bash-ts-mode))
  ;; Outranks Emacs' default entry, which sends bash shebangs to sh-mode.
  :interpreter ("bash" . bash-ts-mode)
  :bind (:map bash-ts-mode-map
              ("C-c i i" . myde-bash-open-shell)
              ("C-c i r" . myde-bash-send-region)
              ("C-c i b" . myde-bash-send-buffer)
              ("C-c i x" . myde-bash-run-buffer))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Formatting via apheleia + shfmt
;;
;; apheleia itself is configured in prog-base.  Here we register shfmt as the
;; formatter for bash-ts-mode buffers.  apheleia's shfmt entry reads sh-shell
;; and sh-basic-offset, so indentation follows the buffer-local settings set
;; by myde-bash-ts-mode-setup.
;; -----------------------------------------------------------------------------

(use-package apheleia
  :after apheleia
  :config
  (setf (alist-get 'bash-ts-mode apheleia-mode-alist) 'shfmt)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Debugging via dape + bash-debug
;;
;; Requires the bash-debug DAP adapter vsix (rogalmic/vscode-bash-debug).
;; One-time setup:
;;   mkdir -p $XDG_DATA_HOME/emacs/debug-adapters
;;   unzip bash-debug-*.vsix -d $XDG_DATA_HOME/emacs/debug-adapters/bash-debug
;; -----------------------------------------------------------------------------

(use-package dape
  :after dape
  :config
  (add-to-list 'dape-configs
               `(bash-debug
                 modes (bash-ts-mode)
                 command "node"
                 command-args (,(expand-file-name
                                 "emacs/debug-adapters/bash-debug/extension/out/bashDebug.js"
                                 (xdg-data-home)))
                 :type "bashdb"
                 :request "launch"
                 :program dape-buffer-default
                 :pathBashdb "bashdb"
                 :pathBash "bash"
                 :pathCat "cat"
                 :pathMkfifo "mkfifo"
                 :pathPkill "pkill"
                 :showDebugOutput nil
                 :trace nil))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :defer t
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((shell . t))))
  :ensure nil)

(use-package indent-bars
  :hook (bash-ts-mode . indent-bars-mode)
  :ensure nil)

;;;; prog-fish
;;;; ---------
;; Gate: fish

(when (executable-find "fish")




(use-package fish-mode  ;; https://github.com/emacsmirror/fish-mode
  :custom
  (fish-indent-offset 2)
  :ensure t)

;; ob-shell supports fish as a shell variant via :shebang #!/usr/bin/env fish
(use-package org
  :defer t
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((shell . t))))
  :ensure nil)

(use-package indent-bars
  :hook (fish-mode . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-nushell
;;;; ------------
;; Gate: nu

(when (executable-find "nu")


;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;;
;; nushell/tree-sitter-nu is official and actively maintained (last push March 2026).
;; Unused now since no proper ts-mode exists on MELPA, but the grammar is
;; registered and ready for when nushell-ts-mode materialises.
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(nu "https://github.com/nushell/tree-sitter-nu"
                    "main" "src"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + nu --lsp
;;
;; nu --lsp is built into nushell >= 0.87.0.  No separate server install.
;; Provides: completions, hover (with manpages for external commands),
;; go-to-definition, diagnostics (parse errors/warnings), rename.
;; Does NOT (yet) expose code actions or formatting through LSP.
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook (nushell-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '((nushell-mode) . ("nu" "--lsp")))
  :bind (:map eglot-mode-map
              ("C-c e r" . eglot-rename)
              ("C-c e a" . eglot-code-actions)
              ("C-c e f" . eglot-format-buffer))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Nushell major mode
;;
;; nushell-mode (MELPA) is regex-based, actively maintained (Nov 2025).
;; nushell-ts-mode exists but is abandoned (Sept 2023) and not on MELPA,
;; so we use the MELPA version.
;; .nu files and #!/usr/bin/env nu shebangs both activate nushell-mode.
;; REPL keybindings use C-c i (C-c i, C-c i r, C-c i b, C-c i x).
;; -----------------------------------------------------------------------------

(use-package nushell-mode
  :hook (nushell-mode . myde-nushell-mode-setup)
  :mode (("\\.nu\\'" . nushell-mode))
  :bind (:map nushell-mode-map
              ("C-c i i" . myde-nushell-open-repl)
              ("C-c i r" . myde-nushell-send-region)
              ("C-c i b" . myde-nushell-send-buffer)
              ("C-c i x" . myde-nushell-run-buffer))
  :interpreter ("nu" . nushell-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Formatting via apheleia + nufmt (OPT-IN ONLY)
;;
;; DESIGN DECISION: nufmt is pre-alpha and can corrupt scripts.
;;
;; nushell/nufmt explicitly warns in its README:
;;   "Some of the outputs deletes comments, break the functionality of the
;;    script or doesn't format at all. Do not use in productive nushell scripts!"
;;
;; CONS of registering in apheleia-mode-alist (auto-format on save):
;;   - Silent data loss: formatter breaks code silently, without compiler error
;;   - User saves a file, formatter corrupts it, they don't notice until runtime
;;   - Breaks contrast with prod-ready formatters (shfmt, prettier) elsewhere
;;   - No escape hatch: disabling requires per-file variable or opt-out config
;;
;; CONS of the current opt-in approach:
;;   - Users must discover M-x apheleia-format-buffer manually
;;   - No "magical" auto-formatting experience
;;   - Requires per-project .dir-locals.el to enable
;;
;; VERDICT: Auto-corruption risk >> UX loss. Silent breakage is worse than
;; no automation. Opt-in is correct until nufmt stabilizes.
;;
;; Users can:
;;   1. Invoke M-x apheleia-format-buffer manually to test
;;   2. Enable per-project (if they accept the risk) via .dir-locals.el:
;;      ((nushell-mode . ((apheleia-mode . t))))
;; (This requires apheleia to be loaded; it's configured in prog-base.)
;; -----------------------------------------------------------------------------

(use-package apheleia
  :after apheleia
  :config
  ;; Register nufmt formatter (not auto-enabled)
  (add-to-list 'apheleia-formatters
               '(nufmt . ("nufmt" "--stdin")))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

;; Requires the nu tree-sitter grammar: M-x treesit-install-language-grammar RET nu
(use-package nushell-ts-babel  ;; https://github.com/herbertjones/nushell-ts-babel
  :after org
  :if (treesit-language-available-p 'nu)
  :ensure (:host github :repo "herbertjones/nushell-ts-babel"))

(use-package indent-bars
  :hook (nushell-mode . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-elisp
;;;; ----------


;; -----------------------------------------------------------------------------
;; Emacs Lisp mode setup
;; -----------------------------------------------------------------------------

(use-package emacs
  :hook ((emacs-lisp-mode . myde-emacs-lisp-mode-setup)
         (emacs-lisp-mode . flycheck-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Testing
;; -----------------------------------------------------------------------------

(use-package buttercup  ;; https://github.com/jorgenschaefer/emacs-buttercup
  :defer t
  :ensure t)

;; -----------------------------------------------------------------------------
;; Package development tools
;; -----------------------------------------------------------------------------

(use-package package-lint  ;; https://github.com/purcell/package-lint
  :defer t
  :ensure t)

(use-package cask-mode  ;; https://github.com/Wilfred/cask-mode
  :defer t
  :ensure t)

(use-package eask-mode  ;; https://github.com/emacs-eask/eask-mode
  :defer t
  :ensure t)

;; -----------------------------------------------------------------------------
;; Elisp utility libraries
;; -----------------------------------------------------------------------------

(use-package dash  ;; https://github.com/magnars/dash.el
  :defer t
  :ensure t)

(use-package s  ;; https://github.com/magnars/s.el
  :defer t
  :ensure t)

(use-package plz  ;; https://github.com/alphapapa/plz.el
  :defer t
  :ensure t)

(use-package indent-bars
  :hook (emacs-lisp-mode . indent-bars-mode)
  :ensure nil)

;;;; prog-clisp
;;;; ----------
;; Gate: sbcl

(when (executable-find "sbcl")


;; Tree-sitter grammar registration for Common Lisp
(use-package treesit
  :config
  ;; Register Common Lisp grammar for future tree-sitter-based major mode
  ;; Currently no stable commonlisp-ts-mode on MELPA, but grammar is available
  (when (treesit-available-p)
    (add-to-list 'treesit-language-source-alist
      '(commonlisp "https://github.com/tree-sitter-grammars/tree-sitter-commonlisp")))
  :ensure nil)

;; Project root detection for CL toolchains
(use-package project
  :config
  ;; Add Common Lisp-specific project markers
  (myde-prog-clisp-setup)
  :ensure nil)

;; Built-in Common Lisp major mode
(use-package lisp-mode
  :mode (("\\.lisp\\'" . lisp-mode)
         ("\\.cl\\'" . lisp-mode)
         ("\\.asd\\'" . lisp-mode))
  :hook (lisp-mode . myde-prog-clisp-lisp-mode-setup)
  :ensure nil)

;; SLY: Primary REPL for interactive Common Lisp development
;; Modern UX, stickers (live feedback), excellent debugger integration
(use-package sly
  :custom
  ;; SBCL by default; SLY auto-detects other implementations at runtime.
  (sly-default-lisp 'sbcl)
  ;; Enable multiple simultaneous REPLs
  (sly-mrepl-history-file-name nil)
  ;; SLY test runner keybindings (standard myde pattern)
  ;; Note: These are aspirational; SLY doesn't have built-in FiveAM test runner
  ;; Tests are run via: C-c i b (eval buffer), manual REPL, or asdf:test-system
  ;; Documented for future integration with SLY test framework enhancements
  :bind (:map sly-mode-map
              ("C-c t b" . sly-eval-buffer)
              ("C-c i i" . sly)
              ("C-c i r" . sly-eval-region)
              ("C-c i b" . sly-eval-buffer)
              ("C-c i e" . sly-eval-last-expression)
              ("C-c i d" . sly-documentation)
              ("C-c i z" . sly-mrepl))
  :ensure t)

;; SLIME: Fallback REPL for Common Lisp (larger ecosystem if SLY unavailable)
;; Battle-tested stability (20+ years), excellent debugging (SLDB)
;; No `(unless (featurep 'sly) ...)' guard: sly's autoloads turn on
;; `sly-editing-mode' in every lisp buffer, so sly is always loaded by the
;; time slime is, and the guard made this whole block dead.  slime only
;; loads on M-x slime, so both stay installed without stepping on each other.
(use-package slime
  :config
  (myde-prog-clisp-slime-init)
  ;; SLIME keybindings (same C-c i prefix for consistency)
  :bind (:map slime-mode-map
              ("C-c i i" . slime)
              ("C-c i r" . slime-eval-region)
              ("C-c i b" . slime-eval-buffer)
              ("C-c i e" . slime-eval-last-expression)
              ("C-c i d" . slime-documentation)
              ("C-c i z" . slime-switch-to-output-buffer))
  :ensure t)

;; FiveAM: Test framework documentation
;; FiveAM is a Common Lisp package (not an Emacs package), so it's not managed via MELPA
;; It's typically loaded in test files via ASDF or manually in REPL
;;
;; Example in REPL:
;;   (asdf:test-system 'my-system)
;;   (fiveam:run! 'my-test-suite)
;;
;; Install in your CL project:
;;   (ql:quickload "fiveam")
;;
;; Documented alternative: Rove (v0.10 BETA)
;; Modern syntax but not recommended until stable version 1.0
;; Install via: (ql:quickload "rove")
;; Usage: (rove:run #'test-function)

;; Indentation is the built-in cl-indent.el, which handles &body and the other
;; macro patterns and needs no configuration, so it has no use-package form.
;;
;; ALTERNATIVE: nice-lisp formatter
;; Requires: (ql:quickload "trivial-formatter") in your CL system
;; Then: (nice-lisp:format-string code)
;; If you install nice-lisp, register it with apheleia:
;;
;; (use-package apheleia
;;   :after apheleia
;;   :config
;;   (add-to-list 'apheleia-formatters
;;     '(nice-lisp . ("sbcl" "--noinform" "--load" "format.lisp" "--eval"
;;                    "(nice-lisp:format-string (read-file-as-string 0))")))
;;   (add-to-list 'apheleia-mode-alist
;;     '(lisp-mode . nice-lisp))
;;   :ensure nil)

;; Eglot: LSP support (optional, requires Roswell + cl-lsp)
(use-package eglot
  :config
  ;; cl-lsp is optional; only setup if Roswell is available
  ;; SLIME/SLY provide superior interactive feedback anyway
  (when (executable-find "ros")
    (let ((lsp-cmd (myde-prog-clisp-lsp-server)))
      (when lsp-cmd
        (add-to-list 'eglot-server-programs
          `(lisp-mode . ,lsp-cmd))
        (add-hook 'lisp-mode-hook 'eglot-ensure))))
  :ensure nil)

;; Known Limitations
;;
;; 1. No Structured Test Runner in Emacs
;;    - FiveAM/Rove don't have Emacs-side runners like CIDER (Clojure)
;;    - Tests run via: C-c i b (eval buffer), manual REPL, or (asdf:test-system ...)
;;
;; 2. LSP is Optional, Not Primary
;;    - SLIME/SLY provide better interactive feedback (REPL paradigm > LSP)
;;    - cl-lsp requires Roswell; gracefully skipped if unavailable
;;
;; 3. No Standard Common Lisp Formatter
;;    - CL community lacks agreement (unlike Python's black, Rust's rustfmt)
;;    - cl-indent.el (built-in) is sufficient for most users
;;    - nice-lisp available as commented alternative
;;
;; 4. No commonlisp-ts-mode Yet
;;    - tree-sitter-commonlisp exists but no corresponding Emacs mode on MELPA
;;    - Grammar registered for future compatibility
;;    - lisp-mode (regex-based) sufficient for now
;;
;; 5. SLY vs SLIME Coexistence
;;    - Both are installed; myde prioritizes SLY (modern)
;;    - SLY turns itself on in lisp buffers; SLIME only after M-x slime
;;    - User picks implementation at M-x sly / M-x slime runtime
;;
;; 6. SLDB Debugging Model
;;    - SLDB is integrated into REPL (Lisp Machine paradigm)
;;    - Superior to DAP for interactive Lisp development
;;    - Not a GUI step-through debugger like dape
;;
;; 7. Multiple CL Implementations
;;    - SBCL is primary (most popular, best ecosystem)
;;    - SLY/SLIME auto-detect available implementations
;;    - User picks at M-x sly / M-x slime startup

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

;; ob-lisp uses sly-eval when SLY is loaded (preferred over the SLIME default)
(use-package org
  :defer t
  :config
  (setq org-babel-lisp-eval-fn #'sly-eval)
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((lisp . t))))
  :ensure nil)

(use-package indent-bars
  :hook (lisp-mode . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-scheme
;;;; -----------
;; Gate: guile

(when (executable-find "guile")


(declare-function apheleia-format-buffer "apheleia")

;; Tree-sitter grammar registration for Scheme
(use-package treesit
  :config
  ;; Register Scheme grammar for future tree-sitter-based major mode
  ;; Currently no stable scheme-ts-mode on MELPA, but grammar is available
  (when (treesit-available-p)
    (add-to-list 'treesit-language-source-alist
      '(scheme "https://github.com/6cdh/tree-sitter-scheme")))
  :ensure nil)

;; Project root detection for Scheme toolchains
(use-package project
  :config
  ;; Add Scheme-specific project markers
  (myde-prog-scheme-setup)
  :ensure nil)

;; Built-in Scheme major mode
(use-package scheme
  :mode (("\\.scm\\'" . scheme-mode)
         ("\\.ss\\'" . scheme-mode)
         ("\\.sls\\'" . scheme-mode))
  ;; Buffer-local before-save formatter: schemat runs only if available and
  ;; eglot is managing the buffer (see myde-prog-scheme-format-buffer-maybe).
  :hook ((scheme-mode . eglot-ensure)
         (scheme-mode . myde-prog-scheme-format-on-save-setup))
  :ensure nil)

;; LSP support for Scheme via implementation-specific servers
;; scheme-langserver (general, R6RS/R7RS) or guile-lsp-server or chicken-lsp-server
(use-package eglot
  :config
  ;; Register dynamic LSP server detection
  ;; myde-prog-scheme-lsp-server returns the first available server
  (add-to-list 'eglot-server-programs
    `(scheme-mode . ,(lambda () (myde-prog-scheme-lsp-server))))
  :ensure nil)

;; Geiser: Interactive Scheme evaluation and REPL
;; Provides evaluation, debugging, documentation, macro expansion, etc.
(use-package geiser
  :custom
  ;; Make all installed Scheme backends available in M-x geiser prompt
  ;; User can choose implementation at runtime
  (geiser-active-implementations '(guile chicken chez))
  :ensure t)

;; Geiser backend: GNU Guile
;; Best Emacs integration, debugger support, used by Guix
(use-package geiser-guile
  :ensure t)

;; Geiser backend: CHICKEN Scheme
;; Excellent C FFI, practical systems programming
(use-package geiser-chicken
  :ensure t)

;; Geiser backend: Chez Scheme
;; Highest performance native-compile implementation
(use-package geiser-chez
  :ensure t)

;; Formatting support: schemat (opt-in)
(use-package apheleia
  :after (scheme apheleia)
  :config
  ;; Register schemat as Scheme formatter
  ;; schemat is cross-implementation (R5RS/R6RS/R7RS)
  ;; Install: cargo install schemat
  (add-to-list 'apheleia-formatters
    '(schemat . ("schemat")))
  (add-to-list 'apheleia-mode-alist
    '(scheme-mode . schemat))
  :ensure nil)

;; REPL keys are geiser's own (`C-c C-z' switches to the REPL).  myde adds
;; none, so there is no second geiser form.

;; Known Limitations
;;
;; 1. LSP is implementation-specific
;;    - scheme-langserver (Chez-based) is the best general option but requires Chez
;;    - guile-lsp-server and chicken-lsp-server are native alternatives
;;    - myde-prog-scheme-lsp-server auto-detects; user may need one installed
;;
;; 2. No scheme-ts-mode tree-sitter integration yet
;;    - Grammar is registered for future use
;;    - A stable scheme-ts-mode on MELPA would enable major-mode remapping
;;    - Until then, scheme-mode (regex-based) is used
;;
;; 3. schemat formatter is opt-in
;;    - Registered in apheleia but only runs if binary is on PATH
;;    - Install: cargo install schemat
;;    - Silent skip if absent (no error)
;;
;; 4. No structured test runner
;;    - Scheme lacks universal test framework integration (unlike CIDER or racket-mode)
;;    - Tests run via: C-c i b (eval buffer), M-x compile, or manual REPL
;;
;; 5. Geiser backend must match installed Scheme implementation
;;    - At least one of guile, chicken, chez must be installed
;;    - Geiser will prompt at M-x geiser to pick one
;;
;; 6. No DAP debugging
;;    - Scheme debugging is REPL-integrated via Geiser
;;    - When an error occurs (esp. Guile), Geiser shows *Geiser Dbg* buffer
;;    - Includes backtrace, frame inspection, breakpoints (not visual step-through)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

;; ob-scheme uses Geiser automatically when it is loaded
(use-package org
  :defer t
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((scheme . t))))
  :ensure nil)

(use-package indent-bars
  :hook (scheme-mode . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-clojure
;;;; ------------
;; Gate: clojure

(when (executable-find "clojure")


(use-package treesit
  :config
  ;; Register Clojure grammar for system-wide availability
  (when (treesit-available-p)
    (add-to-list 'treesit-language-source-alist
      '(clojure "https://github.com/sogaiu/tree-sitter-clojure" "unstable-20250526")))
  :ensure nil)

(use-package project
  :config
  ;; Add Clojure-specific project root markers
  (myde-prog-clojure-setup)
  :ensure nil)

;; Load clojure-mode silently (required as CIDER's undeclared dependency)
;; Future: clojure-ts-mode will subsume clojure-mode (Emacs 32+)
(use-package clojure-mode
  :init
  ;; Don't show clojure-mode in mode-line; clojure-ts-mode is primary
  (setq auto-mode-alist (rassq-delete-all 'clojure-mode auto-mode-alist))
  :ensure t)

(use-package clojure-ts-mode
  :mode (("\\.clj\\'" . clojure-ts-mode)
         ("\\.cljs\\'" . clojure-ts-mode)
         ("\\.cljc\\'" . clojure-ts-mode))
  :init
  ;; Prefer clojure-ts-mode when available
  (add-to-list 'major-mode-remap-alist '(clojure-mode . clojure-ts-mode))
  :ensure t)

(use-package eglot
  :hook ((clojure-ts-mode . eglot-ensure)
         (clojure-mode . eglot-ensure))
  :config
  ;; Register clojure-lsp server for Clojure modes
  ;; Requires: brew install clojure-lsp
  (add-to-list 'eglot-server-programs
    '(clojure-ts-mode . ("clojure-lsp")))
  (add-to-list 'eglot-server-programs
    '(clojure-mode . ("clojure-lsp")))
  (add-to-list 'eglot-server-programs
    '(clojurescript-mode . ("clojure-lsp")))
  :ensure nil)

(use-package cider
  :after clojure-ts-mode
  :hook (clojure-ts-mode . cider-mode)
  :custom
  ;; apheleia formats through cljfmt, so CIDER's own auto-format stays off.
  ;; Users who prefer zprint can override `cider-format-code-options' via
  ;; .dir-locals.el.
  (cider-auto-mode nil)
  ;; Disable CIDER's eldoc display for symbol-at-point to let CIDER's
  ;; eldoc (arglists, docstrings) take precedence when active
  (cider-eldoc-display-for-symbol-at-point nil)
  ;; CIDER test runner keybindings (standard myde pattern)
  ;; C-c t t = test at point
  ;; C-c t f = test file
  ;; C-c t p = test project
  ;; C-c t r = rerun last test
  ;; `:package cider-mode': the map lives in cider-mode.el, which the
  ;; `cider-mode' hook loads without ever providing the `cider' feature, so a
  ;; binding that waited on `cider' would never happen.
  :bind (:map cider-mode-map :package cider-mode
              ("C-c t t" . cider-test-run-test)
              ("C-c t f" . cider-test-run-ns-tests)
              ("C-c t p" . cider-test-run-project-tests)
              ("C-c t r" . cider-test-run-loaded-tests))
  :ensure t)

(use-package apheleia
  :after (clojure-ts-mode apheleia)
  :config
  ;; Register cljfmt (built into clojure-lsp) as default formatter
  (add-to-list 'apheleia-formatters
    '(cljfmt . ("clojure-lsp" "format" "-")))
  (add-to-list 'apheleia-mode-alist
    '(clojure-ts-mode . cljfmt))
  (add-to-list 'apheleia-mode-alist
    '(clojure-mode . cljfmt))

  ;; ALTERNATIVE: zprint formatter (opt-in)
  ;; Requires: brew install zprint
  ;; More aggressive formatting than cljfmt; highly customizable via .dir-locals.el
  ;;
  ;; Uncomment to enable:
  ;; (add-to-list 'apheleia-formatters
  ;;   '(zprint . ("zprint" "-")))
  ;; (add-to-list 'apheleia-mode-alist
  ;;   '(clojure-ts-mode . zprint))
  ;; (add-to-list 'apheleia-mode-alist
  ;;   '(clojure-mode . zprint))
  ;;
  ;; Then configure CIDER's formatter in the cider form's :custom block:
  ;; (cider-format-code-options {:style :community})
  ;;
  ;; Or via .dir-locals.el in project root:
  ;; ((clojure-ts-mode
  ;;   (apheleia-formatter . zprint)
  ;;   (cider-format-code-options . {:style :community})))
  :ensure nil)

;; paredit and rainbow-delimiters are configured in prog-base
;; (shared across all Lisp-family languages)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

;; ob-clojure uses CIDER automatically when it is loaded
(use-package org
  :defer t
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((clojure . t))))
  :ensure nil)

(use-package indent-bars
  :hook ((clojure-ts-mode clojure-mode) . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-erlang
;;;; -----------
;; Gate: erl

(when (executable-find "erl")


;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(erlang "https://github.com/WhatsApp/tree-sitter-erlang"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + ELP
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook (erlang-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '(erlang-mode . ("elp" "server")))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Erlang mode
;; -----------------------------------------------------------------------------

(use-package erlang  ;; https://github.com/erlang/otp (tools/emacs)
  :hook ((erlang-mode . myde-erlang-mode-setup)
         (erlang-mode . flycheck-mode))
  :bind (:map erlang-mode-map
              ("C-c i i" . erlang-shell)
              ("C-c i s" . erlang-shell-display)
              ("C-c t p" . myde-erlang-run-tests))
  :mode (("\\.erl\\'"     . erlang-mode)
         ("\\.hrl\\'"     . erlang-mode)
         ("\\.escript\\'" . erlang-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package ob-erlang  ;; https://github.com/xfwduke/ob-erlang
  :after org
  :ensure (:host github :repo "xfwduke/ob-erlang"))

(use-package indent-bars
  :hook (erlang-mode . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-elixir
;;;; -----------
;; Gate: elixir

(when (executable-find "elixir")


;; -----------------------------------------------------------------------------
;; Tree-sitter grammars
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(elixir "https://github.com/elixir-lang/tree-sitter-elixir"))
  (add-to-list 'treesit-language-source-alist
               '(heex "https://github.com/phoenixframework/tree-sitter-heex"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + elixir-ls
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((elixir-ts-mode . eglot-ensure)
         (heex-ts-mode   . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '(elixir-ts-mode . (lambda (dir) (myde-mise-exec-which dir "elixir-ls"))))
  (add-to-list 'eglot-server-programs
               '(heex-ts-mode . (lambda (dir) (myde-mise-exec-which dir "elixir-ls"))))
  :ensure nil)



;; -----------------------------------------------------------------------------
;; Debugging via dape + elixir-ls
;;
;; ElixirLS includes a DAP debug adapter that supports Mix tasks, breakpoints,
;; variable inspection, and stack traces. The debug adapter automatically
;; interprets all modules in the Mix project and dependencies.
;;
;; For debugging tests, use the 'elixir-mix-test' configuration which includes
;; required test files.
;; -----------------------------------------------------------------------------

(use-package dape
  :after dape
  :config
  ;; Default mix task configuration
  (add-to-list 'dape-configs
               '(elixir-debug
                 modes (elixir-ts-mode heex-ts-mode)
                 ensure (lambda (config)
                          (if (executable-find "elixir-ls")
                              t
                            (message "elixir-ls not found on PATH")
                            nil))
                 command "elixir-ls"
                 :type "mix_task"
                 :request "launch"
                 :task "run"
                 :projectDir dape-buffer-default
                 :startApps t
                 :debugAutoInterpretAllModules t
                 :exitAfterTaskReturns t
                 :breakOnDbg t))

  ;; Mix test configuration
  (add-to-list 'dape-configs
               '(elixir-mix-test
                 modes (elixir-ts-mode)
                 ensure (lambda (config)
                          (if (executable-find "elixir-ls")
                              t
                            (message "elixir-ls not found on PATH")
                            nil))
                 command "elixir-ls"
                 :type "mix_task"
                 :request "launch"
                 :task "test"
                 :taskArgs ("--trace")
                 :projectDir dape-buffer-default
                 :startApps t
                 :debugAutoInterpretAllModules t
                 :requireFiles ("test/**/test_helper.exs" "test/**/*_test.exs")
                 :exitAfterTaskReturns t
                 :breakOnDbg t))

  ;; Phoenix server configuration
  (add-to-list 'dape-configs
               '(elixir-phoenix
                 modes (elixir-ts-mode heex-ts-mode)
                 ensure (lambda (config)
                          (if (executable-find "elixir-ls")
                              t
                            (message "elixir-ls not found on PATH")
                            nil))
                 command "elixir-ls"
                 :type "mix_task"
                 :request "launch"
                 :task "phx.server"
                 :projectDir dape-buffer-default
                 :startApps t
                 :debugAutoInterpretAllModules t
                 :exitAfterTaskReturns nil
                 :breakOnDbg t))

  ;; Remote debugging configuration
  (add-to-list 'dape-configs
               '(elixir-remote
                 modes (elixir-ts-mode heex-ts-mode)
                 ensure (lambda (config)
                          (if (executable-find "elixir-ls")
                              t
                            (message "elixir-ls not found on PATH")
                            nil))
                 command "elixir-ls"
                 :type "mix_task"
                 :request "attach"
                 :remoteNode "your-node@host"
                 :projectDir dape-buffer-default))

  ;; .exs script debugging configuration
  ;;
  ;; Note: .exs scripts must be structured to work around a race condition:
  ;; 1. Wrap main logic in a module function
  ;; 2. Use Task.start with a sleep delay to give the debugger time to interpret
  ;; 3. Example structure:
  ;;
  ;;    defmodule MyScript do
  ;;      def run do
  ;;        # Your code here
  ;;        IO.puts("done")
  ;;      end
  ;;    end
  ;;
  ;;    Task.start(fn ->
  ;;      Process.sleep(4000)  ; Give debugger time to interpret
  ;;      MyScript.run()
  ;;    end)
  ;;
  ;; Alternatively, use Kernel.dbg/2 for simpler debugging without breakpoints.
  ;; The breakOnDbg setting enables automatic breaking on dbg() calls.
  (add-to-list 'dape-configs
               '(elixir-exs-script
                 modes (elixir-ts-mode)
                 ensure (lambda (config)
                          (if (executable-find "elixir-ls")
                              t
                            (message "elixir-ls not found on PATH")
                            nil))
                 command "elixir-ls"
                 :type "mix_task"
                 :request "launch"
                 :task "run"
                 :taskArgs ("--no-mix-exs" dape-buffer-default)
                 :projectDir dape-buffer-default
                 :requireFiles (dape-buffer-default)
                 :startApps nil
                 :debugAutoInterpretAllModules t
                 :exitAfterTaskReturns nil
                 :breakOnDbg t))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Elixir and HEEx modes
;; -----------------------------------------------------------------------------

;; Emacs maps .ex and .exs to elixir-ts-mode itself, and .heex goes to
;; heex-ts-mode below.
(use-package elixir-ts-mode
  :hook ((elixir-ts-mode . myde-elixir-ts-ensure-grammars)
         (elixir-ts-mode . myde-prog-elixir-flycheck-setup)
         (elixir-ts-mode . yas-minor-mode))
  :ensure nil)

;; Built in since Emacs 30.  The external package of the same name shadows it
;; and lacks `heex-ts--range-rules', which the built-in elixir-ts-mode reads.
(use-package heex-ts-mode  ;; built-in (Emacs 30+)
  :after elixir-ts-mode
  :mode ("\\.heex\\'" . heex-ts-mode)
  :hook ((heex-ts-mode . yas-minor-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Testing
;; -----------------------------------------------------------------------------

(use-package exunit  ;; https://github.com/ananthakumaran/exunit.el
  :after elixir-ts-mode
  :hook (elixir-ts-mode . exunit-mode)
  :bind (:map exunit-mode-map
              ("C-c t a" . exunit-verify-all)
              ("C-c t s" . exunit-verify-single)
              ("C-c t t" . exunit-toggle-file-and-test))
  :ensure t)

;; -----------------------------------------------------------------------------
;; REPL
;; -----------------------------------------------------------------------------

(use-package elixir-iex  ;; https://github.com/mojochao/elixir-iex
  :after elixir-ts-mode
  :hook (elixir-ts-mode . elixir-iex-minor-mode)
  :bind (:map elixir-iex-minor-mode-map
              ("C-c i i" . elixir-iex)
              ("C-c i p" . elixir-iex-project)
              ("C-c i l" . elixir-iex-send-line)
              ("C-c i r" . elixir-iex-send-region)
              ("C-c i b" . elixir-iex-send-buffer)
              ("C-c i m" . elixir-iex-reload-module)
              ("C-c i s" . elixir-iex-set-repl))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Linting
;; -----------------------------------------------------------------------------

(use-package flycheck-credo  ;; https://github.com/aaronjensen/flycheck-credo
  :after flycheck
  :custom
  (flycheck-elixir-credo-strict t)
  :config
  (flycheck-credo-setup)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Mix task runner
;; -----------------------------------------------------------------------------

(use-package mix  ;; https://github.com/ayrat555/mix.el
  :after elixir-ts-mode
  :hook (elixir-ts-mode . mix-minor-mode)
  ;; mix binds its command map on C-c d, the shared dape prefix.  The debug
  ;; keys win, so the mix commands move to C-c x.
  :bind (:map mix-minor-mode-map
              ("C-c d" . nil)
              ("C-c x" . mix-minor-mode-command-map))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package ob-elixir  ;; https://github.com/zweifisch/ob-elixir
  :after org
  :ensure t)

(myde-register-snippets
 (expand-file-name "snippets/elixir" user-emacs-directory)
 'elixir-ts-mode)

(use-package indent-bars
  :hook ((elixir-ts-mode heex-ts-mode) . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-cpp
;;;; --------
;; Gate: clangd

(when (executable-find "clangd")


;; -----------------------------------------------------------------------------
;; Tree-sitter grammars
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(c     "https://github.com/tree-sitter/tree-sitter-c"))
  (add-to-list 'treesit-language-source-alist
               '(cpp   "https://github.com/tree-sitter/tree-sitter-cpp"))
  (add-to-list 'treesit-language-source-alist
               '(cmake "https://github.com/uyha/tree-sitter-cmake"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + clangd
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((c++-ts-mode . eglot-ensure)
         (c-ts-mode   . eglot-ensure)
         (c++-mode    . eglot-ensure)
         (c-mode      . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '((c++-ts-mode c-ts-mode c++-mode c-mode)
                 "clangd"
                 "--header-insertion=never"
                 "--clang-tidy"
                 "--completion-style=detailed"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; C/C++ mode
;; -----------------------------------------------------------------------------

(use-package c-ts-mode
  :hook ((c++-ts-mode . myde-cpp-ts-mode-setup)
         (c++-ts-mode . myde-cpp-format-on-save-setup)
         (c-ts-mode   . myde-c-ts-mode-setup)
         (c-ts-mode   . myde-cpp-format-on-save-setup))
  :bind ((:map c++-ts-mode-map
               ("C-c t p" . myde-cpp-run-tests)
               ("C-c o"   . ff-find-other-file))
         (:map c-ts-mode-map
               ("C-c t p" . myde-cpp-run-tests)
               ("C-c o"   . ff-find-other-file)))
  :mode (("\\.cpp\\'" . c++-ts-mode)
         ("\\.cc\\'"  . c++-ts-mode)
         ("\\.cxx\\'" . c++-ts-mode)
         ("\\.hpp\\'" . c++-ts-mode)
         ("\\.hh\\'"  . c++-ts-mode)
         ("\\.hxx\\'" . c++-ts-mode)
         ("\\.h\\'"   . c++-ts-mode)
         ("\\.c\\'"   . c-ts-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; CMake mode
;; -----------------------------------------------------------------------------

(use-package cmake-ts-mode
  :mode (("CMakeLists\\.txt\\'" . cmake-ts-mode)
         ("\\.cmake\\'"         . cmake-ts-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Debugging via dape + codelldb
;; -----------------------------------------------------------------------------

(use-package dape
  :after dape
  :config
  (add-to-list 'dape-configs
               '(cpp-debug
                 modes (c++-ts-mode c-ts-mode c++-mode c-mode)
                 command "codelldb"
                 command-args ("--port" :port)
                 port :autoport
                 :type "lldb"
                 :request "launch"
                 :program myde-cpp-dape-binary))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :defer t
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((C . t))))
  :ensure nil)

(use-package indent-bars
  :hook ((c++-ts-mode c-ts-mode cmake-ts-mode) . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-go
;;;; --------
;; Gate: go

(when (executable-find "go")


;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(go "https://github.com/tree-sitter/tree-sitter-go"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + gopls
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((go-ts-mode . eglot-ensure)
         (go-mode    . eglot-ensure))
  :config
  (myde-eglot-add-workspace-config
   :gopls '(:staticcheck t
            :gofumpt t
            :usePlaceholders t
            :completeUnimported t
            :semanticTokens t
            :hints (:assignVariableTypes t
                    :compositeLiteralFields t
                    :compositeLiteralTypes t
                    :constantValues t
                    :functionTypeParameters t
                    :parameterNames t
                    :rangeVariableTypes t)))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Go mode
;; -----------------------------------------------------------------------------

(use-package go-mode  ;; https://github.com/dominikh/go-mode.el
  :custom
  (go-ts-mode-indent-offset myde-go-tab-width)
  :hook
  ((go-ts-mode . myde-go-mode-setup)
   (go-ts-mode . myde-go-format-on-save-setup)
   (go-mode    . myde-go-mode-setup)
   (go-mode    . myde-go-format-on-save-setup))
  :mode
  (("\\.go\\'" . myde-go-ts-or-plain-mode))
  :ensure t)

;; No :after go-mode: .go files open in the built-in go-ts-mode, which never
;; loads the go-mode package, so the form would never run.
(use-package gotest-ts  ;; https://github.com/chmouel/gotest-ts.el
  :hook (go-ts-mode . gotest-ts-setup)
  :bind (:map go-ts-mode-map
              ;; gotest-ts-setup binds C-c t r/f/i/n/p/m in both Go mode maps.
              ("C-c t t" . gotest-ts-run-dwim))
  :ensure (:host github :repo "chmouel/gotest-ts.el"))

;; -----------------------------------------------------------------------------
;; Debugging via dape + dlv
;; -----------------------------------------------------------------------------

(use-package dape
  :after dape
  :config
  (add-to-list 'dape-configs
               '(go-debug
                 modes (go-ts-mode go-mode)
                 command "dlv"
                 command-args ("dap")
                 :type "go"
                 :request "launch"
                 :mode "debug"
                 :program "."))
  (add-to-list 'dape-configs
               '(go-test
                 modes (go-ts-mode go-mode)
                 command "dlv"
                 command-args ("dap")
                 :type "go"
                 :request "launch"
                 :mode "test"
                 :program "."))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package ob-go  ;; https://github.com/pope/ob-go
  :after org
  :ensure t)

(myde-register-snippets
 (expand-file-name "snippets/go" user-emacs-directory)
 'go-ts-mode)

(use-package indent-bars
  :hook ((go-ts-mode go-mode) . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-rust
;;;; ---------
;; Gate: cargo

(when (executable-find "cargo")


(declare-function dape-cwd "dape")

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(rust "https://github.com/tree-sitter/tree-sitter-rust"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + rust-analyzer
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((rustic-mode  . eglot-ensure)
         (rust-ts-mode . eglot-ensure)
         (rust-mode    . eglot-ensure))
  :config
  (myde-eglot-add-workspace-config
   :rust-analyzer '(:checkOnSave (:command "clippy")
                    :inlayHints (:typeHints (:enable t)
                                 :parameterHints (:enable t)
                                 :chainingHints (:enable t)
                                 :closureReturnTypeHints (:enable t))
                    :completion (:callable (:snippets "fill_arguments")
                                 :postfix (:enable t))
                    :cargo (:buildScripts (:enable t)
                           :features "all")
                    :procMacro (:enable t)))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Rust mode via rustic
;; -----------------------------------------------------------------------------

(use-package rustic  ;; https://github.com/emacs-rustic/rustic
  :custom
  (rustic-lsp-client 'eglot)
  (rust-mode-treesitter-derive t)
  :init
  (setq rustic-format-trigger 'on-save)  ; a defvar in rustic, so not :custom
  :hook ((rustic-mode . myde-rust-mode-setup))
  :bind (:map rustic-mode-map
              ("C-c t t" . rustic-cargo-current-test)
              ("C-c t p" . rustic-cargo-test))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugging via dape + codelldb
;; -----------------------------------------------------------------------------

(use-package dape
  :after dape
  :config
  (add-to-list 'dape-configs
               `(rust-debug
                 modes (rustic-mode rust-ts-mode rust-mode)
                 command "codelldb"
                 command-args ("--port" :port)
                 port :autoport
                 :type "lldb"
                 :request "launch"
                 :program ,#'myde-rust-dape-debug-program))
  (add-to-list 'dape-configs
               `(rust-test
                 modes (rustic-mode rust-ts-mode rust-mode)
                 command "codelldb"
                 command-args ("--port" :port)
                 port :autoport
                 :type "lldb"
                 :request "launch"
                 :args ["--test"]
                 :program ,#'myde-rust-dape-debug-program))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package ob-rust  ;; https://github.com/micanzhang/ob-rust
  :after org
  :ensure t)

(use-package indent-bars
  :hook ((rustic-mode rust-ts-mode rust-mode) . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-zig
;;;; --------
;; Gate: zig

(when (executable-find "zig")


(declare-function dape-cwd "dape")

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(zig "https://github.com/tree-sitter-grammars/tree-sitter-zig"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + zls
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((zig-ts-mode . eglot-ensure)
         (zig-mode    . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '((zig-ts-mode zig-mode) . ("zls")))
  (myde-eglot-add-workspace-config
   :zls '(:enable_build_on_save t
          :inlay_hints_show_builtin t
          :inlay_hints_exclude_single_argument t
          :inlay_hints_show_parameter_name t
          :inlay_hints_show_variable_type_hints t))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Zig mode (fallback, no tree-sitter)
;; -----------------------------------------------------------------------------

(use-package zig-mode  ;; https://github.com/ziglang/zig-mode
  :hook ((zig-mode . myde-zig-mode-setup)
         (zig-mode . myde-zig-format-on-save-setup))
  :bind (:map zig-mode-map
              ("C-c t p" . zig-test-buffer))
  :mode (("\\.zig\\'" . myde-zig-ts-or-plain-mode)
         ("\\.zon\\'" . myde-zig-ts-or-plain-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Zig tree-sitter mode
;; -----------------------------------------------------------------------------

(use-package zig-ts-mode  ;; https://github.com/emacsmirror/zig-ts-mode
  :hook ((zig-ts-mode . myde-zig-mode-setup)
         (zig-ts-mode . myde-zig-format-on-save-setup))
  :bind (:map zig-ts-mode-map
              ("C-c t p" . zig-test-buffer))
  :ensure (:host github :repo "emacsmirror/zig-ts-mode"))

;; -----------------------------------------------------------------------------
;; Debugging via dape + codelldb
;; -----------------------------------------------------------------------------

(use-package dape
  :after dape
  :config
  (add-to-list 'dape-configs
               `(zig-debug
                 modes (zig-ts-mode zig-mode)
                 command "codelldb"
                 command-args ("--port" :port)
                 port :autoport
                 :type "lldb"
                 :request "launch"
                 :program ,#'myde-zig-dape-binary))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

;; A fork of https://github.com/jolby/ob-zig.el, which stopped tracking Zig at
;; 0.11.  The fork targets Zig 0.16 and Emacs 30.1, wraps a block without a
;; main in `pub fn main(init: std.process.Init)', and needs no zig-mode.
(use-package ob-zig  ;; https://github.com/mojochao/ob-zig.el
  :defer t
  :ensure (:host github :repo "mojochao/ob-zig.el"))

(use-package org
  :defer t
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((zig . t))))
  :ensure nil)

(use-package indent-bars
  :hook ((zig-ts-mode zig-mode) . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-python
;;;; -----------
;; Gate: python3

(when (executable-find "python3")


;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(python "https://github.com/tree-sitter/tree-sitter-python"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + basedpyright
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook (python-ts-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '((python-mode python-ts-mode) . ("basedpyright-langserver" "--stdio")))
  (myde-eglot-add-workspace-config
   :basedpyright '(:typeCheckingMode "standard"
                   :useLibraryCodeForTypes t
                   :diagnosticMode "workspace"
                   :inlayHints (:variableTypes t
                                :functionReturnTypes t
                                :callArgumentNames t
                                :genericTypes t)))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Python mode
;; -----------------------------------------------------------------------------

(use-package python
  :hook ((python-ts-mode . myde-python-ts-mode-setup)
         (python-ts-mode . flycheck-mode))
  :bind (:map python-ts-mode-map
              ("C-c i i" . run-python)
              ("C-c i r" . python-shell-send-region)
              ("C-c i b" . python-shell-send-buffer)
              ("C-c i d" . python-shell-send-defun)
              ("C-c i s" . python-shell-switch-to-shell))
  :mode ("\\.py\\'" . python-ts-mode)
  :ensure nil)

(use-package ruff-format  ;; https://github.com/scop/emacs-ruff-format
  :hook (python-ts-mode . ruff-format-on-save-mode)
  :ensure t)

(use-package python-pytest  ;; https://github.com/wbolster/emacs-python-pytest
  :after python
  :bind (:map python-ts-mode-map
              ("C-c t t" . python-pytest-run-def-at-point-treesit)
              ("C-c t f" . python-pytest-file-dwim)
              ("C-c t p" . python-pytest)
              ("C-c t r" . python-pytest-repeat)
              ("C-c t x" . python-pytest-last-failed)
              ("C-c t m" . python-pytest-dispatch))
  :custom
  (python-pytest-unsaved-buffers-behavior 'save-all)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugging via dape + debugpy
;; -----------------------------------------------------------------------------

(use-package dape
  :after dape
  :config
  (add-to-list 'dape-configs
               '(python-debug
                 modes (python-mode python-ts-mode)
                 command "python"
                 command-args ("-m" "debugpy.adapter")
                 :type "python"
                 :request "launch"
                 :program dape-buffer-default
                 :justMyCode nil))
  (add-to-list 'dape-configs
               '(python-test
                 modes (python-mode python-ts-mode)
                 command "python"
                 command-args ("-m" "debugpy.adapter")
                 :type "python"
                 :request "launch"
                 :module "pytest"
                 :args ["-x" "-s"]
                 :justMyCode nil))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :defer t
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((python . t))))
  :ensure nil)

(use-package indent-bars
  :hook (python-ts-mode . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-ruby
;;;; ---------
;; Gate: ruby

(when (executable-find "ruby")


;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(ruby "https://github.com/tree-sitter/tree-sitter-ruby"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + ruby-lsp
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((ruby-ts-mode . eglot-ensure)
         (ruby-mode    . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '((ruby-ts-mode ruby-mode) . ("ruby-lsp")))
  (myde-eglot-add-workspace-config
   :rubyLsp '(:formatter "rubocop"
              :inlayHints (:implicitRescue t
                           :implicitHashValue t)))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Ruby mode (fallback, no tree-sitter)
;; -----------------------------------------------------------------------------

(use-package ruby-mode
  :hook ((ruby-mode . myde-ruby-mode-setup)
         (ruby-mode . myde-ruby-format-on-save-setup))
  :bind (:map ruby-mode-map
              ("C-c i i" . inf-ruby)
              ("C-c i r" . ruby-send-region)
              ("C-c i b" . ruby-send-buffer)
              ("C-c i s" . ruby-switch-to-inf))
  :mode (("\\.rb\\'"      . myde-ruby-ts-or-plain-mode)
         ("\\.rake\\'"    . myde-ruby-ts-or-plain-mode)
         ("\\.gemspec\\'" . myde-ruby-ts-or-plain-mode)
         ("Gemfile\\'"    . myde-ruby-ts-or-plain-mode)
         ("Rakefile\\'"   . myde-ruby-ts-or-plain-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Ruby tree-sitter mode
;; -----------------------------------------------------------------------------

(use-package ruby-ts-mode
  :hook ((ruby-ts-mode . myde-ruby-mode-setup)
         (ruby-ts-mode . myde-ruby-format-on-save-setup))
  :bind (:map ruby-ts-mode-map
              ("C-c i i" . inf-ruby)
              ("C-c i r" . ruby-send-region)
              ("C-c i b" . ruby-send-buffer)
              ("C-c i s" . ruby-switch-to-inf))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; RSpec test runner
;; -----------------------------------------------------------------------------

(use-package rspec-mode  ;; https://github.com/pezra/rspec-mode
  :hook ((ruby-mode    . rspec-mode)
         (ruby-ts-mode . rspec-mode))
  :bind (:map rspec-mode-map
              ("C-c t t" . rspec-verify-single)
              ("C-c t f" . rspec-verify)
              ("C-c t p" . rspec-verify-all)
              ("C-c t r" . rspec-rerun)
              ("C-c t x" . rspec-run-last-failed))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Interactive Ruby REPL via inf-ruby
;; -----------------------------------------------------------------------------

(use-package inf-ruby  ;; https://github.com/nonsequitur/inf-ruby
  :hook ((ruby-mode    . inf-ruby-minor-mode)
         (ruby-ts-mode . inf-ruby-minor-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Code navigation and documentation via robe
;; -----------------------------------------------------------------------------

(use-package robe  ;; https://github.com/dgutov/robe
  :hook ((ruby-mode    . robe-mode)
         (ruby-ts-mode . robe-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugging via dape + rdbg
;; -----------------------------------------------------------------------------

(use-package dape
  :after dape
  :config
  (add-to-list 'dape-configs
               `(ruby-debug
                 modes (ruby-ts-mode ruby-mode)
                 command "rdbg"
                 command-args ("--open" "--host" "127.0.0.1" "--port" :port
                               "-c" "--" "ruby" dape-buffer-default)
                 port :autoport
                 :type "Ruby"
                 :request "launch"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :defer t
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((ruby . t))))
  :ensure nil)

(use-package indent-bars
  :hook ((ruby-ts-mode ruby-mode) . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-lua
;;;; --------
;; Gate: lua

(when (executable-find "lua")


;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

;; Pinned to the commit Emacs 31's lua-ts-mode is written against.  lua-ts-mode
;; registers the same entry, but only once it loads, which is after the first
;; .lua visit has already tried to install the grammar through treesit-auto.
(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(lua "https://github.com/tree-sitter-grammars/tree-sitter-lua"
                     :commit "db16e76558122e834ee214c8dc755b4a3edc82a9"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + lua-language-server
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((lua-ts-mode . eglot-ensure)
         (lua-mode    . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
               '((lua-ts-mode lua-mode) . ("lua-language-server")))
  (myde-eglot-add-workspace-config
   :Lua '(:hint (:enable t
                 :arrayIndex "Enable"
                 :await t
                 :paramName "All"
                 :setType t)
          :diagnostics (:enable t)
          :completion (:callSnippet "Replace")))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Lua mode (fallback, no tree-sitter)
;; -----------------------------------------------------------------------------

(use-package lua-mode  ;; https://github.com/immerrr/lua-mode
  :hook ((lua-mode . myde-lua-mode-setup)
         (lua-mode . myde-lua-format-on-save-setup))
  :bind (:map lua-mode-map
              ("C-c i i" . lua-start-process)
              ("C-c i r" . lua-send-region)
              ("C-c i b" . lua-send-buffer)
              ("C-c i s" . lua-show-process-buffer))
  :mode ("\\.lua\\'" . myde-lua-ts-or-plain-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Lua tree-sitter mode
;; -----------------------------------------------------------------------------

;; The REPL keys use each mode's own inferior Lua.  inf-lua was dropped: it
;; has no minor mode or send commands, only a REPL both modes already ship.
(use-package lua-ts-mode  ;; built-in Emacs 29+
  :hook ((lua-ts-mode . myde-lua-mode-setup)
         (lua-ts-mode . myde-lua-format-on-save-setup))
  :bind (:map lua-ts-mode-map
              ("C-c i i" . lua-ts-inferior-lua)
              ("C-c i r" . lua-ts-send-region)
              ("C-c i b" . lua-ts-send-buffer)
              ("C-c i s" . lua-ts-show-process-buffer))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :defer t
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((lua . t))))
  :ensure nil)

(use-package indent-bars
  :hook ((lua-ts-mode lua-mode) . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-javascript
;;;; ---------------
;; Gate: node

(when (executable-find "node")


;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(javascript "https://github.com/tree-sitter/tree-sitter-javascript"
                            "master" "src"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + rass tslint
;;
;; rass tslint multiplexes:
;;   - typescript-language-server  (completions, JSDoc types, inlay hints, code actions)
;;   - vscode-eslint-language-server (lint diagnostics via ESLint)
;;
;; :checkJs t enables type-checking of JS files via JSDoc annotations.
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((js-ts-mode . eglot-ensure)
         (js-ts-mode . myde-javascript-mode-hook))
  :config
  (add-to-list 'eglot-server-programs
               `((js-ts-mode)
                 . ("rass" "tslint"
                    :initializationOptions
                    (:preferences
                     (:checkJs t
                      :includeInlayParameterNameHints "all"
                      :includeInlayParameterNameHintsWhenArgumentMatchesName t
                      :includeInlayFunctionParameterTypeHints t
                      :includeInlayVariableTypeHints t
                      :includeInlayVariableTypeHintsWhenTypeMatchesName nil
                      :includeInlayPropertyDeclarationTypeHints t
                      :includeInlayFunctionLikeReturnTypeHints t
                      :includeInlayEnumMemberValueHints t
                      :importModuleSpecifierPreference "non-relative"
                      :includeCompletionsForModuleExports t
                      :includeCompletionsWithSnippetText t
                      :completeFunctionCalls t
                      :includeAutomaticOptionalChainCompletions t)))))
  :bind (:map eglot-mode-map
              ("C-c e r" . eglot-rename)
              ("C-c e a" . eglot-code-actions)
              ("C-c e f" . eglot-format-buffer))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; JavaScript / JSX major mode (built-in, Emacs 29+)
;;
;; js-ts-mode uses the javascript tree-sitter grammar which has native JSX
;; node support — no separate tsx grammar or mode needed for .jsx files.
;; -----------------------------------------------------------------------------

(use-package js
  :hook ((js-ts-mode . myde-js-ts-mode-setup)
         (js-ts-mode . myde-javascript-format-on-save-setup))
  :mode (("\\.js\\'"  . js-ts-mode)
         ("\\.jsx\\'" . js-ts-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Local node_modules tool resolution
;;
;; Prepends node_modules/.bin to exec-path so that project-local eslint,
;; prettier etc. shadow global installations.
;; -----------------------------------------------------------------------------

(use-package add-node-modules-path
  :hook (js-ts-mode . add-node-modules-path)
  :ensure t)

;; -----------------------------------------------------------------------------
;; Formatting via apheleia + prettier
;;
;; apheleia itself is configured in prog-base.  Here we register prettier as
;; the formatter for JavaScript/JSX buffers.
;; -----------------------------------------------------------------------------

(use-package apheleia
  :after apheleia
  :config
  (setf (alist-get 'js-ts-mode apheleia-mode-alist) 'prettier)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Test runner: jest-test-mode
;; -----------------------------------------------------------------------------

(use-package jest-test-mode
  :hook (js-ts-mode . jest-test-mode)
  :bind (:map jest-test-mode-map
              ;; Remap from default C-c C-t prefix to module-standard C-c t
              ("C-c C-t t" . nil)
              ("C-c C-t n" . nil)
              ("C-c C-t p" . nil)
              ("C-c C-t a" . nil)
              ("C-c t t"   . jest-test-run-at-point)
              ("C-c t f"   . jest-test-run)
              ("C-c t p"   . jest-test-run-all-tests)
              ("C-c t r"   . jest-test-rerun-test))
  :custom
  (jest-test-options '("--no-coverage"))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Node.js REPL via nodejs-repl
;; -----------------------------------------------------------------------------

(use-package nodejs-repl
  :after js
  :bind (:map js-ts-mode-map
              ("C-c i i" . nodejs-repl)
              ("C-c i r" . nodejs-repl-send-region)
              ("C-c i b" . nodejs-repl-send-buffer)
              ("C-c i s" . nodejs-repl-switch-to-repl))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugging via dape + @vscode/js-debug
;;
;; Requires: npm install -g @vscode/js-debug
;; -----------------------------------------------------------------------------

(use-package dape
  :after dape
  :config
  (add-to-list 'dape-configs
               '(node-script
                 modes (js-ts-mode)
                 command "node"
                 command-args ("${userHome}/node_modules/@vscode/js-debug/src/dapDebugServer.js" "0")
                 :type "pwa-node"
                 :request "launch"
                 :program dape-buffer-default
                 :cwd "${workspaceFolder}"
                 :sourceMaps t
                 :console "integratedTerminal"))
  (add-to-list 'dape-configs
               '(node-jest
                 modes (js-ts-mode)
                 command "node"
                 command-args ("${userHome}/node_modules/@vscode/js-debug/src/dapDebugServer.js" "0")
                 :type "pwa-node"
                 :request "launch"
                 :runtimeExecutable "npx"
                 :runtimeArgs ["jest" "--testPathPattern" "${relativeFile}" "--no-coverage" "--runInBand"]
                 :cwd "${workspaceFolder}"
                 :sourceMaps t
                 :console "integratedTerminal"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package org
  :defer t
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((js . t))))
  :ensure nil)

(use-package indent-bars
  :hook (js-ts-mode . indent-bars-mode)
  :ensure nil)

  )

;;;; prog-typescript
;;;; ---------------
;; Gate: node

(when (executable-find "node")


;; -----------------------------------------------------------------------------
;; Tree-sitter grammars
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(typescript "https://github.com/tree-sitter/tree-sitter-typescript"
                            "master" "typescript/src"))
  (add-to-list 'treesit-language-source-alist
               '(tsx "https://github.com/tree-sitter/tree-sitter-typescript"
                     "master" "tsx/src"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Project root detection
;; -----------------------------------------------------------------------------

;; Ensure eglot and project.el find the project root for node projects that
;; may not have a .git directory at the TS root.
(use-package project
  :config
  (dolist (marker '("tsconfig.json" "jsconfig.json" "package.json"))
    (add-to-list 'project-vc-extra-root-markers marker))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + rass tslint
;;
;; rass tslint multiplexes:
;;   - typescript-language-server  (completions, types, inlay hints, code actions)
;;   - vscode-eslint-language-server (lint diagnostics via ESLint)
;;
;; Eglot's native $/streamDiagnostics support lets both servers' diagnostics
;; appear incrementally without waiting for aggregation.
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook ((typescript-ts-mode . eglot-ensure)
         (tsx-ts-mode        . eglot-ensure)
         (typescript-ts-mode . myde-typescript-mode-hook)
         (tsx-ts-mode        . myde-typescript-mode-hook))
  :config
  (add-to-list 'eglot-server-programs
               `((typescript-ts-mode tsx-ts-mode)
                 . ("rass" "tslint"
                    :initializationOptions
                    (:preferences
                     (:includeInlayParameterNameHints "all"
                      :includeInlayParameterNameHintsWhenArgumentMatchesName t
                      :includeInlayFunctionParameterTypeHints t
                      :includeInlayVariableTypeHints t
                      :includeInlayVariableTypeHintsWhenTypeMatchesName nil
                      :includeInlayPropertyDeclarationTypeHints t
                      :includeInlayFunctionLikeReturnTypeHints t
                      :includeInlayEnumMemberValueHints t
                      :importModuleSpecifierPreference "non-relative"
                      :includeCompletionsForModuleExports t
                      :includeCompletionsWithSnippetText t
                      :completeFunctionCalls t
                      :includeAutomaticOptionalChainCompletions t)))))
  :bind (:map eglot-mode-map
              ("C-c e r" . eglot-rename)
              ("C-c e a" . eglot-code-actions)
              ("C-c e f" . eglot-format-buffer))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; TypeScript / TSX major modes (built-in, Emacs 29+)
;; -----------------------------------------------------------------------------

(use-package typescript-ts-mode
  :hook ((typescript-ts-mode . myde-typescript-ts-mode-setup)
         (tsx-ts-mode        . myde-tsx-ts-mode-setup)
         (typescript-ts-mode . myde-typescript-format-on-save-setup)
         (tsx-ts-mode        . myde-typescript-format-on-save-setup))
  :mode (("\\.ts\\'"  . typescript-ts-mode)
         ("\\.tsx\\'" . tsx-ts-mode))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Local node_modules tool resolution
;;
;; Prepends node_modules/.bin to exec-path so that project-local eslint,
;; prettier, typescript-language-server etc. shadow global installations.
;; -----------------------------------------------------------------------------

(use-package add-node-modules-path
  :hook ((typescript-ts-mode . add-node-modules-path)
         (tsx-ts-mode        . add-node-modules-path))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Formatting via apheleia + prettier
;;
;; apheleia itself is configured in prog-base.  Here we register prettier as
;; the formatter for TypeScript and TSX buffers.
;; -----------------------------------------------------------------------------

(use-package apheleia
  :after apheleia
  :config
  (setf (alist-get 'typescript-ts-mode apheleia-mode-alist) 'prettier)
  (setf (alist-get 'tsx-ts-mode        apheleia-mode-alist) 'prettier)
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Test runner: jest-test-mode
;; -----------------------------------------------------------------------------

(use-package jest-test-mode
  :hook ((typescript-ts-mode . jest-test-mode)
         (tsx-ts-mode        . jest-test-mode))
  :bind (:map jest-test-mode-map
              ;; Remap from default C-c C-t prefix to module-standard C-c t
              ("C-c C-t t" . nil)
              ("C-c C-t n" . nil)
              ("C-c C-t p" . nil)
              ("C-c C-t a" . nil)
              ("C-c t t"   . jest-test-run-at-point)
              ("C-c t f"   . jest-test-run)
              ("C-c t p"   . jest-test-run-all-tests)
              ("C-c t r"   . jest-test-rerun-test))
  :custom
  (jest-test-options '("--no-coverage"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; TypeScript REPL via ts-comint
;; -----------------------------------------------------------------------------

(use-package ts-comint
  :after typescript-ts-mode
  :bind (:map typescript-ts-mode-map
              ("C-c i i" . run-ts)
              ("C-c i r" . ts-send-region)
              ("C-c i b" . ts-send-buffer)
              ("C-c i s" . ts-send-buffer-and-go))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Debugging via dape + @vscode/js-debug
;;
;; Requires: npm install -g @vscode/js-debug
;; -----------------------------------------------------------------------------

(use-package dape
  :after dape
  :config
  (add-to-list 'dape-configs
               '(ts-node-script
                 modes (typescript-ts-mode tsx-ts-mode)
                 command "node"
                 command-args ("${userHome}/node_modules/@vscode/js-debug/src/dapDebugServer.js" "0")
                 :type "pwa-node"
                 :request "launch"
                 :runtimeExecutable "ts-node"
                 :program dape-buffer-default
                 :cwd "${workspaceFolder}"
                 :sourceMaps t
                 :console "integratedTerminal"))
  (add-to-list 'dape-configs
               '(ts-jest
                 modes (typescript-ts-mode tsx-ts-mode)
                 command "node"
                 command-args ("${userHome}/node_modules/@vscode/js-debug/src/dapDebugServer.js" "0")
                 :type "pwa-node"
                 :request "launch"
                 :runtimeExecutable "npx"
                 :runtimeArgs ["jest" "--testPathPattern" "${relativeFile}" "--no-coverage" "--runInBand"]
                 :cwd "${workspaceFolder}"
                 :sourceMaps t
                 :console "integratedTerminal"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Org Babel
;; -----------------------------------------------------------------------------

(use-package ob-typescript  ;; https://github.com/lurdan/ob-typescript
  :after org
  :ensure t)

(use-package indent-bars
  :hook ((typescript-ts-mode tsx-ts-mode) . indent-bars-mode)
  :ensure nil)

  )

;;;; text-base
;;;; ---------


(use-package text-mode
  :hook (text-mode . myde-text-mode-hook-function)
  :ensure nil)

;;;; text-asciidoc
;;;; -------------


;; -----------------------------------------------------------------------------
;; AsciiDoc major mode
;; -----------------------------------------------------------------------------

(use-package adoc-mode  ;; https://github.com/bbatsov/adoc-mode
  :mode (("\\.adoc\\'"     . adoc-mode)
         ("\\.asciidoc\\'" . adoc-mode)
         ("\\.asc\\'"      . adoc-mode))
  :hook ((adoc-mode . myde-adoc-mode-setup)
         (adoc-mode . visual-line-mode)
         (adoc-mode . flycheck-mode)
         (adoc-mode . myde-delete-trailing-whitespace-setup))
  :bind (:map adoc-mode-map
              ("C-c C-p"   . myde-adoc-preview)
              ("C-c C-e h" . myde-adoc-export-html)
              ("C-c C-e p" . myde-adoc-export-pdf))
  :ensure t)

;;;; text-markdown
;;;; -------------


;; -----------------------------------------------------------------------------
;; Markdown mode
;; -----------------------------------------------------------------------------

(use-package markdown-mode  ;; https://github.com/jrblevin/markdown-mode
  :custom
  (markdown-command "pandoc")
  :mode (("\\.md\\'"        . gfm-mode)
         ("README\\.md\\'"  . gfm-mode))
  :hook ((markdown-mode . myde-markdown-mode-setup)
         (markdown-mode . visual-line-mode)
         (markdown-mode . visual-wrap-prefix-mode)
         (markdown-mode . myde-delete-trailing-whitespace-setup))
  :bind (:map markdown-mode-map
              ;; Free C-c C-e (markdown-do) to use as an export prefix.
              ;; markdown-do remains available at its default C-c C-d binding.
              ("C-c C-e"   . nil)
              ("C-c C-e h" . myde-markdown-export-html)
              ("C-c C-e p" . myde-markdown-export-pdf)
              ("C-c v"     . visual-fill-column-mode)
              ("C-c t"   . markdown-table-align))
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
              ("C-c C-p" . markdown-preview-mode))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Live preview via grip-mode (secondary; GitHub-rendered, no mermaid)
;; -----------------------------------------------------------------------------

(use-package grip-mode  ;; https://github.com/seagle0128/grip-mode
  :after markdown-mode
  :custom
  (grip-real-time-refresh t)
  :bind (:map markdown-mode-map
              ("C-c C-g" . grip-mode))
  :ensure t)

;;;; ebook-epub
;;;; ----------


(use-package nov  ;; https://depp.brause.cc/nov.el
  :after xdg
  :custom
  (nov-text-width 80)
  (nov-save-place-file (expand-file-name "emacs/nov-places" (xdg-state-home)))
  :hook
  ((nov-mode . visual-line-mode)
   (nov-mode . variable-pitch-mode))
  :mode
  ("\\.epub\\'" . nov-mode)
  :ensure t)

;;;; ebook-pdf
;;;; ---------
;; Gate: pdftoppm

(when (executable-find "pdftoppm")




(use-package pdf-tools  ;; https://github.com/vedang/pdf-tools
  :custom
  (pdf-view-display-size 'fit-width)
  (pdf-view-resize-factor 1.1)
  (pdf-view-use-scaling t)        ;; Improve rendering responsiveness
  (pdf-view-use-imagemagick nil)
  (pdf-view-continuous t)         ;; Continuous scrolling
  :config
  (pdf-tools-install)             ;; Compile/install epdfinfo server automatically
  :bind (:map pdf-view-mode-map
              ("C-s" . isearch-forward)
              ("h" . pdf-annot-add-highlight-markup-annotation)
              ("t" . pdf-annot-add-text-annotation))
  :mode ("\\.pdf\\'" . pdf-view-mode)
  :ensure t)

  )

;; A daemon starts its own server from startup.el after init; only GUI and
;; TTY sessions need one here.  This runs after the configuration above, as it
;; did when it lived at the end of the bootstrap block.
(unless (daemonp)
  (require 'server)
  (unless (server-running-p) (server-start)))

;; That's all Folks!
(provide 'init)
;;; init.el ends here
