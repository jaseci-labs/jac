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
    has defined: dict[str, bool],
        globals: dict[str, bool] = {};

    def get_function(name: str) -> _Symbol {
        if name not in self.defined {
            raise NameError(name);
        }
        return _Symbol(is_declaration=self.defined[name]);
    }

    def get_global_variable(name: str) -> _Symbol {
        if name not in self.globals {
            raise NameError(name);
        }
        return _Symbol(is_declaration=self.globals[name]);
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

test "the static type exports are validated as globals, not functions" {
    # object.c's static_types table refers to these as global objects. Checking
    # them with get_function() rejects a correct build, so the lookup kind has to
    # follow how each symbol is emitted.
    prepare = _load_prepare();
    merged = _Merged(
        defined={"PyInit__bisect": True},
        globals={"PyRange_Type": False, "PyCell_Type": True}
    );
    assert prepare.undefined_exports(
        merged, ["PyRange_Type", "PyCell_Type", "_PyTemplate_Type"], "global"
    )
        == ["PyCell_Type", "_PyTemplate_Type"];
    # A function of the same name does not satisfy the global contract.
    assert prepare.undefined_exports(merged, ["PyInit__bisect"], "global")
        == ["PyInit__bisect"];
}

test "the export contract checks registered modules and static type globals" {
    # The JacPython build compiles the inittab and runtime roots together, then
    # checks the merged module before and after optimization. Keep the reusable
    # contract helpers importable so this test can check both symbol classes.
    prepare = _load_prepare();
    expected = prepare.registered_exports(Path(JAC_ROOT));
    assert expected;
    assert prepare.missing_exports(expected, expected) == [];
    assert prepare.missing_exports(expected + prepare.STATIC_TYPE_EXPORTS, expected)
        == prepare.STATIC_TYPE_EXPORTS;

    merged = _Merged(
        defined={name: False for name in expected},
        globals={name: False for name in prepare.STATIC_TYPE_EXPORTS}
    );
    assert prepare.undefined_exports(merged, expected) == [];
    assert prepare.undefined_exports(merged, prepare.STATIC_TYPE_EXPORTS, "global")
        == [];
}
