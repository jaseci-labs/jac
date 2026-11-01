import os;
import time;

glob _DIR_LISTINGS: dict[str, tuple[int, list[str]]] = {},
     LISTING_SETTLE_NS: int = 2_000_000_000,
     JAC_LAYOUT_TABLES: LayoutTables = LayoutTables(
         jac_suffix=".jac",
         annex_folders={".impl.jac": ".impl", ".test.jac": ".test"},
         module_suffixes=[".jac"],
         init_files=["__init__.jac"],
         stem_rekey_suffixes=[".impl"],
         foreign_suffixes=[".pyi", ".py", ".jsx", ".tsx", ".js", ".ts"],
         retired_native=[".na.jac", ".na.impl.jac"],
         retired_client=[".cl.jac", ".cl.impl.jac"]
     );

def host_layout_tables -> LayoutTables;

def _dir_entries(directory: str) -> (list[str] | None);

def discover_annex_files(source_path: str, suffix: str = '.impl.jac') -> list[str];

def discover_base_file(annex_path: str) -> (str | None);
