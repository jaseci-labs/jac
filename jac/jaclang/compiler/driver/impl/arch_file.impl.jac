impl is_arch_file(path: str) -> bool {
    return os.path.basename(path) == ARCH_FILE_NAME;
}

impl arch_file_for(path: str) -> (str | None) {
    project = active_host().project_root(path);
    stop = os.path.realpath(project) if project else None;
    real = os.path.realpath(path);
    cur = real if os.path.isdir(real) else os.path.dirname(real);
    while True {
        candidate = os.path.join(cur, ARCH_FILE_NAME);
        if os.path.isfile(candidate) {
            return candidate;
        }
        if stop is not None and cur == stop {
            return None;
        }
        parent = os.path.dirname(cur);
        if parent == cur {
            return None;
        }
        cur = parent;
    }
}
