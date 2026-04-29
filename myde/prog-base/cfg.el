;;; cfg.el --- Programming base configuration -*- coding: utf-8; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(unless (featurep 'myde-prog-base)
  (load-file (expand-file-name "myde/prog-base/lib.el" user-emacs-directory)))

;; Configure display of line numbers and current line highlighting
(add-hook 'prog-mode-hook #'myde/prog-mode-hook-function)
(add-hook 'prog-mode-hook #'myde/delete-trailing-whitespace-setup)

;; Consistent multi-language formatter foundation.
;; Individual language modules register their formatter via apheleia-mode-alist.
(use-package apheleia
  :config
  (apheleia-global-mode +1)
  :ensure t)

;; Structural S-expression editing for Lisp-family languages
(use-package paredit
  :ensure t
  :hook ((emacs-lisp-mode . enable-paredit-mode)
         (lisp-mode . enable-paredit-mode)
         (scheme-mode . enable-paredit-mode)
         (clojure-mode . enable-paredit-mode)
         (clojure-ts-mode . enable-paredit-mode)
         (cider-repl-mode . enable-paredit-mode)))

;; Colorize nested parentheses for readability in Lisp-family languages
(use-package rainbow-delimiters
  :ensure t
  :hook ((emacs-lisp-mode . rainbow-delimiters-mode)
         (lisp-mode . rainbow-delimiters-mode)
         (scheme-mode . rainbow-delimiters-mode)
         (clojure-mode . rainbow-delimiters-mode)
         (clojure-ts-mode . rainbow-delimiters-mode)
         (cider-repl-mode . rainbow-delimiters-mode)))

(provide 'myde-prog-base-cfg)
;;; cfg.el ends here
