#!/usr/bin/env python3
"""Cut a release: set VERSION, turn Unreleased into its changelog section, point the roadmap at it.

Run by `mise run cut <version>`, which then commits, tags, and pushes. This
script only edits files, and every check runs before anything is written. It
refuses when the version is not MAJOR.MINOR.PATCH or not above VERSION, when
the changelog already has that section, when Unreleased has no entries, and
when the roadmap's `## Now` still lists items, since only a person can decide
whether those shipped.

Usage: python3 scripts/cut_release.py <version>
"""

import datetime
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_links import docsify_slugify  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent

USAGE = "usage: python3 scripts/cut_release.py <version>"

FRESH_UNRELEASED = "## Unreleased\n\n### Added\n\n### Changed\n\n### Fixed\n\n"


class CutError(Exception):
    """A reason not to cut the release."""


def section_span(text, heading):
    """Return the match for `## HEADING` through the next `## ` heading, or None."""
    return re.search(rf"^## {re.escape(heading)}\n(.*?)(?=^## |\Z)", text, re.M | re.S)


def check_version(version, current):
    """Raise CutError unless VERSION is MAJOR.MINOR.PATCH and above CURRENT."""
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise CutError(f"version {version!r} is not MAJOR.MINOR.PATCH")
    if tuple(map(int, version.split("."))) <= tuple(map(int, current.split("."))):
        raise CutError(f"version {version} is not above the current VERSION {current}")


def cut_changelog(text, version, date):
    """Return TEXT with Unreleased renamed to VERSION - DATE and a fresh Unreleased above it.

    Empty `###` subsections are dropped from the released section.
    """
    if re.search(rf"^## {re.escape(version)} - ", text, re.M):
        raise CutError(f"docs/changelog.md already has a {version} section")
    m = section_span(text, "Unreleased")
    if not m:
        raise CutError("docs/changelog.md has no ## Unreleased section")
    parts = re.split(r"(?m)^(?=### )", m.group(1))
    kept = [p for p in parts if p.strip() and not (p.startswith("### ") and not p.split("\n", 1)[1].strip())]
    if not any(p.startswith("### ") for p in kept):
        raise CutError("Unreleased has no entries, so there is nothing to release")
    released = f"## {version} - {date}\n\n" + "".join(p.strip("\n") + "\n\n" for p in kept)
    return text[: m.start()] + FRESH_UNRELEASED + released + text[m.end() :]


def now_items(text):
    """Return the `###` item headings under the roadmap's `## Now`."""
    m = section_span(text, "Now")
    return re.findall(r"^### (.+)$", m.group(1), re.M) if m else []


def repoint_roadmap(text, version, date):
    """Return TEXT with its Unreleased changelog links pointed at the VERSION - DATE heading."""
    anchor = docsify_slugify(f"{version} - {date}")
    return text.replace("[Unreleased](changelog.md#unreleased)", f"[{version}](changelog.md#{anchor})")


def main(argv):
    if len(argv) != 2:
        print(USAGE, file=sys.stderr)
        return 2
    version, date = argv[1], datetime.date.today().isoformat()
    version_file = ROOT / "VERSION"
    changelog_file = ROOT / "docs" / "changelog.md"
    roadmap_file = ROOT / "docs" / "roadmap.md"
    try:
        check_version(version, version_file.read_text().strip())
        changelog = cut_changelog(changelog_file.read_text(), version, date)
        roadmap = roadmap_file.read_text()
        if now_items(roadmap):
            raise CutError(
                "docs/roadmap.md still lists items under ## Now: "
                + ", ".join(now_items(roadmap))
                + ". Move the shipped ones to ## Shipped first."
            )
        roadmap = repoint_roadmap(roadmap, version, date)
    except CutError as e:
        print(f"cut: {e}", file=sys.stderr)
        return 1
    version_file.write_text(version + "\n")
    changelog_file.write_text(changelog)
    roadmap_file.write_text(roadmap)
    print(f"cut {version} - {date}: VERSION, docs/changelog.md, docs/roadmap.md")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
