#!/usr/bin/env python3
"""Build Open Spec Vitis software from an exported XSA + fpga/z7_build/sw.

Requires Vitis 2024.2 environment (vitis -s).

Usage:
  vitis -s build_vitis.py
  vitis -s build_vitis.py -- --xsa path/to/hdmi_in.xsa --sw path/to/z7_build/sw
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    here = Path(__file__).resolve().parent
    fpga = here.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--xsa",
        type=Path,
        default=here / "build" / "hdmi_in.xsa",
        help="Fixed hardware XSA from Vivado write_hw_platform",
    )
    parser.add_argument(
        "--sw",
        type=Path,
        default=fpga / "z7_build" / "sw",
        help="Application source tree (Digilent video_demo + drivers)",
    )
    parser.add_argument(
        "--workspace",
        type=Path,
        default=here / "build" / "vitis_ws",
        help="Vitis workspace directory",
    )
    parser.add_argument(
        "--platform-name",
        default="open_spec_pf",
    )
    parser.add_argument(
        "--app-name",
        default="video_demo",
    )
    parser.add_argument(
        "--cpu",
        default="ps7_cortexa9_0",
    )
    parser.add_argument(
        "--domain-name",
        default="standalone_ps7_cortexa9_0",
    )
    # vitis -s forwards args after -- ; also tolerate bare argv
    return parser.parse_args()


def collect_sources(sw_root: Path) -> list[tuple[Path, str]]:
    """Return (absolute_file, relative_posix_path) for all .c/.h under sw."""
    files: list[tuple[Path, str]] = []
    for p in sorted(sw_root.rglob("*")):
        if not p.is_file():
            continue
        if p.suffix.lower() not in {".c", ".h"}:
            continue
        rel = p.relative_to(sw_root).as_posix()
        files.append((p.resolve(), rel))
    return files


def main() -> int:
    args = parse_args()
    xsa = args.xsa.resolve()
    sw = args.sw.resolve()
    workspace = args.workspace.resolve()

    if not xsa.is_file():
        raise SystemExit(f"XSA not found: {xsa}\nRun: build.bat all   (exports XSA after bitstream)")
    if not sw.is_dir():
        raise SystemExit(f"Software source tree not found: {sw}")

    sources = collect_sources(sw)
    if not sources:
        raise SystemExit(f"No .c/.h sources under {sw}")

    try:
        import vitis  # type: ignore
    except ImportError as exc:
        raise SystemExit(
            "Could not import vitis. Run via: vitis -s build_vitis.py\n"
            f"Import error: {exc}"
        ) from exc

    print("============================================================")
    print(" Open Spec Vitis software build")
    print(f"  xsa       : {xsa}")
    print(f"  sw        : {sw}")
    print(f"  workspace : {workspace}")
    print(f"  sources   : {len(sources)} files")
    print("============================================================")

    if workspace.exists():
        print(f"Removing previous workspace: {workspace}")
        shutil.rmtree(workspace)
    workspace.mkdir(parents=True, exist_ok=True)

    client = vitis.create_client()
    client.set_workspace(str(workspace))

    print(f"Creating platform {args.platform_name} ...")
    # Prefer explicit domain (matches AMD platform_uc4_zynq / build_settings examples)
    platform = client.create_platform_component(
        name=args.platform_name,
        hw_design=str(xsa),
        os="standalone",
        cpu=args.cpu,
        domain_name=args.domain_name,
    )
    try:
        domains = platform.list_domains()
        print(f"Platform domains: {domains}")
    except Exception:
        pass
    platform.build()

    platform_xpfm = client.find_platform_in_repos(args.platform_name)
    print(f"Creating app {args.app_name} ...")
    # App-component empty template is "empty" in Vitis 2024.2 examples
    app = None
    last_err = None
    for template in ("empty", "empty_application", "Empty Application"):
        try:
            app = client.create_app_component(
                name=args.app_name,
                platform=platform_xpfm,
                domain=args.domain_name,
                template=template,
            )
            print(f"Using app template: {template}")
            break
        except Exception as exc:  # noqa: BLE001 - Vitis API raises mixed types
            last_err = exc
            try:
                client.delete_component(args.app_name)
            except Exception:
                pass
    if app is None:
        raise SystemExit(f"Failed to create app component: {last_err}")

    # Drop template stub sources if present
    app_src = workspace / args.app_name / "src"
    if app_src.is_dir():
        for stub in app_src.glob("*"):
            if stub.is_file() and stub.name.lower() in {"main.c", "helloworld.c", "readme.txt"}:
                stub.unlink()
                print(f"Removed template stub: {stub.name}")

    from collections import defaultdict

    by_from: dict[Path, list[tuple[str, str]]] = defaultdict(list)
    for abs_path, rel in sources:
        parent = Path(rel).parent
        dest = "src" if str(parent) in (".", "") else f"src/{parent.as_posix()}"
        by_from[abs_path.parent].append((abs_path.name, dest))

    for from_loc, items in by_from.items():
        dest = items[0][1]
        names = [n for n, _ in items]
        print(f"Importing {len(names)} file(s) from {from_loc} -> {dest}")
        app.import_files(
            from_loc=str(from_loc),
            files=names,
            dest_dir_in_cmp=dest,
        )

    include_dirs = [
        "src",
        "src/display_ctrl",
        "src/video_capture",
        "src/intc",
        "src/dynclk",
        "src/timer_ps",
    ]
    abs_includes = [str((workspace / args.app_name / d).resolve()) for d in include_dirs]
    if abs_includes:
        app.set_app_config(key="USER_INCLUDE_DIRECTORIES", values=abs_includes[0])
        for inc in abs_includes[1:]:
            app.append_app_config(key="USER_INCLUDE_DIRECTORIES", values=inc)

    print("Building application ...")
    app.build()

    # Locate ELF
    elf_candidates = list(workspace.rglob(f"{args.app_name}.elf"))
    if not elf_candidates:
        # common Vitis layout
        elf_candidates = list((workspace / args.app_name).rglob("*.elf"))
    if elf_candidates:
        elf = elf_candidates[0]
        stable = workspace.parent / f"{args.app_name}.elf"
        shutil.copy2(elf, stable)
        print(f"ELF written: {stable}")
    else:
        print("WARNING: build finished but .elf was not found under workspace")

    vitis.dispose()
    print("Vitis software build finished OK.")
    return 0


if __name__ == "__main__":
    # Support `vitis -s build_vitis.py -- --xsa ...`
    if "--" in sys.argv:
        idx = sys.argv.index("--")
        sys.argv = [sys.argv[0]] + sys.argv[idx + 1 :]
    raise SystemExit(main())
