import json;
import os;
import shutil;
import from pathlib { Path }

glob MOUNTS_RECORD: str = ".jac-mounts.json",
     COPY_MARKER: str = ".jac-mount-copy";

def _current_target(item: Path) -> str;

def _remove(item: Path);

def _link(item: Path, target: Path);

def link_mounts(build_dir: Path, targets: dict[str, Path]) -> Path;

def read_mounts(build_dir: Path) -> dict[str, str];
