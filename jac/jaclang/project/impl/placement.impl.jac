impl validate_pins(pins: dict[str, str], toml_path: str) -> dict[str, str] {
    for (key, space) in pins.items() {
        if space not in VALID_SPACES {
            raise ValueError(
                f"[placement.pins] in {toml_path}: '{key}' pins to '{space}', "
                    + f"expected one of {list(VALID_SPACES)}."
            );
        }
    }
    return pins;
}

impl module_dot_path(source_path: str, root_dir: str) -> str {
    path = os.path.realpath(source_path);
    relative = os.path.relpath(os.path.dirname(path), os.path.realpath(root_dir));
    parent = relative.replace(os.sep, '.')
        if relative != '.' and not relative.startswith('..')
        else '';
    parts: list[str] = [parent, host_layout_tables().base_stem(path)];
    return '.'.join([part for part in parts if part]);
}

impl match_pin(
    source_path: str, root_dir: str, pins: dict[str, str], element_name: str = ''
) -> str {
    module = module_dot_path(source_path, root_dir);
    for (pattern, space) in pins.items() {
        if element_name and fnmatch.fnmatchcase(f'{module}.{element_name}', pattern) {
            return space;
        }
        if fnmatch.fnmatchcase(module, pattern) {
            return space;
        }
    }
    return '';
}
