import hashlib;
import io;
import json;
import os;
import shutil;
import tarfile;

import from pathlib { Path }

glob JAB_SUFFIX: str = ".jab";

def is_jab(path: str) -> bool;

def materialize_jab(jab_path: str) -> Path;

def materialize_jab_bytes(data: bytes, expected_sha256: str = "") -> Path;

def _materialize_jab_data(
    load: Callable[[], bytes], label: str, expected_sha256: str = ""
) -> Path;

def jab_app_meta(img_root: Path) -> dict[str, any];
