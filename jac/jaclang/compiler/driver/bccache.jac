import os;
import stat;
import time;
import from pathlib { Path }

glob _DIR_LISTINGS: dict[str, tuple[int, list[str]]] = {},
     LISTING_SETTLE_NS: int = 2_000_000_000,
     _LAYOUT_TABLES: list[LayoutTables] = [];

def host_layout_tables -> LayoutTables;

def _dir_entries(directory: str) -> (list[str] | None);

def discover_annex_files(source_path: str, suffix: str = '.impl.jac') -> list[str];

def discover_base_file(annex_path: str) -> (str | None);
