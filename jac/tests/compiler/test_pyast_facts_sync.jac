"""The Python code generator's baked facts match their sources of truth.

`pyast_facts.jac` bakes two name sets and one path predicate so the generator
can lower natively instead of importing a Python module or scanning a stub
file at emit time. Baked data drifts silently, so each fact is pinned against
the thing it bakes: grow the runtime builtin surface, the ambient typing stub,
or the annex suffixes without re-baking and this file fails naming the delta.
"""

import os;
import jaclang;
import jaclang.runtime.builtin as builtin_mod;
import from pathlib { Path }
import from jaclang.compiler.frontend.constant { Tokens }
import from jaclang.jac0core.ext_registry { is_test }
import from jaclang.compiler.backends.py.pyast_gen_pass {
    TOKEN_CLS_BY_NAME,
    UNARY_CLS_BY_NAME
}
import from jaclang.compiler.backends.py.pyast_facts {
    PYAST_AMBIENT_TYPING_NAMES,
    PYAST_BUILTIN_NAMES,
    pyast_is_test_path
}


test "the baked builtin surface matches runtime.builtin.__all__" {
    live = set(builtin_mod.__all__);
    baked = set(PYAST_BUILTIN_NAMES);
    assert baked == live , (
        f"pyast_facts.PYAST_BUILTIN_NAMES drifted from builtin.__all__: "
        f"missing {sorted(live - baked)}, stale {sorted(baked - live)} -- "
        "re-bake the frozenset"
    );
}


test "the baked ambient typing names match typing_ambient.pyi" {
    stub = Path(jaclang.__file__).parent / "compiler" / "types" / "typing_ambient.pyi";
    text = stub.read_text(encoding="utf-8");
    marker = text.find("__all__ =");
    open_b = text.find("[", marker);
    close_b = text.find("]", open_b);
    live: set[str] = set();
    for piece in text[open_b + 1:close_b].split(",") {
        `entry = piece.strip();
        if len(`entry) >= 2 and `entry[0] in "'\"" and `entry[-1] == `entry[0] {
            live.add(`entry[1:-1]);
        }
    }
    baked = set(PYAST_AMBIENT_TYPING_NAMES);
    assert baked == live , (
        f"pyast_facts.PYAST_AMBIENT_TYPING_NAMES drifted from the stub: "
        f"missing {sorted(live - baked)}, stale {sorted(baked - live)} -- "
        "re-bake the frozenset"
    );
}


test "the baked test-path predicate agrees with ext_registry" {
    for path in (
        "/a/foo.test.jac",
        "/a/foo.impl.jac",
        "/a/foo.jac",
        "foo.test.jac",
        "/a/foo.test.jac.bak"
    ) {
        assert pyast_is_test_path(path) == is_test(path) , (
            f"pyast_is_test_path diverges from ext_registry.is_test on " f"{path!r}"
        );
    }
}


test "every operator-map key is a real Tokens member name" {
    live = {member.name for member in Tokens};
    for (label, table) in (
        ("TOKEN_CLS_BY_NAME", TOKEN_CLS_BY_NAME),
        ("UNARY_CLS_BY_NAME", UNARY_CLS_BY_NAME)
    ) {
        unknown = sorted(set(table.keys()) - live);
        assert not unknown , (
            f"{label} keys on token names so the emitter never has to build "
            f"an enum member at emit time; these are not Tokens members: "
            f"{unknown}"
        );
    }
}
