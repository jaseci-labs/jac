impl is_seed_source(rel_path: str) -> bool {
    for entry in SEED_PATHS {
        if entry.endswith("/") {
            if rel_path.startswith(entry) {
                return True;
            }
        } elif rel_path == entry {
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
    for prefix in NATIVE_LOWERED_PATHS {
        if posix == prefix or posix.startswith(prefix + "/") {
            return True;
        }
    }
    return False;
}
