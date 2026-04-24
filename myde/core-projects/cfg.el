;;; cfg.el --- Projects support configuration for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;;; Commentary:
;;;
;;; Package configuration for project management and project tree support:
;;;   projectile + neotree
;;;
;;; Entry point for the core-projects module; loads lib.el automatically.

;;; Code:

(unless (featurep 'myde-core-projects)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; -----------------------------------------------------------------------------
;; Project management
;; -----------------------------------------------------------------------------

(use-package projectile  ;; https://github.com/bbatsov/projectile
  :config
  (projectile-mode +1)
  (setq projectile-project-search-path '("~/Projects/"))
  :bind (:map projectile-mode-map
              ("s-p"   . projectile-command-map)
              ("C-c p" . projectile-command-map))
  :ensure t)

;; -----------------------------------------------------------------------------
;; Project tree explorer
;; -----------------------------------------------------------------------------

(use-package neotree  ;; https://github.com/jaypei/emacs-neotree
  :bind ([f8] . myde/neotree-project-root-toggle)
  :commands (neotree-toggle)
  :config
  (setq neo-theme (if (display-graphic-p) 'icons 'arrow))
  (setq neo-window-fixed-size nil)
  (add-to-list 'window-size-change-functions #'myde/neotree-window-size-change-function)
  (add-hook 'after-save-hook        #'myde/neotree-refresh)
  (add-hook 'after-delete-file-hook #'myde/neotree-refresh)
  (add-hook 'after-create-file-hook #'myde/neotree-refresh)
  :ensure t)

(provide 'myde-core-projects-cfg)
;;; cfg.el ends here
