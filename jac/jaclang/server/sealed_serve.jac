import json;
import os;

import from pathlib { Path }

glob SERVE_MANIFEST_REL: str = os.path.join(".jac", "serve_manifest.json"),
     SERVE_MANIFEST_FORMAT: int = 3,
     CLIENT_DIST_REL: str = os.path.join(".jac", "client", "dist"),
     NATIVE_DIR_REL: str = os.path.join(".jac", "native"),
     _MODULE_KEYS_CACHE: dict[str, tuple[float, set]] = {};


def native_lib_suffix -> str;

def native_lib_name(stem: str) -> str;

def interop_record_path(lib_output: str) -> Path;


def _image_module_keys(img_root: str) -> set;


def _image_key(abs_path: str, img_root: str) -> str;


def _image_roots(abs_path: str) -> Iterator[tuple[str, bool]];


def sealed_root_for(path: str) -> (str | None);


def unlisted_image_root(path: str) -> (str | None);


def serve_manifest_stamp -> dict[str, (int | str)];


def read_serve_manifest(img_root: str) -> dict[str, any];


def serve_manifest_for(path: str) -> (dict[str, any] | None);


def client_dist_for(path: str) -> (Path | None);
