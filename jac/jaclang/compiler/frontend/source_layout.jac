import os;
import from collections.abc { Callable }
import from jaclang.compiler.frontend.host { PathFacts }

obj LayoutTables {
    has jac_suffix: str = ".jac",
        annex_folders: dict[str, str] = {},
        module_suffixes: list[str] = [],
        init_files: list[str] = [],
        stem_rekey_suffixes: list[str] = [],
        foreign_suffixes: list[str] = [],
        retired_native: list[str] = [],
        retired_client: list[str] = [];

    def shared_folder(suffix: str) -> str {
        return suffix[1:-len(self.jac_suffix)];
    }

    def is_annex(path: str) -> bool {
        for suffix in self.annex_folders {
            if path.endswith(suffix) {
                return True;
            }
        }
        return False;
    }

    def base_stem(path: str) -> str {
        name = os.path.basename(path);
        if not name.endswith(self.jac_suffix) {
            for suffix in self.foreign_suffixes {
                if name.endswith(suffix) {
                    return name[:-len(suffix)];
                }
            }
            return name;
        }
        name = name[:-len(self.jac_suffix)];
        stems = list(self.annex_folders.values());
        changed = True;
        while changed {
            changed = False;
            for stem in stems {
                if name.endswith(stem) {
                    name = name[:-len(stem)];
                    changed = True;
                    break;
                }
            }
        }
        return name;
    }
}

def list_directory(directory: str) -> (list[str] | None) {
    if not os.path.isdir(directory) {
        return None;
    }
    try {
        return sorted(os.listdir(directory));
    } except OSError {
        return None;
    }
}

def annex_files_of(
    tables: LayoutTables,
    source_path: str,
    suffix: str,
    listing: Callable[[str], (list[str] | None)]
) -> list[str] {
    src = os.path.realpath(source_path);
    name = os.path.basename(src);
    if not name.endswith(tables.jac_suffix) or name.endswith(suffix) {
        return [];
    }
    base = os.path.splitext(name)[0];
    parent = os.path.dirname(src);
    mod_folder = os.path.join(parent, base + suffix[:-len(tables.jac_suffix)]);
    folders = [parent, mod_folder, os.path.join(parent, tables.shared_folder(suffix))];
    results: list[str] = [];
    for folder in folders {
        names = listing(folder);
        if names is None {
            continue;
        }
        for listed in names {
            if not listed.endswith(suffix) {
                continue;
            }
            if folder != mod_folder and not listed.startswith(f"{base}.") {
                continue;
            }
            candidate = os.path.join(folder, listed);
            if os.path.isfile(candidate) {
                results.append(candidate);
            }
        }
    }
    return results;
}

def base_file_of(tables: LayoutTables, annex_path: str) -> (str | None) {
    src = os.path.realpath(annex_path);
    name = os.path.basename(src);
    folder = os.path.dirname(src);
    parent = os.path.basename(folder);
    for (suffix, folder_suffix) in tables.annex_folders.items() {
        if not name.endswith(suffix) {
            continue;
        }
        base_name = name[:-len(suffix)].split('.')[0];
        candidates: list[tuple[str, str]] = [(folder, base_name)];
        if parent.endswith(folder_suffix) {
            candidates.append((os.path.dirname(folder), parent[:-len(folder_suffix)]));
        }
        shared = [tables.shared_folder(annex) for annex in tables.annex_folders];
        if parent in shared {
            candidates.append((os.path.dirname(folder), base_name));
        }
        for (directory, stem) in candidates {
            for ext in tables.module_suffixes {
                candidate = os.path.join(directory, f"{stem}{ext}");
                if os.path.isfile(candidate) and candidate != src {
                    return candidate;
                }
            }
        }
        break;
    }
    return None;
}

def is_annex_path_of(tables: LayoutTables, candidate: str, base: str) -> bool {
    stem = base[:-len(tables.jac_suffix)] if base.endswith(tables.jac_suffix) else base;
    if candidate.startswith(stem) {
        rest = candidate[len(stem):];
        if not rest.startswith(".") {
            return False;
        }
        for (suffix, folder) in tables.annex_folders.items() {
            if rest.endswith(suffix) or rest.startswith(folder + os.sep) {
                return True;
            }
        }
        return False;
    }
    (base_dir, base_name) = os.path.split(stem);
    (cand_dir, cand_name) = os.path.split(candidate);
    for suffix in tables.annex_folders {
        if cand_dir == os.path.join(base_dir, tables.shared_folder(suffix))
            and cand_name.startswith(base_name + ".")
            and cand_name.endswith(suffix) {
            return True;
        }
    }
    return False;
}

def package_init_of(tables: LayoutTables, directory: str) -> (str | None) {
    for name in tables.init_files {
        candidate = os.path.join(directory, name);
        if os.path.exists(candidate) {
            return candidate;
        }
    }
    return None;
}

def path_facts_of(tables: LayoutTables, path: str) -> PathFacts {
    marker = "";
    for suffix in tables.retired_native {
        if path.endswith(suffix) {
            marker = "native";
        }
    }
    if not marker {
        for suffix in tables.retired_client {
            if path.endswith(suffix) {
                marker = "client";
            }
        }
    }
    name = os.path.basename(path);
    dot = name.rfind(".");
    stem = name[:dot] if dot > 0 else name;
    for suffix in tables.stem_rekey_suffixes {
        if stem.endswith(suffix) {
            stem = stem[:-len(suffix)];
            break;
        }
    }
    return PathFacts(
        is_jac=path.endswith(tables.jac_suffix),
        is_annex=tables.is_annex(path),
        retired_marker=marker,
        module_stem=tables.base_stem(path),
        scope_stem=stem
    );
}
