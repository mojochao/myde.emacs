#!/usr/bin/env python3
"""Manage the qmd docs-search index for this repo.

qmd is a mise-pinned npm tool (see mise.toml). This wraps the project-local
`.qmd/` index over docs/. Run from a mise-activated shell so `qmd` and `npm`
resolve on PATH.

Commands:
    init      build qmd's native sqlite binding, register docs/, and embed
    update    re-index and re-embed docs/ (refresh the db after doc changes)
    query     search the index (this is what `mise run docs-search` calls)

`query` exists so the mise task can be one portable command with no shell
quoting or $var expansion, which would break under cmd on Windows.
"""

import argparse
import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _platform_cmd(cmd: list[str]) -> list[str]:
    """npm-installed CLIs are .cmd shims on Windows, and CreateProcess cannot
    launch a batch file. Route through cmd /c there, keeping the list form so
    there is still no shell quoting anywhere."""
    return ["cmd", "/c", *cmd] if os.name == "nt" else cmd


def sh(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(_platform_cmd(cmd), check=True, **kwargs)


def build_sqlite_binding() -> None:
    """qmd's native better-sqlite3 addon: mise's npm store skips package
    lifecycle scripts, so build the binding once. Recent node majors may have
    no napi prebuild, so prebuild-install falls back to node-gyp. Skips if
    already built."""
    cache = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    stores = sorted(glob.glob(os.path.join(cache, "aube", "virtual-store", "better-sqlite3@*")))
    if not stores:
        return  # not installed via the mise npm store, nothing to build
    pkg = os.path.join(stores[0], "node_modules", "better-sqlite3")
    if os.path.exists(os.path.join(pkg, "build", "Release", "better_sqlite3.node")):
        return
    sh(["npm", "run", "install"], cwd=pkg)


def collection_exists(name: str) -> bool:
    return (
        subprocess.run(
            _platform_cmd(["qmd", "collection", "show", name]),
            cwd=ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        == 0
    )


def update() -> None:
    """Re-scan docs/ and refresh embeddings. embed only re-embeds changed docs."""
    sh(["qmd", "update"], cwd=ROOT)
    sh(["qmd", "embed"], cwd=ROOT)


def init() -> None:
    build_sqlite_binding()
    sh(["qmd", "init"], cwd=ROOT)
    if not collection_exists("docs"):
        sh(["qmd", "collection", "add", "docs", "--name", "docs"], cwd=ROOT)
    update()


def query(terms: list[str]) -> None:
    """Forward to `qmd query`. No shell, so quoting is the OS's problem, not ours."""
    if not terms:
        raise SystemExit("usage: python scripts/qmd.py query <question>")
    sh(["qmd", "query", " ".join(terms)], cwd=ROOT)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Manage the qmd docs-search index.")
    parser.add_argument(
        "command",
        choices=["init", "update", "query"],
        help="init: build the sqlite binding, register docs/, and embed. "
        "update: re-index and re-embed docs/. "
        "query: search the index.",
    )
    parser.add_argument("terms", nargs="*", help="Question to search for (query only)")
    args = parser.parse_args(argv)
    if args.command == "query":
        query(args.terms)
    else:
        {"init": init, "update": update}[args.command]()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
