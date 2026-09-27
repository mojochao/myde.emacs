# Docs Schema, Traceability, Theme, and Publishing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put `docs/` on the SciPlay doc schema with enforced requirement traceability, a vendored docsify 4 site themed Catppuccin Frappé, GitHub Pages publishing, and a root `VERSION` shown in the sidebar.

**Architecture:** Three standard-library Python scripts do the checking and vendoring (`check_links.py` copied from the sciplay-docs skill, `check_trace.py` new, `vendor_docs.py` new), wired into one `mise run docs-check` task that CI also runs before deploying. The ten canonical docs are written from existing sources only, with every requirement linked forward from `prd.md` §8.3 and back from the ADRs, the technical design, QA, the roadmap, and the changelog.

**Tech Stack:** docsify 4.13.1, docsify-themeable 0.9.0, Catppuccin docsify at `628ff26`, Prism 1.30.0 components, Python 3 (stdlib only), markdownlint-cli 0.48.0, mise, GitHub Actions (`actions/*-pages`, `jdx/mise-action`).

**Spec:** `docs/superpowers/specs/2026-09-27-docs-schema-design.md`

---

## Critical context for someone with zero familiarity

Read all of this before Task 0.

1. **hk's pre-commit hook stashes untracked files.**
   On 2026-09-27 an 8.7 MB untracked file made it deadlock in `git stash show -p --include-untracked`, and the file disappeared from the working tree until it was restored from the stash.
   That file is deleted.
   Task 0 checks that nothing large is untracked before the first commit.
   If a commit ever sits in `stash – Running git stash`, stop and ask the owner. Never kill hk or git processes yourself.
2. **Never edit `early-init.el`, `init.el`, or `user-lisp/myde.el`.** They are tangled from `myde.org`, and `.claude/settings.json` denies agent edits to them. This plan changes none of them, and it does not change `myde.org` either.
3. **`~/.config/emacs` is a symlink to this repository.** The running daemon reads it. Docs changes do not affect the daemon, but do not run `mise run tangle` for no reason.
4. **Prose rules, for prose only.** In markdown prose: no em-dashes, no semicolons, one sentence per line, and keep sentences short. Code blocks, inline code, commands, config, and quoted source keep whatever punctuation their syntax needs. Check a file with:

   ```sh
   python3 - docs/prd.md <<'EOF'
   import re, sys
   sys.path.insert(0, "scripts")
   from check_links import mask_code
   for path in sys.argv[1:]:
       for n, line in enumerate(mask_code(open(path, encoding="utf-8").read()).splitlines(), 1):
           if "—" in line or ";" in line:
               print(f"{path}:{n}: {line.strip()}")
   EOF
   ```

   It prints nothing when the file is clean. `scripts/check_links.py` exists from Task 3 on.
   Use plain blockquotes, never `> [!NOTE]` callouts. The flexible-alerts plugin is not vendored, so docsify would print `[!NOTE]` literally.
5. **docsify anchors are not GitHub anchors.** docsify prefixes an underscore to any heading slug that starts with a digit. `### 3.1 Architecture` is `#_31-architecture`. Headings with `:id=adr-00` are anchored by that id.
   Every internal link is relative. A leading `/` resolves against the domain root on Pages, where the site lives under `/myde.emacs/`.
6. **`docs/superpowers/` is point-in-time.** Never edit a plan or spec there except this plan's own checkboxes. The link checker and markdownlint skip it.
7. **Every source outside `myde.org` may be stale.** `tmp/` and the old guides predate the literate config and describe a `modules/` tree that no longer exists. Every key, command, path, and package migrated into a doc must be found in `myde.org` or in the package source under `elpaca/sources/` first. Drop anything you cannot find. Known stale items are listed in spec §3.4.
8. **Search package source under `elpaca/sources/`, never `elpaca/builds/`.** `builds/` is symlinks into `sources/`, and `grep -r` does not follow them.
9. **Do not push, tag, or change repository settings.** The owner does those.
10. **Use `python3`**, as the repo's other tasks do.
11. **Commit messages carry no AI attribution.** No `Co-Authored-By` trailer and no "Generated with" footer.

## File structure

| Path                                   | Status          | Responsibility                                                                 |
|----------------------------------------|-----------------|--------------------------------------------------------------------------------|
| `docs/_sidebar.md`                     | Rewrite         | Canonical ten-entry sidebar                                                    |
| `docs/README.md`                       | Rewrite         | Introduction page                                                              |
| `docs/prd.md` … `docs/glossary.md`     | Create (9)      | The canonical doc set                                                          |
| `docs/index.html`                      | Rewrite         | docsify 4 shell, vendored assets, version plugin                               |
| `docs/vendor/*`                        | Create          | Vendored docsify, theme, and Prism files, written by `vendor_docs.py`          |
| `docs/VERSION`                         | Create symlink  | `../VERSION`, so every serving path sees one value                             |
| `docs/superpowers/plans/*`, `specs/*`  | Move 5          | Old plans and specs, renamed by date                                           |
| `docs/elixir-developer-guide.md`, `docs/org-protocol-setup.md` | Delete after folding | Content moves into `user.md`                         |
| `docs/prog-modules-design.md`, `docs/.nojekyll` | Delete  | Deprecated doc, and a Jekyll marker an Actions deploy does not need            |
| `VERSION`                              | Create          | `0.1.0`                                                                        |
| `scripts/check_links.py`               | Create (copy)   | Link and anchor checker from the sciplay-docs skill                            |
| `scripts/check_trace.py`               | Create          | Traceability checker                                                           |
| `scripts/test_check_trace.py`          | Create          | Fixture tests for the traceability checker                                     |
| `scripts/vendor_docs.py`               | Create          | Pin table, fetcher, and offline remote-reference check                         |
| `.markdownlint.yaml`                   | Create (copy)   | Lint config from the sciplay-docs skill                                        |
| `.markdownlintignore`                  | Create          | Skip `docs/superpowers/`                                                       |
| `.github/workflows/docs.yml`           | Create          | Check, then deploy to GitHub Pages                                             |
| `mise.toml`                            | Modify          | docsify-cli 4.4.4, markdownlint-cli pin, `docs-vendor`, `docs-check`, `tag`    |
| `docs.compose.yaml`                    | Modify          | docsify-cli 4.4.4, mount the repo read-only                                    |
| `README.md`, `.agents/AGENTS.md`       | Modify          | Point at the new pages and tasks                                               |

---

### Task 0: Preconditions

**Files:** none

- [ ] **Step 1: Check for large untracked files**

Run: `git status --short --untracked-files=all | awk '$1 == "??" {print $2}' | xargs -r ls -l`

Expected: no output. If any untracked file is listed, stop and ask the owner what to do with it before the first commit. See *Critical context* item 1.

- [ ] **Step 2: Branch**

```sh
git switch -c docs-schema
```

Expected: `Switched to a new branch 'docs-schema'`.

- [ ] **Step 3: Record the baseline**

```sh
mise run test
mise run forms
mise run check
```

Expected: all three pass. They must still pass at the end, since nothing under `myde.org` changes.

---

### Task 1: Move, delete, and scaffold the doc set

**Files:**
- Move: the five files below
- Delete: `docs/prog-modules-design.md`, `docs/.nojekyll`
- Create: `docs/prd.md`, `docs/adr.md`, `docs/tdd.md`, `docs/qa.md`, `docs/user.md`, `docs/developer.md`, `docs/changelog.md`, `docs/roadmap.md`, `docs/glossary.md`
- Rewrite: `docs/README.md`, `docs/_sidebar.md`

- [ ] **Step 1: Move the plans and specs**

```sh
git mv docs/PLAN_Elixir_Dape_Debugging.md docs/superpowers/plans/2026-06-10-elixir-dape-debugging.md
git mv docs/PLAN_Elixir_EXS_Debugging.md docs/superpowers/plans/2026-06-10-elixir-exs-debugging.md
git mv docs/PLAN_Org_Workflow.md docs/superpowers/plans/2026-08-05-org-workflow.md
git mv docs/org-workflow-design.md docs/superpowers/specs/2026-08-05-org-workflow-design.md
git mv docs/projectile-to-project-migration.md docs/superpowers/specs/2026-05-11-projectile-to-project-design.md
```

- [ ] **Step 2: Delete the deprecated doc and the Jekyll marker**

```sh
git rm -q docs/prog-modules-design.md docs/.nojekyll
```

`docs/elixir-developer-guide.md` and `docs/org-protocol-setup.md` stay until Tasks 12 and 14 fold them into `user.md`.

- [ ] **Step 3: Copy the heading-only templates**

```sh
T=~/.claude/skills/sciplay-docs/assets/templates
for f in prd adr tdd qa user developer changelog roadmap glossary; do cp "$T/$f.md" "docs/$f.md"; done
sed 's/{{PROJECT_TITLE}}/MyDE/' "$T/README.md" > docs/README.md
```

- [ ] **Step 4: Strip the template's example requirements from `docs/prd.md`**

Delete the four example rows (FR-1, FR-2, FR-3, NFR-1 with `{system}`) from the §8.1 and §8.2 tables, keeping each header and separator row.
Delete everything under `### 8.3 Requirements Details` up to `## 9. Stakeholders`, keeping the `### 8.3 Requirements Details` heading itself.
Task 6 writes the real ones.

- [ ] **Step 5: Remove the template's `operations.md` line from `docs/tdd.md`**

Delete these two lines under `## 5. Security, Deployment and Operations`:

```markdown
Design rationale only.
Operational procedures live in `operations.md`.
```

This repo has no `operations.md`.

- [ ] **Step 6: Write the canonical sidebar**

Replace `docs/_sidebar.md` with exactly:

```markdown
- [Introduction](README.md)
- [Product Requirements](prd.md)
- [Architecture Decisions](adr.md)
- [Technical Design](tdd.md)
- [Quality Assurance](qa.md)
- [User Guide](user.md)
- [Developer Guide](developer.md)
- [Changelog](changelog.md)
- [Roadmap](roadmap.md)
- [Glossary](glossary.md)
```

- [ ] **Step 7: Check the tree**

Run: `ls docs docs/superpowers/plans docs/superpowers/specs`

Expected: `docs/` holds `README.md`, `_sidebar.md`, `adr.md`, `changelog.md`, `developer.md`, `elixir-developer-guide.md`, `glossary.md`, `index.html`, `org-protocol-setup.md`, `prd.md`, `qa.md`, `roadmap.md`, `tdd.md`, `user.md`, and `superpowers/`. The plans directory holds five plans plus this one, and the specs directory holds five specs.

- [ ] **Step 8: Commit**

```sh
git add -A docs
git commit -m "docs: restructure docs/ onto the canonical doc set"
```

---

### Task 2: Vendored docsify 4 with Catppuccin Frappé, and VERSION

**Files:**
- Create: `scripts/vendor_docs.py`, `docs/vendor/*` (generated), `VERSION`, `docs/VERSION` (symlink)
- Rewrite: `docs/index.html`
- Modify: `docs.compose.yaml`, `mise.toml`

- [ ] **Step 1: Write `scripts/vendor_docs.py`**

```python
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
# core with markup, css, clike, and javascript. index.html loads these in list
# order, and c must come before cpp.
PRISM_LANGS = [
    "bash", "c", "clojure", "cpp", "elixir", "erlang", "go", "json", "lisp",
    "lua", "python", "ruby", "rust", "scheme", "toml", "typescript", "yaml", "zig",
]

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
```

- [ ] **Step 2: Fetch the pins**

Run: `python3 scripts/vendor_docs.py`

Expected: 23 lines, each `changed` followed by a file name, and no `stale` line.
If it exits with `upstream no longer contains`, stop and report. The Catppuccin theme changed shape and the rewrite needs updating.

- [ ] **Step 3: Write `VERSION` and its symlink**

```sh
printf '0.1.0\n' > VERSION
ln -s ../VERSION docs/VERSION
cat docs/VERSION
```

Expected: `0.1.0`.

- [ ] **Step 4: Rewrite `docs/index.html`**

```html
<!DOCTYPE html>
<!-- Copyright (C) 2020-2026  Allen Gooch -->
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>MyDE</title>
  <meta name="description" content="My Development Environment, a literate Emacs configuration">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <!-- Every asset is vendored under vendor/ by scripts/vendor_docs.py, so the
       site fetches nothing from a third party at runtime.  The Catppuccin
       stylesheet sets colors only, so it loads after the layout theme. -->
  <link rel="stylesheet" href="vendor/theme-simple-dark.css">
  <link rel="stylesheet" href="vendor/catppuccin-frappe-mauve.css">
  <style>
    .app-version { color: var(--subtext0); font-size: 0.6em; margin-left: 0.4em; }
  </style>
</head>
<body>
  <div id="app"></div>
  <script>
    // Show the repo root VERSION (docs/VERSION links to it) after the sidebar
    // name.  Only a bare semver is shown, so an error page served in place of
    // a missing file never reaches the sidebar.
    function mydeVersionPlugin(hook) {
      hook.ready(function () {
        fetch('VERSION')
          .then(function (response) { return response.ok ? response.text() : ''; })
          .then(function (text) {
            var version = text.trim();
            var link = document.querySelector('.app-name-link');
            if (!link || !/^\d+\.\d+\.\d+$/.test(version)) return;
            var span = document.createElement('span');
            span.className = 'app-version';
            span.textContent = 'v' + version;
            link.appendChild(span);
          })
          .catch(function () {});
      });
    }
    window.$docsify = {
      name: 'MyDE',
      repo: 'mojochao/myde.emacs',
      loadSidebar: true,
      subMaxLevel: 2,
      auto2top: true,
      // docsify 4 turns :shortcode: text into images from the GitHub CDN.
      // Turning that off keeps the site same-origin.
      noEmoji: true,
      search: {
        depth: 3,
        placeholder: 'Search',
        noData: 'No matches',
      },
      plugins: [mydeVersionPlugin],
    };
  </script>
  <script src="vendor/docsify.min.js"></script>
  <script src="vendor/search.min.js"></script>
  <script src="vendor/prism-bash.min.js"></script>
  <script src="vendor/prism-c.min.js"></script>
  <script src="vendor/prism-clojure.min.js"></script>
  <script src="vendor/prism-cpp.min.js"></script>
  <script src="vendor/prism-elixir.min.js"></script>
  <script src="vendor/prism-erlang.min.js"></script>
  <script src="vendor/prism-go.min.js"></script>
  <script src="vendor/prism-json.min.js"></script>
  <script src="vendor/prism-lisp.min.js"></script>
  <script src="vendor/prism-lua.min.js"></script>
  <script src="vendor/prism-python.min.js"></script>
  <script src="vendor/prism-ruby.min.js"></script>
  <script src="vendor/prism-rust.min.js"></script>
  <script src="vendor/prism-scheme.min.js"></script>
  <script src="vendor/prism-toml.min.js"></script>
  <script src="vendor/prism-typescript.min.js"></script>
  <script src="vendor/prism-yaml.min.js"></script>
  <script src="vendor/prism-zig.min.js"></script>
</body>
</html>
```

- [ ] **Step 5: Run the offline check**

Run: `python3 scripts/vendor_docs.py --check`

Expected: `0 vendoring issue(s) found`, exit 0.
If it reports a remote reference in `theme-simple-dark.css` or the Catppuccin files, stop and report the line. NFR-7 depends on it.

- [ ] **Step 6: Point the compose file at docsify-cli 4 and the whole repo**

Replace `docs.compose.yaml` with:

```yaml
# Local docs preview: docsify in a container.
# Start:  mise run docs-up    Stop:  mise run docs-down
# `mise run docs' serves the same site natively, without Docker.
name: "myde-docs" # isolate this stack from any other compose stack
services:
  docsify:
    image: node:26-alpine
    # The whole repo is mounted, not just docs/, so the docs/VERSION symlink
    # to ../VERSION resolves inside the container.
    working_dir: /repo/docs
    command: npx -y docsify-cli@4.4.4 serve . -p 3000
    volumes:
      - .:/repo:ro
      - npm-cache:/root/.npm # cache the npx docsify-cli install across restarts
    ports:
      - "3000:3000"
      - "35729:35729" # docsify livereload
volumes:
  npm-cache:
```

- [ ] **Step 7: Pin docsify-cli 4.4.4 and add the `docs-vendor` task in `mise.toml`**

Change `"npm:docsify-cli" = "5.0.0"` to `"npm:docsify-cli" = "4.4.4"`.

After the `[tasks.docs-search]` block, add:

```toml
[tasks.docs-vendor]
description = "Re-fetch the pinned docsify assets into docs/vendor/"
run = "python3 scripts/vendor_docs.py"
```

Then run: `mise install npm:docsify-cli`

Expected: docsify-cli 4.4.4 installs.

- [ ] **Step 8: Serve the site in the container and fetch every asset**

Run `mise run docs-up` in the background, then:

```sh
for f in "" VERSION _sidebar.md README.md $(grep -o 'vendor/[^"]*' docs/index.html) vendor/catppuccin-prism-frappe.css; do
  printf '%s %s\n' "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:3000/$f")" "/$f"
done
curl -s http://localhost:3000/VERSION
```

Expected: every line starts with `200`, and the last command prints `0.1.0`.
If the port does not answer at all, docsify-cli 4.4.4 is binding localhost inside the container. Stop and report rather than guessing a flag.
Then run `mise run docs-down`.

- [ ] **Step 9: Serve natively and repeat the fetch**

Run `mise run docs` in the background and repeat the Step 8 loop.
Expected: the same `200` lines and `0.1.0`. Stop the server afterwards.

- [ ] **Step 10: Ask the owner for a visual check**

Ask the owner to open `http://localhost:3000/` in a browser while `mise run docs-up` runs.
They should see the Frappé base (`#303446`), mauve (`#ca9ee6`) links and active sidebar entry, and `MyDE v0.1.0` at the top of the sidebar.
Record their answer. Continue either way, and list a failed visual check in the final report.

- [ ] **Step 11: Commit**

```sh
git add scripts/vendor_docs.py docs/vendor docs/index.html VERSION docs/VERSION docs.compose.yaml mise.toml
git commit -m "feat: vendor docsify 4 with the Catppuccin Frappe theme and show VERSION"
```

---

### Task 3: Link checker, lint config, and the first `docs-check`

**Files:**
- Create: `scripts/check_links.py`, `.markdownlint.yaml`, `.markdownlintignore`
- Modify: `mise.toml`

- [ ] **Step 1: Copy the checker and lint config verbatim**

```sh
cp ~/.claude/skills/sciplay-docs/assets/tooling/check_links.py scripts/check_links.py
chmod 755 scripts/check_links.py
cp ~/.claude/skills/sciplay-docs/assets/tooling/markdownlint.yaml .markdownlint.yaml
printf 'docs/superpowers/\n' > .markdownlintignore
```

- [ ] **Step 2: Pin markdownlint-cli in `mise.toml`**

Under `[tools]`, after the `"npm:@tobilu/qmd"` line, add:

```toml

# markdownlint-cli lints docs/ for `mise run docs-check'.  Pinned to the
# version the sciplay-docs skill's lint config was written against.
"npm:markdownlint-cli" = "0.48.0"
```

Then run: `mise install npm:markdownlint-cli`

- [ ] **Step 3: Add the `docs-check` task**

After the `[tasks.docs-vendor]` block, add:

```toml
# `run' is a list so the checks run in order and stop at the first failure.
[tasks.docs-check]
description = "Check docs/ links, traceability, vendored assets, and markdown lint"
run = [
  "python3 scripts/check_links.py",
  "python3 scripts/vendor_docs.py --check",
  "markdownlint docs/",
]
```

Task 4 adds the traceability lines.

- [ ] **Step 4: Run it**

Run: `mise run docs-check`

Expected: `check_links.py` reports `0 issue(s)`. If it reports issues, they are in `docs/elixir-developer-guide.md` or `docs/org-protocol-setup.md`, which Tasks 12 and 14 delete. Note them and continue.
markdownlint may report findings in the two old guides for the same reason. It must report none in the files Task 1 created.

- [ ] **Step 5: Commit**

```sh
git add scripts/check_links.py .markdownlint.yaml .markdownlintignore mise.toml
git commit -m "feat: add the docs link checker, lint config, and docs-check task"
```

---

### Task 4: Traceability checker

**Files:**
- Create: `scripts/check_trace.py`, `scripts/test_check_trace.py`
- Modify: `mise.toml`

- [ ] **Step 1: Write the failing test**

`scripts/test_check_trace.py`:

```python
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
```

- [ ] **Step 2: Run it to see it fail**

Run: `python3 scripts/test_check_trace.py`

Expected: FAIL with `ModuleNotFoundError: No module named 'check_trace'`.

- [ ] **Step 3: Write `scripts/check_trace.py`**

```python
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
```

Then `chmod 755 scripts/check_trace.py scripts/test_check_trace.py`.

- [ ] **Step 4: Run the test to see it pass**

Run: `python3 scripts/test_check_trace.py`

Expected: `Ran 10 tests` and `OK`.

- [ ] **Step 5: Run the checker against the scaffold**

Run: `python3 scripts/check_trace.py`

Expected: `0 traceability issue(s) found`. The scaffold has no requirements yet, so there is nothing to trace.

- [ ] **Step 6: Wire it into `docs-check`**

Replace the `[tasks.docs-check]` run list with:

```toml
run = [
  "python3 scripts/check_links.py",
  "python3 scripts/check_trace.py",
  "python3 scripts/test_check_trace.py",
  "python3 scripts/vendor_docs.py --check",
  "markdownlint docs/",
]
```

- [ ] **Step 7: Add the `tag` task**

After `[tasks.docs-check]`, add:

```toml
[tasks.tag]
description = "Tag HEAD v<VERSION> once docs/changelog.md has that release"
run = [
  "grep -qF \"## $(cat VERSION) - \" docs/changelog.md || { echo \"docs/changelog.md has no '## $(cat VERSION) - <date>' heading\"; exit 1; }",
  "git tag -a v$(cat VERSION) -m v$(cat VERSION)",
]
```

Run: `mise run tag`

Expected: it fails with `docs/changelog.md has no '## 0.1.0 - <date>' heading`, and `git tag` lists nothing. That refusal is the behavior QA §3.4 records.

- [ ] **Step 8: Commit**

```sh
git add scripts/check_trace.py scripts/test_check_trace.py mise.toml
git commit -m "feat: add the requirement traceability checker and the tag task"
```

---

### Task 5: Product Requirements (`docs/prd.md`)

**Files:** Modify `docs/prd.md`

Sources: root `README.md` (intro, Organization, Sections, Enabling sections, Running as a daemon), `.agents/AGENTS.md` (Architecture, Platform support), and spec §2 and §4.2.

- [ ] **Step 1: Write §1 to §7**

Keep the template headings exactly. Their anchors are fixed by the Source links in §8: `#_31-architecture`, `#_32-in-scope`, `#_4-target-audience`, `#_51-happy-path`, `#_52-failure-flow`.

| Section                    | Content                                                                                                                                  |
|----------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| 1. Summary                 | What MyDE is: a literate Emacs 31.1+ configuration for Linux and macOS, one `myde.org` tangled to three committed files.               |
| 2. Background & Motivation | It replaced a package.el config with a `modules/` tree and per-module toggles (AGENTS.md *Performance*, commit `803a8cc`, the 2026-09-15 spec). |
| 3.1 Architecture           | The three tangled files, gates, elpaca, XDG paths, and the definitions-only library. This section must name every idea FR-1, FR-2, FR-3, FR-9, NFR-3, NFR-4, NFR-5, and NFR-7 come from. |
| 3.2 In scope               | The section categories from the README *Sections* list, org capture and projects, the keybinding prefixes, MCP, the docs site, Pages, and `VERSION`. |
| 3.3 Out of scope           | Windows (AGENTS.md names Linux and macOS only), Emacs before 31.1 (`user-lisp-directory` does not exist), per-section toggles, and a startup dashboard. |
| 4. Target Audience         | The owner, on Linux and macOS, and coding agents working in the repo (AGENTS.md exists for them). Name the Emacs 31.1 native-compilation floor here. |
| 5.1 Happy path             | Clone, `mise trust`, `mise run init`, first cold start, the launchd daemon, `emacsclient -c` frames.                                    |
| 5.2 Failure flow           | A half-finished elpaca clone, a missing binary that leaves its section off, and a failed bootstrap that still restores GC.              |
| 6. Configuration           | There are no toggles. Presence of a binary is the setting. `custom.el` is gitignored and holds only Customize output.                  |
| 7. Open Questions          | The `C-c d` collision in Elixir buffers (spec §3.4).                                                                                    |

- [ ] **Step 2: Rewrite the §8 priority legend**

Replace the three template bullets under `## 8. Requirements Inventory` with:

```markdown
- **Must** (the config is broken without it)
- **Should** (expected, not blocking)
- **Won't** (explicitly excluded, tracked for visibility)
```

- [ ] **Step 3: Write §8.1, §8.2, and §8.3 exactly as below**

Replace everything from `### 8.1 Functional Requirements` down to, but not including, `## 9. Stakeholders` with:

````markdown
### 8.1 Functional Requirements

| ID    | Requirement                                                                                                          | Priority | Source                    |
|-------|----------------------------------------------------------------------------------------------------------------------|----------|---------------------------|
| FR-1  | A fresh clone starts Emacs without tangling `myde.org`.                                                              | Must     | [§3.1](#_31-architecture) |
| FR-2  | A section that needs a toolchain turns on when its binary is on `PATH` and stays off when it is not, with no toggle. | Must     | [§3.1](#_31-architecture) |
| FR-3  | Binary gates see the login shell's `PATH`, including in macOS GUI and daemon sessions.                               | Must     | [§3.1](#_31-architecture) |
| FR-4  | One daemon serves every frame, and `$EDITOR` reaches it.                                                             | Must     | [§5.1](#_51-happy-path)   |
| FR-5  | Tasks, thoughts, bookmarks, and notes can be captured, including from a browser.                                     | Must     | [§3.2](#_32-in-scope)     |
| FR-6  | Any directory with a `tasks.org` is a project, and its tasks appear in the agenda.                                   | Must     | [§3.2](#_32-in-scope)     |
| FR-7  | Every language uses the same prefixes for LSP, tests, REPL, and debugging.                                           | Should   | [§3.2](#_32-in-scope)     |
| FR-8  | Agents can query and drive the running Emacs over MCP.                                                               | Should   | [§3.2](#_32-in-scope)     |
| FR-9  | Saving `myde.org` keeps the tangled elisp current, and no commit carries drift between them.                         | Must     | [§3.1](#_31-architecture) |
| FR-10 | The docs can be previewed and searched locally.                                                                      | Should   | [§3.2](#_32-in-scope)     |
| FR-11 | A push to `main` that changes the docs publishes them to GitHub Pages, and a failing docs check blocks the publish.  | Should   | [§3.2](#_32-in-scope)     |
| FR-12 | The config carries one version, which names its git tags and shows in the docs sidebar.                              | Should   | [§3.2](#_32-in-scope)     |

### 8.2 Non-Functional Requirements

| ID    | Requirement                                                                                     | Type          | Priority | Source                    |
|-------|-------------------------------------------------------------------------------------------------|---------------|----------|---------------------------|
| NFR-1 | Emacs 31.1 with native compilation is the minimum supported Emacs.                              | Compatibility | Must     | [§4](#_4-target-audience) |
| NFR-2 | The config runs on Linux and macOS.                                                             | Compatibility | Must     | [§4](#_4-target-audience) |
| NFR-3 | A warm start reaches `elpaca-after-init-hook` in about 4 s.                                     | Performance   | Should   | [§3.1](#_31-architecture) |
| NFR-4 | Only packages live inside `user-emacs-directory`. State, data, and cache go to XDG directories. | Operability   | Must     | [§3.1](#_31-architecture) |
| NFR-5 | `user-lisp/myde.el` holds definitions only, so it loads in batch without side effects.          | Testability   | Must     | [§3.1](#_31-architecture) |
| NFR-6 | A failed package bootstrap cannot leave GC disabled or TRAMP broken.                            | Reliability   | Must     | [§5.2](#_52-failure-flow) |
| NFR-7 | The docs site fetches no third-party script or stylesheet at runtime.                           | Security      | Must     | [§3.1](#_31-architecture) |

### 8.3 Requirements Details

One subsection per requirement above, in full.

#### FR-1

A fresh clone starts Emacs without tangling `myde.org`.

- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-00](adr.md#adr-00)
- **Designed in:** [§1.1](tdd.md#_11-the-three-tangled-files)
- **Verified by:** [§2.2](qa.md#_22-integration-tests), [§2.4](qa.md#_24-enforcement-with-git-hooks)
- **Roadmap:** [RM-1](roadmap.md#rm-1)

#### FR-2

A section that needs a toolchain turns on when its binary is on `PATH` and stays off when it is not, with no toggle.

- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-02](adr.md#adr-02)
- **Designed in:** [§1.3](tdd.md#_13-binary-gates)
- **Verified by:** [§2.2](qa.md#_22-integration-tests)
- **Roadmap:** [RM-1](roadmap.md#rm-1), [RM-11](roadmap.md#rm-11)

#### FR-3

Binary gates see the login shell's `PATH`, including in macOS GUI and daemon sessions.

- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-02](adr.md#adr-02)
- **Designed in:** [§4.2](tdd.md#_42-shell-environment-and-platforms)
- **Verified by:** [§2.2](qa.md#_22-integration-tests)
- **Roadmap:** [RM-1](roadmap.md#rm-1)

#### FR-4

One daemon serves every frame, and `$EDITOR` reaches it.

- **Priority:** Must
- **Source:** [§5.1](#_51-happy-path)
- **Decided by:** [ADR-05](adr.md#adr-05)
- **Designed in:** [§1.4](tdd.md#_14-session-model)
- **Verified by:** [§2.1](qa.md#_21-unit-tests), [§3.1](qa.md#_31-daemon-frames-and-mcp)
- **Roadmap:** [RM-5](roadmap.md#rm-5)

#### FR-5

Tasks, thoughts, bookmarks, and notes can be captured, including from a browser.

- **Priority:** Must
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** [ADR-08](adr.md#adr-08)
- **Designed in:** [§2.3](tdd.md#_23-org-files-and-projects), [§4.5](tdd.md#_45-org-protocol-handlers)
- **Verified by:** [§2.1](qa.md#_21-unit-tests), [§3.2](qa.md#_32-browser-capture)
- **Roadmap:** [RM-4](roadmap.md#rm-4)

#### FR-6

Any directory with a `tasks.org` is a project, and its tasks appear in the agenda.

- **Priority:** Must
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** [ADR-08](adr.md#adr-08)
- **Designed in:** [§2.3](tdd.md#_23-org-files-and-projects)
- **Verified by:** [§2.1](qa.md#_21-unit-tests)
- **Roadmap:** [RM-4](roadmap.md#rm-4)

#### FR-7

Every language uses the same prefixes for LSP, tests, REPL, and debugging.

- **Priority:** Should
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** none
- **Designed in:** [§4.3](tdd.md#_43-language-servers-tests-repls-and-debuggers)
- **Verified by:** [§3.5](qa.md#_35-language-keys)
- **Roadmap:** [RM-10](roadmap.md#rm-10)

#### FR-8

Agents can query and drive the running Emacs over MCP.

- **Priority:** Should
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** [ADR-09](adr.md#adr-09)
- **Designed in:** [§3.1](tdd.md#_31-endpoints)
- **Verified by:** [§3.1](qa.md#_31-daemon-frames-and-mcp)
- **Roadmap:** [RM-6](roadmap.md#rm-6)

#### FR-9

Saving `myde.org` keeps the tangled elisp current, and no commit carries drift between them.

- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-00](adr.md#adr-00), [ADR-06](adr.md#adr-06)
- **Designed in:** [§5.1](tdd.md#_51-tangling-and-hooks)
- **Verified by:** [§2.1](qa.md#_21-unit-tests), [§2.4](qa.md#_24-enforcement-with-git-hooks)
- **Roadmap:** [RM-1](roadmap.md#rm-1), [RM-3](roadmap.md#rm-3), [RM-7](roadmap.md#rm-7)

#### FR-10

The docs can be previewed and searched locally.

- **Priority:** Should
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** [ADR-11](adr.md#adr-11)
- **Designed in:** [§5.3](tdd.md#_53-docs-site)
- **Verified by:** [§3.4](qa.md#_34-docs-site)
- **Roadmap:** [RM-8](roadmap.md#rm-8), [RM-9](roadmap.md#rm-9)

#### FR-11

A push to `main` that changes the docs publishes them to GitHub Pages, and a failing docs check blocks the publish.

- **Priority:** Should
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** [ADR-12](adr.md#adr-12)
- **Designed in:** [§5.4](tdd.md#_54-publishing-and-versions)
- **Verified by:** [§2.5](qa.md#_25-docs-checks)
- **Roadmap:** [RM-9](roadmap.md#rm-9)

#### FR-12

The config carries one version, which names its git tags and shows in the docs sidebar.

- **Priority:** Should
- **Source:** [§3.2](#_32-in-scope)
- **Decided by:** [ADR-13](adr.md#adr-13)
- **Designed in:** [§5.4](tdd.md#_54-publishing-and-versions)
- **Verified by:** [§3.4](qa.md#_34-docs-site)
- **Roadmap:** [RM-9](roadmap.md#rm-9)

#### NFR-1

Emacs 31.1 with native compilation is the minimum supported Emacs.

- **Type:** Compatibility
- **Priority:** Must
- **Source:** [§4](#_4-target-audience)
- **Decided by:** none
- **Designed in:** [§1.1](tdd.md#_11-the-three-tangled-files)
- **Verified by:** [§3.3](qa.md#_33-platforms-emacs-version-and-startup-state)
- **Roadmap:** [RM-1](roadmap.md#rm-1)

#### NFR-2

The config runs on Linux and macOS.

- **Type:** Compatibility
- **Priority:** Must
- **Source:** [§4](#_4-target-audience)
- **Decided by:** none
- **Designed in:** [§4.2](tdd.md#_42-shell-environment-and-platforms)
- **Verified by:** [§3.3](qa.md#_33-platforms-emacs-version-and-startup-state)
- **Roadmap:** none

#### NFR-3

A warm start reaches `elpaca-after-init-hook` in about 4 s.

- **Type:** Performance
- **Priority:** Should
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-01](adr.md#adr-01)
- **Designed in:** [§4.1](tdd.md#_41-elpaca)
- **Verified by:** [§2.2](qa.md#_22-integration-tests)
- **Roadmap:** [RM-1](roadmap.md#rm-1), [RM-11](roadmap.md#rm-11)

#### NFR-4

Only packages live inside `user-emacs-directory`. State, data, and cache go to XDG directories.

- **Type:** Operability
- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-04](adr.md#adr-04), [ADR-07](adr.md#adr-07)
- **Designed in:** [§2.1](tdd.md#_21-xdg-paths)
- **Verified by:** [§3.3](qa.md#_33-platforms-emacs-version-and-startup-state)
- **Roadmap:** none

#### NFR-5

`user-lisp/myde.el` holds definitions only, so it loads in batch without side effects.

- **Type:** Testability
- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-03](adr.md#adr-03)
- **Designed in:** [§1.1](tdd.md#_11-the-three-tangled-files)
- **Verified by:** [§2.1](qa.md#_21-unit-tests)
- **Roadmap:** [RM-2](roadmap.md#rm-2)

#### NFR-6

A failed package bootstrap cannot leave GC disabled or TRAMP broken.

- **Type:** Reliability
- **Priority:** Must
- **Source:** [§5.2](#_52-failure-flow)
- **Decided by:** [ADR-10](adr.md#adr-10)
- **Designed in:** [§5.2](tdd.md#_52-startup-failure-containment)
- **Verified by:** [§3.3](qa.md#_33-platforms-emacs-version-and-startup-state)
- **Roadmap:** none

#### NFR-7

The docs site fetches no third-party script or stylesheet at runtime.

- **Type:** Security
- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-11](adr.md#adr-11), [ADR-12](adr.md#adr-12)
- **Designed in:** [§5.3](tdd.md#_53-docs-site)
- **Verified by:** [§2.5](qa.md#_25-docs-checks)
- **Roadmap:** [RM-9](roadmap.md#rm-9)
````

These fields are the inverse of the ADR and roadmap tables in Tasks 6 and 9. Change one side only together with the other.

- [ ] **Step 4: Write §9 and §10**

§9 Stakeholders: a one-row table naming Allen Gooch as owner and sole user.
§10 References: links to the root README, `AGENTS.md` (as `https://github.com/mojochao/myde.emacs/blob/main/AGENTS.md`), and the five specs under `superpowers/specs/`.

- [ ] **Step 5: Check prose and links**

Run the prose check from *Critical context* item 4 on `docs/prd.md`. Expected: no output.
Run: `python3 scripts/check_links.py`. Expected: the only issues are anchors in `adr.md`, `tdd.md`, `qa.md`, and `roadmap.md` that later tasks create, plus any old-guide issues noted in Task 3.

- [ ] **Step 6: Commit**

```sh
git add docs/prd.md
git commit -m "docs: write the product requirements and requirements inventory"
```

---

### Task 6: Architecture Decisions (`docs/adr.md`)

**Files:** Modify `docs/adr.md`

- [ ] **Step 1: Write the index table and intro**

Keep the `<!-- markdownlint-disable MD051 -->` line and the H1. Replace the empty index table with:

```markdown
| ADR               | Title                                                               | Status   |
|-------------------|---------------------------------------------------------------------|----------|
| [ADR-00](#adr-00) | One literate `myde.org` tangled to committed elisp                  | Accepted |
| [ADR-01](#adr-01) | elpaca instead of package.el                                        | Accepted |
| [ADR-02](#adr-02) | Binary gates instead of toggles                                     | Accepted |
| [ADR-03](#adr-03) | Definitions in `user-lisp/myde.el`, activation in `init.el`         | Accepted |
| [ADR-04](#adr-04) | project.el instead of projectile                                    | Accepted |
| [ADR-05](#adr-05) | One daemon with client frames and an on-demand dashboard            | Accepted |
| [ADR-06](#adr-06) | mise tasks and hk hooks that re-tangle rather than reject           | Accepted |
| [ADR-07](#adr-07) | State, data, and cache in XDG directories                           | Accepted |
| [ADR-08](#adr-08) | Project tasks in a `tasks.org` beside the code                      | Accepted |
| [ADR-09](#adr-09) | A fixed MCP socket that never takes over a live one                 | Accepted |
| [ADR-10](#adr-10) | GC and file handlers restored on `emacs-startup-hook`               | Accepted |
| [ADR-11](#adr-11) | Vendored docsify 4 with Catppuccin Frappé                           | Accepted |
| [ADR-12](#adr-12) | GitHub Pages through an Actions deployment gated on the docs checks | Accepted |
| [ADR-13](#adr-13) | One `VERSION` file at the repo root                                 | Accepted |
```

Update the template's closing sentence to name the fields this repo uses: **Status**, **Date**, **Requirements**, **Context**, **Decision**, and **Consequences**.

- [ ] **Step 2: Resolve ADR-10's date**

Run: `git log --format='%ad %h %s' --date=short -S'emacs-startup-hook' -- myde.org early-init.el | tail -3`

Use the date of the commit that put the GC and `file-name-handler-alist` restore on `emacs-startup-hook`. If no commit shows it, use the date of `803a8cc` (2026-09-15), when elpaca arrived and the choice between the two hooks first existed, and say so in the Context.

- [ ] **Step 3: Write each record**

Each record opens with this block, then **Context**, **Decision**, and **Consequences** paragraphs:

```markdown
## ADR-NN: <title from the table> :id=adr-NN

**Status:** Accepted

**Date:** <date>

**Requirements:** <links below>
```

| ADR    | Date       | Requirements line                                    | Sources for Context, Decision, Consequences                                                                                                                          |
|--------|------------|------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ADR-00 | 2026-09-15 | `[FR-1](prd.md#fr-1), [FR-9](prd.md#fr-9)`           | `superpowers/specs/2026-09-15-three-file-literate-config-design.md`, AGENTS.md *Files* ("Tangled outputs are committed, so a fresh clone works without tangling and startup never loads org") |
| ADR-01 | 2026-09-15 | `[NFR-3](prd.md#nfr-3)`                              | AGENTS.md *Package management (elpaca)* and *Performance* (about 4 s against about 7 s for package.el), commit `803a8cc`                                          |
| ADR-02 | 2026-09-15 | `[FR-2](prd.md#fr-2), [FR-3](prd.md#fr-3)`           | AGENTS.md *Section enablement: presence is intent*, including why the gate wraps the whole `use-package` form, and the `exec-path-from-shell` `:wait t` bullet in *Key conventions* |
| ADR-03 | 2026-09-17 | `[NFR-5](prd.md#nfr-5)`                              | `superpowers/specs/2026-09-17-library-config-split-design.md`, AGENTS.md *Commands* paragraph on why the tests load `user-lisp/myde.el` directly                |
| ADR-04 | 2026-05-11 | `[NFR-4](prd.md#nfr-4)`                              | `superpowers/specs/2026-05-11-projectile-to-project-design.md` (one XDG-routed `projects.eld`, one fewer external package), commit `59c95ab`                     |
| ADR-05 | 2026-09-18 | `[FR-4](prd.md#fr-4)`                                | AGENTS.md *Session model*, including why `initial-buffer-choice` is not usable, commit `6dec388`                                                                  |
| ADR-06 | 2026-09-18 | `[FR-9](prd.md#fr-9)`                                | AGENTS.md *Commands* (hk, the three tangle layers, the PreToolUse deny), `hk.pkl` comments, commits `1d8c3e0` and `6f3393e`                                     |
| ADR-07 | 2026-04-27 | `[NFR-4](prd.md#nfr-4)`                              | AGENTS.md *XDG compliance* and its two `early-init.el` exceptions, commit `4a8c68c`                                                                               |
| ADR-08 | 2026-08-10 | `[FR-5](prd.md#fr-5), [FR-6](prd.md#fr-6)`           | `superpowers/specs/2026-08-05-org-workflow-design.md` (the 2026-08-10 revision to a `tasks.org` per project, located by upward search)                          |
| ADR-09 | 2026-09-18 | `[FR-8](prd.md#fr-8)`                                | README *Emacs MCP server* (fixed socket path, `mcp-server-socket-conflict-resolution` set to `error`), commits `69470b4` and `9ee87eb`                         |
| ADR-10 | Step 2     | `[NFR-6](prd.md#nfr-6)`                              | AGENTS.md *Startup hooks*, last paragraph                                                                                                                        |
| ADR-11 | 2026-09-27 | `[FR-10](prd.md#fr-10), [NFR-7](prd.md#nfr-7)`       | Spec §2 and §5. Context: Catppuccin's theme targets docsify 4 on docsify-themeable, and this repo ran docsify 5 from a CDN                                      |
| ADR-12 | 2026-09-27 | `[FR-11](prd.md#fr-11), [NFR-7](prd.md#nfr-7)`       | Spec §6.1. Context: an Actions deploy runs the same `docs-check` as a developer and needs no Jekyll marker                                                     |
| ADR-13 | 2026-09-27 | `[FR-12](prd.md#fr-12)`                              | Spec §6.2, including the symlink and why the sidebar shows the last released version between releases                                                          |

A record links only the requirements on its Requirements line. Linking another requirement anywhere in the record makes the checker demand it in that requirement's Decided by field.

- [ ] **Step 4: Check prose and traceability for this file**

Run the prose check on `docs/adr.md`. Expected: no output.
Run: `python3 scripts/check_trace.py | grep 'adr.md'`. Expected: no line reports `links no requirement` or `does not define`.

- [ ] **Step 5: Commit**

```sh
git add docs/adr.md
git commit -m "docs: record the architecture decisions behind the config and docs"
```

---

### Task 7: Technical Design (`docs/tdd.md`)

**Files:** Modify `docs/tdd.md`

- [ ] **Step 1: Write the sections below, with these exact headings**

Each row's heading anchor is linked from `prd.md`, so the heading text must match exactly. Each section must link every requirement in its "Must link" column, in the form `[FR-1](prd.md#fr-1)`, where the text makes the claim.

| Heading                                                 | Must link              | Content and sources                                                                                                   |
|---------------------------------------------------------|------------------------|-----------------------------------------------------------------------------------------------------------------------|
| `## 1. Architecture Overview`                           |                        | One paragraph and a table of the parts below. Cite [ADR-00](adr.md#adr-00).                                          |
| `### 1.1 The three tangled files`                       | FR-1, NFR-1, NFR-5     | AGENTS.md *Files* table, the 31.1 floor from `user-lisp-directory`, the definitions-only rule and `mise run forms`.  |
| `### 1.2 Startup sequence`                              |                        | AGENTS.md *Startup sequence* steps 1 to 4.                                                                           |
| `### 1.3 Binary gates`                                  | FR-2                   | AGENTS.md *Section enablement*, the gate table, and why the gate wraps the whole form. Cite [ADR-02](adr.md#adr-02). |
| `### 1.4 Session model`                                 | FR-4                   | AGENTS.md *Session model*: one daemon, `emacsclient -c`, Emacsclient.app, dashboard on demand. Cite [ADR-05](adr.md#adr-05). |
| `## 2. Data Model and Persistence`                      |                        | One sentence introducing the subsections.                                                                            |
| `### 2.1 XDG paths`                                     | NFR-4                  | AGENTS.md *XDG compliance* table and its two exceptions. Cite [ADR-07](adr.md#adr-07).                               |
| `### 2.2 Packages`                                      |                        | `./elpaca/` layout (`sources/`, `builds/`, `cache/`), gitignored.                                                    |
| `### 2.3 Org files and projects`                        | FR-5, FR-6             | `~/org/` tree, `inbox.org` as the sink, `tasks.org` located by upward search, `myde-org-code-directory` scan and its pruning. Sources: the 2026-08-05 org spec, README *Org workflow*. Cite [ADR-08](adr.md#adr-08). |
| `### 2.4 Singleton state`                               |                        | The server socket, the MCP socket, and the last-writer-wins XDG state files (AGENTS.md *Session model*).            |
| `## 3. API Contract`                                    |                        | The "API" here is what other programs call: MCP tools, `org-protocol://` URIs, and `emacsclient`.                   |
| `### 3.1 Endpoints`                                     | FR-8                   | The socket path, the `socat` bridge, the MCP tools the README names (`eval-elisp`, diagnostics, Org tools), and the `org-protocol://capture` templates `b` and `N`. Cite [ADR-09](adr.md#adr-09). |
| `### 3.2 Error responses`                               |                        | Socket conflict resolution set to `error`, `CONNECTION_CLOSED`, and the restart command from the README.            |
| `## 4. Integration Layer`                               |                        | One sentence introducing the subsections.                                                                            |
| `### 4.1 elpaca`                                        | NFR-3                  | Queue processing after `after-init-hook`, `:ensure (:wait t)`, one ensuring form per package, the warm and cold start times. Cite [ADR-01](adr.md#adr-01). |
| `### 4.2 Shell environment and platforms`               | FR-3, NFR-2            | `exec-path-from-shell` with `-l`, the platform guards, Homebrew paths, `gls`, and the libgccjit warning (AGENTS.md *Platform support*). |
| `### 4.3 Language servers, tests, REPLs, and debuggers` | FR-7                   | eglot, `myde-eglot-add-workspace-config`, dape, and the `C-c e`, `C-c t`, `C-c i`, `C-c d` prefixes. Record the mix.el `C-c d` collision (`elpaca/sources/mix/mix.el:322`) and link [RM-10](roadmap.md#rm-10). |
| `### 4.4 Tree-sitter`                                   |                        | `treesit-auto` remapping and grammars under `$XDG_DATA_HOME/emacs/tree-sitter/`, from `myde.org`.                  |
| `### 4.5 org-protocol handlers`                         | FR-5                   | The XDG desktop file and the macOS `OrgProtocol.app` (`mise.toml` `install-macos`, and why AppleScript and re-signing are required, from `docs/org-protocol-setup.md`). |
| `## 5. Security, Deployment and Operations`             |                        | One sentence introducing the subsections.                                                                            |
| `### 5.1 Tangling and hooks`                            | FR-9                   | The three tangle layers: tangle on save, the Claude Code hook, and hk pre-commit, plus pre-push as a backstop. Cite [ADR-06](adr.md#adr-06). |
| `### 5.2 Startup failure containment`                   | NFR-6                  | Why GC and file handlers are restored on `emacs-startup-hook` (AGENTS.md *Startup hooks*). Cite [ADR-10](adr.md#adr-10). |
| `### 5.3 Docs site`                                     | FR-10, NFR-7           | docsify 4, the vendored files, the `@import` rewrite, `noEmoji`, and `vendor_docs.py --check`. Cite [ADR-11](adr.md#adr-11). |
| `### 5.4 Publishing and versions`                       | FR-11, FR-12           | The workflow's two jobs, the `docs/VERSION` symlink and `--dereference`, and the release flow. Cite [ADR-12](adr.md#adr-12) and [ADR-13](adr.md#adr-13). |
| `## 6. Testing Strategy`                                |                        | Two or three sentences, then link [Quality Assurance](qa.md).                                                       |
| `## 7. Open Questions`                                  |                        | The `C-c d` collision ([RM-10](roadmap.md#rm-10)) and the probe's stdin ([RM-11](roadmap.md#rm-11)).               |

Requirement links in TDD prose outside the "Must link" column are allowed. The checker does not demand forward entries for them.

- [ ] **Step 2: Check prose and traceability for this file**

Run the prose check on `docs/tdd.md`. Expected: no output.
Run: `python3 scripts/check_trace.py | grep 'tdd.md'`. Expected: no output.

- [ ] **Step 3: Commit**

```sh
git add docs/tdd.md
git commit -m "docs: write the technical design"
```

---

### Task 8: Quality Assurance (`docs/qa.md`)

**Files:** Modify `docs/qa.md`

- [ ] **Step 1: Read the test commentary**

Read the `;;; Commentary:` block of each file under `tests/`. Each names the silent failure its tests cover. §2.1 describes each file from that commentary, not from guesses.

- [ ] **Step 2: Write the sections below, with these exact headings**

| Heading                                                  | Must link                        | Content and sources                                                                                              |
|----------------------------------------------------------|----------------------------------|------------------------------------------------------------------------------------------------------------------|
| `## 1. Summary`                                          |                                  | AGENTS.md: "There is no build or lint step. Two things stand in for one." Name both.                            |
| `### 1.1 Layers of assurance`                            |                                  | A table: layer, what runs, where, what it catches. Rows for ERT, `forms`, `check`, the probe, hk hooks, docs checks, and CI. |
| `## 2. Automatic unit and integration testing`           |                                  | One sentence introducing the subsections.                                                                        |
| `### 2.1 Unit tests`                                     | FR-4, FR-5, FR-6, FR-9, NFR-5    | `mise run test`, one row per `tests/*.el` file from its commentary, and `mise run forms`. The `core-base` tangle-on-save test backs FR-9, the `*Warnings*` advice test backs FR-4, and the `core-org` tests back FR-5 and FR-6. |
| `### 2.2 Integration tests`                              | FR-1, FR-2, FR-3, NFR-3          | `mise run probe <report>`: isolated daemon, `PATH` stripped to `/usr/bin:/bin`, private `XDG_STATE_HOME`, the `declared:` and `mode:` lines, init time. State the limit: `scripts/myde-probe.sh:31` does not close stdin, so `mode:` lines are unreliable ([RM-11](roadmap.md#rm-11)). Confirm that limit against the memory note `probe-cannot-verify-modes.md` before writing it. |
| `### 2.3 How tests are specified`                        |                                  | ERT, loading `user-lisp/myde.el` directly, which works because it is definitions only.                          |
| `### 2.4 Enforcement with git hooks`                     | FR-1, FR-9                       | `hk.pkl`: pre-commit re-tangles, stages the three files, runs `forms` and `test`. pre-push runs `mise run check` as the backstop. |
| `### 2.5 Docs checks`                                    | FR-11, NFR-7                     | `mise run docs-check` and each of its five commands, and the CI `check` job that gates `deploy`.                |
| `## 3. Manual testing`                                   |                                  | One sentence: these requirements have no automated check.                                                       |
| `### 3.1 Daemon, frames, and MCP`                        | FR-4, FR-8                       | `launchctl kickstart -k gui/$(id -u)/gnu.emacs.daemon`, an `emacsclient -c` frame, `$EDITOR` opening a file there, and an MCP `eval-elisp` round trip. |
| `### 3.2 Browser capture`                                | FR-5                             | The end-to-end bookmarklet check from `docs/org-protocol-setup.md` section 3.                                    |
| `### 3.3 Platforms, Emacs version, and startup state`    | NFR-1, NFR-2, NFR-4, NFR-6       | Start on Linux and on macOS. Confirm `emacs-version` is 31.1 or later with native compilation. Confirm `git status` shows no new files after a start. Confirm `gc-cons-threshold` and `file-name-handler-alist` are restored after startup. State that a failed bootstrap is not exercised. |
| `### 3.4 Docs site`                                      | FR-10, FR-12                     | `mise run docs-up` and `mise run docs`, the sidebar showing `v0.1.0`, `mise run docs-search`, and `mise run tag` refusing without a changelog heading. |
| `### 3.5 Language keys`                                  | FR-7                             | In one buffer per gated language, the `C-c e`, `C-c t`, `C-c i`, and `C-c d` keys run their commands. Note that Elixir buffers fail the `C-c d` check today ([RM-10](roadmap.md#rm-10)). |

- [ ] **Step 3: Check prose and traceability for this file**

Run the prose check on `docs/qa.md`. Expected: no output.
Run: `python3 scripts/check_trace.py | grep 'qa.md'`. Expected: no output.

- [ ] **Step 4: Commit**

```sh
git add docs/qa.md
git commit -m "docs: write the quality assurance plan"
```

---

### Task 9: Roadmap and Changelog (`docs/roadmap.md`, `docs/changelog.md`)

**Files:** Modify `docs/roadmap.md`, `docs/changelog.md`

Rule 7 ties these two files together, so they change in one task.

- [ ] **Step 1: Confirm the RM-11 and RM-12 facts**

Run: `sed -n '25,35p' scripts/myde-probe.sh`. Confirm line 31 starts the daemon with no `</dev/null`.
Run: `grep -n 'ob-zig' .agents/AGENTS.md`. Confirm the three options.

- [ ] **Step 2: Write `docs/roadmap.md`**

Under the H1, add `Status as of YYYY-MM-DD.` with the date `date +%F` prints, then replace the four empty sections with:

```markdown
## Now

### RM-9: Docs schema, traceability, theme, Pages, and `VERSION` :id=rm-9

- **Requirements:** [FR-10](prd.md#fr-10), [FR-11](prd.md#fr-11), [FR-12](prd.md#fr-12), [NFR-7](prd.md#nfr-7)
- **Decisions:** [ADR-11](adr.md#adr-11), [ADR-12](adr.md#adr-12), [ADR-13](adr.md#adr-13)

Bring `docs/` onto the SciPlay doc schema with requirement traceability, a vendored Catppuccin Frappé theme, GitHub Pages publishing, and a root `VERSION` file.
It moves to Shipped once the owner enables Pages and the first deploy succeeds.

## Next

### RM-10: Resolve the `C-c d` collision in Elixir buffers :id=rm-10

- **Requirements:** [FR-7](prd.md#fr-7)

`mix.el` binds `C-c d` in `mix-minor-mode` (`elpaca/sources/mix/mix.el:322`).
The global dape keys under `C-c d` therefore do not reach Elixir buffers.

### RM-11: Boot the probe daemon with stdin closed :id=rm-11

- **Requirements:** [FR-2](prd.md#fr-2), [NFR-3](prd.md#nfr-3)

`scripts/myde-probe.sh` starts its throwaway daemon without redirecting stdin.
A startup read of stdin then aborts `elpaca-after-init-hook`, so the probe reports modes as off that are on in a real session.

## Later

### RM-12: Decide on `ob-zig` :id=rm-12

- **Decisions:** [ADR-01](adr.md#adr-01)

`ob-zig` requires `zig-mode` but declares no `Package-Requires`, so elpaca never byte-compiles it and Emacs warns about it on every start.
AGENTS.md lists three options: live with the warning, pin a fork that adds the header, or drop the package.

## Shipped

### RM-8: Docs site with preview and search :id=rm-8

- **Requirements:** [FR-10](prd.md#fr-10)
- **Shipped:** 2026-09-27, [Unreleased](changelog.md#unreleased)

A docsify site for `docs/`, served natively or from a container, with qmd search.

### RM-5: Daemon session :id=rm-5

- **Requirements:** [FR-4](prd.md#fr-4)
- **Decisions:** [ADR-05](adr.md#adr-05)
- **Shipped:** 2026-09-27, [Unreleased](changelog.md#unreleased)

The dashboard opens on demand, and daemon startup warnings stay off the first client frame.

### RM-6: MCP server on a fixed socket :id=rm-6

- **Requirements:** [FR-8](prd.md#fr-8)
- **Decisions:** [ADR-09](adr.md#adr-09)
- **Shipped:** 2026-09-22, [Unreleased](changelog.md#unreleased)

The MCP server listens on a fixed socket that a second Emacs cannot take from a live daemon.

### RM-7: Tangle on save :id=rm-7

- **Requirements:** [FR-9](prd.md#fr-9)
- **Decisions:** [ADR-06](adr.md#adr-06)
- **Shipped:** 2026-09-21, [Unreleased](changelog.md#unreleased)

Saving `myde.org` in Emacs re-tangles it.

### RM-4: Org workflow in `myde.org` :id=rm-4

- **Requirements:** [FR-5](prd.md#fr-5), [FR-6](prd.md#fr-6)
- **Decisions:** [ADR-08](adr.md#adr-08)
- **Shipped:** 2026-09-18, [Unreleased](changelog.md#unreleased)

Capture, `tasks.org` projects, ERT tests, and the macOS `org-protocol://` handler.

### RM-3: mise tasks and hk hooks :id=rm-3

- **Requirements:** [FR-9](prd.md#fr-9)
- **Decisions:** [ADR-06](adr.md#adr-06)
- **Shipped:** 2026-09-18, [Unreleased](changelog.md#unreleased)

mise tasks replace the Makefile, and hk runs the git hooks.

### RM-2: Library and config split :id=rm-2

- **Requirements:** [NFR-5](prd.md#nfr-5)
- **Decisions:** [ADR-03](adr.md#adr-03)
- **Shipped:** 2026-09-18, [Unreleased](changelog.md#unreleased)

`user-lisp/myde.el` holds only definitions.

### RM-1: Three-file literate config :id=rm-1

- **Requirements:** [FR-1](prd.md#fr-1), [FR-2](prd.md#fr-2), [FR-3](prd.md#fr-3), [FR-9](prd.md#fr-9), [NFR-1](prd.md#nfr-1), [NFR-3](prd.md#nfr-3)
- **Decisions:** [ADR-00](adr.md#adr-00), [ADR-01](adr.md#adr-01), [ADR-02](adr.md#adr-02)
- **Shipped:** 2026-09-15, [Unreleased](changelog.md#unreleased)

One literate `myde.org`, elpaca, and binary gates replace the `modules/` tree.
```

Before writing RM-11's second sentence, confirm it against the memory note `probe-cannot-verify-modes.md`. If the note does not support it, keep only the first sentence.

- [ ] **Step 3: Write `docs/changelog.md`**

Replace the file with:

```markdown
# Changelog

No release has been cut yet.
Entries start at 2026-09-15, the three-file literate config.
Earlier history is in `git log`.
Each entry traces to the roadmap item it shipped.

## Unreleased

### Added

- 2026-09-27: A docsify site for `docs/`, served natively or from a container, with qmd search.
  Traces to [RM-8](roadmap.md#rm-8), [FR-10](prd.md#fr-10).
  Commits `161892c`, `9ea6ba4`, `68326e4`, and `b784ddd`.
- 2026-09-21: Saving `myde.org` in Emacs re-tangles it, so the elisp on disk never lags the buffer.
  Traces to [RM-7](roadmap.md#rm-7), [FR-9](prd.md#fr-9), [ADR-06](adr.md#adr-06).
  Commit `6f3393e`.
- 2026-09-18: The org workflow branch is ported into `myde.org`, with `tasks.org` projects, ERT tests for the silent failures, and the macOS `org-protocol://` handler.
  Traces to [RM-4](roadmap.md#rm-4), [FR-5](prd.md#fr-5), [FR-6](prd.md#fr-6), [ADR-08](adr.md#adr-08).
  Commits `a2578f6`, `88aaf9c`, and `8c5a886`.

### Changed

- 2026-09-27: The dashboard opens on demand instead of as the initial buffer, and daemon startup warnings stay off the first client frame.
  Traces to [RM-5](roadmap.md#rm-5), [FR-4](prd.md#fr-4), [ADR-05](adr.md#adr-05).
  Commits `16da103`, `6dec388`, and `1d87ae0`.
- 2026-09-18: mise tasks replace the Makefile, and hk hooks re-tangle on pre-commit and verify on pre-push.
  Traces to [RM-3](roadmap.md#rm-3), [FR-9](prd.md#fr-9), [ADR-06](adr.md#adr-06).
  Commit `1d8c3e0`.
- 2026-09-18: `user-lisp/myde.el` holds only definitions, and every `use-package` form, gate, and assignment moved to `init.el`.
  `mise run forms` asserts the split.
  Traces to [RM-2](roadmap.md#rm-2), [NFR-5](prd.md#nfr-5), [ADR-03](adr.md#adr-03).
  Commits `aefb6ea` to `74fbf2f`.
- 2026-09-15: One literate `myde.org` replaces the `modules/` tree and tangles to `early-init.el`, `init.el`, and `user-lisp/myde.el`.
  elpaca replaces package.el, and toolchain sections are gated on their binary instead of a toggle.
  Traces to [RM-1](roadmap.md#rm-1), [FR-1](prd.md#fr-1), [FR-2](prd.md#fr-2), [FR-3](prd.md#fr-3), [FR-9](prd.md#fr-9), [NFR-1](prd.md#nfr-1), [NFR-3](prd.md#nfr-3), [ADR-00](adr.md#adr-00), [ADR-01](adr.md#adr-01), [ADR-02](adr.md#adr-02).
  Commits `9ad474e` to `f33658c`.

### Fixed

- 2026-09-22: The MCP server keeps a fixed socket path, and a second Emacs on this config no longer takes the socket from a live daemon.
  Traces to [RM-6](roadmap.md#rm-6), [FR-8](prd.md#fr-8), [ADR-09](adr.md#adr-09).
  Commits `69470b4` and `9ee87eb`.
```

- [ ] **Step 4: Run the full traceability check**

Run: `python3 scripts/check_trace.py`

Expected: `0 traceability issue(s) found`.
Fix every finding in the file it names. A finding in `prd.md` about a forward field means the map in Task 5 and the ADR or roadmap tables disagree. Change both sides together.

- [ ] **Step 5: Check prose**

Run the prose check on `docs/roadmap.md docs/changelog.md`. Expected: no output.

- [ ] **Step 6: Commit**

```sh
git add docs/roadmap.md docs/changelog.md
git commit -m "docs: write the roadmap and changelog with traceability links"
```

---

### Task 10: User Guide §1 to §3 (`docs/user.md`)

**Files:** Modify `docs/user.md`, delete `docs/org-protocol-setup.md`

- [ ] **Step 1: Write §1 to §3 with these headings**

```markdown
## 1. Summary
## 2. Onboarding
### 2.1 Prerequisites
### 2.2 Install
### 2.3 Run as a daemon
### 2.4 Turn on a language
### 2.5 Language servers and debuggers
### 2.6 Browser capture
### 2.7 Emacs MCP server
## 3. Key concepts
### 3.1 Sections
### 3.2 Keybinding prefixes
### 3.3 Projects
### 3.4 Where files live
```

| Section | Sources                                                                                                                                                  |
|---------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1       | Root README intro                                                                                                                                        |
| 2.1     | Emacs 31.1 with native compilation, mise, git 2.54 or later (for hk's config-based hooks), `socat` for MCP, GNU `ls` (`gls`) on macOS. AGENTS.md and README. |
| 2.2     | README *Installation*: clone, `mise trust`, `mise run init`, the cold first start.                                                                       |
| 2.3     | README *Running as a daemon*, AGENTS.md *Session model*: the launchd agent, Emacsclient.app, `$EDITOR`, the restart command, and the warning against launching Emacs.app. |
| 2.4     | README gate table, copied as a table                                                                                                                     |
| 2.5     | README *LSP servers*, *Debuggers*, *LemMinX*, and *XML tree-sitter grammar*                                                                              |
| 2.6     | All of `docs/org-protocol-setup.md`, rewritten to the prose rules. Keep the Linux and macOS handler steps, the two macOS details, the bookmarklet, and the end-to-end check. Turn its `> **Note:**` blocks into plain blockquotes. |
| 2.7     | README *Emacs MCP server*                                                                                                                                |
| 3.1     | README *Sections* and *Enabling sections*                                                                                                                |
| 3.2     | README *Keybinding conventions*. Verify each prefix in `myde.org`. Record that `C-c g b` is `blamer-mode` and that no `C-c g` binding opens magit.      |
| 3.3     | `tmp/org-capture-env.md` *Projects*, README *Org workflow*                                                                                              |
| 3.4     | README *XDG paths*, `tmp/org-capture-env.md` *Where things are stored*. Drop its claim that `tasks.org` is in a global gitignore unless `git config --global core.excludesFile` shows a file that lists it. |

- [ ] **Step 2: Delete the folded guide**

```sh
git rm -q docs/org-protocol-setup.md
```

- [ ] **Step 3: Verify the keys you wrote**

```sh
grep -o -E '`C-[^`]+`' docs/user.md | tr -d '`' | sort -u | while read -r k; do
  grep -q -F "\"$k\"" myde.org || echo "not bound in myde.org: $k"
done
```

For each key it prints, find the binding under `elpaca/sources/`, or remove the key from the doc.

- [ ] **Step 4: Check prose and links**

Run the prose check on `docs/user.md`. Expected: no output.
Run: `python3 scripts/check_links.py`. Expected: no issue in `docs/user.md`.

- [ ] **Step 5: Commit**

```sh
git add -A docs
git commit -m "docs: write the user guide onboarding and key concepts"
```

---

### Task 11: User Guide §4.1 Org and notes

**Files:** Modify `docs/user.md`

- [ ] **Step 1: Write §4.1 with these headings**

```markdown
## 4. Usage and workflows
### 4.1 Org and notes
#### 4.1.1 Capturing
#### 4.1.2 The agenda and task states
#### 4.1.3 Finding things by tag
#### 4.1.4 Notes with denote
#### 4.1.5 Refiling and archiving
#### 4.1.6 Org Babel
```

Sources: `tmp/org-capture-env.md` for 4.1.1 to 4.1.5, and the `core-org` (`myde.org` line 949) and `core-notes` (line 1728) sections.
For 4.1.6, list the languages registered with `org-babel-do-load-languages` or `ob-*` packages in `myde.org` (`grep -n 'ob-\|org-babel-do-load-languages' myde.org`), not the ones `tmp/org-babel-plan.md` proposed.
Drop the `modules/` paths and the Emacs 30.2 version line.
Every capture template letter must appear in `org-capture-templates` in `myde.org`.

- [ ] **Step 2: Verify keys**

Run the Task 10 Step 3 loop. Resolve every printed key.

- [ ] **Step 3: Check prose and commit**

Run the prose check on `docs/user.md`. Expected: no output.

```sh
git add docs/user.md
git commit -m "docs: write the user guide org and notes workflows"
```

---

### Task 12: User Guide §4.2 Programming

**Files:** Modify `docs/user.md`, delete `docs/elixir-developer-guide.md`

- [ ] **Step 1: Write §4.2 with these headings, in this order**

| Heading                      | `myde.org` section (line)     | Extra source                          |
|------------------------------|-------------------------------|---------------------------------------|
| `### 4.2 Programming`        |                               |                                       |
| `#### 4.2.1 Common workflow` | `prog-base` (2884), `core-projects` (1861), `core-snippets` (1825) | README, Elixir guide *Keybindings Reference* |
| `#### 4.2.2 Bash`            | `prog-bash` (2951)            |                                       |
| `#### 4.2.3 Fish`            | `prog-fish` (3146)            |                                       |
| `#### 4.2.4 Nushell`         | `prog-nushell` (3179)         |                                       |
| `#### 4.2.5 Emacs Lisp`      | `prog-elisp` (3350)           |                                       |
| `#### 4.2.6 Common Lisp`     | `prog-clisp` (3426)           |                                       |
| `#### 4.2.7 Scheme`          | `prog-scheme` (3685)          |                                       |
| `#### 4.2.8 Clojure`         | `prog-clojure` (3907)         |                                       |
| `#### 4.2.9 Erlang`          | `prog-erlang` (4076)          | `tmp/erlang-ide-plan.md`              |
| `#### 4.2.10 Elixir`         | `prog-elixir` (4157)          | `docs/elixir-developer-guide.md`      |
| `#### 4.2.11 C and C++`      | `prog-cpp` (4464)             | `tmp/cpp-ide-plan.md`                 |
| `#### 4.2.12 Go`             | `prog-go` (4618)              | `tmp/go-ide-plan.md`                  |
| `#### 4.2.13 Rust`           | `prog-rust` (4764)            | `tmp/rust-ide-plan.md`                |
| `#### 4.2.14 Zig`            | `prog-zig` (4887)             |                                       |
| `#### 4.2.15 Python`         | `prog-python` (5033)          | `tmp/python-ide-plan.md`              |
| `#### 4.2.16 Ruby`           | `prog-ruby` (5170)            | `tmp/prog-ruby-plan.md`               |
| `#### 4.2.17 Lua`            | `prog-lua` (5337)             | `tmp/lua-ide-plan.md`                 |
| `#### 4.2.18 JavaScript`     | `prog-javascript` (5463)      |                                       |
| `#### 4.2.19 TypeScript`     | `prog-typescript` (5674)      |                                       |

Line numbers are from commit `d9943e4`. Search for `*** prog-<name>` if they have moved.

Each language subsection covers, where the section has them: the gate binary, modes and file extensions, the LSP server, test, REPL, and debug keys, dape configurations, snippets under `snippets/<language>/`, and Org Babel support.
Leave out any of those the section does not have.

For Elixir, state that `mix-minor-mode` binds `C-c d` (`elpaca/sources/mix/mix.el:322`), so the global dape keys do not reach Elixir buffers, and link [RM-10](roadmap.md#rm-10).
Keep the `.exs` debugging limitation and its example from the Elixir guide.

- [ ] **Step 2: Delete the folded guide**

```sh
git rm -q docs/elixir-developer-guide.md
```

- [ ] **Step 3: Verify keys**

Run the Task 10 Step 3 loop. Resolve every printed key. Keys defined by a package's own keymap, such as mix.el's, are found under `elpaca/sources/<package>/`.

- [ ] **Step 4: Check prose and links, then commit**

Run the prose check on `docs/user.md`. Expected: no output.
Run: `python3 scripts/check_links.py`. Expected: `0 issue(s)`, now that both old guides are gone.

```sh
git add -A docs
git commit -m "docs: write the user guide programming languages"
```

---

### Task 13: User Guide §4.3 to §7

**Files:** Modify `docs/user.md`

- [ ] **Step 1: Write these sections**

```markdown
### 4.3 Git
### 4.4 Writing
## 5. Error handling
### 5.1 A package will not install
### 5.2 "Cannot open load file" after an update
### 5.3 $EDITOR opens files nowhere
### 5.4 MCP bridge CONNECTION_CLOSED
### 5.5 "error invoking gcc driver"
### 5.6 Org problems
## 6. FAQ
## 7. References
```

| Section | Sources                                                                                                                                          |
|---------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| 4.3     | `myde.org` lines around 2094 to 2130 (magit, forge, git-modes, diff-hl, blamer) and 2314 to 2330 (gptel-forge-prs, gptel-magit). Magit is `:commands (magit-status)` with no global key. The only `C-c g` binding is `C-c g b`. |
| 4.4     | `core-spell` (`myde.org` line 2131, jinx) and `text-markdown` (line 6002). Use `tmp/core-spell-plan.md` and `tmp/text-markdown-design.md` for behavior only after confirming it in `myde.org`. |
| 5.1     | AGENTS.md *A package that will not install may be a half-finished clone*: the recursive scan, the checkout, `elpaca-rebuild`, `elpaca-process-queues`. |
| 5.2     | The memory note `elpaca-merge-reuses-stale-file-list.md`: a merge reuses the cached file list, and `elpaca-rebuild` fixes it.                  |
| 5.3     | README *Running as a daemon*: a second Emacs next to the daemon.                                                                                 |
| 5.4     | README *Emacs MCP server*: the restart command and `/mcp`.                                                                                       |
| 5.5     | AGENTS.md *Platform support*, last bullet                                                                                                        |
| 5.6     | `tmp/org-capture-env.md` *Troubleshooting*, each item confirmed in `myde.org`                                                                   |
| 6       | Why the dashboard does not open at startup, how to turn a section off (uninstall its binary), and what `custom.el` holds.                       |
| 7       | Upstream manuals (Org, denote, elpaca, eglot, dape, magit), the root README, and the [Developer Guide](developer.md).                           |

- [ ] **Step 2: Verify keys, check prose, commit**

Run the Task 10 Step 3 loop and the prose check. Resolve every result.

```sh
git add docs/user.md
git commit -m "docs: write the user guide git, writing, errors, and FAQ"
```

---

### Task 14: Developer Guide (`docs/developer.md`)

**Files:** Modify `docs/developer.md`

- [ ] **Step 1: Write the guide with these headings**

```markdown
## 1. Prerequisites
## 2. Onboarding
### 2.1 Clone the repo
### 2.2 Repo structure
### 2.3 Initialize project
#### 2.3.1 Configure environment
#### 2.3.2 Install dependencies
## 3. Build and run project
### 3.1 Editing myde.org
### 3.2 Tangling
### 3.3 Restarting the daemon
### 3.4 Previewing the docs
## 4. Test and lint project
## 5. Infrastructure
### 5.1 The launchd agent and Emacsclient.app
### 5.2 URI handler bundles
## 6. Deployment
### 6.1 Linking the config
### 6.2 Publishing the docs
### 6.3 Releasing a version
## 7. Observability
## 8. Where to look next
```

Replace the template's §5 subsections (ADO Pipelines, ECR Images, AWS Resources, Entra auth). None apply here.

| Section | Sources                                                                                                                                               |
|---------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1       | Emacs 31.1 with native compilation, mise, git 2.54 or later, Docker (optional, for `docs-up`), Python 3                                              |
| 2.1     | README *Installation*                                                                                                                                 |
| 2.2     | A table of top-level paths: `myde.org`, the three tangled files, `tests/`, `scripts/`, `snippets/`, `etc/`, `docs/`, `elpaca/`, `.agents/`, `hk.pkl`, `mise.toml`, `VERSION` |
| 2.3.1   | `mise trust`, and why trust is per machine                                                                                                            |
| 2.3.2   | `mise run init`, `mise install`, the qmd index init                                                                                                   |
| 3.1     | AGENTS.md *Editing workflow*, *use-package constraints*, *Startup hooks* (the elpaca-after-init rule), gates, one ensuring form, `:ensure nil`, no lambdas as hooks, `:ensure` last |
| 3.2     | `mise run tangle`, tangle on save, the Claude Code hook and its deny on the three tangled files                                                      |
| 3.3     | `launchctl kickstart -k gui/$(id -u)/gnu.emacs.daemon`, verifying with `emacsclient`                                                                  |
| 3.4     | `mise run docs`, `mise run docs-up`, `mise run docs-search`, `mise run docs-vendor`                                                                   |
| 4       | `mise run test`, `forms`, `check`, `probe` and diffing its `declared:` and `mode:` lines, `docs-check`, and link [Quality Assurance](qa.md)          |
| 5.1     | AGENTS.md *Session model*: `~/Library/LaunchAgents/gnu.emacs.daemon.plist`, `RunAtLoad`, `KeepAlive`, `~/Applications/Emacsclient.app`, the Dock entry |
| 5.2     | `mise run install-xdg` and `install-macos` and their uninstall tasks                                                                                  |
| 6.1     | `mise run link` and `unlink`                                                                                                                          |
| 6.2     | The workflow, its trigger paths, the one-time Pages setting, and `https://mojochao.github.io/myde.emacs/`                                             |
| 6.3     | The six-step release flow from spec §6.2                                                                                                              |
| 7       | The probe report, `M-x elpaca-log`, `*Warnings*`, `emacs-init-time`, and MCP `eval-elisp`                                                              |
| 8       | Links to [Technical Design](tdd.md), [Architecture Decisions](adr.md), and AGENTS.md on GitHub                                                        |

- [ ] **Step 2: Check prose and links, then commit**

Run the prose check on `docs/developer.md` and `python3 scripts/check_links.py`. Resolve every result.

```sh
git add docs/developer.md
git commit -m "docs: write the developer guide"
```

---

### Task 15: Glossary and Introduction (`docs/glossary.md`, `docs/README.md`)

**Files:** Modify `docs/glossary.md`, `docs/README.md`

- [ ] **Step 1: Write the glossary**

Keep the H1 and the intro line. Replace the `## {Term}` placeholder with one `##` section per term, alphabetical, each one to three sentences from its source:

| Term                  | Source                                  |
|-----------------------|-----------------------------------------|
| Activation block      | AGENTS.md *Editing workflow*            |
| Binary gate           | AGENTS.md *Section enablement*          |
| Client frame          | AGENTS.md *Session model*               |
| Daemon                | AGENTS.md *Session model*               |
| Definition block      | AGENTS.md *Editing workflow*            |
| elpaca order          | AGENTS.md *Package management*          |
| Half-finished clone   | AGENTS.md *Package management*          |
| hk                    | AGENTS.md *Commands*                    |
| MCP server            | README *Emacs MCP server*               |
| mise                  | AGENTS.md *Commands*                    |
| org-protocol          | `docs/user.md` §2.6                     |
| Presence is intent    | AGENTS.md *Section enablement*          |
| Probe                 | AGENTS.md *Commands*                    |
| Project               | README *Org workflow*                   |
| Section               | README *Sections*                       |
| Tangle                | AGENTS.md *Files*                       |
| Traceability          | `docs/prd.md` §8                        |
| user-lisp             | AGENTS.md *Key conventions*             |
| XDG directories       | AGENTS.md *XDG compliance*              |

- [ ] **Step 2: Write the Introduction**

Keep `# MyDE` and the template headings.

| Section              | Content                                                                                                                                              |
|----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| `### Overview`       | What MyDE is, in three or four sentences, and the published site URL `https://mojochao.github.io/myde.emacs/`.                                      |
| `### Intended audience` | A table: reader and where to start. The owner using the config starts with the [User Guide](user.md). Someone changing the config starts with the [Developer Guide](developer.md) and [Technical Design](tdd.md). A reviewer of a decision starts with [Product Requirements](prd.md) and [Architecture Decisions](adr.md). |
| `### What next`      | A numbered reading order over all ten pages.                                                                                                        |
| `### External resources` | The GitHub repo, AGENTS.md on GitHub, and every spec and plan under `superpowers/`, each as a relative link, listed by date.                     |

- [ ] **Step 3: Check prose and links, then commit**

Run the prose check on both files and `python3 scripts/check_links.py`. Resolve every result.

```sh
git add docs/glossary.md docs/README.md
git commit -m "docs: write the glossary and introduction"
```

---

### Task 16: Reconcile the Prism grammars with the fences

**Files:** Modify `scripts/vendor_docs.py`, `docs/index.html`, `docs/vendor/*`

- [ ] **Step 1: List the fence languages the docs use**

```sh
grep -h -o -E '^ {0,3}```[A-Za-z0-9_+-]+' docs/*.md | sed -E 's/^ *```//' | sort -u
```

- [ ] **Step 2: Map each to a Prism component**

| Fence names                    | Component                |
|--------------------------------|--------------------------|
| `elisp`, `emacs-lisp`, `lisp`  | `lisp`                   |
| `sh`, `shell`, `bash`          | `bash`                   |
| `js`, `javascript`             | none, bundled            |
| `ts`, `typescript`             | `typescript`             |
| `c++`, `cpp`                   | `cpp` (after `c`)        |
| `yml`, `yaml`                  | `yaml`                   |
| `py`, `python`                 | `python`                 |
| `rb`, `ruby`                   | `ruby`                   |
| any other name                 | `prism-<name>` if `curl -s -o /dev/null -w '%{http_code}' https://cdn.jsdelivr.net/npm/prismjs@1.30.0/components/prism-<name>.min.js` returns 200, otherwise none |

Fences with no component (`org`, `text`, `fish`, `nu`) render as plain text.

- [ ] **Step 3: Update `PRISM_LANGS` and `index.html` together**

Set `PRISM_LANGS` in `scripts/vendor_docs.py` to the mapped components, alphabetical, with `c` before `cpp`.
Make the `prism-*.min.js` script tags in `docs/index.html` match the list, in the same order.

- [ ] **Step 4: Re-vendor and check**

```sh
python3 scripts/vendor_docs.py
```

Delete any file it reports as `stale`.

Run: `python3 scripts/vendor_docs.py --check`. Expected: `0 vendoring issue(s) found`.

- [ ] **Step 5: Commit**

```sh
git add -A scripts/vendor_docs.py docs/index.html docs/vendor
git commit -m "chore: match the vendored Prism grammars to the docs' code fences"
```

Skip the commit if nothing changed.

---

### Task 17: GitHub Pages workflow

**Files:** Create `.github/workflows/docs.yml`

- [ ] **Step 1: Write the workflow**

```yaml
# Check docs/ and publish it to GitHub Pages.  The deploy job runs only after
# the same `mise run docs-check' a developer runs has passed.
name: docs

on:
  push:
    branches: [main]
    paths:
      - "docs/**"
      - "VERSION"
      - "scripts/**"
      - ".markdownlint*"
      - "mise.toml"
      - ".github/workflows/docs.yml"
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  check:
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    env:
      # Trust this checkout's mise.toml without a prompt, and install only the
      # one tool the checks need rather than every pinned tool.
      MISE_TRUSTED_CONFIG_PATHS: ${{ github.workspace }}
      MISE_TASK_RUN_AUTO_INSTALL: "false"
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: jdx/mise-action@c2a87611a18de5b3828c5652fe268e992400cb5c # v4.3.0
        with:
          version: 2026.9.15
          install_args: "npm:markdownlint-cli"
      - run: mise run docs-check

  deploy:
    needs: check
    runs-on: ubuntu-24.04
    timeout-minutes: 10
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/configure-pages@45bfe0192ca1faeb007ade9deae92b16b8254a0d # v6.0.0
      # The action tars with --dereference, so docs/VERSION ships as a file.
      - uses: actions/upload-pages-artifact@fc324d3547104276b827a68afc52ff2a11cc49c9 # v5.0.0
        with:
          path: docs
      - id: deployment
        uses: actions/deploy-pages@368f82528645a54fb793d4d04e342629a3f51346 # v5.0.1
```

- [ ] **Step 2: Lint it**

Run: `mise exec actionlint@1.7.7 -- actionlint -shellcheck= -pyflakes= .github/workflows/docs.yml`

Expected: no output, exit 0.

- [ ] **Step 3: Confirm the CI check passes without the local-only tools**

```sh
MISE_TASK_RUN_AUTO_INSTALL=false mise run docs-check
```

Expected: the same pass as a normal run. The CI job relies on `docs-check` needing only `python3` and markdownlint.

- [ ] **Step 4: Commit**

```sh
git add .github/workflows/docs.yml
git commit -m "ci: publish docs to GitHub Pages after the docs checks pass"
```

---

### Task 18: Root README and AGENTS.md

**Files:** Modify `README.md`, `.agents/AGENTS.md`

- [ ] **Step 1: Update the root README tasks table**

Add three rows after the `mise run docs-search <q>` row:

```markdown
| `mise run docs-check`      | Check `docs/` links, traceability, vendored assets, and markdown lint     |
| `mise run docs-vendor`     | Re-fetch the pinned docsify assets into `docs/vendor/`                    |
| `mise run tag`             | Tag HEAD `v<VERSION>` once `docs/changelog.md` has that release           |
```

Pad the columns to match the table's existing rows.

- [ ] **Step 2: Repoint the README's links to old docs**

- Replace `For detailed test and REPL keybinding granularity across languages, see `docs/prog-modules-design.md`.` with `Per-language keys are in the User Guide, `docs/user.md` §4.2.`
- In *Org workflow*, replace ``See `docs/org-protocol-setup.md` for both, and `docs/org-workflow-design.md` for the design.`` with ``See `docs/user.md` §2.6 for both, and `docs/tdd.md` §2.3 for the design.``
- Replace the whole *Documentation* table with one sentence and a link: the docs site is published at `https://mojochao.github.io/myde.emacs/` and its source is `docs/`, starting at `docs/README.md`.

- [ ] **Step 3: Update the AGENTS.md command block**

In `.agents/AGENTS.md`, after the `mise run docs-search <q>` line, add:

```shell
mise run docs-check       # Check docs/ links, traceability, vendored assets, and markdown lint
mise run docs-vendor      # Re-fetch the pinned docsify assets into docs/vendor/
mise run tag              # Tag HEAD v<VERSION> once docs/changelog.md has that release
```

- [ ] **Step 4: Check and commit**

Run: `python3 scripts/check_links.py`. Expected: `0 issue(s)`.

```sh
git add README.md .agents/AGENTS.md
git commit -m "docs: point the README and AGENTS.md at the new docs site and tasks"
```

---

### Task 19: Final verification and report

**Files:** none

- [ ] **Step 1: Run every check**

```sh
mise run docs-check
mise run test
mise run forms
mise run check
```

Expected: all pass. Within `docs-check`, `check_links.py` prints `0 issue(s) found across N files`, `check_trace.py` prints `0 traceability issue(s) found`, the test prints `Ran 10 tests` and `OK`, `vendor_docs.py --check` prints `0 vendoring issue(s) found`, and markdownlint prints nothing.

- [ ] **Step 2: Prose check over the whole doc set**

Run the prose check from *Critical context* item 4 with every `docs/*.md` file as arguments. Expected: no output.

- [ ] **Step 3: Serve once more**

Repeat Task 2 Step 8 against `mise run docs-up`. Expected: every asset returns 200 and `VERSION` returns `0.1.0`.

- [ ] **Step 4: Report to the owner**

Report, without pushing or tagging:
- The commit list on `docs-schema` (`git log --oneline main..docs-schema`).
- Requirements whose only verification is manual: FR-7, FR-8, FR-10, FR-12, NFR-1, NFR-2, NFR-4, and NFR-6.
- The visual check result from Task 2 Step 10.
- Anything dropped from a source because it could not be found in `myde.org`.
- The owner's next steps: merge `docs-schema`, set the Pages source to GitHub Actions in the repository settings, push, and move RM-9 to Shipped with a changelog entry once the first deploy succeeds.
