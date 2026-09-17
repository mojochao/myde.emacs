#!/usr/bin/env python3
"""Split the * Configuration subtree of myde.org into paired blocks.

Each `***` section block becomes two blocks: definitions tangled to
user-lisp/myde.el, and everything else inheriting the subtree's :tangle
init.el.  Definitions inside an `executable-find` gate are lifted out of the
gate; the gate is rebuilt around the activation forms that remain.

One-shot tooling.  Deleted once the split is committed.
"""
import re
import sys

DEFS = {
    "defun", "defmacro", "defvar", "defcustom", "defconst",
    "define-derived-mode", "define-minor-mode", "eval-when-compile",
}
LIB_TANGLE = "#+begin_src emacs-lisp :tangle user-lisp/myde.el"
ACT_TANGLE = "#+begin_src emacs-lisp"
GATE_OPEN = re.compile(r'^\(when \(executable-find "[^"]+"\)$')
GATE_CLOSE = "  )"


def count_parens(line):
    """Net paren depth of LINE, ignoring strings, comments and char literals."""
    s = re.sub(r"\\.", "", line)        # escaped chars, incl. \" and \(
    s = re.sub(r'"[^"]*"', '""', s)     # string bodies
    s = s.split(";")[0]                 # comments (strings already gone)
    s = re.sub(r"\?.", "", s)           # character literals like ?(
    return s.count("(") - s.count(")")


def parse_units(body):
    """Split BODY into [(lead, form, kind)] plus trailing filler lines.

    `lead` is the run of blank and comment lines attached to the form that
    follows it, so a banner comment travels with its form.
    """
    units, lead, i = [], [], 0
    while i < len(body):
        line = body[i]
        if not line.strip() or line.lstrip().startswith(";"):
            lead.append(line)
            i += 1
            continue
        m = re.match(r"\s*\((\S+)", line)
        if not m:
            lead.append(line)
            i += 1
            continue
        kind = m.group(1).rstrip(")")
        depth, j = 0, i
        while j < len(body):
            depth += count_parens(body[j])
            if depth <= 0:
                break
            j += 1
        units.append((lead, body[i:j + 1], kind))
        lead = []
        i = j + 1
    return units, lead


def strip_trailing_blanks(lines):
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


def split_block(body):
    """Return (definition_lines, activation_lines) for one section block."""
    # The `;;;;` section header and any `;; Gate:` note come first.  Stop at
    # the first other comment: that one is a lead-in for the unit that
    # follows it and must travel with that unit via `parse_units`, not be
    # duplicated into both sec_head and act_head.
    head, rest = [], list(body)
    while rest and (not rest[0].strip() or rest[0].startswith(";;;;")
                    or rest[0].startswith(";; Gate:")):
        head.append(rest.pop(0))
    sec_head = [l for l in head if not l.startswith(";; Gate:")]
    act_head = list(head)

    defs, acts = [], []
    units, tail = parse_units(rest)
    for lead, form, kind in units:
        if kind in DEFS:
            defs += lead + form
        elif kind == "when" and GATE_OPEN.match(form[0]):
            inner = form[1:]
            # `.strip()', not `.rstrip()': the gate's closing line is "  )".
            while inner and inner[-1].strip() in (")", ""):
                inner.pop()
            g_defs, g_acts = [], []
            g_units, g_tail = parse_units(inner)
            for l2, f2, k2 in g_units:
                if k2 in DEFS:
                    g_defs += l2 + f2
                else:
                    g_acts += l2 + f2
            g_acts += g_tail   # trailing comments inside the gate
            defs += lead + g_defs
            if strip_trailing_blanks(list(g_acts)):
                acts += lead + [form[0], ""] + strip_trailing_blanks(g_acts) \
                        + ["", GATE_CLOSE]
        else:
            acts += lead + form
    acts += tail

    d = strip_trailing_blanks(sec_head + defs) if strip_trailing_blanks(list(defs)) else []
    a = strip_trailing_blanks(act_head + acts) if strip_trailing_blanks(list(acts)) else []
    return d, a


def main(path):
    src = open(path).read().split("\n")
    out, i = [], 0
    # Everything up to `* Configuration` is copied through untouched.
    while i < len(src) and src[i] != "* Configuration":
        out.append(src[i])
        i += 1
    heading = None
    while i < len(src):
        line = src[i]
        if line.startswith("*** "):
            heading = line[4:].strip()
        if line.startswith("#+begin_src emacs-lisp") and heading not in ("Header", "Footer"):
            j = i + 1
            while src[j] != "#+end_src":
                j += 1
            d, a = split_block(src[i + 1:j])
            if d:
                out += [LIB_TANGLE] + d + ["#+end_src", ""]
            if a:
                out += [ACT_TANGLE] + a + ["#+end_src"]
            if not d and not a:
                out += [ACT_TANGLE, "#+end_src"]
            i = j + 1
            continue
        out.append(line)
        i += 1
    open(path, "w").write("\n".join(out))


if __name__ == "__main__":
    main(sys.argv[1])
