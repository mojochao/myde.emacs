;;; cfg.el --- AI base configuration -*- coding: utf-8; no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.el
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;; Shared AI module setup; loaded before all other ai-* modules.


;;; Code:

(unless (featurep 'myde-ai-base)
  (load-file (expand-file-name "myde/ai-base/lib.el" user-emacs-directory)))

(provide 'myde-ai-base-cfg)
;;; cfg.el ends here
