;;; cfg.el --- AI base configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;; Shared AI module setup; loaded before all other ai-* modules.

;;; Code:

(unless (featurep 'myde-ai-base)
  (load-file (expand-file-name "myde/ai-base/lib.el" user-emacs-directory)))

(provide 'myde-ai-base-cfg)
;;; cfg.el ends here
