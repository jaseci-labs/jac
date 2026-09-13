import os;
import from pathlib { Path }
import from jaclang.jac0core.ext_registry { ANNEX_FOLDER, MODULE_SUFFIXES }

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
        if not d.is_dir() {
            continue;
        }
        for f in d.iterdir() {
            if not f.name.endswith(suffix) {
                continue;
            }
            if ((d != mod_folder) and not f.name.startswith(f"{base}.")) {
                continue;
            }
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
