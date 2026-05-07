;;; lib.el --- Markdown support library for myde -*- no-byte-compile: t; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; Library functions for Markdown editing, previewing, and publishing.
;;; Loaded by myde-text-markdown/cfg.el before package configuration.
;;;
;;; External tools used (all optional, but install for full experience):
;;;   grip      -- live GitHub-flavored preview   (pip install grip)
;;;   pandoc    -- HTML/PDF export                (brew install pandoc)
;;;   basictex  -- TeX engine for PDF export      (brew install --cask basictex)
;;;
;;; grip uses GitHub's rendering API.  Without authentication it is rate
;;; limited to 60 requests/hour.  Add a personal access token to ~/.authinfo
;;; for machine api.github.com (or set grip-github-user / grip-github-password
;;; via Customize) to lift the limit to 5000/hour.


;;; Code:


(defconst myde-text-markdown-dir
  (file-name-directory (or load-file-name buffer-file-name))
  "Directory containing the text-markdown module files.")

(defun myde-markdown-preview-script-tag (relative-path)
  "Return the contents of RELATIVE-PATH wrapped in a <script> tag.
RELATIVE-PATH is resolved against `myde-text-markdown-dir'.  The
return value is suitable for `markdown-preview-javascript' --
strings beginning with \"<script\" are inlined verbatim by the
package; everything else is wrapped as <script src=\"…\">, which
fails for filesystem paths the preview HTTP server cannot reach."
  (with-temp-buffer
    (insert "<script>\n")
    (insert-file-contents (expand-file-name relative-path myde-text-markdown-dir))
    (goto-char (point-max))
    (insert "\n</script>")
    (buffer-string)))

(defun myde-markdown-mode-setup ()
  "Set buffer-local settings for markdown-mode buffers."
  (setq-local fill-column 80
              tab-width 2
              indent-tabs-mode nil
              sentence-end-double-space nil))

(defun myde-markdown-export-html ()
  "Export current Markdown buffer to HTML alongside the source file."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer has no file — save it first"))
  (save-buffer)
  (let* ((src (buffer-file-name))
         (out (concat (file-name-sans-extension src) ".html")))
    (if (zerop (call-process "pandoc" nil nil nil
                             "-f" "gfm" "-s" "-o" out src))
        (message "Exported: %s" out)
      (message "pandoc failed; install with: brew install pandoc"))))

(defun myde-markdown-export-pdf ()
  "Export current Markdown buffer to PDF alongside the source file.
Requires pandoc and a TeX engine (e.g. brew install --cask basictex)."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer has no file — save it first"))
  (save-buffer)
  (let* ((src (buffer-file-name))
         (out (concat (file-name-sans-extension src) ".pdf")))
    (if (zerop (call-process "pandoc" nil nil nil
                             "-f" "gfm" "-o" out src))
        (message "Exported: %s" out)
      (message "pandoc PDF failed; need pandoc + a TeX engine"))))

(provide 'myde-text-markdown)
;;; lib.el ends here
