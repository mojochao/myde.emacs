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

(provide 'myde-prog-base-cfg)
;;; cfg.el ends here
