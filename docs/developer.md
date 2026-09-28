# Developer Guide

## 1. Prerequisites

| Requirement | Needed for |
|---|---|
| Emacs 31.1 or later, compiled with native-compile support | The whole config, since `user-lisp-directory` does not exist before 31.1 |
| mise | Every task in `mise.toml`, including install, tangle, and the docs site |
| git 2.54 or later | hk's config-based git hooks |
| Python 3 | The docs checkers under `scripts/` and the qmd search index |
| Docker, optional | `mise run docs-up`, a containerized docs preview |

## 2. Onboarding

### 2.1 Clone the repo

```sh
git clone https://github.com/mojochao/myde.emacs
cd myde.emacs
```

Everything from here on runs from inside the clone.
[2.3](#_23-initialize-project) trusts the mise config and installs the git hooks.

### 2.2 Repo structure

| Path | Holds |
|---|---|
| `myde.org` | The only hand-edited source, tangled into the three files below |
| `early-init.el`, `init.el`, `user-lisp/myde.el` | Tangled output, committed, never edited by hand |
| `tests/` | ERT test files, one per module, run by `mise run test` |
| `scripts/` | Task helpers: the tangle guard, forms checker, probe, docs checkers, qmd wrapper, and vendoring script |
| `snippets/` | Yasnippet snippets, flat under `snippets/<language>/` |
| `etc/` | Assets, plus `org-protocol.desktop`, installed on Linux by `mise run install-xdg` |
| `docs/` | This docs site, served by docsify |
| `elpaca/` | Cloned and built packages, gitignored |
| `.agents/AGENTS.md` | Agent-facing guidance, symlinked to the repo root as `AGENTS.md` and `CLAUDE.md` |
| `hk.pkl` | The git hook definitions `mise run init` installs |
| `mise.toml` | Every task used in this guide |
| `VERSION` | The released version, shown in the docs sidebar |
| `README.md` | The project overview and install steps |
| `.claude/settings.json` | The Claude Code hooks that guard and re-tangle `myde.org`, see [3.1](#_31-editing-mydeorg) |
| `.mcp.json` | Registers qmd as an MCP server, so an agent can search `docs/` directly |
| `docs.compose.yaml` | The container definition behind `mise run docs-up` |

Gitignored, and therefore missing from a fresh clone until built or created: `elpaca/` (built packages), `custom.el` (Customize output), and `build/` (`mise run export` output).
All three are confirmed in `.gitignore`.

### 2.3 Initialize project

#### 2.3.1 Configure environment

`mise trust` is needed once per machine.
mise refuses to read an untrusted config, and trust is machine-local state.
Run it before any other mise command in this repo:

```sh
mise trust
```

A second clone on a different machine needs its own `mise trust`, even for the same user.

#### 2.3.2 Install dependencies

`mise run init` runs two steps in order.

```sh
mise run init
```

- `mise run link` symlinks the repo into `~/.config/emacs`.
- `hk install` registers hk's git hooks.
  hk uses git's config-based hooks (2.54 or later), so `.git/hooks` stays empty.

`mise install` installs the pinned tools in `mise.toml`: `hk`, `npm:docsify-cli`, `npm:@tobilu/qmd`, and `npm:markdownlint-cli`.
`mise run init` does not run this step, run it separately once:

```sh
mise install
```

Build the docs search index once, after `mise install`:

```sh
mise exec -- python3 scripts/qmd.py init
```

Re-index after the docs change with `mise exec -- python3 scripts/qmd.py update`.

Emacs is ready to start after this.
The first start clones and builds every package with elpaca into `./elpaca/`, which takes a few minutes ([Technical Design §4.1](tdd.md#_41-elpaca)).
A later start only activates what is already built, reaching `elpaca-after-init-hook` in about 4 seconds.

## 3. Build and run project

### 3.1 Editing myde.org

- Only `myde.org` is edited by hand.
- `mise run tangle` overwrites `early-init.el`, `init.el`, and `user-lisp/myde.el` on every run.
  An edit to one of the three tangled files directly is silently discarded at the next tangle.
- A section's `***` heading holds up to two blocks, definitions and activation.
  Definitions carry `:tangle user-lisp/myde.el`, activation inherits `:tangle init.el`.
- Put `defun` and `defvar` in the definitions block.
  Put `use-package`, `setq`, and `add-hook` in the activation block.
- Wrap a toolchain-dependent section's whole `use-package` form in `(when (executable-find "<binary>") ...)`.
  elpaca queues the package order when the form is expanded, before `:if` or `:when` runs, so a keyword inside the form cannot stop the clone.
- Every package needs exactly one ensuring form.
  A second `use-package` form for the same package needs `:ensure nil`, and, unless it is otherwise deferred (`:hook`, `:bind`, `:mode`, `:commands`), `:after <package>` too.
- Every built-in package's `use-package` form needs `:ensure nil`.
  Without it, `use-package-always-ensure t` makes elpaca try to clone something already built in.
- Use `:hook (elpaca-after-init . fn)` for a startup hook.
  Never `after-init` or `emacs-startup`, since a use-package body under elpaca runs after those hooks have already fired.
- Never bind a lambda to a hook.
  Define a named function in the same section and reference it by name.
- `:ensure` is the last keyword in a `use-package` form.

See [Technical Design §1.3](tdd.md#_13-binary-gates) for why the gate has to wrap the whole form, and [§4.1](tdd.md#_41-elpaca) for why elpaca needs exactly one ensuring form.

### 3.2 Tangling

Three layers keep the tangled elisp from drifting out of date.

- Run `mise run tangle` by hand to regenerate `early-init.el`, `init.el`, and `user-lisp/myde.el` from `myde.org`.
- In Emacs, `myde-tangle-source-on-save` sits on the global `after-save-hook` and re-tangles on every save of `myde.org`.
- In Claude Code, `.claude/settings.json` runs `scripts/claude-tangle-hook.sh` on every `Edit` or `Write`.
  Its `guard` mode runs on `PreToolUse` and denies any edit to `early-init.el`, `init.el`, or `user-lisp/myde.el`.
  Its `tangle` mode runs on `PostToolUse` and re-tangles when the edited file is `myde.org`.
- hk's pre-commit hook re-tangles rather than rejecting a commit.
  It stashes unstaged changes, runs `mise run tangle`, stages the three tangled files, then runs `mise run forms` and `mise run test`.

See [Technical Design §5.1](tdd.md#_51-tangling-and-hooks) for why the deny matters more than the tangle.

### 3.3 Restarting the daemon

A config change needs a daemon restart to take effect.
On macOS:

```sh
launchctl kickstart -k gui/$(id -u)/gnu.emacs.daemon
```

Verify against `emacsclient`, which always talks to the daemon:

```sh
emacsclient -c
```

Anything that only shows up in a window-system frame needs a client frame to confirm it, since the daemon itself has none.

### 3.4 Previewing the docs

- `mise run docs` serves `docs/` natively with live reload at `http://localhost:3000`.
- `mise run docs-up` serves the same site from a container, and `mise run docs-down` stops it.
- `mise run docs-search <question>` searches `docs/` with qmd.
  Build the index once first, see [2.3.2](#_232-install-dependencies).
- `mise run docs-vendor` re-fetches the pinned docsify, theme, and Prism assets in `docs/vendor/` from the network.
  Review the diff it produces before committing, since a bad fetch would ship straight to the docs site.

## 4. Test and lint project

- `mise run test` runs the ERT checks under `tests/` in batch mode.
- `mise run forms` asserts `user-lisp/myde.el` holds only definitions.
- `mise run check` tangles, then fails if the committed elisp differs from `myde.org`.
- `mise run probe <report>` boots this config as a throwaway daemon and writes a report of its declared `use-package` forms, global modes, init time, and startup errors.
  Run it before and after a change, and diff its `declared:` and `mode:` lines.
  A declared package that disappears, or a mode that flips to `off`, is a regression.
- `mise run docs-check` runs the docs checkers and markdownlint in order: `check_links.py`, `check_trace.py`, `test_check_trace.py`, `vendor_docs.py --check`, then `markdownlint docs/`.

See [Quality Assurance](qa.md) for what each check catches, how it is enforced by git hooks, and the manual checks that have no automated equivalent.

## 5. Infrastructure

### 5.1 The launchd agent and Emacsclient.app

- One `emacs --fg-daemon` is meant to be the only Emacs process on a machine running this config.
- `~/Library/LaunchAgents/gnu.emacs.daemon.plist` starts it at login, with `RunAtLoad` and `KeepAlive` so it restarts if killed.
- Every GUI frame comes from `emacsclient -c` against that daemon, never from launching Emacs.app directly.
- `~/Applications/Emacsclient.app` wraps `emacsclient -c -n -a ""` in a two-line shell script for the Dock.
  It carries Emacs' own `Emacs.icns`, so the Dock tile looks like Emacs but never starts a second process.
- The Dock's persistent-apps entry has to point at `Emacsclient.app`, not at `/Applications/Emacs.app`.
- `$EDITOR` and `$VISUAL` are already set to `emacsclient`, so they reach the same daemon.

Never launch Emacs.app alongside the daemon.
Two processes fight over three singletons: the `server` socket, the `mcp-server` Unix socket under `$XDG_CACHE_HOME/emacs/`, and the XDG state files.
The daemon wins the socket, so the second process silently skips `server-start`, and the state files are last-writer-wins between whichever process touched them last.
See [Technical Design §1.4](tdd.md#_14-session-model) and [§2.4](tdd.md#_24-singleton-state) for the full picture.

### 5.2 URI handler bundles

- `mise run install-xdg` installs the `org-protocol://` URI handler on Linux.
  It installs `etc/org-protocol.desktop` to `$xdg_apps_dir` (`~/.local/share/applications` by default) and refreshes the desktop database.
  `mise run uninstall-xdg` removes it the same way.
- `mise run install-macos` installs the same handler on macOS.
  It builds `~/Applications/OrgProtocol.app` with `osacompile`, registers the `org-protocol` URL scheme in its `Info.plist` with `plutil`, and re-signs the bundle with `codesign`.
  `mise run uninstall-macos` removes the bundle.

See [User Guide §2.6](user.md#_26-browser-capture) for the browser bookmarklet and capture steps these handlers enable.

## 6. Deployment

### 6.1 Linking the config

- `mise run link` symlinks this repo to `$emacs_dir` (`~/.config/emacs` by default), so Emacs loads it as `user-emacs-directory`.
- `mise run unlink` removes that symlink.
- `mise run init` already runs `link`, then `hk install`, so a fresh clone rarely needs `link` run on its own.
  Run `link` directly to relink after moving the clone, or to point a different machine's `~/.config/emacs` at it.

### 6.2 Publishing the docs

`.github/workflows/docs.yml` publishes the docs:

- It triggers on a push to `main` that touches `docs/**`, `VERSION`, `scripts/**`, `.markdownlint*`, `mise.toml`, or the workflow file itself, and on `workflow_dispatch`.
- Its `check` job runs `mise run docs-check`.
- Its `deploy` job needs `check` to pass, and publishes `docs/` with `actions/upload-pages-artifact` and `actions/deploy-pages`.

The repository's Pages source has to be set to "GitHub Actions" once, under Settings, Pages.
That is a one-time step for the repository owner, done outside any commit.
Once it is set, a passing push to `main` publishes to [https://mojochao.github.io/myde.emacs/](https://mojochao.github.io/myde.emacs/).

### 6.3 Releasing a version

1. Edit `VERSION`.
2. Run `/docs-release <version>`, which moves `Unreleased` to that version and `Now` items to `Shipped`.
3. Fix the `Shipped` links that `mise run docs-check` reports.
4. Commit.
5. Run `mise run tag`.
   It checks that `docs/changelog.md` has a `## <VERSION> - <date>` heading, and refuses otherwise.
   `git tag -a` itself refuses if `v<VERSION>` already exists.
6. Push the commit and the tag.

The owner runs step 6.

## 7. Observability

- `mise run probe <report>` boots a throwaway daemon and writes `declared:` and `mode:` lines, init time, and startup errors to a report file, see [4](#_4-test-and-lint-project).
- `M-x elpaca-log`, inside a running Emacs, shows the build status of every package order.
- The `*Warnings*` buffer holds anything logged above `warning-minimum-level`.
- `(emacs-init-time)` reports how long the running session took to start.
- The MCP `eval-elisp` tool lets an agent evaluate elisp in the running daemon, for example to read a variable's current value.

## 8. Where to look next

- [Technical Design](tdd.md) for the architecture, data model, and integration layer this guide assumes.
- [Architecture Decisions](adr.md) for why each of those choices was made.
- [AGENTS.md on GitHub](https://github.com/mojochao/myde.emacs/blob/main/.agents/AGENTS.md) for the conventions agents, and this guide, follow.
