#!/usr/bin/env python3
"""Report top-level form kinds in an elisp file, and optionally assert that a
file contains only definitions.

  scripts/myde-forms.py user-lisp/myde.el --defs-only
  scripts/myde-forms.py init.el
"""
import re
import sys

# `provide' is absent from the splitter's DEFS and present here on purpose: the
# splitter never sees it, because `(provide 'myde)' lives in the pinned Footer
# block, but this script reads the tangled file where it is a top-level form.
DEFS = {
    "defun", "defmacro", "defvar", "defcustom", "defconst",
    "define-derived-mode", "define-minor-mode", "defvar-keymap",
    "declare-function", "eval-when-compile", "provide",
}


def forms(path):
    lines = open(path).read().split("\n")
    i = 0
    while i < len(lines):
        if lines[i].startswith("("):
            kind = re.match(r"\((\S+)", lines[i]).group(1).rstrip(")")
            depth, j = 0, i
            while j < len(lines):
                depth += lines[j].count("(") - lines[j].count(")")
                if depth <= 0:
                    break
                j += 1
            yield kind, i + 1
            i = j + 1
        else:
            i += 1


def main():
    path = sys.argv[1]
    defs_only = "--defs-only" in sys.argv
    counts, offenders = {}, []
    for kind, line in forms(path):
        counts[kind] = counts.get(kind, 0) + 1
        if defs_only and kind not in DEFS:
            offenders.append((line, kind))
    for kind, n in sorted(counts.items(), key=lambda x: (-x[1], x[0])):
        print(f"{n}\t{kind}")
    if offenders:
        print(f"\nERROR: {len(offenders)} non-definition forms in {path}:",
              file=sys.stderr)
        for line, kind in offenders[:20]:
            print(f"  {path}:{line}: {kind}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
