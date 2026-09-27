#!/usr/bin/env python3
"""Check requirement traceability across the docs site.

The chain runs from a requirement in prd.md through the ADRs, the technical
design, QA, and the roadmap to the changelog. Each downstream doc links the
requirements it serves, and each requirement's section 8.3 block links forward
to those docs. This checker fails when the two directions disagree or a link in
the chain is missing. General link and anchor validity is check_links.py's job.

Usage:
    python3 scripts/check_trace.py [--root <repo>]
"""

import argparse
import re
import sys
from pathlib import Path

from check_links import LINK_RE, docsify_slugify, mask_code

DOCS = ("prd.md", "adr.md", "tdd.md", "qa.md", "roadmap.md", "changelog.md")

HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*$")
ID_ATTR_RE = re.compile(r"\s*:id=([A-Za-z0-9_-]+)")
ROW_RE = re.compile(r"^\|\s*(N?FR-\d+)\s*\|")
FIELD_RE = re.compile(r"^\s*-\s+\*\*([A-Za-z ]+):\*\*\s*(.*)$")
REQ_TITLE_RE = re.compile(r"^N?FR-\d+$")
REQ_ANCHOR_RE = re.compile(r"^n?fr-\d+$")
ADR_ANCHOR_RE = re.compile(r"^adr-\d+$")
RM_ANCHOR_RE = re.compile(r"^rm-\d+$")

# Forward field -> (the doc its links must target, whether it may read `none`).
FORWARD = {
    "Decided by": ("adr.md", True),
    "Designed in": ("tdd.md", False),
    "Verified by": ("qa.md", False),
    "Roadmap": ("roadmap.md", True),
}


class Section:
    """A heading and everything under it, up to the next heading at the same or
    higher level. `lines` holds (line number, text with code masked out)."""

    def __init__(self, doc, level, title, anchor, lines, parent):
        self.doc = doc
        self.level = level
        self.title = title
        self.anchor = anchor
        self.lines = lines
        self.parent = parent
        self.line = lines[0][0]

    def links(self):
        return links(self.doc, [text for _, text in self.lines])

    def field(self, name):
        """(line number, value) of the first `- **name:** value` line, or None."""
        for n, text in self.lines:
            m = FIELD_RE.match(text)
            if m and m.group(1) == name:
                return n, m.group(2).strip()
        return None


def links(doc, texts):
    """(target doc, anchor) for every internal link in texts."""
    out = []
    for text in texts:
        for m in LINK_RE.finditer(text):
            target = m.group(1).strip()
            if target.startswith(("http://", "https://", "mailto:")):
                continue
            path, _, anchor = target.partition("#")
            out.append((Path(path).name if path else doc, anchor))
    return out


def requirements(pairs):
    """The requirement IDs among (doc, anchor) link targets."""
    return {a.upper() for d, a in pairs if d == "prd.md" and REQ_ANCHOR_RE.match(a)}


def parse(path):
    """(masked lines, sections) for one doc. Headings are found in the masked
    text, so a `#` inside a code block is not a heading, and titled from the raw
    text, so an inline code span in a title still slugs the way docsify does."""
    if not path.exists():
        return [], []
    raw = path.read_text(encoding="utf-8").splitlines()
    masked = mask_code("\n".join(raw)).splitlines()
    heads = []
    for i, text in enumerate(masked):
        if not HEADING_RE.match(text):
            continue
        m = HEADING_RE.match(raw[i])
        title = m.group(2)
        idm = ID_ATTR_RE.search(title)
        anchor = idm.group(1) if idm else docsify_slugify(title)
        heads.append((i, len(m.group(1)), ID_ATTR_RE.sub("", title).strip(), anchor))
    sections = []
    for k, (i, level, title, anchor) in enumerate(heads):
        end = next((j for j, lv, _, _ in heads[k + 1:] if lv <= level), len(masked))
        parent = next((t for _, lv, t, _ in reversed(heads[:k]) if lv == 2), None)
        body = [(n + 1, masked[n]) for n in range(i, end)]
        sections.append(Section(path.name, level, title, anchor, body, parent))
    return masked, sections


def entries(section):
    """(line number, lines) for each top-level bullet, with its indented
    continuation lines. A non-indented, non-blank line ends an entry."""
    out, current = [], None
    for n, text in section.lines:
        if text.startswith("- "):
            current = [text]
            out.append((n, current))
        elif current is not None and text[:1].isspace() and text.strip():
            current.append(text)
        elif text.strip():
            current = None
    return out


def check(root):
    """Every traceability finding for the repo at root, as printable lines."""
    docs = Path(root) / "docs"
    text, sections = {}, {}
    for name in DOCS:
        text[name], sections[name] = parse(docs / name)
    findings = []

    def find(doc, line, message):
        findings.append(f"docs/{doc}:{line}: {message}")

    def section(doc, anchor):
        return next((s for s in sections[doc] if s.anchor == anchor), None)

    # Rule 1: the section 8 tables and the section 8.3 blocks name the same requirements.
    blocks = {s.title: s for s in sections["prd.md"] if REQ_TITLE_RE.match(s.title)}
    rows = {}
    for n, line in enumerate(text["prd.md"], 1):
        m = ROW_RE.match(line)
        if m:
            rows.setdefault(m.group(1), n)
    for rid, n in rows.items():
        if rid not in blocks:
            find("prd.md", n, f"{rid} is in a requirements table but has no section 8.3 block")
    for rid, block in blocks.items():
        if rid not in rows:
            find("prd.md", block.line, f"{rid} has a section 8.3 block but no requirements table row")

    # Rules 2 and 3: every block has its forward fields, and each forward link is backed.
    forward = {}
    for rid, block in blocks.items():
        forward[rid] = {}
        for name, (doc, may_be_none) in FORWARD.items():
            forward[rid][name] = set()
            field = block.field(name)
            if field is None:
                find("prd.md", block.line, f"{rid} has no {name} field")
                continue
            n, value = field
            targets = links("prd.md", [value])
            if not targets and not (may_be_none and re.match(r"none\b", value)):
                wanted = f"a link to {doc}" + (" or `none`" if may_be_none else "")
                find("prd.md", n, f"{rid} {name} needs {wanted}")
            for tdoc, anchor in targets:
                if tdoc != doc:
                    find("prd.md", n, f"{rid} {name} links {tdoc}, expected {doc}")
                    continue
                target = section(doc, anchor)
                if target is None:
                    find("prd.md", n, f"{rid} {name} links {doc}#{anchor}, which does not exist")
                    continue
                forward[rid][name].add(anchor)
                if rid not in requirements(target.links()):
                    find(doc, target.line, f"'{target.title}' is in {rid} {name} but does not link {rid}")

    # Rules 4, 5, and 6: ADRs and roadmap items link known requirements, and each
    # requirement's forward field lists every ADR and roadmap item that links it.
    adrs = [s for s in sections["adr.md"] if ADR_ANCHOR_RE.match(s.anchor)]
    rms = [s for s in sections["roadmap.md"] if RM_ANCHOR_RE.match(s.anchor)]
    for s in adrs + rms:
        label = s.anchor.upper()
        is_rm = s.doc == "roadmap.md"
        field = "Roadmap" if is_rm else "Decided by"
        cited = requirements(s.links())
        cited_adrs = {a for d, a in s.links() if d == "adr.md" and ADR_ANCHOR_RE.match(a)} if is_rm else set()
        for a in sorted(cited_adrs):
            if section("adr.md", a) is None:
                find(s.doc, s.line, f"{label} links {a.upper()}, which adr.md does not define")
        if not cited and not cited_adrs:
            find(s.doc, s.line, f"{label} links no requirement" + (" or ADR" if is_rm else ""))
        for rid in sorted(cited):
            if rid not in blocks:
                find(s.doc, s.line, f"{label} links {rid}, which prd.md does not define")
            elif s.anchor not in forward[rid][field]:
                find("prd.md", blocks[rid].line, f"{rid} {field} does not list {label}, which links {rid}")

    # Rule 7: changelog entries link roadmap items, and every shipped item has an
    # entry under the version its Shipped field names.
    entry_rms = {}
    for version in (s for s in sections["changelog.md"] if s.level == 2):
        for n, entry in entries(version):
            linked = {a for d, a in links("changelog.md", entry) if d == "roadmap.md" and RM_ANCHOR_RE.match(a)}
            if not linked:
                find("changelog.md", n, "entry links no roadmap item")
            for a in sorted(linked):
                if section("roadmap.md", a) is None:
                    find("changelog.md", n, f"entry links {a.upper()}, which roadmap.md does not define")
            entry_rms.setdefault(version.anchor, set()).update(linked)
    for s in rms:
        if s.parent != "Shipped":
            continue
        label = s.anchor.upper()
        field = s.field("Shipped")
        versions = [a for d, a in links("roadmap.md", [field[1]]) if d == "changelog.md"] if field else []
        if not versions:
            find("roadmap.md", s.line, f"{label} is shipped but has no Shipped link to a changelog version")
        elif not any(s.anchor in entry_rms.get(v, ()) for v in versions):
            where = ", ".join(sorted(v for v, linked in entry_rms.items() if s.anchor in linked)) or "no version"
            find("roadmap.md", field[0], f"{label} Shipped links {', '.join(versions)}, but its changelog entry is under {where}")
    return findings


def main(argv=None):
    parser = argparse.ArgumentParser(description="Check requirement traceability across docs/.")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent,
                        help="repo root, by default the one holding this script")
    args = parser.parse_args(argv)
    findings = check(args.root)
    for finding in findings:
        print(finding)
    print(f"\n{len(findings)} traceability issue(s) found")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
