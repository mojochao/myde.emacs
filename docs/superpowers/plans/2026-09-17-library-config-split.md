# Library / Config Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split `user-lisp/myde.el` so it holds only definitions, moving every `use-package` form, binary gate, and variable assignment into `init.el`, with both files still tangled from one `myde.org`.

**Architecture:** One mechanical pass, driven by a throwaway Python script that rewrites `myde.org` in place. Each `***` section keeps one heading and gains a second source block: definitions tangle to `user-lisp/myde.el`, everything else inherits the subtree's new `:tangle init.el`. The script is verified by line conservation — every input line must land in exactly one output block — before it is allowed near the real file. Verification is the existing probe harness, comparing declared packages and startup modes against a baseline.

**Tech Stack:** Emacs 31.1, `org-babel-tangle`, Python 3 (throwaway tooling only), GNU Make, `scripts/myde-probe.sh`.

**Spec:** `docs/superpowers/specs/2026-09-17-library-config-split-design.md`

---

## Critical context for someone with zero familiarity

Read all of this before Task 0. Each item is a live hazard confirmed against the tree at `aefb6ea`.

1. **`~/.config/emacs` is a symlink to this repository.** Editing the main working tree
   changes the running config immediately. All work happens in a git worktree,
   exercised with `emacs --init-directory=`.

2. **Do not put the worktree or the probe reports under `/tmp`.** macOS purges it. The
   previous migration lost its worktree and its only pre-migration baseline report that
   way. This plan uses `~/devel/worktrees/myde-library-split` and
   `~/.local/state/myde-probe-reports/`.

3. **`elpaca/` is gitignored, and a cold build takes minutes.** Symlink the worktree's
   `elpaca` to the main tree's so the probe starts warm.

4. **`elpaca/builds/` entries are symlinks into `elpaca/sources/`.** They were converted
   to relative paths on 2026-09-17, so a symlink of the whole directory resolves. Never
   copy or move `elpaca/` with anything that rewrites symlinks to absolute paths.

5. **`custom.el` is gitignored.** Copy the main tree's into the worktree or the probe
   runs against different settings than the live config.

6. **Only `myde.org` is edited by hand.** `early-init.el`, `init.el`, and
   `user-lisp/myde.el` are tangled output; `make tangle` overwrites them. `make check`
   fails if the committed `.el` files differ from a fresh tangle, so `myde.org` and the
   tangled files are always committed together.

7. **A per-block `:tangle` header overrides the subtree property, and each target
   collects its blocks in document order.** This is the mechanism the whole plan rests
   on. Verified by tangle test; Task 1 re-verifies it on a fixture.

8. **Order within each file is load order and is load-bearing.** Do not reorder
   sections. `exec-path-from-shell` must stay `:ensure (:wait t)` in the Environment
   section ahead of the first binary gate, and the XDG assignments must stay in the
   `core-base` activation block ahead of every package that reads them.

9. **All 20 binary gates have one identical shape.** The line `(when (executable-find
   "<binary>")` alone, a blank line, the body at column 0, and a closing line of exactly
   two spaces and `)`. There is exactly one gate per gated section, and no nested gates.
   The script depends on this; Task 1 asserts it.

10. **Definitions are not contiguous.** In 8 of 52 sections a definition follows an
    activation form (`core-base`, `core-ui`, `core-ux`, `core-projects`, `prog-scheme`,
    `prog-rust`, `prog-zig`, `ebook-pdf`). The script must gather definitions from
    anywhere in the section and preserve their relative order. A simple split point is
    wrong.

11. **Counting parens needs string and character literals stripped first.** Elisp here
    contains `"\\.foo\\'"` regexps and `?\(` literals. A naive count desynchronises the
    parser. The `count_parens` helper in Task 1 handles escapes, then strings, then
    comments, then char literals, in that order.

12. **`(provide 'init)` and `;;; init.el ends here` currently sit in the `* Bootstrap`
    block, which precedes `* Configuration` in document order.** Once activation blocks
    also tangle to `init.el` they would land *after* that footer. The footer, and the
    `(unless (daemonp) … (server-start))` form above it, must move to the end of
    `* Configuration`. The server start has to run after the configuration loads, as it
    does today.

13. **`myde.el` keeps `no-byte-compile: t`.** See the spec's *Compilation* section. Do
    not remove it as part of this work.

14. **Emacs runs daemon-only on this machine.** `emacsclient` always reaches the login
    daemon, never a GUI app. Restart it with
    `launchctl kickstart -k gui/$(id -u)/gnu.emacs.daemon`. Anything that needs a window
    system frame has to be checked by creating one with `emacsclient -c -n`.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `scripts/myde-split.py` | One-shot splitter. Rewrites the `* Configuration` subtree of `myde.org` into paired definition/activation blocks. Deleted in Task 5. |
| `scripts/myde-forms.py` | Form-kind inventory and assertion over a tangled `.el` file. Kept — it becomes the `make forms` target. |

**Modified:** `myde.org`, `init.el`, `user-lisp/myde.el` (the latter two as tangled
output only), `Makefile`, `.agents/AGENTS.md`, `.agents/skills/myde/SKILL.md`, `README.md`

Note on paths: `CLAUDE.md` and `AGENTS.md` are both symlinks to `.agents/AGENTS.md`, and
`.claude/skills` is a symlink to `.agents/skills`. Always edit and `git add` the
`.agents/` paths.

**Deleted:** nothing.

---

## Task 0: Worktree and baseline

**Files:**
- Create: `~/devel/worktrees/myde-library-split` (git worktree)
- Create: `~/.local/state/myde-probe-reports/00-baseline.txt`

- [ ] **Step 1: Create the worktree on a new branch**

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
mkdir -p ~/devel/worktrees
git worktree add -b migration/library-config-split ~/devel/worktrees/myde-library-split
```

Expected: `Preparing worktree (new branch 'migration/library-config-split')` and a
`HEAD is now at aefb6ea` line.

- [ ] **Step 2: Give the worktree the two gitignored inputs it needs**

```bash
cd ~/devel/worktrees/myde-library-split
cp /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs/custom.el .
ln -s /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs/elpaca elpaca
ls -d elpaca/builds >/dev/null && echo "elpaca reachable"
```

Expected: `elpaca reachable`.

- [ ] **Step 3: Take the baseline probe**

```bash
mkdir -p ~/.local/state/myde-probe-reports
cd ~/devel/worktrees/myde-library-split
scripts/myde-probe.sh "$PWD" ~/.local/state/myde-probe-reports/00-baseline.txt
```

Expected, on the summary lines:

```
  init-file-had-error: nil
  declared packages: 161
  modes off:         0
  startup errors:    none
```

If `declared packages` is not 161, stop. The worktree is not seeing the same inputs as
the live config; recheck steps 1-2.

- [ ] **Step 4: Record the baseline form inventory**

```bash
cd ~/devel/worktrees/myde-library-split
python3 - <<'EOF' | tee ~/.local/state/myde-probe-reports/00-forms.txt
import re, pathlib, collections
lines = pathlib.Path("user-lisp/myde.el").read_text().split("\n")
c = collections.Counter()
i = 0
while i < len(lines):
    if lines[i].startswith("("):
        c[re.match(r"\((\S+)", lines[i]).group(1).rstrip(")")] += 1
        d, j = 0, i
        while j < len(lines):
            d += lines[j].count("(") - lines[j].count(")")
            if d <= 0: break
            j += 1
        i = j + 1
    else:
        i += 1
for k, v in sorted(c.items(), key=lambda x: (-x[1], x[0])):
    print(f"{v}\t{k}")
EOF
```

Expected to include `135 use-package`, `57 defun`, `22 when`, `20 setq`, `11 defvar`,
`4 add-hook`.

- [ ] **Step 5: Record the baseline section order**

```bash
cd ~/devel/worktrees/myde-library-split
grep '^;;;; [a-z]' user-lisp/myde.el | grep -v '^;;;; -' \
  > ~/.local/state/myde-probe-reports/00-sections.txt
wc -l < ~/.local/state/myde-probe-reports/00-sections.txt
```

Expected: `52`. Task 4 diffs the tangled `init.el` against this file.

---

## Task 1: The splitter script, verified on a fixture first

**Files:**
- Create: `~/devel/worktrees/myde-library-split/scripts/myde-split.py`

- [ ] **Step 1: Write the splitter**

Create `scripts/myde-split.py` with exactly this content:

```python
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
    # The `;;;;` section header and any `;; Gate:` note come first.
    head, rest = [], list(body)
    while rest and (not rest[0].strip() or rest[0].startswith(";")):
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
```

- [ ] **Step 2: Write the fixture and its line-conservation check**

This is the test. It asserts the two properties the real run depends on: every
non-blank, non-comment input line lands in exactly one output block, and a mixed gate is
rebuilt correctly. Run it from the worktree root:

```bash
cd ~/devel/worktrees/myde-library-split
mkdir -p /tmp/split-fixture && cd /tmp/split-fixture
cat > f.org <<'EOF'
* Configuration
:PROPERTIES:
:header-args:emacs-lisp: :tangle init.el :mkdirp yes
:END:

** Languages

*** prog-go

#+begin_src emacs-lisp
;;;; prog-go
;;;; -------
;; Gate: go

(when (executable-find "go")

(defvar myde-go-tab-width 2
  "Tab width.")

(defun myde-go-setup ()
  "Setup."
  (setq-local tab-width myde-go-tab-width))

;; -----------------------------------------------------------------------------
;; LSP
;; -----------------------------------------------------------------------------

(use-package eglot
  :mode ("\\.go\\'" . go-ts-mode)
  :hook (go-ts-mode . myde-go-setup)
  :ensure nil)

  )
#+end_src

*** core-ux

#+begin_src emacs-lisp
;;;; core-ux
;;;; -------

(setq confirm-kill-emacs nil)

(defun myde-ux-thing () "Doc." t)

(global-set-key (kbd "C-c x") #'myde-ux-thing)
#+end_src
EOF
cp ~/devel/worktrees/myde-library-split/scripts/myde-split.py .
cp f.org f.org.orig
python3 myde-split.py f.org
cat f.org
```

Expected output: `prog-go` now has a `:tangle user-lisp/myde.el` block holding the
`;;;;` header, the `defvar` and the `defun` with no gate around them, followed by a
default block holding the header plus `(when (executable-find "go")`, the `;; LSP`
banner, the `use-package` form, and `  )`. `core-ux` likewise splits, with
`myde-ux-thing` in the definitions block and both the `setq` and the `global-set-key`
in the activation block.

- [ ] **Step 3: Assert line conservation and that both targets tangle**

```bash
cd /tmp/split-fixture
python3 - <<'EOF'
import re, pathlib, collections
def code(p):
    out, inb = [], False
    for l in pathlib.Path(p).read_text().split("\n"):
        if l.startswith("#+begin_src"): inb = True; continue
        if l == "#+end_src": inb = False; continue
        # Comments are counted too.  Filtering them out would make a dropped
        # banner invisible, which is exactly the failure mode being guarded.
        if inb and l.strip(): out.append(l.strip())
    return collections.Counter(out)
before = code("f.org.orig")
after = code("f.org")
added = after - before
removed = before - after
print("added  :", dict(added))
print("removed:", dict(removed))
assert not removed, f"LINES LOST: {dict(removed)}"
unexpected = {k: n for k, n in added.items() if not k.startswith(";;;;")}
assert not unexpected, f"UNEXPECTED ADDITIONS: {unexpected}"
print("OK: line conservation holds")
EOF
emacs -Q --batch --eval '(progn (require (quote org)) (org-babel-tangle-file "f.org"))' 2>&1 | tail -1
echo "--- init.el ---"; cat init.el
echo "--- user-lisp/myde.el ---"; cat user-lisp/myde.el
```

Expected: `OK: line conservation holds`, `Tangled 4 code blocks`, and two files whose
contents match the description in step 2. `user-lisp/myde.el` must contain no
`use-package` and no `(when (executable-find`.

The only permitted additions are `;;;;` lines, because each section's header is
deliberately copied into both blocks. Anything else under `added` — and *any* entry
under `removed` — is a splitter bug. Note that the gate's own `(when (executable-find
…)` and `  )` lines are reused rather than synthesised, so they must balance out to
zero, not appear as additions.

- [ ] **Step 4: Commit the script**

```bash
cd ~/devel/worktrees/myde-library-split
git add scripts/myde-split.py
git commit -m "Add one-shot myde.org library/config splitter"
```

---

## Task 2: Move the init.el footer out of the Bootstrap block

This has to happen before the split, or the split's activation blocks land after
`(provide 'init)`.

**Files:**
- Modify: `~/devel/worktrees/myde-library-split/myde.org`

- [ ] **Step 1: Delete the tail of the `* Bootstrap` block**

Remove these lines from the end of the `* Bootstrap` source block (they currently sit
just before its `#+end_src`), keeping `(require 'myde)` and the `;;;; Configuration`
comment where they are:

```elisp
;; A daemon starts its own server from startup.el after init; only GUI and
;; TTY sessions need one here.
(unless (daemonp)
  (require 'server)
  (unless (server-running-p) (server-start)))

;; That's all Folks!
(provide 'init)
;;; init.el ends here
```

- [ ] **Step 2: Add an init footer heading at the very end of `myde.org`**

Append, after the existing `*** Footer` block that provides `myde`:

```org
*** Init footer

#+begin_src emacs-lisp
;; A daemon starts its own server from startup.el after init; only GUI and
;; TTY sessions need one here.  This runs after the configuration above, as it
;; did when it lived at the end of the bootstrap block.
(unless (daemonp)
  (require 'server)
  (unless (server-running-p) (server-start)))

;; That's all Folks!
(provide 'init)
;;; init.el ends here
#+end_src
```

- [ ] **Step 3: Verify nothing tangles yet differently**

`* Configuration` still tangles to `user-lisp/myde.el` at this point, so the new block
lands in the wrong file. That is expected and is fixed in Task 3; do not tangle here.
Just confirm the org is well formed:

```bash
cd ~/devel/worktrees/myde-library-split
grep -c '^#+begin_src emacs-lisp' myde.org
```

Expected: `57` (was 56).

- [ ] **Step 4: Commit**

```bash
git add myde.org
git commit -m "Move the init.el footer to the end of myde.org"
```

---

## Task 3: Retarget the subtree and run the splitter

**Files:**
- Modify: `~/devel/worktrees/myde-library-split/myde.org`

- [ ] **Step 1: Flip the `* Configuration` subtree property**

Change the property drawer under `* Configuration` from:

```org
:header-args:emacs-lisp: :tangle user-lisp/myde.el :mkdirp yes
```

to:

```org
:header-args:emacs-lisp: :tangle init.el :mkdirp yes
```

- [ ] **Step 2: Pin the three blocks that must not follow the new default**

Give `*** Header` and `*** Footer` an explicit target, so the `myde.el` file header and
`(provide 'myde)` still land in the library. Change each of their
`#+begin_src emacs-lisp` lines to:

```org
#+begin_src emacs-lisp :tangle user-lisp/myde.el
```

`*** Init footer` from Task 2 keeps the bare `#+begin_src emacs-lisp` and inherits
`init.el`.

- [ ] **Step 3: Keep a pre-split copy, then split**

```bash
cd ~/devel/worktrees/myde-library-split
cp myde.org ~/.local/state/myde-probe-reports/myde.org.presplit
python3 scripts/myde-split.py myde.org
grep -c '^#+begin_src emacs-lisp' myde.org
grep -c '^#+begin_src emacs-lisp :tangle user-lisp/myde.el' myde.org
```

Expected exactly `98` and `43`.

The arithmetic, so a wrong number is diagnosable: `* Configuration` holds 54 blocks —
`Header`, `Footer`, and 52 section blocks — plus 1 each for `* Early Init` and
`* Bootstrap`, plus the `Init footer` from Task 2, giving 57 before the split. 41 of the
52 sections contain at least one definition and so become two blocks: 57 + 41 = 98. The
library-targeted blocks are those 41 plus the 2 pinned ones = 43.

A total below 98 means sections were merged or dropped; a library count below 43 means
the splitter classified definitions as activation.

- [ ] **Step 4: Assert line conservation on the real file**

```bash
cd ~/devel/worktrees/myde-library-split
python3 - <<'EOF'
import pathlib, collections
def code(p):
    out, inb = [], False
    for l in pathlib.Path(p).read_text().split("\n"):
        if l.startswith("#+begin_src"): inb = True; continue
        if l == "#+end_src": inb = False; continue
        # Comments are counted too.  Filtering them out would make a dropped
        # banner invisible, which is exactly the failure mode being guarded.
        if inb and l.strip(): out.append(l.strip())
    return collections.Counter(out)
before, after = code(pathlib.Path.home() / ".local/state/myde-probe-reports/myde.org.presplit"), code("myde.org")
removed, added = before - after, after - before
print("removed:", dict(removed))
print("added  :", dict(added))
assert not removed, f"LINES LOST: {dict(removed)}"
unexpected = {k: n for k, n in added.items() if not k.startswith(";;;;")}
assert not unexpected, f"UNEXPECTED ADDITIONS: {unexpected}"
print("OK: nothing lost; additions are duplicated section headers only")
EOF
```

Expected: `OK: nothing lost; additions are duplicated section headers only`.

All 20 gates contain at least one activation form, so no gate disappears and the gate
lines must balance to zero. Any entry under `removed` is a splitter bug — fix `scripts/myde-split.py`, restore `myde.org` from
`~/.local/state/myde-probe-reports/myde.org.presplit`, and re-run.

- [ ] **Step 5: Commit the org change only**

```bash
git add myde.org
git commit -m "Split myde.org sections into definition and activation blocks"
```

---

## Task 4: Tangle and verify structurally

**Files:**
- Modify (as output): `~/devel/worktrees/myde-library-split/init.el`, `user-lisp/myde.el`
- Create: `~/devel/worktrees/myde-library-split/scripts/myde-forms.py`

- [ ] **Step 1: Tangle**

```bash
cd ~/devel/worktrees/myde-library-split
make tangle
wc -l init.el user-lisp/myde.el
```

Expected: `init.el` around 4,000 lines, `user-lisp/myde.el` around 900. Both must exist.

- [ ] **Step 2: Add the form-kind inventory script**

Create `scripts/myde-forms.py`:

```python
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
    "define-derived-mode", "define-minor-mode", "eval-when-compile", "provide",
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
```

- [ ] **Step 3: Assert the library holds only definitions**

```bash
cd ~/devel/worktrees/myde-library-split
python3 scripts/myde-forms.py user-lisp/myde.el --defs-only
```

Expected: a table of `defun`/`defvar`/`defcustom`/`defconst`/`define-*`/`provide`
counts, exit status 0, and no `ERROR:` block. Expected counts: `57 defun`, `11 defvar`,
`1` each of `defcustom`, `defconst`, `define-derived-mode`, `define-minor-mode`,
`eval-when-compile`, `provide`.

If it exits 1, the listed forms are activation code the splitter left behind. Fix
`DEFS` or the splitter, restore, re-run Task 3.

- [ ] **Step 4: Assert the activation file is complete**

```bash
cd ~/devel/worktrees/myde-library-split
python3 scripts/myde-forms.py init.el | head -20
```

Expected to include `135 use-package`, `20 setq` plus the bootstrap's own, `22 when`
(20 gates plus 2 others) and `4 add-hook`. The `use-package` count must be exactly 135
— a lower number means forms were dropped.

- [ ] **Step 5: Assert section order is unchanged**

```bash
cd ~/devel/worktrees/myde-library-split
R=~/.local/state/myde-probe-reports
grep '^;;;; [a-z]' init.el | grep -v '^;;;; -' > $R/01-sections.txt
diff $R/00-sections.txt $R/01-sections.txt
```

Expected: the only differences are two added lines, `;;;; Use-package support` and
`;;;; Configuration`, which the bootstrap block contributes to `init.el`. Any
*removed* line, or any reordering, is a regression — the 52 section headers must appear
in `init.el` in exactly the order `00-sections.txt` records.

- [ ] **Step 6: `make check`**

```bash
cd ~/devel/worktrees/myde-library-split
make check
```

Expected: `tangled output is up to date`.

- [ ] **Step 7: Probe and compare against the baseline**

```bash
cd ~/devel/worktrees/myde-library-split
scripts/myde-probe.sh "$PWD" ~/.local/state/myde-probe-reports/01-split.txt
diff <(grep -E '^(declared|mode):' ~/.local/state/myde-probe-reports/00-baseline.txt) \
     <(grep -E '^(declared|mode):' ~/.local/state/myde-probe-reports/01-split.txt) \
  && echo "NO REGRESSION"
```

Expected: `init-file-had-error: nil`, `declared packages: 161`, `modes off: 0`,
`startup errors: none`, and `NO REGRESSION`.

If `init-file-had-error: t`, read the daemon's `*Messages*`. The likely causes, in order:
a definition that a `use-package` form references was left inside a gate and is now
undefined when the binary is absent; a `setq` that a `defvar` initform read moved after
it; or the splitter mis-parsed a form and produced unbalanced parens, which shows as a
`End of file during parsing` error naming a line in `init.el`.

- [ ] **Step 8: Commit the tangled output**

```bash
cd ~/devel/worktrees/myde-library-split
git add scripts/myde-forms.py init.el user-lisp/myde.el
git commit -m "Tangle the library/config split"
```

---

## Task 5: Wire the assertion into make, drop the splitter, update docs

**Files:**
- Modify: `~/devel/worktrees/myde-library-split/Makefile`
- Delete: `~/devel/worktrees/myde-library-split/scripts/myde-split.py`
- Modify: `.agents/AGENTS.md`, `.agents/skills/myde/SKILL.md`, `README.md`

- [ ] **Step 1: Add a `forms` target**

Append to the `##@ Literate config targets` section of the `Makefile`:

```make
.PHONY: forms
forms: ## Assert user-lisp/myde.el contains only definitions
	@python3 scripts/myde-forms.py user-lisp/myde.el --defs-only >/dev/null
	@echo "user-lisp/myde.el contains only definitions"
```

Then change the `check` target's prerequisites from `tangle` to `tangle forms`, so its
first line reads:

```make
check: tangle forms ## Verify committed elisp matches myde.org
```

- [ ] **Step 2: Verify the new target both passes and can fail**

```bash
cd ~/devel/worktrees/myde-library-split
make forms
printf '\n(setq myde-deliberate-breakage t)\n' >> user-lisp/myde.el
make forms; echo "exit=$?"
git checkout user-lisp/myde.el
make forms
```

Expected: pass, then an `ERROR: 1 non-definition forms` block with `exit=1`, then pass
again after the checkout.

- [ ] **Step 3: Delete the splitter**

```bash
cd ~/devel/worktrees/myde-library-split
git rm scripts/myde-split.py
```

- [ ] **Step 4: Update `.agents/AGENTS.md`**

In the *Files* table, change the `init.el` and `user-lisp/myde.el` rows to:

| `init.el` | Tangled from `* Bootstrap` and from the activation blocks of `* Configuration`. Installs elpaca, `(require 'myde)`, then every `use-package` form, binary gate, and variable assignment in load order. |
| `user-lisp/myde.el` | Tangled from the definition blocks of `* Configuration`. Definitions only — `defun`, `defvar`, `defcustom`, `defconst`, `define-derived-mode`, `define-minor-mode`. No side effects, asserted by `make forms`. |

Add to the *Commands* block:

```shell
make forms     # Assert user-lisp/myde.el contains only definitions
```

In *Section enablement: presence is intent*, add after the existing gate paragraph:

> Gates live in `init.el` only. `myde.el` defines its functions unconditionally, so a
> `myde-prog-go-*` function exists whether or not `go` is installed. Nothing calls it
> unless the gate passed.

In *Editing workflow*, replace step 1 with:

> 1. Edit `myde.org`. A section's `***` heading holds up to two blocks: definitions,
>    carrying `:tangle user-lisp/myde.el`, and activation, inheriting `:tangle init.el`.
>    Put `defun`/`defvar` in the first and `use-package`/`setq`/`add-hook` in the second.
>    Wrap the activation block's body in a binary gate if the tool needs a toolchain.

- [ ] **Step 5: Update `.agents/skills/myde/SKILL.md`**

Change the *Edit myde.org only* bullet list so the third entry reads:

> - `* Early Init` tangles to `early-init.el`. `* Bootstrap` and the activation blocks of
>   `* Configuration` tangle to `init.el`. The definition blocks of `* Configuration`
>   tangle to `user-lisp/myde.el`.

Replace the *Adding support for a tool* example with:

````markdown
```org
*** prog-foo

#+begin_src emacs-lisp :tangle user-lisp/myde.el
;;;; prog-foo
;;;; --------

(defun myde-prog-foo-setup ()
  "Set buffer-local settings for Foo buffers."
  (setq-local fill-column 100))
#+end_src

#+begin_src emacs-lisp
;;;; prog-foo
;;;; --------
;; Gate: foo

(when (executable-find "foo")

(use-package foo-mode
  :mode "\\.foo\\'"
  :hook (foo-mode . myde-prog-foo-setup))

  )
#+end_src
```
````

Add to the *Quality checklist*:

> - [ ] Definitions are in the `:tangle user-lisp/myde.el` block, activation in the
>   inheriting block. `make forms` passes.

Bump the skill's `version` frontmatter to `3.0.0`.

- [ ] **Step 6: Update `README.md`**

In the organization section, change the file descriptions to match the new split, using
the same two sentences as the AGENTS.md table rows in step 4.

- [ ] **Step 7: Verify and commit**

```bash
cd ~/devel/worktrees/myde-library-split
make check
make forms
git add -A
git commit -m "Assert the definitions-only invariant; update docs for the split"
```

Expected: both targets pass, tree clean afterwards.

---

## Task 6: Go live

- [ ] **Step 1: Re-probe the final branch state**

```bash
cd ~/devel/worktrees/myde-library-split
scripts/myde-probe.sh "$PWD" ~/.local/state/myde-probe-reports/02-final.txt
diff <(grep -E '^(declared|mode):' ~/.local/state/myde-probe-reports/00-baseline.txt) \
     <(grep -E '^(declared|mode):' ~/.local/state/myde-probe-reports/02-final.txt) \
  && echo "NO REGRESSION"
```

Expected: `NO REGRESSION`.

- [ ] **Step 2: Merge**

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
git merge --no-ff migration/library-config-split -m "Merge library/config split

user-lisp/myde.el now holds definitions only; every use-package form, binary
gate and variable assignment moved to init.el. Both are still tangled from
myde.org, which keeps one heading per section with two blocks."
make check && make forms
```

Expected: both targets pass on the main tree.

- [ ] **Step 3: Restart the daemon and verify the live config**

```bash
launchctl kickstart -k gui/$(id -u)/gnu.emacs.daemon
sleep 20
emacsclient -e '(list :init-err init-file-had-error :myde (featurep (quote myde)) :vertico (bound-and-true-p vertico-mode) :go (executable-find "go"))'
```

Expected: `(:init-err nil :myde t :vertico t :go "/opt/homebrew/bin/go")`.

- [ ] **Step 4: Verify a client frame still renders the dashboard**

```bash
emacsclient -c -n
sleep 3
emacsclient -e '(car (delq nil (mapcar (lambda (f) (when (frame-parameter f (quote client)) (let ((b (window-buffer (frame-selected-window f)))) (list (buffer-name b) (buffer-local-value (quote major-mode) b))))) (frame-list))))'
```

Expected: `("*dashboard*" dashboard-mode)`.

- [ ] **Step 5: Clean up**

```bash
cd /Users/edwin-gooch/devel/repos/github.com/mojochao/myde.emacs
git worktree remove ~/devel/worktrees/myde-library-split
git branch -d migration/library-config-split
git status --porcelain && echo "(clean)"
```

Expected: `(clean)`. Keep `~/.local/state/myde-probe-reports/` until satisfied;
`00-baseline.txt` is the only record of the pre-split state.

---

## Follow-up work

- Byte/native compilation of `user-lisp/myde.el`, with a measurement behind it. See the
  spec's *Compilation* section for why it is deliberately out of scope here.
- Deferral audit via `M-x use-package-report`, now that every `use-package` form is in
  one file.
- Collapsing the 25 `indent-bars` hook-only forms into one.
