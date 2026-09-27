#!/usr/bin/env python3
"""Check internal markdown links (relative paths + anchors) across git-tracked *.md files.

Anchors are matched using docsify's actual slugify algorithm (see
docsifyjs/docsify src/core/render/slugify.js), not GitHub's, since this repo's
docs/ site is served by docsify. Headings with an explicit docsify `:id=` are
matched by that id instead.

Link resolution follows docsify too, not the filesystem: a target starting with
`/` is relative to the docs root, and the `':include ...'` directive that
docsify allows after a path is not part of the path.
"""

import os
import re
import subprocess
import sys
import urllib.parse

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
# The unicode punctuation ranges are copied verbatim from docsify's slugify and
# deliberately include ambiguous look-alike spaces (EN QUAD and friends), so
# RUF001's "did you mean SPACE?" is wrong here: replacing them would stop
# matching the characters docsify actually strips.
PUNCT_RE = re.compile("[ -⁯⸀-⹿\\\\'!\"#$%&()*+,./:;<=>?@\\[\\]^`{|}~]")  # noqa: RUF001


# The docsify site root. docsify resolves a link beginning with "/" against
# this directory, so `/user.md` in the sidebar means `docs/user.md`, not a path
# at the filesystem root.
DOCS_ROOT = "docs"

# Plans and specs under docs/superpowers/ are point-in-time records of what was
# true when they were written. Their links are deliberately not retrofitted when
# files move, and they carry illustrative placeholders like `#adr-NN`, so
# checking them reports history rather than defects.
ARCHIVE_PREFIX = f"{DOCS_ROOT}/superpowers/"

# docsify embeds a file with [title](path ':include :type=code'). The directive
# rides in the link target after the path, so strip it before resolving.
DIRECTIVE_RE = re.compile(r"\s+'[^']*'$")

FENCED_RE = re.compile(r"^ {0,3}(```|~~~).*?^ {0,3}\1[^\n]*", re.M | re.S)
CODE_SPAN_RE = re.compile(r"``[^`]+``|`[^`\n]+`")


def mask_code(content):
    """Blank out fenced code blocks and inline code spans, preserving newlines,
    so illustrative links inside code are not treated as real links."""

    def blank(m):
        return re.sub(r"[^\n]", " ", m.group(0))

    return CODE_SPAN_RE.sub(blank, FENCED_RE.sub(blank, content))


def docsify_slugify(s):
    s = s.strip()
    s = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", s)
    s = re.sub(r"[A-Z]+", lambda m: m.group(0).lower(), s)
    s = re.sub(r"<[^>]+>", "", s)
    s = PUNCT_RE.sub("", s)
    # docsify collapses runs of whitespace AND hyphens to a single '-': its
    # chain is .replace(/\s/g,'-').replace(/-+/g,'-'). Doing only the first
    # means a heading like `corpus --version` slugs to 'corpus---version'
    # instead of 'corpus-version', so correct links to it look broken and
    # incorrect ones look fine.
    s = re.sub(r"[\s-]+", "-", s)
    s = re.sub(r"^(\d)", r"_\1", s)
    return s


def get_headings(path):
    anchors = {}
    if not os.path.exists(path):
        return anchors
    with open(path, encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            m = re.match(r"^(#{1,6})\s+(.*)", line)
            if not m:
                continue
            heading = m.group(2).strip()
            idm = re.search(r":id=([A-Za-z0-9_-]+)", heading)
            if idm:
                anchors.setdefault(idm.group(1), lineno)
                heading = re.sub(r":id=[A-Za-z0-9_-]+", "", heading).strip()
            slug = docsify_slugify(heading)
            anchors.setdefault(slug, lineno)
    return anchors


def main():
    files = subprocess.run(
        ["git", "ls-files", "*.md"], capture_output=True, text=True
    ).stdout.splitlines()

    issues = []
    for f in files:
        # A tracked file can be staged for deletion (git ls-files still lists it)
        # yet be gone from the working tree. Skip it rather than crash.
        if not os.path.exists(f):
            continue
        if f.startswith(ARCHIVE_PREFIX):
            continue
        with open(f, encoding="utf-8") as fh:
            content = fh.read()
        base_dir = os.path.dirname(f)
        for m in LINK_RE.finditer(mask_code(content)):
            target = DIRECTIVE_RE.sub("", m.group(1).strip())
            if target.startswith(("http://", "https://", "mailto:")):
                continue
            line_no = content[: m.start()].count("\n") + 1
            path_part, _, anchor = target.partition("#")
            if path_part == "":
                resolved = f
            elif path_part == "/":
                # The docsify home route, served from the docs root README.
                resolved = f"{DOCS_ROOT}/README.md"
            elif path_part.startswith("/"):
                resolved = os.path.normpath(
                    os.path.join(DOCS_ROOT, urllib.parse.unquote(path_part).lstrip("/"))
                )
            else:
                resolved = os.path.normpath(os.path.join(base_dir, urllib.parse.unquote(path_part)))
            if path_part != "" and not os.path.exists(resolved):
                issues.append((f, line_no, target, f"FILE NOT FOUND: {resolved}"))
                continue
            if anchor:
                anchors = get_headings(resolved)
                if anchor not in anchors:
                    issues.append((f, line_no, target, f"ANCHOR NOT FOUND in {resolved}"))

    for f, line_no, target, reason in issues:
        print(f"{f}:{line_no}: [{target}] -> {reason}")
    print(f"\n{len(issues)} issue(s) found across {len(files)} files")
    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
