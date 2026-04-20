"""Shared CLI helper functions used across command implementations."""

import os;
import from jaclang.cli.console { console }

glob _runtime_initialized = False;

"""Initialize Jac runtime once on first use."""
def ensure_jac_runtime {
    global _runtime_initialized;
    if not _runtime_initialized {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        Jac.setup();
        _runtime_initialized = True;
    }
}

"""Create JacRuntime and return the base path, module name, and runtime state.

This is the canonical function for setting up CLI execution context.
It handles base_path setup, closing any existing context, and creating a new one.
"""
def proc_file(filename: str) -> tuple {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    (base, mod) = os.path.split(filename);
    base = base or './';
    if filename.endswith('.na.jac') {
        mod = mod[:-7];
    } elif filename.endswith('.jac') {
        mod = mod[:-4];
    } elif filename.endswith('.py') {
        mod = mod[:-3];
    } else {
        console.error('Not a valid file!\nOnly supports `.jac` and `.py`');
        `exit(1);
    }
    # Only set base path if not already set (allows tests to override)
    if not Jac.base_path_dir {
        Jac.set_base_path(base);
    }
    # CLI contexts use system_root (no user authentication)
    mach = Jac.create_j_context(user_root=None);
    Jac.set_context(mach);
    return (base, mod, mach);
}
