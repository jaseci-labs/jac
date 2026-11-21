"""The cl -> na edge is decided by the target's own placement, not hub luck.

A client component that (transitively) reaches a native module through its
import chain is not itself native: importing it must stay a plain JS import
in every compile order. Previously the edge classifier walked
module_has_native_anchor recursively through whatever happened to be in the
program hub, so compiling the component first (as a route scanner does)
made a later importer see "native anchor" through component -> host ->
arena and bind the component as a wasm stub -- while a fresh program,
whose hub lacked the chain, classified the same import correctly. The
classifier now demands the target's decided placement and accepts only the
target's own in-body native evidence.
"""

import os;
import tempfile;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }

glob ARENA_SRC: str = (
         "def:pub tick(buf: own str) -> int {\n" "    return len(buf);\n" "}\n"
     ),
     HOST_SRC: str = (
         "import from .arena { tick }\n"
         "\n"
         "async def:pub crank -> int {\n"
         "    return await tick(\"spin\");\n"
         "}\n"
     ),
     COMP_SRC: str = (
         "import from .host { crank }\n"
         "\n"
         "def:pub Comp -> JsxElement {\n"
         "    return <div onClick={crank}>comp</div>;\n"
         "}\n"
     ),
     PAGE_SRC: str = (
         "import from .comp { Comp }\n"
         "\n"
         "def:pub Page -> JsxElement {\n"
         "    return <main><Comp/></main>;\n"
         "}\n"
     ),
     PINS: str = "[placement.pins]\nhost = \"client\"\n";

def write_fixture -> str {
    tmp = os.path.realpath(tempfile.mkdtemp(prefix="jac_na_decided_"));
    for (name, src) in {
        "arena.jac": ARENA_SRC,
        "host.jac": HOST_SRC,
        "comp.jac": COMP_SRC,
        "page.jac": PAGE_SRC,
        "jac.toml": PINS
    }.items() {
        with open(os.path.join(tmp, name), "w") as f {
            f.write(src);
        }
    }
    return tmp;
}

def na_targets(mod: uni.Module) -> list[str] {
    return sorted(
        {str(b.source_module) for b in mod.gen.interop_manifest.client_native_imports}
    );
}

test "a client component stays a plain import in every hub order" {
    tmp = write_fixture();
    prog = JacProgram();
    prog.compile(os.path.join(tmp, "arena.jac"));
    prog.compile(os.path.join(tmp, "host.jac"));
    prog.compile(os.path.join(tmp, "comp.jac"));
    page = prog.compile(os.path.join(tmp, "page.jac"));
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    js = page.gen.js;
    assert './comp.js' in js , "importer must take the plain JS import";
    assert '__na_bind("comp"' not in js , "a client component is not a wasm stub";
    targets = na_targets(page);
    assert not [
        t
        for t in targets
        if t.endswith("comp.jac")
    ] , f"component wrongly recorded as an na target: {targets}";
}

test "cold and warm compiles emit identical importer js" {
    tmp = write_fixture();
    cold_prog = JacProgram();
    cold = cold_prog.compile(os.path.join(tmp, "page.jac"));
    warm_prog = JacProgram();
    warm_prog.compile(os.path.join(tmp, "arena.jac"));
    warm_prog.compile(os.path.join(tmp, "host.jac"));
    warm_prog.compile(os.path.join(tmp, "comp.jac"));
    warm = warm_prog.compile(os.path.join(tmp, "page.jac"));
    assert cold.gen.js == warm.gen.js , (
        "importer emission must not depend on hub population order"
    );
}

test "the genuine na edge survives a warm hub" {
    tmp = write_fixture();
    prog = JacProgram();
    prog.compile(os.path.join(tmp, "arena.jac"));
    host = prog.compile(os.path.join(tmp, "host.jac"));
    js = host.gen.js;
    assert '__na_bind' in js , "native target must still bind the wasm stub";
    assert '"arena"' in js , "expected the arena stem in the bind call";
    targets = na_targets(host);
    assert len(targets) == 1 and targets[0].endswith("arena.jac") , (
        f"native import must drive wasm emission; got: {targets}"
    );
}
