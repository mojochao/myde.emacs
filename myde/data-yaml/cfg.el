;;; cfg.el --- YAML editing configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; YAML mode setup for .yaml and .yml files.


;;; Code:

(unless (featurep 'myde-data-yaml)
  (load-file (expand-file-name "myde/data-yaml/lib.el" user-emacs-directory)))

;; YAML editing support
(use-package yaml-mode  ;; https://github.com/yoshiki/yaml-mode
  :mode
  (("\\.yaml\\'" . yaml-mode)
   ("\\.yml\\'" . yaml-mode))
  :ensure t)

(provide 'myde-data-yaml-cfg)
;;; cfg.el ends here
