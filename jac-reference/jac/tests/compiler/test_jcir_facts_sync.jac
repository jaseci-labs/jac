"""The JCIR emitter's baked facts match their sources of truth.

`jcir_facts.jac` bakes two name sets, one path predicate and the target
CPython version so the emitter and the container format can lower
natively instead of importing a Python module, scanning a stub file, or
reading `sys.version_info` at emit time. Baked data drifts silently, so
each fact is pinned against the thing it bakes: grow the runtime builtin
surface, the ambient typing stub, or the annex suffixes without
re-baking and this file fails naming the delta.

The version pin carries the weight `read_container` used to carry at
read time. The container stamps the CPython minor the build targets and
refuses a container stamped for another; that the build's target is the
interpreter actually running it is this file's job, and a mismatch fails
here instead of on the first container read.
"""

import os;
import sys;
import jaclang;
import jaclang.runtime.builtin as builtin_mod;
import from pathlib { Path }
import from jaclang.compiler.backends.py.codegen_ir { cir_python_version }
import from jaclang.compiler.frontend.constant { Tokens }
import from jaclang.jac0core.ext_registry { is_test }
import from jaclang.compiler.backends.py.jcir_gen_pass {
    TOKEN_CLS_BY_NAME,
    UNARY_CLS_BY_NAME
}
import from jaclang.compiler.backends.py.jcir_facts {
    JCIR_AMBIENT_TYPING_NAMES,
    JCIR_BUILTIN_NAMES,
    JCIR_PYTHON_MAJOR,
    JCIR_PYTHON_MINOR,
    jcir_is_test_path,
    jcir_python_version
}


test "the baked builtin surface matches runtime.builtin.__all__" {
    live = set(builtin_mod.__all__);
    baked = set(JCIR_BUILTIN_NAMES);
    assert baked == live , (
        f"jcir_facts.JCIR_BUILTIN_NAMES drifted from builtin.__all__: "
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
    baked = set(JCIR_AMBIENT_TYPING_NAMES);
    assert baked == live , (
        f"jcir_facts.JCIR_AMBIENT_TYPING_NAMES drifted from the stub: "
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
        assert jcir_is_test_path(path) == is_test(path) , (
            f"jcir_is_test_path diverges from ext_registry.is_test on " f"{path!r}"
        );
    }
}


test "the baked CPython target is the interpreter running this build" {
    assert (JCIR_PYTHON_MAJOR, JCIR_PYTHON_MINOR)
        == (sys.version_info.major, sys.version_info.minor) , (
        f"jcir_facts bakes Python {JCIR_PYTHON_MAJOR}.{JCIR_PYTHON_MINOR} but "
        f"this interpreter is {sys.version_info.major}."
        f"{sys.version_info.minor}. Every JCIR container this build writes "
        "would be stamped for the wrong minor -- re-bake the constants"
    );
}


test "the container version stamp is the baked target" {
    assert cir_python_version() == jcir_python_version() , (
        "codegen_ir.cir_python_version drifted from the baked fact; the "
        "container stamp and the reader's refusal must come from one source"
    );
    assert cir_python_version()
        == ((sys.version_info.major << 8) | sys.version_info.minor) , (
        "the container version stamp does not encode this interpreter's "
        "major/minor in the documented (major << 8) | minor form"
    );
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
