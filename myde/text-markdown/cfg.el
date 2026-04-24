;;; cfg.el --- Markdown package configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Package configuration for Markdown editing support.
;;; Entry point for the text-markdown module; loads lib.el automatically.

;;; Code:

(unless (featurep 'myde-text-markdown)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Markdown mode
;; -----------------------------------------------------------------------------

(use-package markdown-mode  ;; https://github.com/jrblevin/markdown-mode
  :init
  (setq markdown-command "multimarkdown")
  :mode (("\\.md\\'"        . gfm-mode)
         ("README\\.md\\'"  . gfm-mode))
  :hook ((markdown-mode . myde/markdown-mode-setup)
         (markdown-mode . display-line-numbers-mode)
         (markdown-mode . myde/delete-trailing-whitespace-setup))
  :bind (:map markdown-mode-map
              ("C-c C-e" . markdown-do))
  :ensure t)

(provide 'myde-text-markdown-cfg)
;;; cfg.el ends here
