;;; pre-early-init.el --- Loaded before early-init.el -*- no-byte-compile: t; lexical-binding: t; -*-

;; By default, minimal-emacs-package-initialize-and-refresh is set to t, which
;; makes minimal-emacs.d call the built-in package manager. Since Elpaca will
;; replace the package manager, there is no need to call it.
(setq minimal-emacs-package-initialize-and-refresh nil)

;; Configure basic UI
(setq minimal-emacs-ui-features '(context-menu menu-bar dialogs tooltips))
