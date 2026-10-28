import os;
import sys;

glob _KIT: list[tuple[str, (SealedImage | None)]] = [];

def kit_image -> (tuple[str, SealedImage] | None);

def pr_kit_omits(name: str) -> bool;

def kit_path(rel: str) -> str;

def _find_kit -> tuple[str, (SealedImage | None)];

def _unsealed_runtime_site -> str;

def runtime_floor_root(sealed: bool) -> str;

def osarch(triple: str = "") -> str;
