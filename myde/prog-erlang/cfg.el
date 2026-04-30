;;; cfg.el --- Erlang package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Side-effect configuration for the `myde-prog-erlang-cfg' module:
;; use-package declarations, hooks, and keybindings.  Loads the
;; sister lib.el for definitions.


;;; Code:

(unless (featurep 'myde-prog-erlang)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(erlang "https://github.com/WhatsApp/tree-sitter-erlang"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + ELP
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook (erlang-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '(erlang-mode . ("elp" "server")))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Erlang mode
;; -----------------------------------------------------------------------------

(use-package erlang  ;; https://github.com/erlang/otp (tools/emacs)
  :hook ((erlang-mode . myde/erlang-mode-setup)
         (erlang-mode . myde/delete-trailing-whitespace-setup)
         (erlang-mode . flycheck-mode))
  :bind (:map erlang-mode-map
              ("C-c i i" . erlang-shell)
              ("C-c i s" . erlang-shell-buffer)
              ("C-c i r" . inferior-erlang-send-region)
              ("C-c t p" . myde/erlang-run-tests))
  :mode (("\\.erl\\'"     . erlang-mode)
         ("\\.hrl\\'"     . erlang-mode)
         ("\\.escript\\'" . erlang-mode))
  :ensure t)

(provide 'myde-prog-erlang-cfg)
;;; cfg.el ends here
