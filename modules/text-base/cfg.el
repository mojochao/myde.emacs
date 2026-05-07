;;; cfg.el --- Text base configuration -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Text foundation shared by all text-mode-derived language modules.
;; Entry point for the text-base module; loads lib.el automatically.
;;
;; Configures:
;;   text-mode hooks — line numbers on all text-mode-derived buffers


;;; Code:

(unless (featurep 'myde-text-base)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

(add-hook 'text-mode-hook #'myde-text-mode-hook-function)

(provide 'myde-text-base-cfg)
;;; cfg.el ends here
