;;; cfg.el --- Snippets package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for yasnippet snippet expansion.
;;; Entry point for the core-snippets module; loads lib.el automatically.
;;;
;;; TAB is explicitly unbound from yas-minor-mode-map to avoid conflicts with
;;; comint/REPL completion (e.g. inf-elixir).  Use yas-insert-snippet instead.
;;; yasnippet-classic-snippets provides a curated set of community snippets.
;;; Per-module snippets are registered via myde-register-snippets in each module.


;;; Code:

(unless (featurep 'myde-core-snippets)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

(use-package yasnippet  ;; https://github.com/joaotavora/yasnippet
  :hook (after-init . yas-global-mode)
  :config
  ;; Do not bind TAB globally for snippet expansion -- it conflicts with
  ;; comint/REPL completion (e.g. inf-elixir).  Snippets can still be
  ;; expanded via `yas-insert-snippet' or the `yas-minor-mode-map' binding.
  (define-key yas-minor-mode-map (kbd "TAB") nil)
  (define-key yas-minor-mode-map [(tab)] nil)
  :diminish yas-minor-mode
  :ensure t)

(use-package yasnippet-classic-snippets  ;; https://elpa.gnu.org/packages/yasnippet-classic-snippets.html
  :after yasnippet
  :ensure t)

(provide 'myde-core-snippets-cfg)
;;; cfg.el ends here
