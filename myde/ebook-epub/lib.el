;;; lib.el --- Ebook ePub library -*- coding: utf-8; lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(defun myde/reading-setup ()
  "Improve readability for long-form documents."
  (visual-line-mode 1)
  (setq-local line-spacing 0.15))

(defun myde/reading-keybindings ()
  "Unified navigation keys across readers."
  (local-set-key (kbd "i") #'org-noter)
  (local-set-key (kbd "n") #'org-noter-insert-note)
  (local-set-key (kbd "h") #'org-remark-mark)
  (local-set-key (kbd "j") #'org-noter-sync-next-note)
  (local-set-key (kbd "k") #'org-noter-sync-prev-note))

(provide 'myde-ebook-epub)
;;; lib.el ends here
