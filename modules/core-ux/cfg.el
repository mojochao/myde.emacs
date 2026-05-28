;;; cfg.el --- Core UX configuration -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Interaction quality-of-life: keyboard ergonomics, editing conveniences,
;; and global behavioral defaults.
;;
;; Configures:
;;   - macOS modifier swap: command → meta, option → super (GUI only)
;;   - global-auto-revert-mode, delete-selection-mode, vc-follow-symlinks
;;   - suppress kill-buffer-with-process and nonexistent-file confirmations
;;   - expreg for semantic region expand/contract (C-= / C--)
;;   - surround for Vim-style pair editing (M-' keymap)
;;   - multiple-cursors for multi-point editing (C->, C-<, C-S-c C-S-c)
;;   - whole-line-or-region to operate on the current line when no region is active
;;   - pathaction for path-based action dispatch via .pathaction files
;;   - smooth pixel-precise scrolling via ultra-scroll (supports emacs-mac, NS, pgtk)


;;; Code:

(unless (featurep 'myde-core-ux)
  (load-file (expand-file-name "modules/core-ux/lib.el" user-emacs-directory)))

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

;; Squelch prompt on exit when active processes (e.g. mcp-server) are running
(setq confirm-kill-processes nil)

;; Use 'y'/n' instead of 'yes'/'no' for confirmations (Emacs 30+)
(setq use-short-answers t)

;; Global keyboard remap
(global-set-key [remap keyboard-quit] #'myde-keyboard-quit)
(global-set-key (kbd "M-Z") #'zap-up-to-char)

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
  :config
  (setq mc/list-file
        (expand-file-name "emacs/mc-lists.el" (xdg-state-home)))
  (setq mc/always-run-for-all t)   ;; Make cursor movement more predictable
  :ensure t)

;; Operate on whole line or region
(use-package whole-line-or-region  ;; https://github.com/purcell/whole-line-or-region
  :hook (after-init . whole-line-or-region-global-mode)
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

(provide 'myde-core-ux-cfg)
;;; cfg.el ends here
