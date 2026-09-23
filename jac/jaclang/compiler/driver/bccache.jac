import os;
import stat;
import time;
import from pathlib { Path }
import from jaclang.jac0core.ext_registry { ANNEX_FOLDER, MODULE_SUFFIXES }

glob _DIR_LISTINGS: dict[str, tuple[int, list[str]]] = {},
     LISTING_SETTLE_NS: int = 2_000_000_000;

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
    src = Path(source_path).resolve();
    if (not src.name.endswith('.jac') or src.name.endswith(suffix)) {
        return [];
    }
    base = src.stem;
    mod_folder = src.parent / (base + suffix[:-4]);
    shared_folder = suffix[1:-4];
    dirs = [src.parent, mod_folder, (src.parent / shared_folder)];
    results: list[str] = [];
    for d in dirs {
        names = _dir_entries(str(d));
        if names is None {
            continue;
        }
        for name in names {
            if not name.endswith(suffix) {
                continue;
            }
            if ((d != mod_folder) and not name.startswith(f"{base}.")) {
                continue;
            }
            f = d / name;
            if not f.is_file() {
                continue;
            }

            results.append(str(f));
        }
    }
    return results;
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
    src = Path(annex_path).resolve();
    for (suffix, folder_suffix) in ANNEX_FOLDER.items() {
        if src.name.endswith(suffix) {
            base_name = src.name[:-len(suffix)].split('.')[0];
            parent = src.parent.name;
            candidates = [(src.parent, base_name)];
            if parent.endswith(folder_suffix) {
                candidates.append((src.parent.parent, parent[:-len(folder_suffix)]));
            }
            if (parent in {'impl', 'test'}) {
                candidates.append((src.parent.parent, base_name));
            }
            for (directory, name) in candidates {
                for ext in MODULE_SUFFIXES {
                    path = directory / f"{name}{ext}";
                    if (path.is_file() and (path != src)) {
                        return str(path);
                    }
                }
            }
            break;
        }
    }
    return None;
}
