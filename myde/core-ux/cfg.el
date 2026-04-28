;;; cfg.el --- Core UX configuration -*- coding: utf-8; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(unless (featurep 'myde-core-ux)
  (load-file (expand-file-name "myde/core-ux/lib.el" user-emacs-directory)))

;; Swap option and command keys on macOS to match Linux keyboard layout
(when (and (display-graphic-p) (string-equal system-type "darwin"))
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

;; Suppress native compilation warnings for undefined functions in third-party packages.
;; These warnings don't affect runtime functionality; the functions are available at runtime.
(setq native-comp-warning-on-missing-defs nil)

;; Squelch prompt to kill buffer with process attached to it
(setq kill-buffer-query-functions
      (remq 'process-kill-buffer-query-function kill-buffer-query-functions))

;; Global keyboard remap
(global-set-key [remap keyboard-quit] #'myde/keyboard-quit)

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
         ("C->"         . mc/mark-next-like-this)      ;; add next match
         ("C-<"         . mc/mark-previous-like-this)  ;; add previous match
         ("C-c C-<"     . mc/mark-all-like-this))      ;; mark all matches
  :config
  (setq mc/list-file
        (expand-file-name "emacs/mc-lists.el" (xdg-state-home)))
  (setq mc/always-run-for-all t)   ;; Make cursor movement more predictable
  :ensure t)

;; Operate on whole line or region
(use-package whole-line-or-region  ;; https://github.com/purcell/whole-line-or-region
  :config
  (whole-line-or-region-global-mode)
  :ensure t)

;; Path action tool configuration
(use-package pathaction  ;; https://www.jamescherti.com/pathaction-el-emacs-package-universal-makefile/
  :config
  (add-to-list 'display-buffer-alist '("\\*pathaction:"
                                       (display-buffer-at-bottom)
                                       (window-height . 0.33)))
  :ensure t)

(provide 'myde-core-ux-cfg)
;;; cfg.el ends here
