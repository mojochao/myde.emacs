;;; cfg.el --- Core UI configuration -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Visual appearance: frame chrome, theme system, icons, and fonts.
;;
;; Configures:
;;   - Frame startup: inhibit splash, hide scrollbar/toolbar (size set in early-init.el)
;;   - menubar hidden in TUI and in GUI on non-macOS systems
;;   - Active theme: batppuccin-frappe; additional themes deferred on demand
;;   - auto-dark on Linux for automatic light/dark switching with batppuccin
;;   - nerd-icons (universal) and all-the-icons (GUI only) for icon support
;;   - show-font for font preview (C-c s f preview, C-c s t tabulated)
;;   - spacious-padding for comfortable UI spacing
;;   - diminish to suppress minor-mode lighters in the modeline


;;; Code:

(unless (featurep 'myde-core-ui)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

;; Clear echo area after all startup hooks have run (removes last info message).
(add-hook 'emacs-startup-hook #'myde/clear-echo-area)

;; Disable startup splash screen and initial scratch message
(setq inhibit-startup-message t
      inhibit-startup-echo-area-message t
      initial-scratch-message nil)

;; Collapse minor modes in modeline
(setq mode-line-collapse-minor-modes t)

;; Enable smooth scrolling in GUI.
;; Get rid of the scrollbar and toolbar in GUI. They take up precious space
;; and one of my goals is to keep my hands on the keyboard, not the mouse.
(when (display-graphic-p)
  (pixel-scroll-precision-mode 1)
  (scroll-bar-mode -1)
  (tool-bar-mode -1))

;; Disable the menubar in TUI (on any OS) or GUI (only on macOS).
;; One thing I like about Emacs GUI app on macOS is that it uses a global app
;; menu that changes with the app, so leave it alone in that case.
(unless (and (display-graphic-p) (string-equal system-type "darwin"))
  (menu-bar-mode -1))

;; Blink cursor
(blink-cursor-mode 1)

;; Enable display of column numbers in buffer modeline
(setq column-number-mode t)

;; Show full file path (or default-directory for non-file buffers) in frame title
(setq frame-title-format '("%b — " (:eval (or buffer-file-name default-directory))))

;; Hide or shorten minor-mode lighters that convey no real-time information
(use-package diminish
  :config
  (diminish 'eldoc-mode)
  (diminish 'auto-revert-mode)
  :ensure t)

;; UI quality of life improvements
(use-package spacious-padding  ;; https://github.com/protesilaos/spacious-padding
  :hook (after-init . spacious-padding-mode)
  :ensure t)

;; Indent guides
(use-package indent-bars  ;; https://github.com/jdtsmith/indent-bars
  :custom
  (indent-bars-treesit-support t)
  (indent-bars-color '(highlight :face-bg t :blend 0.2))
  (indent-bars-pattern ".")
  (indent-bars-width-frac 0.1)
  (indent-bars-pad-frac 0.1)
  (indent-bars-zigzag nil)
  (indent-bars-color-by-depth nil)
  (indent-bars-highlight-current-depth nil)
  (indent-bars-display-on-blank-lines nil)
  :ensure t)

;; Icons support
(use-package all-the-icons  ;; https://github.com/domtronn/all-the-icons.el
  :if (display-graphic-p)
  :ensure t)

(use-package nerd-icons  ;; https://github.com/rainstormstudio/nerd-icons.el
  :ensure t)

;; Fonts support
(use-package show-font  ;; https://github.com/protesilaos/show-font
  :bind
  (("C-c s f" . show-font-select-preview)
   ("C-c s t" . show-font-tabulated))
  :ensure t)

;; Themes support (only active theme and preview are loaded; others defer on demand)
(use-package easy-theme-preview  ;; https://github.com/ayys/easy-theme-preview.el
  :defer t
  :ensure t)

(use-package color-theme-sanityinc-tomorrow  ;; https://github.com/purcell/color-theme-sanityinc-tomorrow
  :defer t
  :ensure t)

(use-package doom-themes ;; https://github.com/doomemacs/themes
  :defer t
  :custom
  (doom-themes-enable-bold t)   ; if nil, bold is universally disabled
  (doom-themes-enable-italic t) ; if nil, italics is universally disabled
  (doom-themes-treemacs-theme "doom-atom") ; use "doom-colors" for less minimal icon theme
  :config
  (doom-themes-visual-bell-config)  ;; Enable flashing mode-line on errors
  (doom-themes-neotree-config)      ;; Enable custom neotree theme (nerd-icons must be installed!)
  (doom-themes-treemacs-config)     ;; or for treemacs users
  (doom-themes-org-config)          ;; Corrects (and improves) org-mode's native fontification.
  :ensure t)

(use-package ef-themes  ;; https://github.com/protesilaos/ef-themes
  :defer t
  :ensure t)

(use-package jetbrains-darcula-theme  ;; https://github.com/ianyepan/jetbrains-darcula-emacs-theme
  :defer t
  :ensure t)

(use-package batppuccin
  :config
  (load-theme 'batppuccin-frappe t)
  :ensure t)

(use-package auto-dark
  :after batppuccin
  :if (string= system-type "linux")
  :custom
  (auto-dark-themes '((batppuccin-frappe) (batppuccin-latte)))
  :init
  (auto-dark-mode t)
  :ensure t)

(provide 'myde-core-ui-cfg)
;;; cfg.el ends here
