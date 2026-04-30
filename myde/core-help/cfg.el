;;; cfg.el --- Help packages configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Help/docs packages configuration for user help support.
;;; Entry point for the core-help module; loads lib.el automatically.


;;; Code:

(unless (featurep 'myde-core-help)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

(use-package eldoc
  :config
  (setq eldoc-idle-delay most-positive-fixnum)  ;; Disable automatic echo-area display; docs are shown on demand with C-c e h.
  :ensure nil)

(use-package eldoc-box  ;; https://github.com/casouri/eldoc-box
  :bind (("C-c e h" . eldoc-box-help-at-point)
         ("C-c e q" . eldoc-box-quit-frame))
  :ensure t)

(use-package helpful  ;; https://github.com/Wilfred/helpful
  :bind
  (("C-c C-d" . helpful-at-point)
   ("C-h f" . helpful-callable)
   ("C-h F" . helpful-function)
   ("C-h k" . helpful-key)
   ("C-h v" . helpful-variable))
  :ensure t)

(use-package which-key
  :hook (after-init . which-key-mode)
  :diminish which-key-mode
  :ensure nil)

(provide 'myde-core-help-cfg)
;;; cfg.el ends here
