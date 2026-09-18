;;; core-org.el --- Tests for the core-org module -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright (C) 2020-2026  Allen Gooch

;; Author:   Allen Gooch <allen.gooch@gmail.com>
;; URL:      https://github.com/mojochao/myde.emacs
;; Keywords: convenience, configuration

;; This file is not part of GNU Emacs.

;; Released under the MIT License; see the LICENSE file at the repository
;; root for the full text.

;;; Commentary:
;;;
;;; ERT checks for `core-org' project discovery and tag sanitization.
;;; These cover logic that fails silently rather than loudly:
;;;
;;;   - An invalid `#+filetags:' value makes tag search return nothing.
;;;   - A missing `#+category:' makes every per-project tasks.org show up
;;;     in the agenda as "tasks", indistinguishable from every other one.
;;;   - A missing agenda directory is treated by org as though it were a
;;;     file, and a missing agenda file blocks startup on a prompt.
;;;   - An unpruned recursive scan walks .git internals and archived
;;;     projects kept in dot-directories.
;;;
;;; Every test builds its own temporary tree, so none depend on the
;;; contents of ~/devel/projects or ~/org.
;;;
;;; Run with `make test'.


;;; Code:

(require 'ert)
(require 'org)

(defvar myde-test-root
  (expand-file-name
   ".." (file-name-directory (or load-file-name buffer-file-name)))
  "Repository root, derived from this file's location.")

;; The whole library, not one module: since the library/config split
;; `user-lisp/myde.el' holds definitions only and has no side effects, so
;; loading it in batch is safe and needs no package to be installed.
(load (expand-file-name "user-lisp/myde.el" myde-test-root))

(defun myde-test--tag-valid-p (tag)
  "Return non-nil when TAG matches `org-tag-re' in full."
  (and (string-match (concat "\\`" org-tag-re "\\'") tag) t))

(defun myde-test--touch (path)
  "Create an empty file at PATH, making parent directories as needed."
  (make-directory (file-name-directory path) :parents)
  (write-region "" nil path nil 'silent))

(ert-deftest myde-org-sanitize-tag/produces-valid-org-tags ()
  "Characters outside `org-tag-re' become underscores."
  (should (equal (myde-org-sanitize-tag "scitech-idp") "scitech_idp"))
  (should (equal (myde-org-sanitize-tag "myde.emacs") "myde_emacs"))
  (should (equal (myde-org-sanitize-tag "already_ok9") "already_ok9"))
  (dolist (name '("scitech-idp" "myde.emacs" "hybrid-eks-poc" "a b/c"))
    (should (myde-test--tag-valid-p (myde-org-sanitize-tag name)))))

(ert-deftest myde-org-ensure-tree/creates-dirs-and-inbox ()
  "The org tree and inbox file are created when absent.
A missing agenda *directory* is silently returned by `org-agenda-files'
as though it were a file; a missing agenda *file* triggers a blocking
`[R]emove or [A]bort?' prompt.  Both must exist."
  (let* ((tmp (make-temp-file "myde-org-test" :dir))
         (myde-org-directory (file-name-as-directory tmp))
         (myde-org-inbox-file (expand-file-name "inbox.org" myde-org-directory))
         (myde-org-archive-directory
          (file-name-as-directory (expand-file-name "archive" myde-org-directory))))
    (unwind-protect
        (progn
          (myde-org-ensure-tree)
          (should (file-directory-p myde-org-archive-directory))
          (should (file-exists-p myde-org-inbox-file))
          ;; Idempotent: a second call must not signal or truncate.
          (with-temp-file myde-org-inbox-file (insert "* keep me\n"))
          (myde-org-ensure-tree)
          (should (equal (with-temp-buffer
                           (insert-file-contents myde-org-inbox-file)
                           (buffer-string))
                         "* keep me\n")))
      (delete-directory tmp :recursive))))

(ert-deftest myde-org-project-root/finds-nearest-tasks-file ()
  "The project root is the nearest ancestor holding a tasks file."
  (let* ((tmp (file-name-as-directory (make-temp-file "myde-org-test" :dir))))
    (unwind-protect
        (progn
          (myde-test--touch (expand-file-name "outer/tasks.org" tmp))
          (myde-test--touch (expand-file-name "outer/inner/tasks.org" tmp))
          (make-directory (expand-file-name "outer/plain/deep" tmp) :parents)
          (make-directory (expand-file-name "nowhere/deep" tmp) :parents)
          ;; Nearest wins: inner shadows outer.
          (should (equal (file-truename (myde-org-project-root
                                        (expand-file-name "outer/inner" tmp)))
                         (file-truename (expand-file-name "outer/inner/" tmp))))
          ;; Walks upward past directories with no tasks file.
          (should (equal (file-truename (myde-org-project-root
                                        (expand-file-name "outer/plain/deep" tmp)))
                         (file-truename (expand-file-name "outer/" tmp))))
          ;; The tasks file's own directory resolves to itself.
          (should (equal (file-truename (myde-org-project-root
                                        (expand-file-name "outer" tmp)))
                         (file-truename (expand-file-name "outer/" tmp))))
          ;; Nothing up the tree: nil, not an error.  Bounded by tmp's
          ;; ancestors having no tasks.org.
          (let ((default-directory (expand-file-name "nowhere/deep" tmp)))
            (should (null (myde-org-project-root)))))
      (delete-directory tmp :recursive))))

(ert-deftest myde-org-project-name/is-the-root-directory-name ()
  "The project name is the basename of the directory holding the tasks file."
  (let* ((tmp (file-name-as-directory (make-temp-file "myde-org-test" :dir))))
    (unwind-protect
        (progn
          (myde-test--touch (expand-file-name "scitech-idp/tasks.org" tmp))
          (make-directory (expand-file-name "scitech-idp/docs/deep" tmp) :parents)
          (should (equal (myde-org-project-name
                          (expand-file-name "scitech-idp/docs/deep" tmp))
                         "scitech-idp"))
          (should (equal (myde-org-project-tasks-file
                          (expand-file-name "scitech-idp/docs/deep" tmp))
                         (expand-file-name "scitech-idp/tasks.org" tmp))))
      (delete-directory tmp :recursive))))

(ert-deftest myde-org-capture-target/falls-back-to-inbox ()
  "Capture targets the nearest tasks file, or the inbox when there is none."
  (let* ((tmp (file-name-as-directory (make-temp-file "myde-org-test" :dir)))
         (myde-org-inbox-file (expand-file-name "inbox.org" tmp)))
    (unwind-protect
        (progn
          (myde-test--touch (expand-file-name "proj/tasks.org" tmp))
          (make-directory (expand-file-name "bare/deep" tmp) :parents)
          (let ((default-directory (expand-file-name "proj" tmp)))
            (should (equal (myde-org-capture-target)
                           (expand-file-name "proj/tasks.org" tmp))))
          (let ((default-directory (expand-file-name "bare/deep" tmp)))
            (should (equal (myde-org-capture-target) myde-org-inbox-file))))
      (delete-directory tmp :recursive))))

(ert-deftest myde-org-find-task-files/prunes-dot-dirs-and-node-modules ()
  "Discovery finds nested tasks files but skips pruned directories.
Pruning dot-directories keeps .git internals out of the walk and
excludes archived projects parked in directories like .ATTIC."
  (let* ((tmp (file-name-as-directory (make-temp-file "myde-org-test" :dir)))
         (myde-org-code-directory tmp))
    (unwind-protect
        (progn
          (myde-test--touch (expand-file-name "alpha/tasks.org" tmp))
          (myde-test--touch (expand-file-name "group/beta/tasks.org" tmp))
          (myde-test--touch (expand-file-name ".ATTIC/archived/tasks.org" tmp))
          (myde-test--touch (expand-file-name ".git/weird/tasks.org" tmp))
          (myde-test--touch (expand-file-name "gamma/node_modules/x/tasks.org" tmp))
          (let ((found (mapcar (lambda (f)
                                 (file-relative-name f tmp))
                               (myde-org-find-task-files))))
            (should (equal (sort found #'string<)
                           '("alpha/tasks.org" "group/beta/tasks.org")))))
      (delete-directory tmp :recursive))))

(ert-deftest myde-org-project-tasks-template/sets-category-and-valid-filetags ()
  "The template carries a category and a tag matching `org-tag-re'.
Without `#+category:', org falls back to the file name, so every
per-project tasks.org would appear in the agenda as \"tasks\"."
  (dolist (name '("scitech-idp" "myde.emacs" "plain"))
    (let ((text (myde-org-project-tasks-template name)))
      (should (string-match "^#\\+category: \\(.*\\)$" text))
      (should (myde-test--tag-valid-p (match-string 1 text)))
      (should (string-match "^#\\+filetags: :\\(.*\\):$" text))
      (should (myde-test--tag-valid-p (match-string 1 text)))
      ;; The category must not be the bare file name.
      (should-not (equal (progn (string-match "^#\\+category: \\(.*\\)$" text)
                                (match-string 1 text))
                         "tasks")))))

(ert-deftest myde-org-vc-root/finds-repository-root ()
  "The repository root is found from a `.git' directory or a `.git' file.
Git worktrees and submodules use a `.git' *file* holding a gitdir
pointer, not a directory, so both forms must be recognized."
  (let* ((tmp (file-name-as-directory (make-temp-file "myde-org-test" :dir))))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "realrepo/.git/objects" tmp) :parents)
          (make-directory (expand-file-name "realrepo/src/deep" tmp) :parents)
          (make-directory (expand-file-name "worktree/src" tmp) :parents)
          (with-temp-file (expand-file-name "worktree/.git" tmp)
            (insert "gitdir: /elsewhere/.git/worktrees/wt\n"))
          (make-directory (expand-file-name "norepo/deep" tmp) :parents)
          ;; .git as a directory, found from a nested subdirectory.
          (should (equal (file-truename (myde-org-vc-root
                                        (expand-file-name "realrepo/src/deep" tmp)))
                         (file-truename (expand-file-name "realrepo/" tmp))))
          ;; .git as a file (worktree / submodule).
          (should (equal (file-truename (myde-org-vc-root
                                        (expand-file-name "worktree/src" tmp)))
                         (file-truename (expand-file-name "worktree/" tmp))))
          ;; Not under version control at all.
          (should (null (myde-org-vc-root (expand-file-name "norepo/deep" tmp)))))
      (delete-directory tmp :recursive))))

(ert-deftest myde-org-create-project-tasks/creates-from-template-and-never-clobbers ()
  "Creation writes the template once and never overwrites existing content."
  (let* ((tmp (file-name-as-directory (make-temp-file "myde-org-test" :dir)))
         (myde-org-code-directory tmp)
         (myde-org-inbox-file (expand-file-name "inbox.org" tmp))
         (dir (expand-file-name "scitech-idp" tmp))
         (file (expand-file-name "tasks.org" dir))
         buf)
    (unwind-protect
        (progn
          (make-directory dir :parents)
          (setq buf (myde-org-create-project-tasks dir))
          (should (file-exists-p file))
          (with-temp-buffer
            (insert-file-contents file)
            (should (string-match-p "^#\\+category: scitech_idp$" (buffer-string)))
            (should (string-match-p "^#\\+filetags: :scitech_idp:$" (buffer-string)))
            (should (string-match-p "^\\* Tasks$" (buffer-string))))
          ;; Drop the visiting buffer before touching the file on disk, or the
          ;; second `find-file' stops to ask whether to reread it.
          (when (buffer-live-p buf) (kill-buffer buf))
          ;; Existing content must survive a second invocation.
          (with-temp-file file (insert "* Tasks\n** TODO do not lose me\n"))
          (myde-org-create-project-tasks dir)
          (with-temp-buffer
            (insert-file-contents file)
            (should (equal (buffer-string) "* Tasks\n** TODO do not lose me\n"))))
      (dolist (b (buffer-list))
        (when (and (buffer-file-name b)
                   (string-prefix-p tmp (buffer-file-name b)))
          (kill-buffer b)))
      (delete-directory tmp :recursive))))

(ert-deftest myde-org-tags-match-string/ands-and-ors ()
  "Tags join with `+' for all-of and `|' for any-of."
  (should (equal (myde-org-tags-match-string '("a" "b") nil) "a+b"))
  (should (equal (myde-org-tags-match-string '("a" "b") t) "a|b"))
  (should (equal (myde-org-tags-match-string '("solo") nil) "solo")))

(ert-deftest myde-org-tag-counts/tallies-including-filetags ()
  "Tags are tallied per entry and per file, most frequent first.
Counting uses `org-get-tags', which includes tags inherited from
`#+filetags:'.  That matches what `org-tags-view' returns, so a
displayed count never disagrees with the search it launches."
  (let* ((tmp (file-name-as-directory (make-temp-file "myde-org-test" :dir)))
         (proj (expand-file-name "proj.org" tmp))
         (loose (expand-file-name "loose.org" tmp))
         (gone (expand-file-name "not-there.org" tmp)))
    (unwind-protect
        (progn
          (with-temp-file proj
            (insert "#+filetags: :proj:\n"
                    "* TODO alpha :shared:\n"
                    "* TODO beta\n"
                    "** TODO beta-child\n"))
          (with-temp-file loose
            (insert "* TODO gamma :shared:\n"
                    "* TODO delta\n"))
          (let ((counts (myde-org-tag-counts (list proj loose gone))))
            ;; proj is a filetag: it lands on all three entries of proj.org.
            (should (equal (assoc "proj" counts) '("proj" 3 1)))
            ;; shared appears once in each of two files.
            (should (equal (assoc "shared" counts) '("shared" 2 2)))
            ;; Most frequent first.
            (should (equal (mapcar #'car counts) '("proj" "shared")))
            ;; Tags must be plain strings; org hands back propertized ones
            ;; for inherited tags, which breaks display and comparison.
            (dolist (row counts)
              (should (equal (car row) (substring-no-properties (car row))))))
          ;; An unreadable file is skipped, yielding nil rather than signalling.
          (should (null (myde-org-tag-counts (list gone)))))
      (dolist (b (buffer-list))
        (when (and (buffer-file-name b)
                   (string-prefix-p tmp (buffer-file-name b)))
          (kill-buffer b)))
      (delete-directory tmp :recursive))))

;;; core-org.el ends here
