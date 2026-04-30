;;; early-init.el --- Emacs early initialization -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;; Loaded before init.el and before Emacs startup.el creates directories.
;; This file is the highest-leverage place to optimize startup: runs before
;; the GUI initializes and before package loading begins.

;;; Code:

;;;; Garbage collection optimization

;; Garbage collection is a major contributor to slow startup. Temporarily
;; disable it during init by raising the threshold to its maximum value.
;; This will be restored to a sensible value after init completes.
(defvar myde--gc-cons-threshold gc-cons-threshold)
(defvar myde--gc-cons-percentage gc-cons-percentage)
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 1.0)

(defun myde--restore-gc ()
  "Restore garbage collection to normal values after init."
  (setq gc-cons-threshold (* 32 1024 1024)  ; 32 MB (vs. default 800 KB)
        gc-cons-percentage 0.1))

(add-hook 'emacs-startup-hook #'myde--restore-gc 105)

;;;; File name handler optimization

;; The `file-name-handler-alist' is checked on every file operation.
;; Temporarily clearing it during startup saves thousands of regex checks.
;; We restore it after init so TRAMP and other handlers work normally.
(defvar myde--file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

(defun myde--restore-file-name-handler-alist ()
  "Restore `file-name-handler-alist' after init."
  (setq file-name-handler-alist
        (delete-dups (append file-name-handler-alist
                            myde--file-name-handler-alist))))

(add-hook 'emacs-startup-hook #'myde--restore-file-name-handler-alist 104)

;;;; Package system configuration

;; Prevent package.el from auto-initializing before init.el runs.
;; This prevents package-initialize from running twice (once here, once in init.el).
(setq package-enable-at-startup nil)

;; Use package archives with priority: GNU > NonGNU > MELPA > MELPA-stable
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

;;;; Load preference and use-package optimization

;; Prefer newer compiled files (.elc, .eln) over their .el sources.
(setq load-prefer-newer t)

;; use-package configuration for fast startup:
;; - Minimize macro expansion output to reduce init overhead
(setq use-package-expand-minimally t
      use-package-verbose nil
      use-package-minimum-reported-time (if init-file-debug 0 0.1)
      use-package-ensure-function #'package-install)

;;;; Frame setup (avoid redraw overhead)

;; Set frame parameters early to avoid expensive mode function calls
;; (tool-bar-mode, menu-bar-mode, scroll-bar-mode all trigger redraws).
;; We use default-frame-alist to set these once and avoid redundant calls.
(setq default-frame-alist
      '((menu-bar-lines . 0)      ; disable menu bar
        (tool-bar-lines . 0)      ; disable tool bar
        (vertical-scroll-bars)    ; disable scroll bars
        (horizontal-scroll-bars)))

;;;; Early frame optimization

;; Prevent Emacs from trying to resize the frame to a specific column size.
(setq frame-inhibit-implied-resize t)

;; Resizing the frame when changing the font is expensive. Defer this.
(setq frame-resize-pixelwise t)

;;;; File name handler optimization (filesystem checks)

;; A second, case-insensitive pass over auto-mode-alist is redundant.
(setq auto-mode-case-fold nil)

;;;; Font cache optimization

;; Font compacting can be very resource-intensive, especially on Windows.
;; Disable it to improve startup times.
(setq inhibit-compacting-font-caches t)

;;;; Process buffer optimization

;; Increase how much is read from processes in a single chunk.
;; This improves performance for LSP servers and other subprocesses.
(setq read-process-output-max (* 2 1024 1024))  ; 2 MB
(setq process-adaptive-read-buffering nil)

;;;; Initial buffer optimization

;; The initial buffer is created during startup. Using fundamental-mode
;; avoids loading extra packages and running hooks from lisp-interaction-mode.
(setq initial-major-mode 'fundamental-mode
      initial-scratch-message nil)

;;;; Startup screen suppression

;; Disable startup screens and messages for a cleaner, faster experience.
(setq inhibit-startup-screen t
      inhibit-startup-echo-area-message user-login-name
      inhibit-startup-buffer-menu t
      inhibit-x-resources t)

;; Suppress the "For information about GNU Emacs..." message at startup.
(advice-add 'display-startup-echo-area-message :override #'ignore)
(advice-add 'display-startup-screen :override #'ignore)

;;;; Input/Output optimization

;; Don't ping things that look like domain names.
(setq ffap-machine-p-known 'reject)

;;;; XDG path redirection (must stay here — before init.el)

;; This must be set in early-init.el because Emacs creates the directory
;; from the default value before init.el runs.
(let ((state-home (or (getenv "XDG_STATE_HOME")
                      (expand-file-name ".local/state" "~"))))
  (setq auto-save-list-file-prefix
        (expand-file-name "emacs/auto-save-list/.saves-" state-home)))

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))

;;;; Security settings

(setq gnutls-verify-error t)
(setq tls-checktrust t)
(setq gnutls-min-prime-bits 3072)

;;;; Miscellaneous optimizations

(set-language-environment "UTF-8")

;; Suppress warnings from the legacy advice API.
(setq ad-redefinition-action 'accept)

;; In PGTK, this timeout introduces latency. Reducing it improves responsiveness.
(when (boundp 'pgtk-wait-for-event-timeout)
  (setq pgtk-wait-for-event-timeout 0.001))

(setq warning-minimum-level (if init-file-debug :warning :error))
(setq warning-suppress-types '((lexical-binding)))

(when init-file-debug
  (setq message-log-max 16384))

(provide 'early-init)
;;; early-init.el ends here
