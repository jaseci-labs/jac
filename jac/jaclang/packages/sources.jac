import hashlib;
import os;
import shutil;
import subprocess;
import from pathlib { Path }

obj GitError(Exception) {}

obj GitCheckout {
    has url: str,
        commit: str,
        tree: Path;
}

def _git(args: list[str], cwd: Path | None = None) -> str;

def _mirror_dir(url: str) -> Path;

def checkout(url: str, rev: str = "") -> GitCheckout;

def pack_checkout(co: GitCheckout) -> tuple[bytes, str];

def resolve_path(base: Path, rel: str) -> Path;
