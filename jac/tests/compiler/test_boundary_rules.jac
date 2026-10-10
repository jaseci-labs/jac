"""What crosses a codespace boundary is one rule, read off declared signatures.

Between native and Python code only the ctypes scalars cross. Between client
and server code a call is a request, so what crosses is what the request
binder can build from JSON and the response serializer can write: scalars,
containers of them, string-keyed dicts, enums, archetypes whose fields
cross, uploads as parameters and generators as streamed results."""

import os;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.boundary_rules { archetype_refusals, signature_refusals }
import from jaclang.compiler.capability_notes {
    TARGET_CLIENT,
    TARGET_NATIVE,
    TARGET_SERVER
}

glob WIRE_SRC = (
         "import from typing { Generator }\n\n"
         "enum Color { RED, BLUE }\n\n"
         "obj Item {\n"
         "    has name: str,\n"
         "        tags: list[str] = [],\n"
         "        shade: Color = Color.RED,\n"
         "        parent: Item | None = None;\n"
         "}\n\n"
         "obj Holder {\n"
         "    has label: str,\n"
         "        hook: Callable[[int], int];\n"
         "}\n\n"
         "walker Visit {\n"
         "    has start: Item,\n"
         "        seen: dict[int, str] = {};\n"
         "}\n\n"
         "def fine(a: int, b: list[Item], c: dict[str, float] | None) -> Item {\n"
         "    return Item(name=str(a));\n"
         "}\n\n"
         "def int_keys(m: dict[int, str]) -> None {}\n\n"
         "def callback(f: Callable[[int], int]) -> int {\n"
         "    return f(1);\n"
         "}\n\n"
         "def stream(n: int) -> Generator[Item, None, None] {\n"
         "    yield Item(name=str(n));\n"
         "}\n\n"
         "def drain(it: Iterator[str]) -> int {\n"
         "    return 0;\n"
         "}\n\n"
         "def holder -> Holder {\n"
         "    return Holder(label='x', hook=lambda (x: int) { x });\n"
         "}\n\n"
         "def scalar(x: int, y: float) -> int {\n"
         "    return x;\n"
         "}\n\n"
         "def listy(xs: list[int]) -> int {\n"
         "    return len(xs);\n"
         "}\n"
     );

def typed_module -> uni.Module {
    path = os.path.join(tempfile.mkdtemp(), "wire.jac");
    with open(path, "w", encoding="utf-8") as fh {
        fh.write(WIRE_SRC);
    }
    return JacProgram().compile(path, options=CompileOptions(no_cgen=True));
}

def function_named(mod: uni.Module, name: str) -> uni.Ability {
    for stmt in mod.body {
        if isinstance(stmt, uni.Ability) and stmt.sym_name == name {
            return stmt;
        }
    }
    raise KeyError(name);
}

def request_refusals(mod: uni.Module, name: str) -> list[tuple[str, str, str]] {
    return signature_refusals(function_named(mod, name), TARGET_CLIENT, TARGET_SERVER);
}

test "scalars, containers, enums and archetypes cross between client and server" {
    mod = typed_module();
    assert request_refusals(mod, "fine") == [];
    assert request_refusals(mod, "scalar") == [];
}

test "a dict crosses only with string keys" {
    found = request_refusals(typed_module(), "int_keys");
    assert len(found) == 1 , found;
    (what, spelled, why) = found[0];
    assert what == "parameter 'm'" and "string keys" in why , found;
}

test "behaviour does not cross: a callable has no wire form" {
    found = request_refusals(typed_module(), "callback");
    assert [what for (what, _spelled, _why) in found] == ["parameter 'f'"] , found;
}

test "a generator crosses as a streamed result and never as a parameter" {
    mod = typed_module();
    assert request_refusals(mod, "stream") == [];
    found = request_refusals(mod, "drain");
    assert len(found) == 1 and "streamed result" in found[0][2] , found;
}

test "an archetype crosses only when every field does" {
    found = request_refusals(typed_module(), "holder");
    assert len(found) == 1 , found;
    (what, spelled, why) = found[0];
    assert what == "the return" and spelled == "Holder" , found;
    assert "hook" in why , why;
}

test "a walker spawned from the client is judged by its fields" {
    mod = typed_module();
    spawned = [
        s
        for s in mod.body
        if isinstance(s, uni.Archetype) and s.sym_name == "Visit"
    ][0];
    found = archetype_refusals(spawned, TARGET_CLIENT, TARGET_SERVER);
    assert [what for (what, _spelled, _why) in found] == ["field 'seen'"] , found;
}

test "between native and Python code only the scalars cross" {
    mod = typed_module();
    scalar = function_named(mod, "scalar");
    assert signature_refusals(scalar, TARGET_NATIVE, TARGET_SERVER) == [];
    found = signature_refusals(
        function_named(mod, "listy"), TARGET_NATIVE, TARGET_SERVER
    );
    assert [what for (what, _spelled, _why) in found] == ["parameter 'xs'"] , found;
    assert signature_refusals(scalar, TARGET_SERVER, TARGET_SERVER) == [];
}
