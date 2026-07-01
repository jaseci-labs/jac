import os;
import from jaclang.cli.console { console }
import from jaclang.jac0core.ext_registry { base_stem, is_jac, is_python }


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
