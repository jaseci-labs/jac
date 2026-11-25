import os;

glob _ROOT_REAL: list[str] = [];

def _target_root_real -> str;

def target_package_rel(path: str) -> (str | None);

def package_host_edge(mod_path: str) -> bool;

def scope_allows_inferred_path(mod_path: str) -> bool;

def binds_bare_arch_names(mod_path: str) -> bool;
