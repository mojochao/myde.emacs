# Docs schema, traceability, theme, and publishing design

**Date:** 2026-09-27
**Author:** Allen Gooch
**Status:** Approved in brainstorming, awaiting spec review

## 1. Goal

Bring `docs/` onto the SciPlay doc schema used by `~/devel/projects/multi-tenancy`, without the `sciplay-docs-theme/` shell.
The site gets a vendored docsify v4 stack themed with Catppuccin Frappé, full requirement traceability enforced by a checker, publishing to GitHub Pages, and a version shown in the sidebar.

## 2. Decisions

| Topic               | Decision                                                                                                 |
|---------------------|----------------------------------------------------------------------------------------------------------|
| Doc set             | The ten canonical files. No `operations.md`, because nothing here deploys to a cluster.                 |
| Content             | Fill every file from existing sources only. A section with no source stays a bare heading.              |
| Sources             | Root `README.md`, `AGENTS.md`, `myde.org`, git history, the old `docs/` files, and `tmp/`.              |
| Docsify             | v4 (4.13.1), vendored under `docs/vendor/`, replacing the v5 CDN build.                                 |
| Theme               | `docsify-themeable` simple-dark for layout, Catppuccin Frappé with the mauve accent for color.          |
| Footer              | None. The skill's `_footer.md` carries the Light & Wonder copyright, which does not apply to this repo. |
| Validators          | `check_links.py` and markdownlint, run by hand and in CI. No hk steps.                                  |
| Traceability        | Links in both directions, enforced by `scripts/check_trace.py`.                                         |
| Vendoring           | A pin script, `scripts/vendor_docs.py`.                                                                  |
| Publishing          | GitHub Pages through a GitHub Actions deployment, gated on the docs checks.                             |
| Version             | A root `VERSION` file names the git tag and shows in the docs sidebar.                                  |
| Changelog start     | 2026-09-15, the three-file literate config. Earlier history stays in git.                               |

## 3. Doc set

### 3.1 Canonical files and sidebar

`docs/_sidebar.md` holds exactly the canonical order:

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

Specs and plans leave the sidebar.
`README.md` links them under External resources, the way multi-tenancy does.
Every internal link is relative.
A leading `/` would resolve against the domain root on Pages, where the site lives under `/myde.emacs/`.

### 3.2 Moves, folds, and deletions

Moves use `git mv` with content unchanged, because plans and specs are point-in-time records.
Each date is the file's first commit.

| From `docs/`                         | To                                                              |
|--------------------------------------|-----------------------------------------------------------------|
| `PLAN_Elixir_Dape_Debugging.md`      | `superpowers/plans/2026-06-10-elixir-dape-debugging.md`         |
| `PLAN_Elixir_EXS_Debugging.md`       | `superpowers/plans/2026-06-10-elixir-exs-debugging.md`          |
| `PLAN_Org_Workflow.md`               | `superpowers/plans/2026-08-05-org-workflow.md`                  |
| `org-workflow-design.md`             | `superpowers/specs/2026-08-05-org-workflow-design.md`           |
| `projectile-to-project-migration.md` | `superpowers/specs/2026-05-11-projectile-to-project-design.md`  |

`elixir-developer-guide.md` and `org-protocol-setup.md` fold into `user.md` and are then deleted.
`prog-modules-design.md` is deleted.
It is marked DEPRECATED and describes the `modules/` tree, which no longer exists.
Its one live fact, the keybinding prefixes, lands in `user.md` §3.2.
`docs/.nojekyll` is deleted, because an Actions deployment never runs Jekyll.
Nothing from `tmp/` enters git.
It is gitignored scratch, and only its content is reused.

### 3.3 Content sources per file

| File           | Content                                                                                                                                                                                  |
|----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `README.md`    | Overview, intended audience, reading order, external resources, and the published site URL.                                                                                             |
| `prd.md`       | §1 to §7 from the root README and AGENTS.md. §8 holds the requirements in §4.2 of this spec. §9 Stakeholders is Allen Gooch.                                                           |
| `adr.md`       | The records in §4.3 of this spec.                                                                                                                                                        |
| `tdd.md`       | §1 the three tangled files and the startup sequence. §2 XDG paths, `elpaca/`, `~/org`, and the singleton state files. §3 the MCP tools, `org-protocol://` URIs, and socket-conflict behavior. §4 elpaca, exec-path-from-shell, eglot, dape, tree-sitter. §5 the daemon, the launchd agent, vendoring, and Pages. |
| `qa.md`        | The ERT files, `forms`, `check`, the probe, hk hooks, the docs checks, and the CI gate. Each check cites the requirements it verifies.                                                  |
| `user.md`      | The outline in §3.4.                                                                                                                                                                     |
| `developer.md` | Prerequisites, repo structure, the editing workflow and use-package rules from AGENTS.md, tangle, test, probe, and the release flow from §6.2 of this spec. §5 is the launchd agent, Emacsclient.app, and the URI handler bundles. §6 is link, daemon restart, and Pages. §7 is the probe, `elpaca-log`, `*Warnings*`, and init time. |
| `changelog.md` | `## Unreleased` only, since no tag exists yet. One dated entry per shipped milestone since 2026-09-15, citing RM, FR, and ADR IDs and the commits behind it.                           |
| `roadmap.md`   | Now, Next, Later, and Shipped, holding `RM-N` items. Shipped mirrors the changelog entries one to one.                                                                                  |
| `glossary.md`  | Terms from AGENTS.md and the README, such as tangle, activation block, definition block, binary gate, elpaca order, half-finished clone, probe, project, and client frame.              |

The root `README.md` docs and tasks tables and the `AGENTS.md` command block are updated to the new pages and tasks.

### 3.4 User Guide outline

Everything in `tmp/` predates the literate config and describes the `modules/` tree.
The Elixir guide has the same problem.
Every key, command, and path migrated into `user.md` is checked against `myde.org`, and anything not found there is dropped.
Known stale items:

- The Elixir guide binds `magit-status` to `C-c g` and forge commands to `C-c g f …`. Neither binding exists in `myde.org`.
- `tmp/cpp-ide-plan.md` binds `ff-find-other-file` to `C-c o`, which is now the Org prefix.
- `tmp/org-capture-env.md` names `modules/core-org/` and Emacs 30.2.
- `mix.el` binds `C-c d` in `mix-minor-mode` (`elpaca/sources/mix/mix.el:322`), which shadows the global dape `C-c d` keys in Elixir buffers. The guide records that behavior, and roadmap Next gets an item to resolve it. Changing the config is out of scope.

```text
# User Guide
## 1. Summary                                  root README intro
## 2. Onboarding
### 2.1 Prerequisites                          README, AGENTS.md
### 2.2 Install                                README
### 2.3 Run as a daemon                        README, AGENTS.md
### 2.4 Turn on a language                     README gate table
### 2.5 Language servers and debuggers         README
### 2.6 Browser capture                        docs/org-protocol-setup.md
### 2.7 Emacs MCP server                       README
## 3. Key concepts
### 3.1 Sections                               README
### 3.2 Keybinding prefixes                    README, myde.org
### 3.3 Projects                               tmp/org-capture-env.md, README
### 3.4 Where files live                       README, tmp/org-capture-env.md
## 4. Usage and workflows
### 4.1 Org and notes                          tmp/org-capture-env.md
#### 4.1.1 Capturing
#### 4.1.2 The agenda and task states
#### 4.1.3 Finding things by tag
#### 4.1.4 Notes with denote
#### 4.1.5 Refiling and archiving
#### 4.1.6 Org Babel                           tmp/org-babel-plan.md, myde.org
### 4.2 Programming
#### 4.2.1 Common workflow                     README, Elixir guide
#### 4.2.2 Bash                                myde.org
#### 4.2.3 Fish                                myde.org
#### 4.2.4 Nushell                             myde.org
#### 4.2.5 Emacs Lisp                          myde.org
#### 4.2.6 Common Lisp                         myde.org
#### 4.2.7 Scheme                              myde.org
#### 4.2.8 Clojure                             myde.org
#### 4.2.9 Erlang                              tmp/erlang-ide-plan.md, myde.org
#### 4.2.10 Elixir                             docs/elixir-developer-guide.md, myde.org
#### 4.2.11 C and C++                          tmp/cpp-ide-plan.md, myde.org
#### 4.2.12 Go                                 tmp/go-ide-plan.md, myde.org
#### 4.2.13 Rust                               tmp/rust-ide-plan.md, myde.org
#### 4.2.14 Zig                                myde.org
#### 4.2.15 Python                             tmp/python-ide-plan.md, myde.org
#### 4.2.16 Ruby                               tmp/prog-ruby-plan.md, myde.org
#### 4.2.17 Lua                                tmp/lua-ide-plan.md, myde.org
#### 4.2.18 JavaScript                         myde.org
#### 4.2.19 TypeScript                         myde.org
### 4.3 Git                                    Elixir guide, corrected against myde.org
### 4.4 Writing                                tmp/core-spell-plan.md, tmp/text-markdown-design.md
## 5. Error handling
### 5.1 A package will not install             AGENTS.md
### 5.2 "Cannot open load file" after an update  elpaca-rebuild fix from a past session
### 5.3 $EDITOR opens files nowhere            README
### 5.4 MCP bridge CONNECTION_CLOSED           README
### 5.5 "error invoking gcc driver"            AGENTS.md
### 5.6 Org problems                           tmp/org-capture-env.md
## 6. FAQ                                      README, AGENTS.md
## 7. References                               upstream manuals, org cheatsheet
```

Languages follow `myde.org` section order.
Each §4.2 language subsection covers its gate binary, modes and file types, LSP server, test, REPL, and debug keys, snippets, and Org Babel support, where the section has them.
The `data-*` and `text-*` formats get no subsection.

Left out of `user.md`: `tmp/best-practices-analysis.md` and `tmp/literate-config-migration-handoff.md` (developer history), `tmp/macos-clean-install-startup-fix.md` (package.el, since removed), `tmp/org-brain-*` (superseded by the org workflow design), `tmp/prog-csharp-plan.md` (no matching section in `myde.org`), `tmp/projectile-to-project-migration.md` (duplicate), and `tmp/ONBOARDING.md` (an unrelated Claude Code template).

## 4. Traceability

### 4.1 ID families

| Artifact     | ID and anchor                                                                                          |
|--------------|--------------------------------------------------------------------------------------------------------|
| Requirement  | `FR-N` and `NFR-N`, `#### FR-N` headings in `prd.md` §8.3, anchored `#fr-n`                            |
| Decision     | `ADR-NN`, `## ADR-NN: <title> :id=adr-NN` in `adr.md`                                                  |
| Design       | numbered section anchors in `tdd.md`, such as `#_21-xdg-paths`                                         |
| Verification | numbered section anchors in `qa.md`, such as `#_21-unit-tests`                                         |
| Roadmap item | `RM-N`, `### RM-N: <title> :id=rm-N` under Now, Next, Later, or Shipped. The anchor survives a move.   |
| Changelog    | dated bullets under a version heading. Bullets take no anchor, so links target the version heading.    |

Every reference is a markdown link, never a bare ID.
`check_links.py` already resolves `:id=` anchors.

### 4.2 Requirements

| ID     | Requirement                                                                                          | Type          | Priority |
|--------|------------------------------------------------------------------------------------------------------|---------------|----------|
| FR-1   | A fresh clone starts without tangling.                                                               |               | Must     |
| FR-2   | A toolchain section turns on when its binary is on `PATH` and off when it is not, with no toggle.   |               | Must     |
| FR-3   | Binary gates see the login shell's `PATH`, including in macOS GUI and daemon sessions.              |               | Must     |
| FR-4   | One daemon serves every frame, and `$EDITOR` reaches it.                                            |               | Must     |
| FR-5   | Tasks, thoughts, bookmarks, and notes can be captured, including from a browser.                    |               | Must     |
| FR-6   | Any directory with a `tasks.org` is a project, and its tasks appear in the agenda.                  |               | Must     |
| FR-7   | Every language uses the same prefixes for LSP, tests, REPL, and debugging.                          |               | Should   |
| FR-8   | Agents can query and drive the running Emacs over MCP.                                              |               | Should   |
| FR-9   | Saving `myde.org` keeps the elisp current, and no commit carries drift.                             |               | Must     |
| FR-10  | The docs can be previewed and searched locally.                                                     |               | Should   |
| FR-11  | A push to `main` that changes the docs publishes them to GitHub Pages, and a failing check blocks it. |             | Should   |
| FR-12  | The config carries one version, which names its git tags and shows in the docs sidebar.             |               | Should   |
| NFR-1  | Emacs 31.1 with native compilation is the floor.                                                    | Compatibility | Must     |
| NFR-2  | The config runs on Linux and macOS.                                                                 | Compatibility | Must     |
| NFR-3  | A warm start reaches `elpaca-after-init-hook` in about 4 s.                                        | Performance   | Should   |
| NFR-4  | Only packages live inside `user-emacs-directory`. State, data, and cache go to XDG directories.    | Operability   | Must     |
| NFR-5  | `user-lisp/myde.el` holds definitions only, so it loads in batch without side effects.             | Testability   | Must     |
| NFR-6  | A failed package bootstrap cannot leave GC disabled or TRAMP broken.                               | Reliability   | Must     |
| NFR-7  | The docs site fetches no third-party script or stylesheet at runtime.                              | Security      | Must     |

Each requirement's Source field links the `prd.md` section it comes from, in docsify anchor form.

### 4.3 Architecture decisions

All are Accepted.
Each record carries **Status**, **Date**, **Requirements**, **Context**, **Decision**, and **Consequences**.

| ADR    | Decision                                                                    | Date       | Requirements   | Evidence                          |
|--------|-----------------------------------------------------------------------------|------------|----------------|-----------------------------------|
| ADR-00 | Keep one literate `myde.org`, tangled to committed elisp                    | 2026-09-15 | FR-1, FR-9     | spec 2026-09-15, `9ad474e`        |
| ADR-01 | Manage packages with elpaca instead of package.el                           | 2026-09-15 | NFR-3          | `803a8cc`                         |
| ADR-02 | Gate sections on binary presence instead of toggles                         | 2026-09-15 | FR-2, FR-3     | `d7ec43e`                         |
| ADR-03 | Split definitions into `user-lisp/myde.el`, activation into `init.el`      | 2026-09-17 | NFR-5          | spec 2026-09-17, `aefb6ea`        |
| ADR-04 | Use built-in project.el instead of projectile                               | 2026-05-11 | NFR-4          | spec 2026-05-11, `59c95ab`        |
| ADR-05 | Run one daemon with client frames, and open the dashboard on demand        | 2026-09-18 | FR-4           | `6dec388`                         |
| ADR-06 | Run tasks with mise and hooks with hk, and re-tangle rather than reject    | 2026-09-18 | FR-9           | `1d8c3e0`, `6f3393e`              |
| ADR-07 | Put state, data, and cache in XDG directories                               | 2026-04-27 | NFR-4          | `4a8c68c`                         |
| ADR-08 | Keep each project's tasks in a `tasks.org` beside its code                  | 2026-08-10 | FR-5, FR-6     | spec 2026-08-05, revised 08-10    |
| ADR-09 | Serve MCP on a fixed socket, and never take over a live one                 | 2026-09-18 | FR-8           | `69470b4`, `9ee87eb`              |
| ADR-10 | Restore GC and file handlers on `emacs-startup-hook`                        | from git   | NFR-6          | AGENTS.md *Startup hooks*         |
| ADR-11 | Serve docs with vendored docsify v4 and Catppuccin Frappé                   | 2026-09-27 | FR-10, NFR-7   | this spec                         |
| ADR-12 | Publish docs through a GitHub Actions Pages deployment gated on the checks | 2026-09-27 | FR-11, NFR-7   | this spec                         |
| ADR-13 | Keep the version in a root `VERSION` file                                   | 2026-09-27 | FR-12          | this spec                         |

ADR-10's date comes from `git log -S` on the hook placement during implementation.

### 4.4 Forward fields

Each `prd.md` §8.3 block gains four fields below Priority and Source:

```markdown
#### FR-1

A fresh clone starts without tangling.

- **Priority:** Must
- **Source:** [§3.1](#_31-architecture)
- **Decided by:** [ADR-00](adr.md#adr-00)
- **Designed in:** [§1](tdd.md#_1-architecture-overview)
- **Verified by:** [§2.4](qa.md#_24-enforcement-with-git-hooks)
- **Roadmap:** [RM-1](roadmap.md#rm-1)
```

Decided by and Roadmap may read `none`.
Roadmap reads `none` for a requirement no milestone since 2026-09-15 has touched.
Designed in and Verified by always hold at least one link.
When a requirement has no automated check, `qa.md` §3 gets a manual check for it, and the final report lists those requirements.

A roadmap item:

```markdown
### RM-1: Three-file literate config :id=rm-1

- **Requirements:** [FR-1](prd.md#fr-1), [FR-9](prd.md#fr-9)
- **Decisions:** [ADR-00](adr.md#adr-00)
- **Shipped:** 2026-09-15, [Unreleased](changelog.md#unreleased)

One or two sentences on what the item delivers.
```

A changelog entry:

```markdown
- 2026-09-15: One literate `myde.org` tangles to `early-init.el`, `init.el`, and `user-lisp/myde.el` ([RM-1](roadmap.md#rm-1), [FR-1](prd.md#fr-1), [ADR-00](adr.md#adr-00)).
  Commits `9ad474e` to `f33658c`.
```

Commits that belong to no milestone get no entry.
`git log` holds them.

Candidate milestones, which implementation confirms against `git log --since=2026-09-15`:

| Section | Item                                                                                      |
|---------|-------------------------------------------------------------------------------------------|
| Shipped | Three-file literate config, elpaca, and binary gates (2026-09-15)                         |
| Shipped | Library and config split (2026-09-17 to 2026-09-18)                                        |
| Shipped | Org workflow ported into `myde.org`, with ERT tests and the macOS org-protocol handler (2026-09-18) |
| Shipped | mise tasks and hk hooks replace the Makefile (2026-09-18)                                 |
| Shipped | Daemon session: dashboard on demand, warnings kept off the first frame (2026-09-18 to 2026-09-27) |
| Shipped | MCP server on a fixed socket that a second Emacs cannot take (2026-09-18 to 2026-09-22)   |
| Shipped | Tangle on save (2026-09-21)                                                                |
| Shipped | Docs site, containerized preview, and qmd search (2026-09-18 to 2026-09-27)               |
| Now     | Docs schema, traceability, Catppuccin theme, Pages, and `VERSION` (this spec)             |
| Next    | Resolve the `C-c d` collision between mix.el and dape in Elixir buffers (FR-7)            |
| Next    | Boot the probe daemon with stdin closed, so startup modes can be verified. `scripts/myde-probe.sh:31` does not redirect stdin today. |
| Later   | Decide on `ob-zig`: live with the warning, pin a fork, or drop it (AGENTS.md)            |

### 4.5 Checker

`scripts/check_trace.py` is standard-library Python.
It imports the slug function from `check_links.py` rather than copying it.
It takes `--root` so the test can point it at a fixture tree, skips `docs/superpowers/`, prints one line per finding, and exits 1 on any finding.

1. Every requirement in the §8.1 and §8.2 tables has a §8.3 block, and every block has a table row.
2. Every block has all four forward fields. Designed in and Verified by are never empty.
3. Each forward link is backed. The target section, from its heading to the next heading at the same or higher level, links the requirement.
4. When an ADR or RM item links a requirement, that requirement's matching forward field lists it. Requirement links in TDD or QA prose need no forward entry.
5. Every linked FR, NFR, ADR, and RM exists.
6. Every ADR links at least one requirement. Every RM item links at least one requirement or ADR.
7. Every changelog entry links an RM item. Every Shipped RM item has an entry, and its Shipped link targets the version heading that holds the entry.

`/docs-release` renames `Unreleased` to a version, which leaves Shipped links pointing at `#unreleased`.
Rule 7 flags them, and they are fixed by hand.
The global `/docs-*` commands stay unmodified.

`scripts/test_check_trace.py` builds a minimal fixture tree in a temp dir, asserts the checker passes on it, then breaks each rule once and asserts the matching finding.

## 5. Theme and vendoring

### 5.1 Vendored files

| File under `docs/vendor/`     | Source                                                   | Pin                         |
|-------------------------------|----------------------------------------------------------|-----------------------------|
| `docsify.min.js`              | `docsify@4.13.1/lib/docsify.min.js`                      | 4.13.1                      |
| `search.min.js`               | `docsify@4.13.1/lib/plugins/search.min.js`               | 4.13.1                      |
| `theme-simple-dark.css`       | `docsify-themeable@0.9.0/dist/css/theme-simple-dark.css` | 0.9.0                       |
| `catppuccin-frappe-mauve.css` | `catppuccin/docsify` `themes/frappe/mauve.css`            | commit `628ff26`            |
| `catppuccin-prism-frappe.css` | `https://prismjs.catppuccin.com/frappe.css`              | unversioned, fetch date in the pin table |
| `prism-<lang>.min.js`         | `prismjs@1.30.0/components/prism-<lang>.min.js`          | 1.30.0                      |

The npm sources come from `cdn.jsdelivr.net/npm/`.
The Catppuccin theme comes from `raw.githubusercontent.com` at the pinned commit.
Prism grammars cover each fence language the finished docs use, found by scanning the fences.
Docsify v4 bundles Prism core with markup, CSS, C-like, and JavaScript only.

The Catppuccin theme starts with `@import url(https://prismjs.catppuccin.com/frappe.css);`.
That line is rewritten to `@import url(catppuccin-prism-frappe.css);`, which keeps NFR-7 true.
`theme-simple-dark.css` and the Catppuccin Prism file have no remote `@import` or `url()`, checked on 2026-09-27.

### 5.2 index.html

- Keeps the copyright comment and the `name`, `repo`, `loadSidebar`, `subMaxLevel`, `auto2top`, and `search` config.
- Loads `theme-simple-dark.css`, then `catppuccin-frappe-mauve.css`, then docsify, search, and the Prism grammars, all by relative path.
- Drops the SRI attributes and the comment explaining them, since every asset is same-origin.
- Adds a small inline docsify plugin that fetches `VERSION` and appends it to the sidebar app name as `v<version>` through `textContent`. When the fetch fails, the name shows alone.
- Frappé only. No light-mode toggle and no footer.

### 5.3 vendor_docs.py

`scripts/vendor_docs.py` holds the pin table and writes each file into `docs/vendor/`.
It applies the one `@import` rewrite and fails if the expected line is missing, so an upstream change cannot leave the remote import in place.
It prints one line per file, changed or unchanged.
An upgrade is: edit a pin, run `mise run docs-vendor`, and review the git diff.

`--check` runs offline.
It scans `docs/index.html` and `docs/vendor/*.css` for a remote `@import`, `url()`, `src`, or `href`, and exits 1 on any hit.
That is the automated check behind NFR-7.

## 6. Publishing and version

### 6.1 GitHub Pages

`.github/workflows/docs.yml`:

- Triggers on push to `main` touching `docs/**`, `VERSION`, `scripts/**`, `.markdownlint*`, `mise.toml`, or the workflow itself, and on `workflow_dispatch`.
- A `check` job checks out the repo, runs `mise trust`, installs only `npm:markdownlint-cli` through `jdx/mise-action`, and runs `mise run docs-check`.
- A `deploy` job needs `check`. It runs `actions/configure-pages`, `actions/upload-pages-artifact` with `path: docs`, and `actions/deploy-pages`, in the `github-pages` environment.
- Top-level permissions are `contents: read`. The deploy job adds `pages: write` and `id-token: write`.
- Concurrency group `pages`, with `cancel-in-progress: false`.
- Every action is pinned to a full commit SHA, with the version in a trailing comment.

The site publishes at `https://mojochao.github.io/myde.emacs/`.
The repository has no Pages site yet (`gh api repos/mojochao/myde.emacs/pages` returns 404).
Setting the Pages source to GitHub Actions is a one-time step in the repository settings, done by the owner.
Nothing in this work pushes or changes repository settings.

### 6.2 VERSION

`VERSION` at the repo root holds one semver string and a newline, starting at `0.1.0`.
It names the version most recently released, so between releases the sidebar shows the last tag.

`docs/VERSION` is a relative symlink to `../VERSION`.
That keeps one source of truth across all three ways the site is served:

- `docsify serve` (the `docs` task) follows the symlink.
- `actions/upload-pages-artifact` tars with `--dereference`, so the artifact holds the file. Implementation confirms that flag in the pinned action.
- `docs.compose.yaml` mounts the repo root read-only at `/repo` and serves `/repo/docs`, so the link resolves inside the container.

Release flow, documented in `developer.md`:

1. Edit `VERSION`.
2. Run `/docs-release <version>`, which moves `Unreleased` to the version and Now items to Shipped.
3. Fix the Shipped links that `mise run docs-check` reports.
4. Commit.
5. Run `mise run tag`, which creates the annotated tag `v<VERSION>`. It refuses when `changelog.md` has no `## <VERSION>` heading or the tag already exists.
6. Push the commit and the tag.

## 7. Tooling

| File                               | Change                                                                                                  |
|------------------------------------|---------------------------------------------------------------------------------------------------------|
| `mise.toml`                        | `npm:docsify-cli` 5.0.0 to 4.4.4. Add `"npm:markdownlint-cli" = "0.48.0"`. Add tasks `docs-vendor`, `docs-check`, and `tag`. |
| `docs.compose.yaml`                | `docsify-cli@4.4.4`, mount `.` read-only at `/repo`, serve `/repo/docs`, and drop `--host 0.0.0.0` and its comment. |
| `scripts/check_links.py`           | New, copied verbatim from the sciplay-docs skill.                                                       |
| `scripts/check_trace.py`           | New, §4.5.                                                                                              |
| `scripts/test_check_trace.py`      | New, §4.5.                                                                                              |
| `scripts/vendor_docs.py`           | New, §5.3.                                                                                              |
| `.markdownlint.yaml`               | New, copied from the skill.                                                                             |
| `.markdownlintignore`              | New, listing `docs/superpowers/`, matching `check_links.py`.                                           |
| `.github/workflows/docs.yml`       | New, §6.1.                                                                                              |
| `VERSION`, `docs/VERSION`          | New, §6.2.                                                                                              |

`docs-check` runs `check_links.py`, `check_trace.py`, `test_check_trace.py`, `vendor_docs.py --check`, and `markdownlint docs/`.
Tasks keep calling `python3`, as the existing ones do.
No python pin is added, because the global mise shim already provides `python` for the `/docs-*` commands.

Not adopted: `align_tables.py`, `.yamllint.yaml`, hk steps, `_footer.md`, and `operations.md`.

## 8. Authoring rules

New prose under `docs/` follows the skill's authoring conventions:

- One sentence per line.
- No em-dashes and no semicolons.
- Numbered section headings, linked in docsify's underscore form (`#_31-architecture`).
- Tight table separator rows.
- Plain blockquotes instead of `> [!NOTE]` callouts. The flexible-alerts plugin is not vendored, so docsify would print `[!NOTE]` literally.

Migrated content is rewritten to these rules.
Files under `docs/superpowers/` stay as written.

## 9. Verification

- `mise run docs-check` passes.
- `mise run test`, `mise run forms`, and `mise run check` still pass, since nothing under `myde.org` changes.
- `mise run docs-up` serves the site, every asset `index.html` references returns 200, and the sidebar shows `v0.1.0`.
- `mise run docs` does the same natively.
- A browser shows the Frappé theme with the mauve accent. That check is visual and is the owner's.
- The workflow is linted with `actionlint` if it is installed. It runs for real only after the owner pushes and enables Pages.

## 10. Commit sequence

1. Moves and deletions under `docs/`.
2. Vendored theme, `index.html`, `vendor_docs.py`, the compose and mise changes, and `VERSION`.
3. Validators, `check_trace.py` and its test, and the `docs-check` and `tag` tasks.
4. The ten canonical files and the sidebar.
5. The Pages workflow.
6. Root `README.md` and `AGENTS.md` updates.

## 11. Out of scope

- Changing `myde.org`, including the `C-c d` collision and the probe's stdin.
- Pushing, tagging, or enabling Pages.
- Editing the global `/docs-*` commands or the sciplay-docs skill.
- A light theme.
