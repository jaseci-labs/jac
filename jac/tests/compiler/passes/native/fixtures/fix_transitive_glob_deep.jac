"""Deepest module for transitive-glob-init fix test.

Has a stateful glob list.  __jac_glob_init initialises _TABLE to an empty
list.  Before the fix, when only imported transitively (not directly from
the entry file), __jac_glob_init_<safe_name> was never called from
jac_entry, leaving _TABLE null and causing SIGSEGV on first access.
"""

glob _TABLE: list[int] = [];

def:pub table_len() -> int {
    return len(_TABLE);
}

def:pub table_push(v: int) -> None {
    _TABLE.append(v);
}
