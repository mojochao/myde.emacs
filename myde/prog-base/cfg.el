;;; cfg.el --- Programming base configuration -*- coding: utf-8; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(unless (featurep 'myde-prog-base)
  (load-file (expand-file-name "myde/prog-base/lib.el" user-emacs-directory)))

;; Configure display of line numbers and current line highlighting
(add-hook 'prog-mode-hook #'myde/prog-mode-hook-function)
(add-hook 'prog-mode-hook #'myde/delete-trailing-whitespace-setup)

(provide 'myde-prog-base-cfg)
;;; cfg.el ends here
