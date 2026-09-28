#!/usr/bin/env python3
"""Tests for release_notes.py: the right section is cut, and doc links point at the site.

Run: python3 scripts/test_release_notes.py
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from release_notes import DOCS_URL, absolute_links, section  # noqa: E402

CHANGELOG = """# Changelog

Intro.

## Unreleased

### Fixed

- Not released yet.

## 0.2.0 - 2026-10-01

### Added

- Two.

## 0.1.0 - 2026-09-28

### Fixed

- One.
"""


class SectionTest(unittest.TestCase):
    def test_cuts_between_headings_without_the_heading(self):
        self.assertEqual(section(CHANGELOG, "0.2.0"), "### Added\n\n- Two.\n")

    def test_last_section_runs_to_end_of_file(self):
        self.assertEqual(section(CHANGELOG, "0.1.0"), "### Fixed\n\n- One.\n")

    def test_missing_version_is_none(self):
        self.assertIsNone(section(CHANGELOG, "9.9.9"))

    def test_version_is_not_a_prefix_match(self):
        self.assertIsNone(section(CHANGELOG, "0.1"))


class AbsoluteLinksTest(unittest.TestCase):
    def test_page_and_anchor(self):
        self.assertEqual(
            absolute_links("[RM-11](roadmap.md#rm-11)"),
            f"[RM-11]({DOCS_URL}#/roadmap?id=rm-11)",
        )

    def test_page_without_anchor(self):
        self.assertEqual(absolute_links("[PRD](prd.md)"), f"[PRD]({DOCS_URL}#/prd)")

    def test_external_links_are_untouched(self):
        text = "[fork](https://github.com/mojochao/ob-zig.el) and `roadmap.md`"
        self.assertEqual(absolute_links(text), text)


if __name__ == "__main__":
    unittest.main()
