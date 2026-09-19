"""The jac0 seed tier and the full compiler agree on the object-spatial subset.

`jaclang/jac0.py` lowers node/edge/walker declarations, `+>:T:+>`, `[x ->:T:->]`,
`spawn`, `visit`, `disengage`, `del` and `can f with T entry|exit` onto
`jaclang.jac0core.osp0`, which reaches the same runtime statics the full
compiler's codegen targets. This fixture exercises every construct in that
subset under both compilers and compares what they compute.
"""

import os;
import sys;
import types;
import from jaclang.jac0 { compile_jac }
import from tests.compiler.fixtures.jac0_osp_subset { run as full_run }


def _jac0_run -> tuple[int, list[str], int, int, int, int, int] {
    path = os.path.join(os.path.dirname(__file__), "fixtures", "jac0_osp_subset.jac");
    with open(path, encoding="utf-8") as f {
        src = f.read();
    }
    py = compile_jac(src, path);
    mod = types.ModuleType("jac0_osp_subset_seed");
    mod.__file__ = path;
    sys.modules[mod.__name__] = mod;
    try {
        exec(compile(py, path, "exec"), mod.__dict__);
        return mod.run();
    } finally {
        sys.modules.pop(mod.__name__, None);
    }
}


test "jac0 lowers the object-spatial seed subset to the full compiler's semantics" {
    expected = (
        6,
        ["enter:top", "enter:a", "enter:b", "exit:b", "exit:a", "exit:top", "done"],
        2,
        1,
        2,
        2,
        1,

    );
    assert full_run() == expected;
    assert _jac0_run() == expected;
}


test "jac0 refuses object-spatial forms outside the seed subset" {
    for src in [
        "def f(a: any, b: any, c: any) { a ++> b ++> c; }",
        "def f(a: any) -> list[any] { return [a ->:T:-> (?x == 1)]; }",

    ] {
        failed = False;
        try {
            compile_jac(src, "probe.jac");
        } except Exception {
            failed = True;
        }
        assert failed , src;
    }
}

test "jac0 type filters preserve order and avoid capturing a type name" {
    src = "def select(items: list, _jac_seed_filter_item: type) -> list {\n"
        + "    return items[?:_jac_seed_filter_item];\n}\n"
        + "def chained(items: list) -> list { return items[?:int][?:int]; }\n";
    generated = compile_jac(src, "seed_type_filter.jac");
    namespace: dict[str, any] = {};
    exec(compile(generated, "seed_type_filter.jac", "exec"), namespace);
    assert namespace["select"]([1, "x", 2, "y"], str) == ["x", "y"];
    assert namespace["chained"]([1, "x", 2]) == [1, 2];
}

test "jac0 erases edge endpoint annotations without evaluating their types" {
    plain = compile_jac("edge Link: any --> any {}", "endpoints.jac");
    typed = compile_jac("edge Link: Source --> Target {}", "endpoints.jac");
    assert plain == typed;
}

test "jac0 erases casts without loading their annotations" {
    src = "def select(value: any) -> any {\n"
    " return (value) as list[Missing | None];\n}\n"
    "def optional(value: any) -> any { return value as (Missing | None); }\n"
    "def chained(value: any) -> any { return value as Missing as Other; }\n"
    "def nested(value: any) -> any { return [(value as Missing), value as Other]; }\n";
    namespace: dict[str, any] = {};
    exec(
        compile(compile_jac(src, "seed_cast.jac"), "seed_cast.jac", "exec"), namespace
    );
    value = [1, 2];
    for name in ["select", "optional", "chained"] {
        assert namespace[name](value) is value;
    }
    assert namespace["nested"](value) == [value, value];
}

test "jac0 casts do not erase context manager or exception aliases" {
    src = "import from contextlib { nullcontext }\n"
    "def probe -> str {\n"
    " with nullcontext('kept') as value {\n"
    "  try { raise ValueError(value); }\n"
    "  except ValueError as err { return str(err); }\n"
    " }\n return '';\n}\n";
    namespace: dict[str, any] = {};
    exec(
        compile(compile_jac(src, "seed_alias.jac"), "seed_alias.jac", "exec"), namespace
    );
    assert namespace["probe"]() == "kept";
}
