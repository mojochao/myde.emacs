;;; cfg.el --- Core base configuration -*- coding: utf-8; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(unless (featurep 'myde-core-base)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; XDG directory support and built-in configuration
;; It is important that this is loaded early before we set locations
;; for the various state files written by emacs and external packages.
(use-package xdg
  :ensure nil)

(use-package emacs
  :after xdg
  :config
  ;; Load user customizations
  (let* ((path (expand-file-name "custom.el" user-emacs-directory))
         (exists (file-exists-p path)))
    (setq custom-file path)
    (when exists
      (load-file custom-file)))

  ;; Disable backup files (handled by buffer-guardian)
  (setq make-backup-files nil)

  ;; Store backups in XDG state directory
  (setq backup-directory (expand-file-name "emacs/backup" (xdg-state-home))
        backup-directory-alist `(("." . ,backup-directory)))
  (make-directory backup-directory :parents)

  ;; Package initialization
  (require 'package)
  (setq package-user-dir
        (expand-file-name "emacs/elpa" (xdg-data-home)))

  ;; Redirect native compilation cache
  (when (featurep 'native-compile)
    (startup-redirect-eln-cache
     (expand-file-name "emacs/eln-cache" (xdg-cache-home))))
  
  (setq package-archives
        '(("melpa"  . "https://melpa.org/packages/")
          ("gnu"    . "https://elpa.gnu.org/packages/")
          ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
  (setq package-install-upgrade-built-in t)
  (unless package-archive-contents
    (package-refresh-contents))
  (package-initialize)

  ;; TRAMP connection cache
  (setq tramp-persistency-file-name
        (expand-file-name "emacs/tramp" (xdg-state-home)))

  ;; URL library configuration (cookies, cache)
  (setq url-configuration-directory
        (expand-file-name "emacs/url/" (xdg-cache-home))))

;; Increase subprocess read buffer size for LSP throughput (default is 4096).
(setq read-process-output-max (* 1024 1024))  ; 1 MiB

;; Auto-detect shebang comments and use shell-script-mode appropriately.
(dolist (interp '("bash" "sh" "zsh"))
  (add-to-list 'interpreter-mode-alist (cons interp 'shell-script-mode)))

;; Environment variables from shell initialization
(use-package exec-path-from-shell  ;; https://github.com/purcell/exec-path-from-shell
  :config
  (exec-path-from-shell-initialize)
  :ensure t)

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
  :ensure nil)

;; Remember last position within files
(use-package saveplace
  :after xdg
  :init
  (setq save-place-file
        (expand-file-name "emacs/places.eld" (xdg-state-home)))
  :config
  (save-place-mode)
  :ensure nil)

;; Remember minibuffer history
(use-package savehist
  :after xdg
  :init
  (setq savehist-file
        (expand-file-name "emacs/history" (xdg-state-home)))
  :config
  (savehist-mode)
  :ensure nil)

;; Transient menus and popups
(use-package transient
  :after xdg
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
  :ensure t)

;; macOS-specific setup
(use-package emacs
  :if (string= system-type "darwin")
  :config
  (setq dired-use-ls-dired t)
  (setq insert-directory-program "/usr/local/bin/gls")
  (setq dired-listing-switches "-aBhl --group-directories-first")
  :ensure nil)

(provide 'myde-core-base-cfg)
;;; cfg.el ends here
