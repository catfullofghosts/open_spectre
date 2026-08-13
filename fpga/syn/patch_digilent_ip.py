#!/usr/bin/env python3
"""Patch Digilent rgb2dvi for Vivado OOC synthesis.

Problem: Digilent uses `entity work.ResetBridge` while Vivado often compiles
those sources into xil_defaultlib. The GUI project may show ResetBridge in
"work", but OOC synth runs in a separate in-memory project and fails.

Fix (same pattern Digilent already uses in ClockGen.vhd):
  Replace `entity work.*` instantiations with component instantiations so
  binding happens in whatever library Vivado assigned the sources to.

Also copies the patched sources into an existing project's ipshared tree.
"""

from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path

DIGILENT_IPS = ("rgb2dvi",)


def sync_ipshared(repo: Path, project: Path) -> int:
    """Copy patched Digilent sources over generated ipshared copies."""
    src_dir = repo / "ip" / "rgb2dvi" / "src"
    if not src_dir.is_dir() or not project.is_dir():
        return 0
    n = 0
    for name in ("rgb2dvi.vhd", "SyncAsyncReset.vhd"):
        src = src_dir / name
        if not src.is_file():
            continue
        for dst in project.rglob(name):
            path_l = str(dst).lower().replace("\\", "/")
            if "/ipshared/" not in path_l:
                continue
            if "rgb2dvi" not in path_l and "/d57c/" not in path_l:
                continue
            shutil.copy2(src, dst)
            print(f"Synced {src.name} -> {dst}")
            n += 1
    return n


def verify_no_entity_work(repo: Path) -> None:
    src = repo / "ip" / "rgb2dvi" / "src" / "rgb2dvi.vhd"
    if not src.is_file():
        raise SystemExit(f"missing {src}")
    text = src.read_text(encoding="utf-8", errors="replace").lower()
    if re.search(r"\bentity\s+work\.", text):
        raise SystemExit(
            f"{src} still contains 'entity work.*'. "
            "Replace with component instantiations (see ClockGen.vhd style)."
        )
    print(f"OK: {src} uses component instantiations (no entity work.*)")


def main() -> int:
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo",
        type=Path,
        default=here.parent / "deps" / "vivado-library",
    )
    parser.add_argument(
        "--project",
        type=Path,
        default=here / "build" / "open_spec",
    )
    args = parser.parse_args()

    repo = args.repo.resolve()
    verify_no_entity_work(repo)
    n = sync_ipshared(repo, args.project.resolve())
    print(f"Done. Synced {n} project file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
