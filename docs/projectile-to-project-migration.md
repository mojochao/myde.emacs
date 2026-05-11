# Design Doc: Migrate from projectile to built-in project.el

**Date:** 2026-05-11
**Author:** Allen Gooch
**Status:** Draft

---

## Background

The config currently loads the external `projectile` package as its primary project
management layer alongside the built-in `project.el`. Both are configured, but projectile
holds the active keybindings (`C-c p` / `s-p`), the dashboard backend, and one function
call in the C++ module. `project.el` is present but passive.

Emacs 30 ships a fully capable `project.el`. Eliminating projectile removes an external
dependency, reduces startup load, and consolidates project state into the single XDG-routed
`projects.eld` file already configured.

---

## Current Usage Audit

| Location | Usage |
|---|---|
| `core-projects/cfg.el` | `projectile-mode` global minor mode; `C-c p` / `s-p` keybinds; `projectile-project-search-path`; XDG-routed `projectile-known-projects-file` |
| `core-projects/cfg.el` | `rg` package loaded `:after projectile` for `projectile-ripgrep` |
| `core-dashboard/cfg.el` | `(dashboard-projects-backend 'projectile)` |
| `prog-cpp/lib.el:53` | `(projectile-project-root)` to resolve build dir in `myde-cpp-dape-binary` |

---

## Comparison

### projectile (External)

**Pros:**
- Large command surface (~80 commands): compile, test, replace, regenerate tags, invalidate
  cache, switch project type, etc.
- `C-c p` prefix is well-documented and familiar to many Emacs users.
- `projectile-project-search-path` with depth control for auto-discovering projects under
  a directory tree.
- Per-project-type awareness (cmake, mix, cargo, leiningen, etc.) that auto-configures
  compile/test commands.
- Mature, actively maintained.

**Cons:**
- External dependency — install, update, and trust cost.
- Duplicates functionality now well-covered by `project.el` in Emacs 30.
- Maintains a separate `projectile-known-projects-file` alongside `project-list-file`.
- `rg` is loaded only to support `projectile-ripgrep`; removing projectile also removes
  this dependency.

### project.el (Built-in, Emacs 30)

**Pros:**
- Zero external dependency.
- `C-x p` prefix with: find-file, find-regexp, search, compile, switch-project,
  kill-buffers, dired, eshell, shell, vc-dir.
- `project-list-file` is already XDG-routed in this config
  (`$XDG_STATE_HOME/emacs/projects.eld`).
- `project-root` / `project-current` are already used in `myde-neotree-project-root-toggle`
  — the codebase is already partially on project.el.
- `project-find-regexp` delegates to `xref` which uses ripgrep if `rg` is on `exec-path`,
  without requiring the `rg` package.
- No global minor mode needed — no mode-line clutter.
- Dashboard supports `'project` as a backend (`dashboard-projects-backend 'project`).

**Cons:**
- Smaller command set — no per-project-type compile/test commands, no `invalidate-cache`,
  no `regenerate-tags`.
- No `project-search-path` equivalent for pre-scanning a directory tree. Projects register
  on first visit rather than being pre-discovered.
- `project-switch-project` UX differs slightly from projectile's (no built-in
  per-project action dispatch, no recent-project ordering out of the box).

---

## Capability Gap Analysis

| Projectile Feature | project.el Equivalent | Gap? |
|---|---|---|
| `projectile-find-file` | `project-find-file` (`C-x p f`) | None |
| `projectile-switch-project` | `project-switch-project` (`C-x p p`) | Minor UX difference |
| `projectile-grep` / `projectile-ripgrep` | `project-find-regexp` (`C-x p g`) via xref+rg | None |
| `projectile-compile-project` | `project-compile` (`C-x p c`) | None |
| `projectile-project-root` | `(project-root (project-current t))` | None |
| `projectile-project-buffers` | `project-buffers` | None |
| `projectile-project-search-path` | `project-remember-projects-under` (helper fn) | Needs one helper |
| Per-project-type compile/test commands | Not built-in | Gap (not currently used) |
| `projectile-invalidate-cache` | Not available | Gap (not currently used) |

The only active gap is `projectile-project-search-path '("~/Projects/")`. This can be
replicated with a one-time call to `(project-remember-projects-under "~/Projects/" t)`
or a small hook.

---

## Required Changes

All changes are mechanical and low-risk.

### `modules/core-projects/cfg.el`

1. Remove the `use-package projectile` block (lines 45–55).
2. Remove the `use-package rg` block (lines 58–60).
3. Remove the `(declare-function projectile-project-buffers ...)` stub from the
   `eval-when-compile` block.
4. Add `project-remember-projects-under` call (or hook) to replace
   `projectile-project-search-path`.
5. Optionally bind `C-c p` / `s-p` to `project-prefix-map` for muscle-memory continuity.
   The canonical built-in prefix is `C-x p`.
6. Update the commentary header to remove projectile/rg lines.

### `modules/core-dashboard/cfg.el`

7. Change `(dashboard-projects-backend 'projectile)` to `(dashboard-projects-backend 'project)`.
8. Update the commentary header.

### `modules/prog-cpp/lib.el`

9. Replace `(projectile-project-root)` with `(when-let ((proj (project-current)))
   (project-root proj))` in `myde-cpp-dape-binary`.

---

## Migration Recommendation

**Proceed with migration.**

The scope is small (~15 lines across 3 files), all gaps are either irrelevant to this
config's actual usage or can be closed with a one-liner helper. The result is one fewer
external dependency, a single consolidated project state file, and no behavioral
regression for the workflows this config actually exercises.

The `rg` package can be removed entirely — `project-find-regexp` via xref will pick up
the `rg` binary automatically from `exec-path` (populated by `exec-path-from-shell` on
macOS) without the Emacs package wrapper.

---

## Rollback Plan

`projectile` and `rg` are still available on MELPA. Reverting is a git revert of the
commit that removes them.
