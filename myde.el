;;; myde.el --- Loaded early in post-init.el -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Library code used by user config in post-init.el file.

;;; Code:

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

;; -----------------------------------------------------------------------------
;; Terraform/OpenTofu support
;; -----------------------------------------------------------------------------

(defcustom myde/terraform-exe "terraform"
  "Path to the terraform or tofu executable."
  :type 'string
  :group 'terraform)

(defun myde/terraform-format-buffer ()
  "Format the current buffer with terraform executable fmt subcommand."
  (interactive)
  (when (or (executable-find "terraform") (executable-find "terraform"))
    (call-process-region (point-min) (point-max) myde/terraform-exe t t nil "fmt" "-")))

(define-minor-mode myde/terraform-format-on-save-mode
  "Auto-format Terraform buffer on save using terraform fmt."
  :lighter " fmt"
  (if terraform-format-on-save-mode
      (add-hook 'before-save-hook #'myde/terraform-format-buffer nil t)
    (remove-hook 'before-save-hook #'myde/terraform-format-buffer t)))

;; -----------------------------------------------------------------------------
;; Project tree explorer support
;; -----------------------------------------------------------------------------

(defun myde/neotree-project-root-toggle ()
  "Toggle NeoTree.  If opening, set the root to the current 'project' root."
  (interactive)
  (if (and (fboundp 'neo-global--window-exists-p)
           (neo-global--window-exists-p))
      (neotree-hide)
    (let ((project (project-current)))
      (if project
          (neotree-dir (project-root project))
        (neotree-show)))))

(defun myde/neotree-refresh ()
  "Refresh neotree if visible."
  (when (neo-global--window-exists-p)
    (neo-buffer--refresh)))

(defun myde/neotree-window-size-change-function (frame)
  (let ((neo-window (neo-global--get-window)))
    (unless (null neo-window)
      (setq neo-window-width (window-width neo-window)))))

;; -----------------------------------------------------------------------------
;; Generic programming modes support
;; -----------------------------------------------------------------------------

(defun myde/prog-mode-hook-function ()
  (display-line-numbers-mode t))

(defun myde/delete-trailing-whitespace-setup ()
  "Delete trailing whitespace on save."
  (add-hook 'before-save-hook #'delete-trailing-whitespace nil t))

(defun myde/mise-exec-which (dir exe)
  "Resolve EXE path via mise exec for project in DIR."
  (let ((default-directory (or dir
                               (and (buffer-file-name (buffer-base-buffer))
                                    (file-name-directory (buffer-file-name (buffer-base-buffer))))
                               default-directory)))
    (list (string-trim
           (shell-command-to-string
            (concat mise-executable " exec -- which " exe))))))

;; -----------------------------------------------------------------------------
;; eglot support
;; -----------------------------------------------------------------------------

(defun myde/eglot-add-workspace-config (server-key config)
  "Upsert CONFIG for SERVER-KEY in `eglot-workspace-configuration'.
Safe to call from multiple language modules independently; replaces
any existing entry for SERVER-KEY without clobbering other languages."
  (setq-default eglot-workspace-configuration
                (cons (cons server-key config)
                      (assq-delete-all server-key
                                       (default-value
                                         'eglot-workspace-configuration)))))

;; -----------------------------------------------------------------------------
;; Org mode setup
;; -----------------------------------------------------------------------------

(defvar myde/org-directory "~/org/")
(defvar myde/reading-notes "~/org/reading/")
(defvar myde/highlight-file "~/org/highlights.org")

(defun myde/find-org-agenda-files (root-dir)
  '("/home/agooch/Projects/platykus/org/tasks.org"
    "/home/agooch/Projects/myde/org/tasks.org"
    "/home/agooch/Projects/mydc/org/tasks.org"
    "/home/agooch/Projects/playdate/org/tasks.org"
    "/home/agooch/Projects/life/org/tasks.org"
    "/home/agooch/Projects/dayjob/org/tasks.org"))

(defun myde/reading-setup ()
  "Improve readability for long-form documents."
  (visual-line-mode 1)
  (setq-local line-spacing 0.15))

(defun myde/reading-keybindings ()
  "Unified navigation keys across readers."
  (local-set-key (kbd "i") #'org-noter)
  (local-set-key (kbd "n") #'org-noter-insert-note)
  (local-set-key (kbd "h") #'org-remark-mark)
  (local-set-key (kbd "j") #'org-noter-sync-next-note)
  (local-set-key (kbd "k") #'org-noter-sync-prev-note))

(defvar myde/denote-directory "~/org/notes/")

;; -----------------------------------------------------------------------------
;; Secrets (auth-source-1password) support
;; -----------------------------------------------------------------------------

(defun myde/auth-source-1password-construct-secret-reference
    (_backend _type host &optional user _port)
  "Construct 1Password entry path as vault/host/password (or vault/host/user/password if user provided)."
  (if user
      (mapconcat #'identity (list auth-source-1password-vault host user "password") "/")
    (mapconcat #'identity (list auth-source-1password-vault host "password") "/")))

;; -----------------------------------------------------------------------------
;; AI enablement
;; -----------------------------------------------------------------------------

(defun myde/gptel-api-key-from-environment (&optional var)
  (lambda ()
    (getenv (or var                     ;provided key
                (thread-first           ;or fall back to <TYPE>_API_KEY
                  (type-of gptel-backend)
                  (symbol-name)
                  (substring 6)
                  (upcase)
                  (concat "_API_KEY"))))))


;; -----------------------------------------------------------------------------
;; That's all folks!!!
;; -----------------------------------------------------------------------------

(provide 'myde)
;;; myde.el ends here
