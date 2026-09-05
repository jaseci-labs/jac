"""The emitter's last driver read becomes a stamped fact (#8288 M1 rung 1).

`JcirGenPass.exit_import` was the one place a sealed pass still reached
for `self.prog`: it asked `native_only_import_target` whether the import
resolved to a module the native lane owns, then asked the filesystem
whether that module lived inside jaclang's own tree. Both are
import-resolution questions -- they need the hub, the placement pins and
`os.path` -- and both are the driver's, which is why the seam coverage
waived the method for exactly that reason.

The driver now answers them once and stamps the verdict on the node, the
way `Module.access_enforced` and `Module.mobui_enforced_root` are
stamped. The pass consumes a bool.

Pinned here: the stamp lands where the coverage says it must (before the
emitter runs), it agrees with the computation it replaced, and the pass
unit no longer names `prog` at all -- the last of the eight driver names
`test_pass_driver_seam_baseline.jac` forbids.
"""

import os;
import jaclang;
import jaclang.compiler.frontend.unitree as uni;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.boundary_classify { native_only_import_target }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     PINNED_IMPORTER = "na_py_interop_multi.jac",
     PKG_PATH = Path(jaclang.__file__).parent;


"""Compile a fixture the ordinary way and hand back (program, module)."""
def _compiled(fixture: str) -> tuple {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, fixture),
        options=CompileOptions()
    );
    return (prog, mod, );
}


test "the driver stamps every import before the emitter reads it" {
    (prog, mod) = _compiled(PINNED_IMPORTER);
    imports = list(mod.get_all_sub_nodes(uni.Import));
    assert imports , f"{PINNED_IMPORTER} has no imports to stamp";
    stamped = [
        imp
        for imp in imports
        if imp.native_only_drop
    ];
    assert stamped , (
        "no import in a module that imports two natively pinned modules "
        "carries the verdict; an unstamped tree makes the emitter drop "
        "nothing, silently"
    );
}


test "the stamped verdict is the computation it replaced" {
    (prog, mod) = _compiled(PINNED_IMPORTER);
    for imp in mod.get_all_sub_nodes(uni.Import) {
        target = native_only_import_target(imp, prog);
        expected = target is not None
            and (os.sep + "jaclang" + os.sep) not in os.path.abspath(target);
        assert imp.native_only_drop == expected , (
            f"the stamp and the retired computation disagree for the "
            f"import at line {imp.loc.first_line}: stamped "
            f"{imp.native_only_drop}, computed {expected}"
        );
    }
}


test "the emitter unit no longer names the driver" {
    text = (
        PKG_PATH / "compiler" / "backends" / "py" / "impl" / "jcir_gen_pass.impl.jac"
    ).read_text(
        encoding="utf-8"
    );
    assert "self.prog" not in text , (
        "the JCIR emitter reaches for the compile driver again; a sealed "
        "pass cannot, and the driver-seam coverage forbids the name"
    );
    assert "native_only_import_target" not in text , (
        "the emitter resolves import placement itself again instead of "
        "consuming the stamped verdict"
    );
}
