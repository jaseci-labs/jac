import fnmatch as patterns;
import os as operating_system;
import os.path as paths;

def standard_library_module_alias_probe -> bool {
    return patterns.fnmatchcase("compiler.jac", "*.jac")
        and not patterns.fnmatchcase("compiler.py", "*.jac");
}

def mixed_path_dispatch_probe -> bool {
    here = operating_system.getcwd();
    return paths.isdir(here)
        and operating_system.path.isdir(here)
        and paths.exists(paths.realpath(here))
        and paths.normpath(paths.join(here, ".")) == paths.normpath(here);
}
