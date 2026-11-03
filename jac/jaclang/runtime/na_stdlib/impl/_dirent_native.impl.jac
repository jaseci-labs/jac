impl dirent_name(ent: int) -> str {
    return strdup(__jac_dirent_name(ent));
}

impl dirent_type(ent: int) -> int {
    return __jac_dirent_type(ent);
}
