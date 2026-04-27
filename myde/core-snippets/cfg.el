;;; cfg.el --- Snippets package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Snippets configuration for yasnippets support.
;;; Entry point for the core-snippets module; loads lib.el automatically.

;;; Code:

(unless (featurep 'myde-core-snippets)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

(use-package yasnippet  ;; https://github.com/joaotavora/yasnippet
  :config
  (setq yas-snippet-dirs (cons (expand-file-name "snippets" user-emacs-directory) yas-snippet-dirs))
  (yas-global-mode 1)
  ;; Do not bind TAB globally for snippet expansion -- it conflicts with
  ;; comint/REPL completion (e.g. inf-elixir).  Snippets can still be
  ;; expanded via `yas-insert-snippet' or the `yas-minor-mode-map' binding.
  (define-key yas-minor-mode-map (kbd "TAB") nil)
  (define-key yas-minor-mode-map [(tab)] nil)
  :ensure t)

(use-package yasnippet-classic-snippets  ;; https://elpa.gnu.org/packages/yasnippet-classic-snippets.html
  :after yasnippet
  :ensure t)

(provide 'myde-core-snippets-cfg)
;;; cfg.el ends here
