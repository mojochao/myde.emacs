;;; cfg.el --- Completion stack configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Package configuration for the minibuffer and in-buffer completion stack:
;;;   vertico + orderless + marginalia + consult + embark + corfu
;;;
;;; Entry point for the core-complete module; loads lib.el automatically.


;;; Code:

(unless (featurep 'myde-core-complete)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Minibuffer completion
;; -----------------------------------------------------------------------------

(use-package vertico  ;; https://github.com/minad/vertico
  :hook (after-init . vertico-mode)
  :ensure t)

(use-package orderless  ;; https://github.com/oantolin/orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-pcm-leading-wildcard t)
  (completion-category-overrides '((file (styles . (partial-completion)))))
  :ensure t)

(use-package marginalia  ;; https://github.com/minad/marginalia
  :hook (after-init . marginalia-mode)
  :ensure t)

(use-package consult  ;; https://github.com/minad/consult
  :bind (("C-s"     . consult-line)
         ("C-x b"   . consult-buffer)
         ("C-x C-b" . consult-buffer)
         ("M-y"     . consult-yank-pop))
  :ensure t)

(use-package embark  ;; https://github.com/oantolin/embark
  :bind (("C-."   . embark-act)
         ("C-h B" . embark-bindings))
  :init
  (setq prefix-help-command #'embark-prefix-help-command)
  :ensure t)

(use-package embark-consult
  :hook (embark-collect-mode . consult-preview-at-point-mode)
  :ensure t)

;; -----------------------------------------------------------------------------
;; In-buffer completion
;; -----------------------------------------------------------------------------

(use-package corfu  ;; https://github.com/minad/corfu
  :hook (after-init . global-corfu-mode)
  :config
  (corfu-popupinfo-mode)
  :diminish corfu-mode
  :ensure t)

(provide 'myde-core-complete-cfg)
;;; cfg.el ends here
