"""A native unit holds a class from a module the build cannot lower as `any`.

The build session's own lowering verdict decides it, not the module's
placement: a dependency that lowers keeps its real native type even when it
is not a declared native unit, and one that produced no native interface is
erased, so the unit records no link edge to it and still links. A
dependency that fails to lower with errors of its own keeps them: they are
its failure, not its importer's.
"""
import os;
import sys;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.backends.native.kernel_resolve { kernel_options }
import from jaclang.compiler.backends.native.link_plan {
    ArtifactKind,
    build_link_plan,
    link_artifact
}

glob CONFIG: str = (
         "[project]\nname = \"erasure\"\nversion = \"0.1.0\"\n\n"
         "[placement.pins]\n\"pkg.hostreg\" = \"server\"\n"
     ),
     SOURCES: dict[str, str] = {
         "__init__.jac": "",
         "hostreg.jac": (
             "obj Registry {\n    has items: dict[str, int] = {};\n\n"
             "    def size -> int {\n        return len(self.items);\n    }\n}\n"
         ),
         "natbox.jac": (
             "import from .hostreg { Registry }\n\n"
             "obj Box {\n    has n: int = 0;\n\n"
             "    def pick(reg: Registry) -> Registry {\n        return reg;\n    }\n}\n"
         ),
         "hostlib.jac": (
             "import ctypes;\n\n"
             "obj Lib {\n    has handle: int = 0;\n\n"
             "    def width -> int {\n        return ctypes.sizeof(ctypes.c_int);\n    }\n}\n"
         ),
         "user.jac": (
             "import from .hostreg { Registry }\n"
             "import from .natbox { Box }\n"
             "import from .hostlib { Lib }\n\n"
             "obj Holder {\n    has reg: Registry;\n    has box: Box;\n"
             "    has count: int = 0;\n}\n\n"
             "def:pub keep(reg: Registry) -> Registry {\n"
             "    held = Holder(reg=reg, box=Box(n=1));\n    held.count += held.box.n;\n"
             "    return held.reg;\n}\n\n"
             "def:pub bump(n: int) -> int {\n    return n + 1;\n}\n\n"
             "def:pub hold(lib: Lib) -> Lib {\n    return lib;\n}\n\n"
             "def:pub through(box: Box, reg: Registry) -> Registry {\n"
             "    return box.pick(reg);\n}\n"
         )
     };

test "a class from a module that does not lower is held as any and the unit links" {
    with tempfile.TemporaryDirectory(prefix="jac-host-erasure-") as base {
        Path(base, "jac.toml").write_text(CONFIG);
        Path(base, "pkg").mkdir();
        for (name, text) in SOURCES.items() {
            Path(base, "pkg", name).write_text(text);
        }
        user = os.path.realpath(os.path.join(base, "pkg", "user.jac"));
        hostreg = os.path.realpath(os.path.join(base, "pkg", "hostreg.jac"));
        natbox = os.path.realpath(os.path.join(base, "pkg", "natbox.jac"));
        hostlib = os.path.realpath(os.path.join(base, "pkg", "hostlib.jac"));
        prog = JacProgram();
        plan = build_link_plan(prog, [user], kernel_options(), native_unit=True);
        failures = prog.native_units().failures;
        assert hostreg in failures , failures;
        assert "ctypes" in failures.get(hostlib, "") , failures;
        unit = plan.unit(user);
        assert unit is not None;
        deps = [os.path.realpath(dep) for dep in unit.iface.deps];
        assert hostreg not in deps and hostlib not in deps , deps;
        assert natbox in deps , deps;
        assert plan.unit(natbox) is not None;
        layout = unit.iface.layout;
        assert layout is not None;
        structs = layout.structs;
        keep = layout.functions["keep"];
        assert keep.param_types == ["JacVal"] , keep.param_types;
        assert keep.ret_type == "JacVal" , keep.ret_type;
        assert layout.functions["hold"].param_types == ["JacVal"];
        assert layout.functions["through"].ret_type == "JacVal";
        assert not unit.iface.demoted , unit.iface.demoted;
        holder = [
            struct
            for (name, struct) in structs.items()
            if name.startswith("Holder")
        ][0];
        fields = {field.name: field.llvm_type for field in holder.fields};
        assert fields["reg"] == "JacVal" , fields;
        assert fields["box"] != "JacVal" , fields;
        if sys.platform.startswith("linux") or sys.platform == "darwin" {
            suffix = ".dylib" if sys.platform == "darwin" else ".so";
            out = os.path.join(base, "libuser" + suffix);
            link_artifact(plan, out, ArtifactKind.SHARED);
            import ctypes;
            lib = ctypes.CDLL(out);
            lib.bump.restype = ctypes.c_int64;
            lib.bump.argtypes = [ctypes.c_int64];
            assert lib.bump(41) == 42;
        }
    }
}
