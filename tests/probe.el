;;; probe.el --- Tests for the probe's startup error scan -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; ERT checks for `scripts/myde-probe.el'.  These cover logic that fails
;;; silently rather than loudly:
;;;
;;;   - `myde-probe-startup-errors' decides what a probe report lists under
;;;     `error:'.  If it misses a line, the report says `error: (none)' for
;;;     a startup that failed, which is how RM-11 went unreported.
;;;
;;; Run with `mise run test'.

;;; Code:

(require 'ert)

(defvar myde-test-root
  (expand-file-name
   ".." (file-name-directory (or load-file-name buffer-file-name)))
  "Repository root, derived from this file's location.")

(load (expand-file-name "scripts/myde-probe.el" myde-test-root))

(ert-deftest myde-probe-startup-errors/reports-hook-errors-and-warnings ()
  "An elpaca hook error and a warning are reported, the held MCP socket is not."
  (with-temp-buffer
    (insert "Loading custom.el (source)...done\n"
            " ■  Warning (files): Missing ‘lexical-binding’ cookie in \"ob-zig.el\".\n"
            "MCP server not started: Failed to start MCP server: Socket already"
            " exists: /x/emacs-mcp-server.sock. Use different name or stop existing server\n"
            " ■  Error (elpaca): Subscriber elpaca--check-queue-completion error"
            " for status finished: (end-of-file \"Error reading from stdin\")\n")
    (should (equal (myde-probe-startup-errors (current-buffer))
                   '("■  Warning (files): Missing ‘lexical-binding’ cookie in \"ob-zig.el\"."
                     "■  Error (elpaca): Subscriber elpaca--check-queue-completion error for status finished: (end-of-file \"Error reading from stdin\")")))))

;;; probe.el ends here
