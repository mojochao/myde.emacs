#!/usr/bin/env python3
"""Tests for check_trace.py: a clean fixture passes, and each rule catches its break.

Run: python3 scripts/test_check_trace.py
"""

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_trace import check  # noqa: E402

CLEAN = {
    "prd.md": """# Product Requirements

## 8. Requirements Inventory

### 8.1 Functional Requirements

| ID   | Requirement | Priority | Source |
|------|-------------|----------|--------|
| FR-1 | It works.   | Must     | x      |

### 8.3 Requirements Details

#### FR-1

It works.

- **Priority:** Must
- **Decided by:** [ADR-00](adr.md#adr-00)
- **Designed in:** [§1](tdd.md#_1-design)
- **Verified by:** [§1](qa.md#_1-checks)
- **Roadmap:** [RM-1](roadmap.md#rm-1)
""",
    "adr.md": """# Architecture Decisions

## ADR-00: Do it :id=adr-00

**Requirements:** [FR-1](prd.md#fr-1)
""",
    "tdd.md": "# Technical Design\n\n## 1. Design\n\nServes [FR-1](prd.md#fr-1).\n",
    "qa.md": "# Quality Assurance\n\n## 1. Checks\n\nVerifies [FR-1](prd.md#fr-1).\n",
    "roadmap.md": """# Roadmap

## Now

## Shipped

### RM-1: Ship it :id=rm-1

- **Requirements:** [FR-1](prd.md#fr-1)
- **Shipped:** 2026-09-27, [Unreleased](changelog.md#unreleased)
""",
    "changelog.md": """# Changelog

## Unreleased

### Added

- 2026-09-27: It works.
  Traces to [RM-1](roadmap.md#rm-1).
""",
}


def run(overrides=None):
    """check() over CLEAN with some docs replaced, returning its findings."""
    with tempfile.TemporaryDirectory() as tmp:
        docs = Path(tmp) / "docs"
        docs.mkdir()
        for name, text in {**CLEAN, **(overrides or {})}.items():
            (docs / name).write_text(text, encoding="utf-8")
        return check(Path(tmp))


def edit(name, old, new):
    """CLEAN[name] with old replaced by new, as an overrides dict."""
    assert old in CLEAN[name], old
    return {name: CLEAN[name].replace(old, new)}


class CheckTraceTest(unittest.TestCase):
    def assert_finds(self, needle, overrides):
        findings = run(overrides)
        self.assertTrue(any(needle in f for f in findings), findings)

    def test_clean_fixture_passes(self):
        self.assertEqual(run(), [])

    def test_none_is_allowed_where_a_field_may_be_empty(self):
        overrides = edit("prd.md", "[ADR-00](adr.md#adr-00)", "none")
        overrides["adr.md"] = "# Architecture Decisions\n"
        self.assertEqual(run(overrides), [])

    def test_rule1_table_row_without_block(self):
        row = "| FR-1 | It works.   | Must     | x      |"
        self.assert_finds(
            "FR-2 is in a requirements table but has no section 8.3 block",
            edit("prd.md", row, row + "\n| FR-2 | More.       | Must     | x      |"),
        )

    def test_rule2_missing_forward_field(self):
        self.assert_finds(
            "FR-1 has no Verified by field",
            edit("prd.md", "- **Verified by:** [§1](qa.md#_1-checks)\n", ""),
        )

    def test_rule3_forward_link_not_backed(self):
        self.assert_finds(
            "'1. Design' is in FR-1 Designed in but does not link FR-1",
            edit("tdd.md", "Serves [FR-1](prd.md#fr-1).", "Serves nothing."),
        )

    def test_rule4_back_link_missing_from_forward_field(self):
        self.assert_finds(
            "FR-1 Decided by does not list ADR-00, which links FR-1",
            edit("prd.md", "[ADR-00](adr.md#adr-00)", "none"),
        )

    def test_rule5_unknown_requirement(self):
        self.assert_finds(
            "ADR-00 links FR-9, which prd.md does not define",
            edit("adr.md", "[FR-1](prd.md#fr-1)", "[FR-1](prd.md#fr-1), [FR-9](prd.md#fr-9)"),
        )

    def test_rule6_adr_without_requirement(self):
        self.assert_finds(
            "ADR-01 links no requirement",
            {"adr.md": CLEAN["adr.md"] + "\n## ADR-01: Other :id=adr-01\n\nNo requirement here.\n"},
        )

    def test_rule7_changelog_entry_without_roadmap_item(self):
        self.assert_finds(
            "entry links no roadmap item",
            edit("changelog.md", "  Traces to [RM-1](roadmap.md#rm-1).\n", ""),
        )

    def test_rule7_shipped_link_to_the_wrong_version(self):
        self.assert_finds(
            "RM-1 Shipped links unreleased, but its changelog entry is under _010-2026-09-27",
            edit("changelog.md", "## Unreleased", "## 0.1.0 - 2026-09-27"),
        )


if __name__ == "__main__":
    unittest.main()
