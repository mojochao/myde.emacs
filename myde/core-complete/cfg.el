;;; cfg.el --- Completion stack configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

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
  :init
  (vertico-mode)
  :ensure t)

(use-package orderless  ;; https://github.com/oantolin/orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-pcm-leading-wildcard t)
  (completion-category-overrides '((file (styles . (partial-completion)))))
  :ensure t)

(use-package marginalia  ;; https://github.com/minad/marginalia
  :init
  (marginalia-mode)
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
  :config
  (global-corfu-mode)
  (corfu-popupinfo-mode)
  :ensure t)

(provide 'myde-core-complete-cfg)
;;; cfg.el ends here
