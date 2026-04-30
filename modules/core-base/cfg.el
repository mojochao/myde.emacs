;;; cfg.el --- Core base configuration -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Foundation module loaded first; all other modules depend on the paths and
;; package system established here.
;;
;; Configures:
;;   - XDG-compliant paths for state/cache/data/eln via xdg.el (early require)
;;   - ELPA package archives (MELPA, GNU, NonGNU) and package-initialize
;;   - Native compilation cache redirected to $XDG_CACHE_HOME/emacs/eln-cache
;;   - recentf, saveplace, savehist, transient with XDG-relative persistence files
;;   - buffer-guardian for auto-save on focus loss (replaces backup files)
;;   - exec-path-from-shell on macOS GUI (deferred to emacs-startup-hook)
;;   - dired with GNU ls (gls) and --group-directories-first on macOS


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

;; Redirect native compilation cache
(when (featurep 'native-compile)
  (startup-redirect-eln-cache
   (expand-file-name "emacs/eln-cache" (xdg-cache-home))))

(setq package-archives
      '(("melpa"  . "https://melpa.org/packages/")
        ("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
(setq package-install-upgrade-built-in t)
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
  (add-hook 'emacs-startup-hook #'myde/exec-path-from-shell-startup-hook 90))

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

;; Transient menus and popups
(use-package transient
  :init
  (let ((dir (expand-file-name "emacs/transient" (xdg-data-home))))
    (setq transient-levels-file  (expand-file-name "levels.el"  dir)
          transient-values-file  (expand-file-name "values.el"  dir)
          transient-history-file (expand-file-name "history.el" dir)))
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

;; Tree-sitter grammar storage — redirect load path to XDG data dir.
;; `treesit-extra-load-path' tells Emacs where to find compiled grammars.
;; Use `myde/treesit-install-language-grammar' (defined in lib.el) to install
;; grammars; it passes the XDG path explicitly, avoiding the need for advice.
(use-package treesit
  :init
  (let ((dir (expand-file-name "emacs/tree-sitter" (xdg-data-home))))
    (make-directory dir :parents)
    (setq treesit-extra-load-path (list dir)))
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
