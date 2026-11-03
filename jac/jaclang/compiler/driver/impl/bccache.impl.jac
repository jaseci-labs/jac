impl host_layout_tables -> LayoutTables {
    return JAC_LAYOUT_TABLES;
}

impl _dir_entries(directory: str) -> (list[str] | None) {
    if not os.path.isdir(directory) {
        return None;
    }
    mtime_ns = os.stat(directory).st_mtime_ns;
    cached = _DIR_LISTINGS.get(directory);
    if cached is not None and cached[0] == mtime_ns {
        return cached[1];
    }
    names = sorted(os.listdir(directory));
    if time.time_ns() - mtime_ns > LISTING_SETTLE_NS {
        _DIR_LISTINGS[directory] = (mtime_ns, names);
    } else {
        _DIR_LISTINGS.pop(directory, None);
    }
    return names;
}

impl discover_annex_files(source_path: str, suffix: str = '.impl.jac') -> list[str] {
    return annex_files_of(host_layout_tables(), source_path, suffix, _dir_entries);
}

impl discover_base_file(annex_path: str) -> (str | None) {
    return base_file_of(host_layout_tables(), annex_path);
}
