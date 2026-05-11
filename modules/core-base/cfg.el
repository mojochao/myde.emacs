;;; cfg.el --- Core base configuration -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Foundation module loaded first; all other modules depend on the paths and
;; package system established here.
;;
;; Configures:
;;   - XDG-compliant paths for state/cache/data via xdg.el (early require)
;;   - ELPA package archives (MELPA, GNU, NonGNU) and package-initialize
;;   - recentf, saveplace, savehist, transient with XDG-relative persistence files
;;   - buffer-guardian for auto-save on focus loss (replaces backup files)
;;   - exec-path-from-shell on macOS GUI (deferred to emacs-startup-hook)
;;   - dired with GNU ls (gls) and --group-directories-first on macOS
;;   - goto-address: URL/email fontification + browse-url-at-point on C-c u
;;
;; Note: Native compilation cache redirection happens in early-init.el


;;; Code:

(unless (featurep 'myde-core-base)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; XDG directory support — load early so all XDG paths are available immediately.
(require 'xdg)

;; Disable backup files (handled by buffer-guardian)
(setq make-backup-files nil)

;; Store backups in XDG state directory
(let ((backup-dir (expand-file-name "emacs/backup" (xdg-state-home))))
  (setq backup-directory-alist `(("." . ,backup-dir)))
  (make-directory backup-dir :parents))

;; Package initialization — must run before custom.el is loaded because
;; package-vc-selected-packages' :set function triggers package-vc--ensure,
;; which calls package-vc-install and requires an initialized package system.
(require 'package)
(setq package-user-dir (expand-file-name "elpa" user-emacs-directory))

(setq package-archives
      '(("gnu"          . "https://elpa.gnu.org/packages/")
        ("nongnu"       . "https://elpa.nongnu.org/nongnu/")
        ("melpa"        . "https://melpa.org/packages/")
        ("melpa-stable" . "https://stable.melpa.org/packages/")))

(setq package-archive-priorities
      '(("gnu"    . 99)
        ("nongnu" . 80)
        ("melpa"  . 70)
        ("melpa-stable" . 50)))

;; Pin built-in packages that should never be managed by the external package
;; system.  Pinning to the non-existent "builtin" archive causes package.el to
;; omit them from package-archive-contents entirely, so package-upgrade-all
;; never sees them as upgradeable even when package-install-upgrade-built-in
;; is t.  Both variables and these built-ins exist in Emacs 29+ (30 and 31).
(dolist (pkg '(csharp-mode wallpaper))
  (add-to-list 'package-pinned-packages (cons pkg "builtin")))

;; Disable automatic upgrade of built-in packages.  Built-ins that have been
;; upgraded into elpa (org, tramp, transient) are handled by the standard
;; first condition in package--upgradeable-packages (installed elpa version vs
;; archive version).  Keeping this t permanently re-adds upgraded built-ins to
;; the upgradeable list via a separate built-in version check, which causes
;; spurious "Cannot upgrade 'X'" errors once the elpa version matches the
;; archive.
(setq package-install-upgrade-built-in nil)
(package-initialize)
;; Refresh package archives only on first run (empty package-user-dir).
;; Avoids blocking startup once packages are installed.
(unless (file-exists-p package-user-dir)
  (package-refresh-contents))

;; Load user customizations after the package system is initialized so that
;; package-vc-selected-packages' :set handler can find installed packages.
(let* ((path (expand-file-name "custom.el" user-emacs-directory))
       (exists (file-exists-p path)))
  (setq custom-file path)
  (when exists
    (load-file custom-file)))

;; TRAMP connection cache
(setq tramp-persistency-file-name
      (expand-file-name "emacs/tramp" (xdg-state-home)))

;; URL library configuration (cookies, cache)
(setq url-configuration-directory
      (expand-file-name "emacs/url/" (xdg-cache-home)))

;; Auto-detect shebang comments and use shell-script-mode appropriately.
(dolist (interp '("bash" "sh" "zsh"))
  (add-to-list 'interpreter-mode-alist (cons interp 'shell-script-mode)))

;; Environment variables from shell initialization
;; NOTE: This is only needed on macOS where GUI applications don't inherit
;; the shell environment. On Linux, Emacs already has the correct environment
;; from the login shell via execve.
;; Installation and initialization are both deferred to emacs-startup-hook so
;; that neither the package download nor the shell subprocess can block init.
(when (memq window-system '(mac ns))
  (add-hook 'emacs-startup-hook #'myde-exec-path-from-shell-startup-hook 90))

;; Recent files management
(use-package recentf
  :init
  (setq recentf-save-file
        (expand-file-name "emacs/recentf.eld" (xdg-state-home)))
  :config
  (recentf-mode t)
  (setq recentf-auto-cleanup (if (daemonp) 300 'never))
  (setq recentf-exclude
        '("^/tmp/" "^/ssh:" "/COMMIT_EDITMSG\\'"
          "/bookmarks" "/info/" "/diary$" "/\\.elpa/"))
  (add-hook 'kill-emacs-hook #'recentf-cleanup -90)
  :commands (recentf-mode recentf-cleanup)
  :diminish recentf-mode
  :ensure nil)

;; Remember last position within files
(use-package saveplace
  :init
  (setq save-place-file
        (expand-file-name "emacs/places.eld" (xdg-state-home)))
  :config
  (save-place-mode)
  :diminish save-place-mode
  :ensure nil)

;; Remember minibuffer history
(use-package savehist
  :init
  (setq savehist-file
        (expand-file-name "emacs/history" (xdg-state-home)))
  :config
  (savehist-mode)
  :diminish savehist-mode
  :ensure nil)

;; Bookmarks (`M-x bookmark-set' et al.) — `bookmark-default-file' defaults
;; to <user-emacs-directory>/bookmarks, which lands in the repo root since
;; ~/.config/emacs is symlinked there.  Redirect to XDG state.
(use-package bookmark
  :init
  (setq bookmark-default-file
        (expand-file-name "emacs/bookmarks" (xdg-state-home)))
  :ensure nil)

;; Transient menus and popups — XDG-compliant persistence paths.
(use-package transient
  :init
  (let ((dir (expand-file-name "emacs/transient" (xdg-data-home))))
    (setq transient-levels-file  (expand-file-name "levels.el"  dir)
          transient-values-file  (expand-file-name "values.el"  dir)
          transient-history-file (expand-file-name "history.el" dir)))
  :ensure nil)

;; Pin transient to the archive whose compat requirement matches the running
;; Emacs.  MELPA transient requires (compat (31 0)), which the built-in compat
;; satisfies only on Emacs 31+ (built-in version is (major minor 9999)).
;; melpa-stable transient requires only (compat (30 1)), satisfiable on both.
(use-package transient
  :if (= emacs-major-version 30)
  :pin "melpa-stable"
  :ensure nil)

(use-package transient
  :if (>= emacs-major-version 31)
  :pin "melpa"
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
  (after-init . buffer-guardian-mode)
  :diminish buffer-guardian-mode
  :ensure t)

;; Tree-sitter grammar storage — redirect both load path and install path to
;; the XDG data dir.  `treesit-extra-load-path' tells Emacs where to find
;; compiled grammars.  The `:around' advice on `treesit-install-language-grammar'
;; ensures all callers (including `treesit-auto') write grammars to the same
;; XDG location rather than the default `user-emacs-directory/tree-sitter/'.
(use-package treesit
  :init
  (let ((dir (expand-file-name "emacs/tree-sitter" (xdg-data-home))))
    (make-directory dir :parents)
    (setq treesit-extra-load-path (list dir)))
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
  :bind (("C-c u" . browse-url-at-point))
  :config
  ;; macOS trackpads have no native middle-click.  Plain mouse-1 stays
  ;; as point movement; Super+click follows the link (on macOS, Super
  ;; is whichever physical key the user has mapped to it — Cmd by
  ;; default).  Disabling `mouse-1-click-follows-link' is what
  ;; prevents Emacs from translating a quick plain mouse-1 on a
  ;; `follow-link' overlay into a virtual mouse-2 click.
  (setq mouse-1-click-follows-link nil)
  (define-key goto-address-highlight-keymap [s-mouse-1] #'goto-address-at-point)
  (global-goto-address-mode 1)
  :ensure nil)

;; macOS-specific setup
(use-package emacs
  :if (string= system-type "darwin")
  :config
  (setq dired-use-ls-dired t)
  (setq insert-directory-program
        (or (executable-find "gls") insert-directory-program))
  (setq dired-listing-switches "-aBhl --group-directories-first")
  :ensure nil)

(provide 'myde-core-base-cfg)
;;; cfg.el ends here
