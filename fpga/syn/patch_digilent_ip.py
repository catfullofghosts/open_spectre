#!/usr/bin/env python3
"""Patch Digilent rgb2dvi for Vivado OOC synthesis (works on fresh clones).

Problem: upstream Digilent uses `entity work.ResetBridge` while Vivado OOC
often compiles those sources into another library, so synth fails even when
the GUI project shows ResetBridge in work.

Fix: overlay component-style sources from fpga/syn/patches/digilent/rgb2dvi/
onto the cloned vivado-library, then sync into any existing project ipshared.
"""

from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path

ENTITY_WORK_RE = re.compile(r"\bentity\s+work\.", re.IGNORECASE)
PATCH_FILES = ("rgb2dvi.vhd", "SyncAsyncReset.vhd")


def apply_repo_overlays(repo: Path, patch_dir: Path) -> int:
    dst_dir = repo / "ip" / "rgb2dvi" / "src"
    if not dst_dir.is_dir():
        raise SystemExit(f"Digilent rgb2dvi src not found: {dst_dir}")
    if not patch_dir.is_dir():
        raise SystemExit(f"Patch directory not found: {patch_dir}")

    n = 0
    for name in PATCH_FILES:
        src = patch_dir / name
        dst = dst_dir / name
        if not src.is_file():
            raise SystemExit(f"Missing patch file: {src}")
        shutil.copy2(src, dst)
        print(f"Applied overlay: {src.name} -> {dst}")
        n += 1

    # Sanity check after overlay
    rgb = (dst_dir / "rgb2dvi.vhd").read_text(encoding="utf-8", errors="replace")
    if ENTITY_WORK_RE.search(rgb):
        raise SystemExit(
            f"{dst_dir / 'rgb2dvi.vhd'} still contains entity work.* after overlay"
        )
    if "component ResetBridge" not in rgb:
        raise SystemExit(
            f"{dst_dir / 'rgb2dvi.vhd'} missing component ResetBridge after overlay"
        )
    print("OK: rgb2dvi.vhd uses component instantiations")
    return n


def sync_ipshared(repo: Path, project: Path) -> int:
    """Copy patched Digilent sources over generated ipshared copies."""
    src_dir = repo / "ip" / "rgb2dvi" / "src"
    if not src_dir.is_dir() or not project.is_dir():
        return 0
    n = 0
    for name in PATCH_FILES:
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


def main() -> int:
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo",
        type=Path,
        default=here.parent / "deps" / "vivado-library",
        help="Path to Digilent vivado-library checkout",
    )
    parser.add_argument(
        "--project",
        type=Path,
        default=here / "build" / "open_spec",
        help="Optional Vivado project root to sync ipshared copies",
    )
    parser.add_argument(
        "--patch-dir",
        type=Path,
        default=here / "patches" / "digilent" / "rgb2dvi",
        help="Directory with overlay VHDL sources",
    )
    args = parser.parse_args()

    n = apply_repo_overlays(args.repo.resolve(), args.patch_dir.resolve())
    n += sync_ipshared(args.repo.resolve(), args.project.resolve())
    print(f"Done. Applied/synced {n} file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
