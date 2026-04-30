;;; cfg.el --- Nushell package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for Nushell script development support.
;;; Entry point for the prog-nushell module; loads lib.el automatically.
;;;
;;; nu --lsp is built into nushell >= 0.87.0; no separate server install needed.
;;;
;;; nufmt (pre-alpha formatter) is registered in apheleia but NOT auto-enabled.
;;; Users can invoke M-x apheleia-format-buffer manually or opt-in per-project
;;; via .dir-locals.el if they accept the pre-alpha risks.


;;; Code:

(unless (featurep 'myde-prog-nushell)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Tree-sitter grammar
;;
;; nushell/tree-sitter-nu is official and actively maintained (last push March 2026).
;; Unused now since no proper ts-mode exists on MELPA, but the grammar is
;; registered and ready for when nushell-ts-mode materialises.
;; -----------------------------------------------------------------------------

(use-package treesit
  :config
  (add-to-list 'treesit-language-source-alist
               '(nu "https://github.com/nushell/tree-sitter-nu"
                    "main" "src"))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; LSP via eglot + nu --lsp
;;
;; nu --lsp is built into nushell >= 0.87.0.  No separate server install.
;; Provides: completions, hover (with manpages for external commands),
;; go-to-definition, diagnostics (parse errors/warnings), rename.
;; Does NOT (yet) expose code actions or formatting through LSP.
;; -----------------------------------------------------------------------------

(use-package eglot
  :hook (nushell-mode . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '((nushell-mode) . ("nu" "--lsp")))
  :bind (:map eglot-mode-map
              ("C-c e r" . eglot-rename)
              ("C-c e a" . eglot-code-actions)
              ("C-c e f" . eglot-format-buffer))
  :ensure nil)

;; -----------------------------------------------------------------------------
;; Nushell major mode
;;
;; nushell-mode (MELPA) is regex-based, actively maintained (Nov 2025).
;; nushell-ts-mode exists but is abandoned (Sept 2023) and not on MELPA,
;; so we use the MELPA version.
;; .nu files and #!/usr/bin/env nu shebangs both activate nushell-mode.
;; REPL keybindings use C-c i (C-c i, C-c i r, C-c i b, C-c i x).
;; -----------------------------------------------------------------------------

(use-package nushell-mode
  :hook (nushell-mode . myde/nushell-mode-setup)
  :mode (("\\.nu\\'" . nushell-mode))
  :bind (:map nushell-mode-map
              ("C-c i i" . myde/nushell-open-repl)
              ("C-c i r" . myde/nushell-send-region)
              ("C-c i b" . myde/nushell-send-buffer)
              ("C-c i x" . myde/nushell-run-buffer))
  :config
  (add-to-list 'interpreter-mode-alist '("nu" . nushell-mode))
  :ensure t)

;; Add trailing whitespace cleanup
(add-hook 'nushell-mode-hook #'myde/delete-trailing-whitespace-setup)

;; -----------------------------------------------------------------------------
;; Formatting via apheleia + nufmt (OPT-IN ONLY)
;;
;; DESIGN DECISION: nufmt is pre-alpha and can corrupt scripts.
;;
;; nushell/nufmt explicitly warns in its README:
;;   "Some of the outputs deletes comments, break the functionality of the
;;    script or doesn't format at all. Do not use in productive nushell scripts!"
;;
;; CONS of registering in apheleia-mode-alist (auto-format on save):
;;   - Silent data loss: formatter breaks code silently, without compiler error
;;   - User saves a file, formatter corrupts it, they don't notice until runtime
;;   - Breaks contrast with prod-ready formatters (shfmt, prettier) elsewhere
;;   - No escape hatch: disabling requires per-file variable or opt-out config
;;
;; CONS of the current opt-in approach:
;;   - Users must discover M-x apheleia-format-buffer manually
;;   - No "magical" auto-formatting experience
;;   - Requires per-project .dir-locals.el to enable
;;
;; VERDICT: Auto-corruption risk >> UX loss. Silent breakage is worse than
;; no automation. Opt-in is correct until nufmt stabilizes.
;;
;; Users can:
;;   1. Invoke M-x apheleia-format-buffer manually to test
;;   2. Enable per-project (if they accept the risk) via .dir-locals.el:
;;      ((nushell-mode . ((apheleia-mode . t))))
;; (This requires apheleia to be loaded; it's configured in prog-base.)
;; -----------------------------------------------------------------------------

(use-package apheleia
  :config
  ;; Register nufmt formatter (not auto-enabled)
  (add-to-list 'apheleia-formatters
               '(nufmt . ("nufmt" "--stdin")))
  :ensure nil)

(provide 'myde-prog-nushell-cfg)
;;; cfg.el ends here
