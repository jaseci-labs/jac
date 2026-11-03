impl discover_spaces(
    paths: list[str], prog: (JacProgram | None) = None
) -> dict[str, set[str]] {
    target = prog if prog is not None else JacProgram();
    out: dict[str, set[str]] = {};
    for p in paths {
        ap = os.path.abspath(p);
        mod = hub_module_for_path(ap, target);
        if mod is None {
            record = module_record(ap, target);
            if record is not None and record.spaces {
                out[ap] = set(record.spaces);
                continue;
            }
            try {
                mod = target.compile(file_path=ap, no_cgen=True);
            } except Exception {}
        }
        spaces = set(module_spaces(mod));
        if target.count_module_errors(os.path.normpath(ap)) > 0 {
            spaces.add(SPACE_SERVER);
        }
        out[ap] = spaces;
    }
    if prog is None {
        target.release_compile_closure();
    }
    return out;
}

impl module_record(
    source_path: str, program: (JacProgram | None) = None
) -> (PlacementSummary | None) {
    real = os.path.realpath(source_path);
    if program is None {
        return _record_at(real);
    }
    actual = program._get_compiler().product_program(real, program, execution=True);
    with cache_scope(owner_scope_options(actual)) {
        return _record_at(real);
    }
}

impl _record_at(real: str) -> (PlacementSummary | None) {
    try {
        cache_path = get_module_cache_path(real);
        if not is_module_cache_valid(real, cache_path) {
            return None;
        }
        data = read_jir(cache_path);
        raw = read_section_bytes(data, SEC_PLACEMENT);
        if raw is None {
            return None;
        }
        return summary_from_bytes(raw, path_mapper=read_jir_paths(data).resolve);
    } except OSError {
        return None;
    }
}
