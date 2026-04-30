;;; cfg.el --- Fish shell language configuration -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Fish shell script editing via fish-mode.
;; Entry point for the prog-fish module; loads lib.el automatically.
;;
;; fish-mode provides syntax highlighting and indentation (offset: 2 spaces).
;; No LSP or DAP configured — fish-mode alone is sufficient for Fish scripting.


;;; Code:

(unless (featurep 'myde-prog-fish)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

(use-package fish-mode  ;; https://github.com/emacsmirror/fish-mode
  :custom
  (fish-indent-offset 2)
  :ensure t)

;; ob-shell supports fish as a shell variant via :shebang #!/usr/bin/env fish
(use-package org
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages '((shell . t))))
  :ensure nil)

(provide 'myde-prog-fish-cfg)
;;; cfg.el ends here
