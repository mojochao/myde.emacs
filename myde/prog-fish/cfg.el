;;; cfg.el --- Fish shell language configuration -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;; Side-effect configuration for the `myde-prog-fish-cfg' module:
;; use-package declarations, hooks, and keybindings.  Loads the
;; sister lib.el for definitions.


;;; Code:

(unless (featurep 'myde-prog-fish)
  (load-file (expand-file-name "lib.el" (file-name-directory load-file-name))))

(use-package fish-mode  ;; https://github.com/emacsmirror/fish-mode
  :custom
  (fish-indent-offset 2)
  :ensure t)

(provide 'myde-prog-fish-cfg)
;;; cfg.el ends here
