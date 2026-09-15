;;; myde-probe.el --- Capture observable config state -*- lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;;; Commentary:
;; Loaded into an already-started Emacs via emacsclient.  Writes a stable,
;; diffable report of what the config actually did, for before/after comparison
;; across migration phases.  Not part of the config; lives under scripts/.
;;
;; The primary metric is the set of *declared* packages: every `use-package'
;; form that was evaluated, read from `use-package-statistics'.  It is
;; gate-sensitive (a form inside a false `when' is never expanded) and it
;; includes deferred packages, which `load-history' does not.  It requires
;; `use-package-compute-statistics' to be t before the config loads.

;;; Code:

(defconst myde-probe-gate-binaries
  '("go" "cargo" "zig" "lua" "ruby" "python3" "node" "elixir" "erl" "clojure"
    "guile" "sbcl" "clangd" "fish" "nu" "pdftoppm" "op" "kubectl" "claude")
  "Binaries that gate a module section in myde.el.
Keep in sync with the gate table in the spec.")

(defconst myde-probe-startup-modes
  '(buffer-guardian-mode vertico-mode marginalia-mode global-corfu-mode
    editorconfig-mode global-treesit-auto-mode global-flycheck-mode
    global-mise-mode global-diff-hl-mode which-key-mode spacious-padding-mode
    yas-global-mode whole-line-or-region-global-mode)
  "Global modes the config enables from startup hooks.
Under elpaca a `:hook (after-init . fn)' never fires, so these are the
canaries for that failure.  Dashboard is not listed; it is verified in the GUI.")

(defun myde-probe-declared-packages ()
  "Return sorted names of every `use-package' form that was evaluated."
  (let ((names '()))
    (when (boundp 'use-package-statistics)
      (maphash (lambda (k _v) (push (symbol-name k) names))
               use-package-statistics))
    (sort names #'string<)))

(defun myde-probe--package-name (dir)
  "Return package name for elpa/elpaca build directory DIR.
Strips a trailing MELPA-style or semver version from elpa directories.
Elpaca build directories carry no version, so DIR is returned unchanged."
  (replace-regexp-in-string
   "-\\(?:[0-9]\\{8\\}\\(?:\\.[0-9]+\\)?\\|[0-9]+\\(?:\\.[0-9]+\\)*\\)\\'" "" dir))

(defun myde-probe-loaded-packages ()
  "Return a sorted list of third-party packages with a file in `load-history'.
Secondary metric: only packages actually loaded at startup appear here."
  (let ((names '()))
    (dolist (entry load-history)
      (let ((file (car entry)))
        (when (and (stringp file)
                   (string-match "/\\(?:elpa\\|elpaca/builds\\)/\\([^/]+\\)/" file))
          (let ((name (myde-probe--package-name (match-string 1 file))))
            (unless (member name names) (push name names))))))
    (sort names #'string<)))

(defun myde-probe-startup-errors ()
  "Return startup error lines found in the *Messages* buffer."
  (let ((hits '()))
    (with-current-buffer (messages-buffer)
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward
                (concat "^\\(.*\\(?:"
                        "Invalid function\\|Symbol's value as variable is void\\|"
                        "Symbol's function definition is void\\|"
                        "error in process\\|Wrong type argument\\|"
                        "Wrong number of arguments\\|"
                        "use-package.*Error\\|Package.*is unavailable\\|"
                        "Failed to\\|Cannot open load file\\|Cannot load"
                        "\\).*\\)$")
                nil t)
          (push (string-trim (match-string 1)) hits))))
    (nreverse hits)))

(defun myde-probe-enabled-modules ()
  "Return sorted `myde-module-*-enabled' variables that are non-nil.
Only meaningful for the baseline; empty once the toggles are gone."
  (let ((found '()))
    (mapatoms
     (lambda (sym)
       (when (and (string-match "\\`myde-module-\\(.+\\)-enabled\\'" (symbol-name sym))
                  (boundp sym)
                  (symbol-value sym))
         (push (match-string 1 (symbol-name sym)) found))))
    (sort found #'string<)))

(defun myde-probe--seconds-since-start (time)
  "Format TIME as seconds since `before-init-time', or n/a if TIME is nil."
  (if time
      (format "%.3f" (float-time (time-subtract time before-init-time)))
    "n/a"))

(defun myde-probe-write (out)
  "Write the probe report to file OUT."
  (with-temp-file out
    (insert ";; myde probe report\n")
    (insert (format "emacs-version: %s\n" emacs-version))
    (insert (format "init-file-had-error: %s\n" init-file-had-error))
    (insert (format "init-time-seconds: %s\n"
                    (myde-probe--seconds-since-start after-init-time)))
    (insert (format "elpaca-init-time-seconds: %s\n"
                    (myde-probe--seconds-since-start
                     (bound-and-true-p elpaca-after-init-time))))
    (insert (format "exec-path-entries: %d\n" (length exec-path)))
    (insert "\n;; enabled modules (toggles; empty once they are gone)\n")
    (dolist (m (myde-probe-enabled-modules)) (insert (format "module: %s\n" m)))
    (insert "\n;; gate binaries\n")
    (dolist (b myde-probe-gate-binaries)
      (insert (format "binary: %-10s %s\n" b (if (executable-find b) "yes" "no"))))
    (insert "\n;; startup modes\n")
    (dolist (m myde-probe-startup-modes)
      (insert (format "mode: %-34s %s\n" m
                      (if (and (boundp m) (symbol-value m)) "on" "off"))))
    (insert "\n;; declared packages (every evaluated use-package form)\n")
    (dolist (p (myde-probe-declared-packages)) (insert (format "declared: %s\n" p)))
    (insert "\n;; loaded third-party packages (load-history)\n")
    (dolist (p (myde-probe-loaded-packages)) (insert (format "loaded: %s\n" p)))
    (insert "\n;; startup errors\n")
    (let ((errs (myde-probe-startup-errors)))
      (if errs
          (dolist (e errs) (insert (format "error: %s\n" e)))
        (insert "error: (none)\n")))))

(provide 'myde-probe)
;;; myde-probe.el ends here
