import ctypes;
import os;
import platform;
import re;
import shutil;
import tempfile;
import urllib.request;
import from pathlib { Path }

glob SELF_UPDATE_REPO: str = "jaseci-labs/jaseci";

def platform_triple(system: str = "", machine: str = "") -> ((str, str) | None);

def release_asset(
    assets: list[any], plat: str, arch: str
) -> ((dict[str, any], str) | None);

def up_to_date(current: str, latest: str) -> bool;

def _fetch_text(url: str) -> (str | None);

def _sidecar_digest(url: str) -> (str | None);

def _running_jacpython -> bool;

def update_self(release: str, current: str, verbose: bool) -> int;
