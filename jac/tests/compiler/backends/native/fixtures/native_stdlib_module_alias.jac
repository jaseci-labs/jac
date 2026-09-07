import fnmatch as patterns;

def standard_library_module_alias_probe -> bool {
    return patterns.fnmatchcase("compiler.jac", "*.jac")
        and not patterns.fnmatchcase("compiler.py", "*.jac");
}
