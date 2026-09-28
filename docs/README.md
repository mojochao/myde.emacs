# My Development Environment (MyDE) - Emacs

## Introduction

### Overview

MyDE is a literate Emacs configuration for Emacs 31.1 and later, compiled with native-compile support, targeting Linux and macOS.
One file, `myde.org`, is edited by hand and tangles into three committed files: `early-init.el`, `init.el`, and `user-lisp/myde.el`.
A section that needs a toolchain turns on only when the toolchain is on `PATH`, with no toggle to maintain.
The published site is at [https://mojochao.github.io/myde.emacs/](https://mojochao.github.io/myde.emacs/).

### Intended audience

| Reader | Start with |
|---|---|
| The owner using the config | [User Guide](user.md) |
| Someone changing the config | [Developer Guide](developer.md) and [Technical Design](tdd.md) |
| A reviewer of a decision | [Product Requirements](prd.md) and [Architecture Decisions](adr.md) |

### What next

1. Introduction, this page, sets the scope and points to the rest.
2. [User Guide](user.md) walks through install, onboarding, and daily workflows.
3. [Developer Guide](developer.md) covers cloning, building, testing, and releasing the repo itself.
4. [Product Requirements](prd.md) states what MyDE must do and for whom.
5. [Architecture Decisions](adr.md) records why the design took its current shape.
6. [Technical Design](tdd.md) details the architecture, data model, and integration layer.
7. [Quality Assurance](qa.md) explains how tests, hooks, and manual checks catch regressions.
8. [Changelog](changelog.md) lists what shipped, traced back to the roadmap.
9. [Roadmap](roadmap.md) tracks what is planned, in progress, or done.
10. [Glossary](glossary.md) defines the terms used across these pages.

### External resources

- [MyDE on GitHub](https://github.com/mojochao/myde.emacs)
- [AGENTS.md](https://github.com/mojochao/myde.emacs/blob/main/.agents/AGENTS.md), the repo conventions agents read

Every spec and plan under `docs/superpowers/` is a point-in-time record, not updated after it was written.

- 2026-09-27: [Docs schema, traceability, theme, and publishing design](superpowers/specs/2026-09-27-docs-schema-design.md)
- 2026-09-27: [Docs schema, traceability, theme, and publishing plan](superpowers/plans/2026-09-27-docs-schema.md)
- 2026-09-17: [Library/config split design](superpowers/specs/2026-09-17-library-config-split-design.md)
- 2026-09-17: [Library/config split plan](superpowers/plans/2026-09-17-library-config-split.md)
- 2026-09-15: [Three-file literate config design](superpowers/specs/2026-09-15-three-file-literate-config-design.md)
- 2026-09-15: [Three-file literate config plan](superpowers/plans/2026-09-15-three-file-literate-config.md)
- 2026-08-05: [Org workflow design](superpowers/specs/2026-08-05-org-workflow-design.md)
- 2026-08-05: [Org workflow plan](superpowers/plans/2026-08-05-org-workflow.md)
- 2026-06-10: [Elixir dape debugging plan](superpowers/plans/2026-06-10-elixir-dape-debugging.md)
- 2026-06-10: [Elixir .exs script debugging plan](superpowers/plans/2026-06-10-elixir-exs-debugging.md)
- 2026-05-11: [Projectile to project.el migration design](superpowers/specs/2026-05-11-projectile-to-project-design.md)
