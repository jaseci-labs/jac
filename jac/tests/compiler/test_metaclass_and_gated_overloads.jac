"""A class object exposes its real metaclass, and version-gated overloads count.

A class is an instance of its metaclass, so attribute lookup on a class object
falls back to that metaclass. The fallback was hardcoded to `type`, so members
a real metaclass adds -- `EnumMeta.__members__` being the common one -- were
invisible on every class that had one.

Separately, typeshed splits overload sets across `if sys.version_info` guards.
Member lookup returned as soon as it found the name in the class body, so the
gated half of an overload set was never collected. Only genuine @overload
declarations merge across a guard: version-gated `__new__`/`__init__` pairs
are alternatives, not additions, and merging those would break construction.
"""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="meta.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "a class object exposes members its metaclass declares" {
    src = "import enum;\n"
        + "class Color(enum.Enum) {\n"
        + "    RED = 1;\n"
        + "}\n"
        + "def probe -> None {\n"
        + "    assert Color.__members__ is not None;\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"metaclass member invisible on class object: {errs}";
}

test "version-gated alternatives do not merge into an overload set" {
    src = "import from pathlib { Path }\n"
        + "def probe(base: str) -> Path {\n"
        + "    return Path(base) / 'sub';\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"gated constructor alternatives broke construction: {errs}";
}

test "a local member does not evaluate shadowed conditional alternatives" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from unittest.mock { patch }
    import from jaclang.compiler.frontend.unitree { Archetype }
    import from jaclang.compiler.types.type_utils { collect_member_syms }
    with TemporaryDirectory() as td {
        source = Path(td) / "members.pyi";
        source.write_text(
            "import sys\nclass Box:\n    value: int\n"
            "    if sys.version_info >= (3, 0):\n        value: str\n"
        );
        module = JacProgram().load_dependency_module(str(source));
        assert module is not None;
        scope = module.get_all_sub_nodes(Archetype)[0];
        local = scope.lookup("value", deep=False);
        assert local is not None;
        with patch(
            "jaclang.compiler.frontend.helpers.evaluate_version_condition"
        ) as evaluate {
            assert collect_member_syms(scope, "value") == [local];
            evaluate.assert_not_called();
        }
    }
}


test "a local overload still merges a live conditional overload" {
    import from pathlib { Path }
    import from tempfile { TemporaryDirectory }
    import from jaclang.compiler.frontend.unitree { Archetype }
    import from jaclang.compiler.types.type_utils { collect_member_syms }
    with TemporaryDirectory() as td {
        source = Path(td) / "overloads.pyi";
        source.write_text(
            "import sys\nfrom typing import overload\nclass Box:\n"
            "    @overload\n    def value(self, arg: int) -> int: ...\n"
            "    if sys.version_info >= (3, 0):\n"
            "        @overload\n        def value(self, arg: str) -> str: ...\n"
        );
        module = JacProgram().load_dependency_module(str(source));
        assert module is not None;
        scope = module.get_all_sub_nodes(Archetype)[0];
        assert len(collect_member_syms(scope, "value")) == 2;
    }
}
