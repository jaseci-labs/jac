import os;
import sys;
import json;
import logging;
import struct;
import from pathlib { Path }

glob _logger: logging.Logger = logging.getLogger("byllm.model_cache"),
     _GGUF_SCALAR_SIZES: dict[int, int] = {
         0: 1,
         1: 1,
         2: 2,
         3: 2,
         4: 4,
         5: 4,
         6: 4,
         7: 1,
         10: 8,
         11: 8,
         12: 8
     },
     _GGML_BLOCKS: dict[int, tuple[int, int]] = {
         0: (1, 4),
         1: (1, 2),
         2: (32, 18),
         3: (32, 20),
         6: (32, 22),
         7: (32, 24),
         8: (32, 34),
         9: (32, 40),
         10: (256, 84),
         11: (256, 110),
         12: (256, 144),
         13: (256, 176),
         14: (256, 210),
         15: (256, 292),
         16: (256, 66),
         17: (256, 74),
         18: (256, 98),
         19: (256, 50),
         20: (32, 18),
         21: (256, 110),
         22: (256, 82),
         23: (256, 136),
         24: (1, 1),
         25: (1, 2),
         26: (1, 4),
         27: (1, 8),
         28: (1, 8),
         29: (256, 56),
         30: (1, 2),
         34: (256, 54),
         35: (256, 66),
         39: (32, 17),
         40: (64, 36),
         41: (128, 18)
     };

def _is_interactive -> bool;

def _emit(msg: str);

def get_cache_dir -> Path;

def alias_dir(alias: str) -> Path;

def gguf_path(alias: str, spec: dict[str, any]) -> Path;

def _consent_marker(alias: str) -> Path;

def is_downloaded(alias: str, spec: dict[str, any]) -> bool;

def _read_le(f: any, fmt: str) -> int;

def _skip_gguf_value(f: any, vtype: int);

def _gguf_size_needed(f: any) -> int;

def _fmt_size(mb: int) -> str;

def _resolve_consent(alias: str, spec: dict[str, any], auto_download: bool) -> bool;

def _download(alias: str, spec: dict[str, any], force: bool = False) -> Path;

def ensure_model(alias: str, spec: dict[str, any], auto_download: bool = False) -> str;

def force_pull(alias: str, spec: dict[str, any]) -> str;

def remove_alias(alias: str) -> bool;

def list_downloaded -> list[dict[str, any]];
