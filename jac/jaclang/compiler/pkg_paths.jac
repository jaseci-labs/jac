import os;

glob _ROOT_REAL: list[str] = [];

def target_pkg_root -> str;

def _target_root_real -> str;

def is_target_package_path(path: str) -> bool;

def target_package_rel(path: str) -> (str | None);

def package_host_edge(mod_path: str) -> bool;

def scope_allows_inferred_path(mod_path: str) -> bool;

def binds_bare_arch_names(mod_path: str) -> bool;
