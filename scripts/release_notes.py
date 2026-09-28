#!/usr/bin/env python3
"""Print the docs/changelog.md section for the version in VERSION, as release notes.

`mise run release` passes the output to `gh release create`. The section is
everything between the `## <version> - <date>` heading and the next `## `
heading, without the heading itself, since the release title already names it.

Links to docs pages are relative (`roadmap.md#rm-11`). A release page resolves
them against github.com/<repo>/releases/tag/, where they 404, so they are
rewritten to the published docsify site, which routes pages as `#/<page>` and
anchors as `?id=<anchor>`.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# ponytail: the Pages URL is fixed by the repo name, so it is a constant rather
# than an API lookup.  Change it here if the site moves to a custom domain.
DOCS_URL = "https://mojochao.github.io/myde.emacs/"

DOC_LINK_RE = re.compile(r"\]\(([A-Za-z0-9_-]+)\.md(?:#([^)\s]+))?\)")


def section(changelog, version):
    """Return the body of CHANGELOG's `## VERSION - ' section, or None."""
    lines = changelog.splitlines()
    head = f"## {version} - "
    start = next((i for i, line in enumerate(lines) if line.startswith(head)), None)
    if start is None:
        return None
    end = next(
        (i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")),
        len(lines),
    )
    return "\n".join(lines[start + 1 : end]).strip() + "\n"


def absolute_links(markdown):
    """Rewrite relative `page.md#anchor' links in MARKDOWN to the docs site."""

    def to_site(m):
        page, anchor = m.group(1), m.group(2)
        url = f"{DOCS_URL}#/{page}"
        return f"]({url}?id={anchor})" if anchor else f"]({url})"

    return DOC_LINK_RE.sub(to_site, markdown)


def main():
    version = (ROOT / "VERSION").read_text().strip()
    body = section((ROOT / "docs" / "changelog.md").read_text(), version)
    if body is None:
        print(f"docs/changelog.md has no '## {version} - <date>' heading", file=sys.stderr)
        return 1
    sys.stdout.write(absolute_links(body))
    return 0


if __name__ == "__main__":
    sys.exit(main())
