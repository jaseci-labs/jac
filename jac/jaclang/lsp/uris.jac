"""URI utilities for converting between filesystem paths and file:// URIs."""

import re;
import sys;
import from urllib { parse }
import from typing { Optional, Tuple }

glob IS_WIN = sys.platform == "win32",
     RE_DRIVE_LETTER_PATH = re.compile(r"^\/[a-zA-Z]:");

def _normalize_win_path(path: str) -> tuple[str, str];
def from_fs_path(path: str) -> Optional[str];
def to_fs_path(uri: str) -> Optional[str];
def uri_scheme(uri: str) -> Optional[str];
def _urlparse(uri: str) -> tuple[str, str, str, str, str, str];
def _urlunparse(parts: tuple[str, str, str, str, str, str]) -> str;
