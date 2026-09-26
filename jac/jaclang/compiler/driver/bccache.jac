import os;
import stat;
import time;
import from pathlib { Path }
import from jaclang.compiler.frontend.source_layout {
    LayoutTables,
    annex_files_of,
    base_file_of
}

glob _DIR_LISTINGS: dict[str, tuple[int, list[str]]] = {},
     LISTING_SETTLE_NS: int = 2_000_000_000,
     _LAYOUT_TABLES: list[LayoutTables] = [];

def host_layout_tables -> LayoutTables {
    if not _LAYOUT_TABLES {
        import from jaclang.jac0core.ext_registry {
            ANNEX_FOLDER,
            INIT_FILES,
            JAC_SUFFIX,
            MODULE_SUFFIXES,
            RETIRED_CLIENT_SUFFIX,
            RETIRED_NATIVE_SUFFIX,
            STEM_REKEY_SUFFIXES,
            _JS_SUFFIXES,
            _PY_SUFFIXES
        }
        _LAYOUT_TABLES.append(
            LayoutTables(
                jac_suffix=JAC_SUFFIX,
                annex_folders=dict(ANNEX_FOLDER),
                module_suffixes=list(MODULE_SUFFIXES),
                init_files=list(INIT_FILES),
                stem_rekey_suffixes=list(STEM_REKEY_SUFFIXES),
                foreign_suffixes=list(_PY_SUFFIXES) + list(_JS_SUFFIXES),
                retired_native=[RETIRED_NATIVE_SUFFIX, ".na.impl.jac"],
                retired_client=[RETIRED_CLIENT_SUFFIX, ".cl.impl.jac"]
            )
        );
    }
    return _LAYOUT_TABLES[0];
}

def _dir_entries(directory: str) -> (list[str] | None) {
    """The names in a directory, cached by the directory's mtime. Annex
    discovery runs for every import of every program in a process, and a
    directory that has not changed costs one stat instead of a scan. A
    listing taken within two seconds of the directory's last change is not
    cached, since a coarse filesystem clock could hide an entry added in
    that window.""";
    try {
        st = os.stat(directory);
    } except OSError {
        return None;
    }
    if not stat.S_ISDIR(st.st_mode) {
        return None;
    }
    cached = _DIR_LISTINGS.get(directory);
    if cached is not None and cached[0] == st.st_mtime_ns {
        return cached[1];
    }
    try {
        names = sorted(os.listdir(directory));
    } except OSError {
        return None;
    }
    if time.time_ns() - st.st_mtime_ns > LISTING_SETTLE_NS {
        _DIR_LISTINGS[directory] = (st.st_mtime_ns, names);
    } else {
        _DIR_LISTINGS.pop(directory, None);
    }
    return names;
}

def discover_annex_files(source_path: str, suffix: str = '.impl.jac') -> list[str] {
    return annex_files_of(host_layout_tables(), source_path, suffix, _dir_entries);
}

def discover_style_annex(source_path: str) -> (str | None) {
    src = Path(source_path).resolve();
    if not src.name.endswith('.jac') {
        return None;
    }
    base = src.stem;
    candidate = src.parent / (base + '.style.css');
    return str(candidate) if candidate.is_file() else None;
}

def discover_base_file(annex_path: str) -> (str | None) {
    return base_file_of(host_layout_tables(), annex_path);
}
