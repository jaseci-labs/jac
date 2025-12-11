obj : pub ModulePublObj {}
obj : priv ModulePrivObj {}

glob : pub module_publ_glob: int = 0;
glob : priv module_priv_glob: int = 0;

with entry {
    ModulePrivObj();  # <-- okey.
    ModulePublObj();  # <-- okey.

    module_publ_glob;  # <-- okey.
    module_priv_glob;  # <-- okey.
}
