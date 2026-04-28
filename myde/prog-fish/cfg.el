;;; cfg.el --- Fish shell language configuration -*- coding: utf-8; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(unless (featurep 'myde-prog-fish)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

(use-package fish-mode  ;; https://github.com/emacsmirror/fish-mode
  :custom
  (fish-indent-offset 2)
  :ensure t)

(provide 'myde-prog-fish-cfg)
;;; cfg.el ends here
