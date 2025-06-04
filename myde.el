;;; myde.el --- Loaded early in post-init.el -*- no-byte-compile: t; lexical-binding: t; -*-

;; Enable config for emacs in general.
(defun myde/after-init-hook-function ()
  ;; Hide warnings and display only errors
  (setq warning-minimum-level :error)
  ;; Configure cursor
  (setq-default cursor-type 'bar)
  (blink-cursor-mode 1)
  ;; Configure Emacs to ask for confirmation before exiting
  (setq confirm-kill-emacs 'y-or-n-p)
  ;; Delete region selected when overwriting it
  (delete-selection-mode 1)
  ;; Update buffer to reflect changes made to file on disk
  (global-auto-revert-mode)
  ;; Highlight current line everywhere 
  (global-hl-line-mode)
  ;; Enable clickable/selectable links for URLs in buffers
  (goto-address-mode 1)
  ;; Automatically follow links to version controlled files when opening them.
  (setq vc-follow-symlinks t)
  ;; Automatically follow links to version controlled files when opening them.
  (setq vc-follow-symlinks t)
  ;; Use pixel-based scrolling for smooth UI
  (pixel-scroll-precision-mode 1)
  ;; Remember recently accessed files
  (recentf-mode)
  (setq recentf-max-saved-items 50)
  ;; Remember last locations within files
  (save-place-mode)
  ;; Remember minibuffer history
  (savehist-mode)
  ;; Squelch annoying confirmation if a file or buffer does not exist.
  (setq confirm-nonexistent-file-or-buffer nil)
  ;; Improve display of search candidates.
  (setq isearch-lazy-count t
        lazy-count-prefix-format nil
        lazy-count-suffix-format "   (%s/%s)")    
  ;; Configure terminal text encoding
  (set-terminal-coding-system 'utf-8-unix)
  ;; Enable draggable window divider sliders
  (window-divider-mode)
  ;; Restore window layouts
  (winner-mode))

;; Enable config for programming modes in general.
(defun myde/prog-mode-hook-function ()
  (display-line-numbers-mode t))

;; Squelch annoying audible bell. Briefly flash the mode line instead.
(defun myde/flash-mode-line ()
  (invert-face 'mode-line)
  (run-with-timer 0.1 nil #'invert-face 'mode-line))
(setq visible-bell nil
      ring-bell-function 'myde/flash-mode-line)

;; Create missing dirs as needed.
(defun myde/auto-create-missing-dirs ()
  (let ((target-dir (file-name-directory buffer-file-name)))
    (unless (file-exists-p target-dir)
      (make-directory target-dir t))))
(add-to-list 'find-file-not-found-functions #'myde/auto-create-missing-dirs)

;; https://emacsredux.com/blog/2025/06/01/let-s-make-keyboard-quit-smarter/
(defun myde/keyboard-quit ()
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
