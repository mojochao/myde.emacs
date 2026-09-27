#!/usr/bin/env python3
"""Vendor the docs site's third-party assets into docs/vendor/, or check them.

Usage:
    python3 scripts/vendor_docs.py          fetch every pin into docs/vendor/
    python3 scripts/vendor_docs.py --check  offline: fail on a remote reference,
                                            or a missing or unloaded asset

To upgrade, edit a pin below, run the script, and review the git diff.
"""

import argparse
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INDEX = ROOT / "docs" / "index.html"
VENDOR = ROOT / "docs" / "vendor"

NPM = "https://cdn.jsdelivr.net/npm"
CATPPUCCIN = "https://raw.githubusercontent.com/catppuccin/docsify/628ff2668a8d952b6ef04e435632cc3470cd24b2"

# One Prism grammar per fence language the docs use. docsify 4 bundles Prism
# core with markup, css, clike, and javascript. bash also covers sh and shell,
# and lisp covers elisp. index.html loads these in list order, so a grammar
# that extends another (cpp extends c) must come after it.
PRISM_LANGS = ["bash", "elixir", "lisp"]

PINS = {
    "docsify.min.js": f"{NPM}/docsify@4.13.1/lib/docsify.min.js",
    "search.min.js": f"{NPM}/docsify@4.13.1/lib/plugins/search.min.js",
    "theme-simple-dark.css": f"{NPM}/docsify-themeable@0.9.0/dist/css/theme-simple-dark.css",
    "catppuccin-frappe-mauve.css": f"{CATPPUCCIN}/themes/frappe/mauve.css",
    # prismjs.catppuccin.com publishes no versions. Last fetched 2026-09-27.
    "catppuccin-prism-frappe.css": "https://prismjs.catppuccin.com/frappe.css",
}
PINS.update({
    f"prism-{lang}.min.js": f"{NPM}/prismjs@1.30.0/components/prism-{lang}.min.js"
    for lang in PRISM_LANGS
})

# The Catppuccin theme imports its Prism colors from a remote host. Point it at
# the vendored copy, so the published site fetches nothing third-party.
REWRITES = {
    "catppuccin-frappe-mauve.css": (
        "@import url(https://prismjs.catppuccin.com/frappe.css);",
        "@import url(catppuccin-prism-frappe.css);",
    ),
}

# Loaded by another vendored file rather than by index.html.
INDIRECT = {"catppuccin-prism-frappe.css"}

REMOTE_RE = re.compile(r"""(?:@import\s+|url\(\s*|\b(?:src|href)\s*=\s*)['"]?(?:https?:)?//""", re.I)
VENDOR_REF_RE = re.compile(r"vendor/([\w.-]+)")


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "myde-vendor-docs"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def vendor():
    VENDOR.mkdir(parents=True, exist_ok=True)
    for name, url in PINS.items():
        data = fetch(url)
        if name in REWRITES:
            old, new = REWRITES[name]
            text = data.decode("utf-8")
            if old not in text:
                sys.exit(f"{name}: upstream no longer contains {old!r}, update REWRITES")
            data = text.replace(old, new).encode("utf-8")
        path = VENDOR / name
        changed = not path.exists() or path.read_bytes() != data
        path.write_bytes(data)
        print(f"  {'changed' if changed else 'unchanged':9} {name}")
    for path in sorted(VENDOR.iterdir()):
        if path.name not in PINS:
            print(f"  stale     {path.name}    not pinned, delete it")
    return 0


def check():
    problems = []
    for path in [INDEX, *sorted(VENDOR.glob("*.css"))]:
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if REMOTE_RE.search(line):
                problems.append(f"{path.relative_to(ROOT)}:{n}: remote reference")
    loaded = set(VENDOR_REF_RE.findall(INDEX.read_text(encoding="utf-8")))
    for name in sorted(loaded - set(PINS)):
        problems.append(f"docs/index.html: loads vendor/{name}, which is not pinned")
    for name in sorted(set(PINS) - INDIRECT - loaded):
        problems.append(f"docs/index.html: never loads pinned vendor/{name}")
    for name in sorted(PINS):
        if not (VENDOR / name).exists():
            problems.append(f"docs/vendor/{name}: pinned but missing, run mise run docs-vendor")
    for problem in problems:
        print(problem)
    print(f"\n{len(problems)} vendoring issue(s) found")
    return 1 if problems else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description="Vendor or check the docs site's assets.")
    parser.add_argument("--check", action="store_true", help="check offline, write nothing")
    args = parser.parse_args(argv)
    return check() if args.check else vendor()


if __name__ == "__main__":
    sys.exit(main())
