"""The JacPython build checks its registered PyInit_* exports against the
compiled plan and merged module. native_api.jac contains no PyInit_* text:
archwire.jac wires each binding module into its compilation closure."""

import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from tests.support { JAC_ROOT }

"""Load the build's prepare_native.py without running its build."""
def _load_prepare -> any {
    import importlib.util;
    path = os.path.join(JAC_ROOT, "bootstrap", "python", "prepare_native.py");
    spec = importlib.util.spec_from_file_location("prepare_native_under_test", path);
    assert spec is not None;
    mod = importlib.util.module_from_spec(spec);
    loader = spec.loader;
    assert loader is not None;
    loader.exec_module(mod);
    return mod;
}

obj _Symbol {
    has is_declaration: bool;
}

obj _Merged {
    has defined: dict[str, bool];

    def get_function(name: str) -> _Symbol {
        if name not in self.defined {
            raise NameError(name);
        }
        return _Symbol(is_declaration=self.defined[name]);
    }
}

test "the registry names the PyInit_* exports and skips comments and blanks" {
    prepare = _load_prepare();
    with TemporaryDirectory() as tmp {
        tree = Path(tmp);
        registry = Path(
            os.path.join(tmp, "bootstrap", "python", "jacpython-modules.txt")
        );
        registry.parent.mkdir(parents=True);
        registry.write_text(
            "# one module per line\n"
                + "\n"
                + "_bisect test.test_bisect\n"
                + "math test.test_math\n"
        );
        assert prepare.registered_exports(tree) == ["PyInit__bisect", "PyInit_math"];
    }
}

test "a registered module absent from the compiled exports is reported" {
    prepare = _load_prepare();
    expected = ["PyInit__bisect", "PyInit_math"];
    assert prepare.missing_exports(expected, []) == expected;
    assert prepare.missing_exports(expected, ["PyInit_math"]) == ["PyInit__bisect"];
    assert prepare.missing_exports(expected, expected + ["PyInit_extra"]) == [];
}

test "a declared-only export is not accepted as a defined entry point" {
    prepare = _load_prepare();
    merged = _Merged(defined={"PyInit__bisect": False, "PyInit_math": True});
    assert prepare.undefined_exports(
        merged, ["PyInit__bisect", "PyInit_math", "PyInit__json"]
    )
        == ["PyInit_math", "PyInit__json"];
}

test "the registered PyInit_* exports are all reachable from native_api.jac" {
    # Compiles the real native_api.jac closure the build lowers and asserts the
    # exact contract prepare_native checks before emitting jacpython.o. Deleting
    # a binding wire from archwire.jac fails here, in the normal test suite,
    # instead of only in the native build. Runs the plan construction only: pure
    # Jac lowering, no LLVM shim and no CPython source tree needed.
    prepare = _load_prepare();
    built = prepare.native_plan(JAC_ROOT, "x86_64-unknown-linux-gnu");
    program = built[0];
    plan = built[1];
    assert not program.errors_had , [e.pretty_print() for e in program.errors_had];
    assert plan.units , "native_api.jac lowered to an empty plan";
    exports = plan.pub_exports();
    missing = prepare.missing_exports(
        prepare.registered_exports(Path(JAC_ROOT)), exports
    );
    assert not missing , (
        "native_api.jac does not export registered PyInit_* symbols: "
        + ", ".join(missing)
    );
    missing = prepare.missing_exports(prepare.STATIC_TYPE_EXPORTS, exports);
    assert not missing , (
        "native_api.jac does not define the static type objects the patched C"
        " static_types table references (wire their object_model units into"
        " this closure): "
        + ", ".join(missing)
    );
}
