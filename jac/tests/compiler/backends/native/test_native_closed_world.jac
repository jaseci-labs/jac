"""#9782 step 1a: native calls into Python have a declared provider.

A native call to a server function lowers to an extern named by one
module-qualified symbol, `__jac_na_import_<provider unit>_<name>`, derived
from the module that defines the function. The boundary analysis records
that symbol on the binding, and every consumer reads it from there: the
emitter, the shared-library glue, the JIT callback registration, the
Python-side callback table and the sealed product record.

A native call to a server function that has no such provider is refused by
the native legality analysis (E5092 "call to Python function"), which
places the calling unit in Python, or fails the build when the module must
be native.
"""

import json;
import os;
import re;
import tempfile;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo { InteropContext }
import from jaclang.compiler.passes.placement_pass { build_native_legality }
import from tests.support {
    KernelFixture,
    diagnostics_text,
    error_codes,
    kernel_compile_file,
    kernel_compile_source,
    sv_run
}


"""Write a tiny multi-file project into a temp dir; return its path."""
def _write_mods(mods: dict[str, str]) -> str {
    tmp = tempfile.mkdtemp(prefix="jac_closed_world_");
    for (fname, src) in mods.items() {
        with open(os.path.join(tmp, fname), "w") as f {
            f.write(src);
        }
    }
    return tmp;
}


"""Compile `main.jac` of a project: ahead of time for the native codespace,
or with the JIT engine when `aot` is off."""
def _compile_main(tmp: str, aot: bool = True) -> tuple[JacProgram, any] {
    prog = JacProgram();
    options = CompileOptions(
        aot_mode=True, default_codespace='native', skip_native_engine=True
    )
        if aot
        else CompileOptions();
    mod = prog.compile(os.path.join(tmp, "main.jac"), options=options);
    assert not prog.errors_had , (
        f"main.jac must compile; errors: {[str(e) for e in prog.errors_had]}"
    );
    return (prog, mod);
}


test "import from os { getppid } is refused before it can reach libc" {
    # `os` is a bundled Jac module in native code, and it defines no
    # `getppid`, so the import itself is refused. The call never reaches the
    # interop path, and no bare `getppid` extern can resolve against libc.
    result = kernel_compile_source(
        "import from os { getppid }\n"
            + "def:pub pid -> i64 { return i64(getppid()); }\n",
        "closed_world_getppid.jac",
        CompileOptions(native_required=True)
    );
    msgs = diagnostics_text(result);
    assert "E1145" in error_codes(result) and "getppid" in msgs , (
        f"the import must be refused by name; got: {msgs[:300]}"
    );
    ir_text = "\n".join(unit.native_ir for unit in result.units);
    assert re.search(r'@"?getppid"?\(', ir_text) is None , (
        "no bare getppid extern may be declared"
    );
}


test "a native call to a server function with no provider is a legality refusal" {
    tmp = _write_mods(
        {
            "jac.toml": '[placement.pins]\nhelper = "server"\n',
            "helper.jac": "def:pub answer -> int {\n    return 42;\n}\n",
            "main.jac": (
                "import from helper { answer }\n\n"
                + "def:pub run -> int {\n"
                + "    return answer();\n"
                + "}\n"
            )
        }
    );
    (prog, mod) = _compile_main(tmp);
    binding = mod.gen.interop_manifest.bindings["answer"];
    assert binding.native_callable , "a pinned server function has a provider";
    def gate_refusals -> list[any] {
        found: list[any] = [];
        for refusals in build_native_legality(mod, prog).units.values() {
            for refusal in refusals {
                if refusal.kind == "call to Python function" {
                    found.append(refusal);
                }
            }
        }
        return found;
    }
    assert not gate_refusals() , "a declared provider must not be refused";
    native_callers = set(binding.callers);
    binding.callers = {InteropContext.SERVER};
    binding.provider_app = "billing";
    refused = gate_refusals();
    assert len(refused) == 1 , f"expected one refusal, got {refused}";
    assert refused[0].code == "E5092" and refused[0].name == "answer";
    assert "another application" in (refused[0].help or "") , refused[0].help;
    binding.callers = native_callers;
    binding.provider_app = "";
    binding.symbol = "";
    refused = gate_refusals();
    assert len(refused) == 1 and "nothing to link" in (refused[0].help or "") , (
        f"a binding with no provider symbol must be refused: {refused}"
    );
    assert "#9782" not in (refused[0].help or "");
}


test "bare and aliased spellings resolve to one interop symbol" {
    # `import helper` itself is refused earlier on the native pathway (a
    # module object cannot cross the boundary), so the spellings that reach
    # the emit are the bare and aliased `from` forms of one export -- and
    # they must emit a single qualified extern.
    tmp = _write_mods(
        {
            "jac.toml": '[placement.pins]\nhelper = "server"\n',
            "helper.jac": "def:pub answer -> int {\n    return 42;\n}\n",
            "main.jac": (
                "import from helper { answer }\n"
                + "import from helper { answer as ans }\n\n"
                + "def:pub two_ways -> int {\n"
                + "    return answer() + ans();\n"
                + "}\n"
            )
        }
    );
    result = kernel_compile_file(
        os.path.join(tmp, "main.jac"),
        CompileOptions(aot_mode=True, default_codespace='native', skip_native_engine=True)
    );
    assert result.ok() , diagnostics_text(result);
    unit = result.unit(os.path.join(tmp, "main.jac"));
    ir_text = unit.native_ir;
    assert ir_text , "main.jac must lower for the native codespace";
    bindings = json.loads(unit.interop)["bindings"];
    symbol = bindings["answer"]["symbol"];
    assert symbol.startswith("__jac_na_import_helper_") , symbol;
    assert bindings["ans"]["symbol"] == symbol , "an alias names the same function";
    decls = re.findall(r"declare [^\n]*@\"?(__jac_na_import_\w+)", ir_text);
    assert len(decls) == 1 , f"bare/aliased spellings must emit one extern, got {decls}";
    assert decls[0] == symbol , f"the extern must be the binding's symbol, got {decls[0]}";
    for bare in ("answer", "ans") {
        assert re.search(r'@"?' + bare + r'"?\(', ir_text) is None , (
            f"no bare-name extern '{bare}' may survive"
        );
    }
}


test "one name imported from two modules dispatches to each module's function" {
    tmp = _write_mods(
        {
            "jac.toml": (
                '[placement.pins]\nhelper_a = "server"\nhelper_b = "server"\n'
                + '"main.both" = "native"\n'
            ),
            "helper_a.jac": "def:pub f -> int {\n    return 1;\n}\n",
            "helper_b.jac": "def:pub f -> int {\n    return 2;\n}\n",
            "main.jac": (
                "import from helper_a { f }\n"
                + "import from helper_b { f as g }\n\n"
                + "def:pub both -> int {\n"
                + "    return f() * 10 + g();\n"
                + "}\n\n"
                + "with entry {\n"
                + "    print(both());\n"
                + "}\n"
            )
        }
    );
    (out, _err) = sv_run(os.path.join(tmp, "main.jac"));
    assert out.split() == ["12"] , f"each import must call its own module's function: {out}";
}


test "a native function calls a server function declared after it" {
    tmp = _write_mods(
        {
            "jac.toml": (
                '[placement.pins]\n"main.run" = "native"\n"main.later" = "server"\n'
            ),
            "main.jac": (
                "def:pub run -> int {\n"
                + "    return later() + 1;\n"
                + "}\n\n"
                + "def later -> int {\n"
                + "    return 41;\n"
                + "}\n\n"
                + "with entry {\n"
                + "    print(run());\n"
                + "}\n"
            )
        }
    );
    (out, _err) = sv_run(os.path.join(tmp, "main.jac"));
    assert out.split() == ["42"] , f"a later server function must still get a provider: {out}";
}


test "a native element of a mixed module calls a server function it imports" {
    # `pickle` keeps `pack` on the server, so the module is mixed: the import
    # of `f` is placed in Python and only `both` is pinned native. The call
    # from `both` must still be recorded as a native call with a provider.
    tmp = _write_mods(
        {
            "jac.toml": (
                '[placement.pins]\nhelper = "server"\n"main.both" = "native"\n'
            ),
            "helper.jac": "def:pub f -> int {\n    return 7;\n}\n",
            "main.jac": (
                "import pickle;\n"
                + "import from helper { f }\n\n"
                + "def both -> int {\n"
                + "    return f() * 10;\n"
                + "}\n\n"
                + "def pack -> bytes {\n"
                + "    return pickle.dumps([f(), both()]);\n"
                + "}\n"
            )
        }
    );
    path = os.path.join(tmp, "main.jac");
    result = kernel_compile_file(path, CompileOptions(), ["bytecode", "mir"]);
    assert result.ok() , diagnostics_text(result);
    fx = KernelFixture(path=path, result=result, unit=result.unit(path));
    assert fx.iface() is not None and "both" in fx.iface().exports , (
        f"both must stay native: {fx.demoted()}"
    );
    assert not fx.is_demoted("both") , f"the native call to f must have a provider: {fx.reason('both')}";
    binding = json.loads(fx.unit.interop)["bindings"].get("f");
    assert binding is not None and binding["symbol"] , (
        f"the native call to f must have a provider: {binding}"
    );
}
