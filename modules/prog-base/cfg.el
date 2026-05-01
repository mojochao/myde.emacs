;;; cfg.el --- Programming base configuration -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Programming foundation shared by all language modules.
;; Entry point for the prog-base module; loads lib.el automatically.
;;
;; Configures:
;;   apheleia           — global format-on-save dispatcher; individual language
;;                        modules register their formatter in apheleia-mode-alist
;;   paredit            — structural S-expression editing for Lisp-family modes
;;                        (emacs-lisp, lisp, scheme, clojure, clojure-ts, cider,
;;                        sly, slime)
;;   rainbow-delimiters — nested-parenthesis colorization for the same Lisp modes
;;   prog-mode hooks    — line numbers and trailing-whitespace cleanup on all
;;                        programming buffers


;;; Code:

(unless (featurep 'myde-prog-base)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; Configure display of line numbers and current line highlighting
(add-hook 'prog-mode-hook #'myde-prog-mode-hook-function)
(add-hook 'prog-mode-hook #'myde-delete-trailing-whitespace-setup)

;; Consistent multi-language formatter foundation.
;; Individual language modules register their formatter via apheleia-mode-alist.
(use-package apheleia
  :config
  (apheleia-global-mode +1)
  :diminish apheleia-mode
  :ensure t)

;; Structural S-expression editing for Lisp-family languages
(use-package paredit
  :hook ((emacs-lisp-mode . enable-paredit-mode)
         (lisp-mode . enable-paredit-mode)
         (scheme-mode . enable-paredit-mode)
         (clojure-mode . enable-paredit-mode)
         (clojure-ts-mode . enable-paredit-mode)
         (cider-repl-mode . enable-paredit-mode)
         (sly-mode . enable-paredit-mode)
         (slime-repl-mode . enable-paredit-mode))
  :diminish paredit-mode
  :ensure t)

;; Colorize nested parentheses for readability in Lisp-family languages
(use-package rainbow-delimiters
  :hook ((emacs-lisp-mode . rainbow-delimiters-mode)
         (lisp-mode . rainbow-delimiters-mode)
         (scheme-mode . rainbow-delimiters-mode)
         (clojure-mode . rainbow-delimiters-mode)
         (clojure-ts-mode . rainbow-delimiters-mode)
         (cider-repl-mode . rainbow-delimiters-mode)
         (sly-mode . rainbow-delimiters-mode)
         (slime-repl-mode . rainbow-delimiters-mode))
  :diminish rainbow-delimiters-mode
  :ensure t)

(provide 'myde-prog-base-cfg)
;;; cfg.el ends here
