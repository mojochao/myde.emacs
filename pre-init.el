;;; pre-init.el --- Loaded before init.el -*- no-byte-compile: t; lexical-binding: t; -*-

;; Add Linuxbrew bin to exec-path if it exists
(let ((linuxbrew-bin "/home/linuxbrew/.linuxbrew/bin"))
  (when (file-directory-p linuxbrew-bin)
    (add-to-list 'exec-path linuxbrew-bin)))
