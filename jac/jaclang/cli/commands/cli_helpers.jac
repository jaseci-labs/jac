import os;
import from jaclang.cli.console { console }
import from jaclang.jac0core.ext_registry { base_stem, is_jac, is_python }


"""Flatten a repeatable CLI flag's list-of-lists into a flat list.

argparse `action="append"` with `nargs="+"` yields `[["a"], ["b","c"]]` for
`-I a -I b c`; consumers want `["a","b","c"]`. Returns None when the flag was
never given, so each driver's own defaults apply."""
def flatten_append(groups: list | None) -> list | None {
    if not groups {
        return None;
    }
    return [v for g in groups for v in g];
}


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

    mod = base_stem(mod);

    if not Jac.get_base_path_dir() {
        Jac.set_base_path(base);
    }

    mach = Jac.create_j_context(
        user_root=None,
        base_path_dir=Jac.get_base_path_dir(),
        full_target_path=Jac.get_full_target_path()
    );
    Jac.set_context(mach);
    return (base, mod, mach);
}
