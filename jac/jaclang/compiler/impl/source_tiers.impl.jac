impl is_seed_source(rel_path: str) -> bool {
    for seed_entry in SEED_PATHS {
        if seed_entry.endswith("/") {
            if rel_path.startswith(seed_entry) {
                return True;
            }
        } elif rel_path == seed_entry {
            return True;
        }
    }
    return False;
}

impl is_native_only(rel_path: str) -> bool {
    if rel_path in NATIVE_ONLY_REL {
        return True;
    }
    for directory in NATIVE_ONLY_DIR_REL {
        if rel_path.startswith(directory + "/") {
            return True;
        }
    }
    return False;
}

impl is_native_lowered(rel: str) -> bool {
    posix = rel.replace("\\", "/");
    if posix in BYTECODE_SHARED_REL {
        return False;
    }
    for prefix in NATIVE_LOWERED_PATHS {
        if posix == prefix or posix.startswith(prefix + "/") {
            return True;
        }
    }
    return False;
}
