;;; cfg.el --- YAML editing configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; YAML mode setup for .yaml and .yml files.

;;; Code:

(unless (featurep 'myde-data-yaml)
  (load-file (expand-file-name "myde/data-yaml/lib.el" user-emacs-directory)))

;; YAML editing support
(use-package yaml-mode  ;; https://github.com/yoshiki/yaml-mode
  :mode
  (("\\.yaml\\'" . yaml-mode)
   ("\\.yml\\'" . yaml-mode))
  :ensure t)

(provide 'myde-data-yaml-cfg)
;;; cfg.el ends here
