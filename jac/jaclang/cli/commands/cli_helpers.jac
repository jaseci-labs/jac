"""Shared CLI helper functions used across command implementations."""

import os;
import from jaclang.cli.console { console }
import from jaclang.jac0core.ext_registry { base_stem, is_jac, is_python }


"""Create JacRuntime and return the base path, module name, and runtime state.

This is the canonical function for setting up CLI execution context.
It handles base_path setup, closing any existing context, and creating a new one.
"""
def proc_file(filename: str) -> tuple {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    (base, mod) = os.path.split(filename);
    base = base or './';
    if not (is_jac(filename) or is_python(filename)) {
        console.error('Not a valid file!\nOnly supports `.jac` and `.py`');
        `exit(1);
    }
    # Collapse the compound codespace suffix (.na.jac / .sv.jac / .cl.jac) to
    # the bare module stem via the shared longest-suffix matcher; stripping only
    # the trailing `.jac` would leave e.g. `main.sv`, which the meta-importer
    # misreads as the package `main.sv` ("No module named 'main.sv'"). #6696.
    mod = base_stem(mod);
    # Only set base path if not already set (allows tests to override)
    if not Jac.get_base_path_dir() {
        Jac.set_base_path(base);
    }
    # CLI contexts use system_root (no user authentication). Pass the
    # seeds explicitly so the ctx's L3 path is locked in at postinit
    # time, immune to later seed mutations by sibling clients.
    mach = Jac.create_j_context(
        user_root=None,
        base_path_dir=Jac.get_base_path_dir(),
        full_target_path=Jac.get_full_target_path()
    );
    Jac.set_context(mach);
    return (base, mod, mach);
}
