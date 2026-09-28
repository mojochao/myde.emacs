#!/usr/bin/env python3
"""Tests for cut_release.py: the changelog and roadmap edits, and every refusal.

Run: python3 scripts/test_cut_release.py
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cut_release import (  # noqa: E402
    FRESH_UNRELEASED,
    CutError,
    check_version,
    cut_changelog,
    now_items,
    repoint_roadmap,
)

CHANGELOG = """# Changelog

Intro.

## Unreleased

### Added

### Changed

### Fixed

- 2026-09-28: A fix.
  Commit `abc1234`.

## 0.1.2 - 2026-09-20

### Fixed

- Older.
"""

ROADMAP_EMPTY_NOW = """# Roadmap

## Now

Nothing is in progress.

## Shipped

### RM-2: Two :id=rm-2

- **Shipped:** 2026-09-28, [Unreleased](changelog.md#unreleased)

### RM-1: One :id=rm-1

- **Shipped:** 2026-09-20, [0.1.2](changelog.md#_012-2026-09-20)
"""


class CheckVersionTest(unittest.TestCase):
    def test_accepts_a_higher_patch_minor_or_major(self):
        for v in ("0.1.3", "0.2.0", "1.0.0", "0.1.10"):
            check_version(v, "0.1.2")

    def test_compares_numerically_not_as_strings(self):
        check_version("0.1.10", "0.1.9")

    def test_rejects_equal_or_lower(self):
        for v in ("0.1.2", "0.1.1", "0.0.9"):
            with self.assertRaises(CutError):
                check_version(v, "0.1.2")

    def test_rejects_other_shapes(self):
        for v in ("v0.1.3", "0.1", "0.1.3-rc1", "0.1.3;rm", ""):
            with self.assertRaises(CutError):
                check_version(v, "0.1.2")


class CutChangelogTest(unittest.TestCase):
    def test_keeps_entries_drops_empty_subsections_adds_fresh_block(self):
        out = cut_changelog(CHANGELOG, "0.1.3", "2026-09-28")
        self.assertIn(
            "Intro.\n\n"
            + FRESH_UNRELEASED
            + "## 0.1.3 - 2026-09-28\n\n### Fixed\n\n- 2026-09-28: A fix.\n  Commit `abc1234`.\n\n"
            + "## 0.1.2 - 2026-09-20\n",
            out,
        )

    def test_released_section_has_no_empty_subsections(self):
        out = cut_changelog(CHANGELOG, "0.1.3", "2026-09-28")
        released = out.split("## 0.1.3 - 2026-09-28\n")[1].split("## 0.1.2")[0]
        self.assertNotIn("### Added", released)
        self.assertNotIn("### Changed", released)

    def test_unreleased_as_last_section(self):
        text = "# Changelog\n\n## Unreleased\n\n### Added\n\n- New.\n"
        out = cut_changelog(text, "0.1.0", "2026-09-28")
        self.assertTrue(out.endswith("## 0.1.0 - 2026-09-28\n\n### Added\n\n- New.\n\n"))

    def test_refuses_a_version_already_cut(self):
        with self.assertRaises(CutError):
            cut_changelog(CHANGELOG, "0.1.2", "2026-09-28")

    def test_refuses_empty_unreleased(self):
        empty = CHANGELOG.replace("- 2026-09-28: A fix.\n  Commit `abc1234`.\n\n", "")
        with self.assertRaises(CutError):
            cut_changelog(empty, "0.1.3", "2026-09-28")

    def test_refuses_a_changelog_without_unreleased(self):
        with self.assertRaises(CutError):
            cut_changelog("# Changelog\n\n## 0.1.2 - 2026-09-20\n", "0.1.3", "2026-09-28")


class RoadmapTest(unittest.TestCase):
    def test_empty_now_has_no_items(self):
        self.assertEqual(now_items(ROADMAP_EMPTY_NOW), [])

    def test_now_items_are_listed(self):
        busy = ROADMAP_EMPTY_NOW.replace(
            "Nothing is in progress.", "### RM-3: Three :id=rm-3\n\nWork."
        )
        self.assertEqual(now_items(busy), ["RM-3: Three :id=rm-3"])

    def test_repoints_only_unreleased_links_to_the_docsify_anchor(self):
        out = repoint_roadmap(ROADMAP_EMPTY_NOW, "0.1.3", "2026-09-28")
        self.assertIn("[0.1.3](changelog.md#_013-2026-09-28)", out)
        self.assertNotIn("#unreleased", out)
        self.assertIn("[0.1.2](changelog.md#_012-2026-09-20)", out)


if __name__ == "__main__":
    unittest.main()
