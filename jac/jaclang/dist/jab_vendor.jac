import json;
import logging;
import os;
import platform;
import re;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob logger = logging.getLogger(__name__);

glob VENDOR_DIR_REL: str = "_vendor",
     WHEELS_SUBDIR: str = "wheels",
     SITE_SUBDIR: str = "site",
     VENDOR_MANIFEST: str = "VENDOR.json",
     SITE_READY_MARKER: str = ".site-ready";

glob MAX_SOURCE_ROUNDS: int = 10;

glob MANYLINUX_ALIASES: dict[tuple[int, int], str] = {
         (2, 5): "manylinux1",
         (2, 12): "manylinux2010",
         (2, 17): "manylinux2014"
     };

glob _NO_MATCH_RE = re.compile(
         r"^(?:ERROR: )?No matching distribution found for (.+?)\s*$", re.M
     ),
     _NO_DIST_HEADER: str = "no matching distributions available for your environment:";


def manylinux_tags(arch: str, glibc: tuple[int, int]) -> list[str];


obj WheelTarget {
    has arch: str,
        python_version: str,
        glibc: tuple[int, int];

    def platform_tag -> str;
    def host_build_compatible -> bool;
    def platform_tags -> list[str];
    def pip_args(allow_host_build: bool = False) -> list[str];
    def describe -> str;
}


obj WheelDownloadResult {
    has ok: bool,
        missing: list[str] = [],
        detail: str = "";
}


def vendor_dir(img_root: Path) -> Path;


def wheels_dir(img_root: Path) -> Path;


def site_dir(img_root: Path) -> Path;


def has_vendored(img_root: Path) -> bool;


def _pip(args: list[str]) -> tuple[int, str];


def download_wheels(
    specs: list[str], dest: Path, target: (WheelTarget | None) = None
) -> WheelDownloadResult;


def _resolve_wheels(
    specs: list[str], dest: Path, target: (WheelTarget | None), build_dir: Path
) -> WheelDownloadResult;


def _missing_requirements(out: str) -> dict[str, list[str]];


def _project_name(req: str) -> str;


def _build_from_source(
    missing: dict[str, list[str]], dest: Path
) -> tuple[dict[str, list[Path]], str];


def _reject_unfit(
    unfit: list[str], built: dict[str, list[Path]], target: (WheelTarget | None)
) -> str;


def write_vendor_manifest(
    img_root: Path, specs: list[str], python_tag: str = "", platform_tag: str = ""
);


def _install_offline(wheels: Path, site: Path);


def activate_vendored(img_root: Path) -> Path | None;
