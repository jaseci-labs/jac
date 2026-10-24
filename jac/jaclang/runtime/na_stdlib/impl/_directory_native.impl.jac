impl directory_names(path: str) -> list[str] {
    directory = __jac_opendir(path);
    if directory == 0 {
        raise_os_error("opendir", path, last_errno());
    }
    names: list[str] = [];
    try {
        while True {
            clear_errno();
            ent = __jac_readdir(directory);
            if ent == 0 {
                error = last_errno();
                if error != 0 {
                    raise_os_error("readdir", path, error);
                }
                break;
            }
            name = dirent_name(ent);
            if name != "." and name != ".." {
                names.append(name);
            }
        }
    } finally {
        __jac_closedir(directory);
    }
    return names;
}

impl try_directory_names(path: str) -> list[str] {
    names: list[str] = [];
    directory = __jac_opendir(path);
    if directory == 0 {
        return names;
    }
    ent = __jac_readdir(directory);
    while ent != 0 {
        name = dirent_name(ent);
        if name != "." and name != ".." {
            names.append(name);
        }
        ent = __jac_readdir(directory);
    }
    __jac_closedir(directory);
    return names;
}
