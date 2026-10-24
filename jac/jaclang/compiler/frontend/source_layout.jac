import os;
import from collections.abc { Callable }

obj LayoutTables {
    has jac_suffix: str = ".jac",
        annex_folders: dict[str, str] = {},
        module_suffixes: list[str] = [],
        init_files: list[str] = [],
        stem_rekey_suffixes: list[str] = [],
        foreign_suffixes: list[str] = [],
        retired_native: list[str] = [],
        retired_client: list[str] = [];

    def shared_folder(suffix: str) -> str;
    def is_annex(path: str) -> bool;
    def base_stem(path: str) -> str;
}

def list_directory(directory: str) -> (list[str] | None);

def style_annex_of(source_path: str) -> (str | None);

def annex_files_of(
    tables: LayoutTables,
    source_path: str,
    suffix: str,
    listing: Callable[[str], (list[str] | None)]
) -> list[str];

def base_file_of(tables: LayoutTables, annex_path: str) -> (str | None);

def is_annex_path_of(tables: LayoutTables, candidate: str, base: str) -> bool;

def package_init_of(tables: LayoutTables, directory: str) -> (str | None);

def path_facts_of(tables: LayoutTables, path: str) -> PathFacts;
