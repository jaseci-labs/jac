import os;
import from pathlib { Path }
import from jaclang.jac0core.ext_registry {
    VARIANT_STEM_SUFFIXES,
    VARIANT_SUFFIXES,
    ANNEX_FOLDER,
    MODULE_SUFFIXES
}

def discover_annex_files(source_path: str, suffix: str = '.impl.jac') -> list[str] {
    src = Path(source_path).resolve();
    if (not src.name.endswith('.jac') or src.name.endswith(suffix)) {
        return [];
    }
    base = src.stem;

    src_variant: (str | None) = None;
    for vext in VARIANT_STEM_SUFFIXES {
        if base.endswith(vext) {
            src_variant = vext;
            base = base[:-len(vext)];
            break;
        }
    }

    bare_head_exists = (
        src_variant is not None and (src.parent / (base + '.jac')).is_file()
    );
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

            annex_stem = f.name[:-len(suffix)];
            annex_variant: (str | None) = None;
            for vext in VARIANT_STEM_SUFFIXES {
                if annex_stem.endswith(vext) {
                    annex_variant = vext;
                    break;
                }
            }

            if annex_variant is not None {
                if (annex_variant != src_variant) {
                    continue;
                }
            } elif (src_variant is not None and bare_head_exists) {
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
    for vext in VARIANT_STEM_SUFFIXES {
        if base.endswith(vext) {
            base = base[:-len(vext)];
            break;
        }
    }
    candidate = src.parent / (base + '.style.css');
    return str(candidate) if candidate.is_file() else None;
}

def discover_variant_files(source_path: str) -> list[str] {
    src = Path(source_path).resolve();
    if not src.name.endswith('.jac') {
        return [];
    }
    if ('.impl.' in src.name or '.test.' in src.name) {
        return [];
    }

    stem = src.stem;
    head_suffix: (str | None) = None;
    for vs in VARIANT_SUFFIXES {
        ext = vs[:-4];
        if stem.endswith(ext) {
            head_suffix = vs;
            stem = stem[:-len(ext)];
            break;
        }
    }

    if (head_suffix is not None) {
        if (src.parent / f"{stem}.jac").is_file() {
            return [];
        }
        for vs in VARIANT_SUFFIXES {
            if (vs == head_suffix) {
                break;
            }
            if (src.parent / f"{stem}{vs}").is_file() {
                return [];
            }
        }
    }

    if (head_suffix is None) {
        search_suffixes = list(VARIANT_SUFFIXES);
    } else {
        idx = list(VARIANT_SUFFIXES).index(head_suffix);
        search_suffixes = list(VARIANT_SUFFIXES)[idx + 1:];
    }
    variants: list[str] = [];
    for variant_suffix in search_suffixes {
        variant_path = src.parent / f"{stem}{variant_suffix}";
        if variant_path.is_file() {
            variants.append(str(variant_path));
        }
    }
    return variants;
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
