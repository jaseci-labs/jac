"""Placement evidence semantics: PERSIST on graph archetypes requires
actual persistence evidence (root access in the defining module), and
imports of jaclang-internal .jac modules pin server.

Without the first rule, every node/edge/walker archetype anchored server
unconditionally and beat explicit client pins, making in-browser OSP
object models unreachable in real projects. Without the second, a def:pub
whose module imports compiler internals was dual-emitted into the client
bundle, where the internal import is a ReferenceError at call time."""

import os;
import shutil;
import tempfile;
import from jaclang.jac0core.program { JacProgram }

def _proj(files: dict, pins: str = "") -> str {
    d = tempfile.mkdtemp(prefix="jacplace_");
    toml = "[project]\nname = \"t\"\nentry-point = \"main.jac\"\n";
    if pins != "" {
        toml += "\n[placement.pins]\n" + pins + "\n";
    }
    with open(os.path.join(d, "jac.toml"), "w") as f {
        f.write(toml);
    }
    for (name, content) in files.items() {
        path = os.path.join(d, name);
        os.makedirs(os.path.dirname(path), exist_ok=True);
        with open(path, "w") as f {
            f.write(content);
        }
    }
    return d;
}

test "rootless graph archetypes follow a client pin" {
    d = _proj(
        {
            "model.jac": (
                "node Block {\n    has opcode: str = \"\";\n}\n"
                + "edge NextOf {}\n"
                + "def make_pair() -> Block {\n"
                + "    a = Block(opcode=\"a\");\n"
                + "    b = Block(opcode=\"b\");\n"
                + "    a +>:NextOf():+> b;\n"
                + "    return a;\n"
                + "}\n"
            )
        },
        pins='"model.*" = "client"'
    );
    try {
        prog = JacProgram();
        mod = prog.compile(os.path.join(d, "model.jac"));
        js = mod.gen.js;
        assert "class Block" in js , f"rootless pinned archetype missing from client bundle: {js[0:400]}";
        msgs = " ".join([str(e) for e in prog.errors_had]);
        assert "E5082" not in msgs and "no client-side presence" not in msgs , msgs;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "root-using archetypes keep the server anchor" {
    d = _proj(
        {
            "store.jac": (
                "node Doc {\n    has label: str = \"\";\n}\n"
                + "def:pub save_doc() -> None {\n"
                + "    root ++> Doc(label=\"x\");\n"
                + "}\n"
            )
        }
    );
    try {
        prog = JacProgram();
        mod = prog.compile(os.path.join(d, "store.jac"));
        found = "";
        for el in mod.body {
            if type(el).__name__ == "Archetype" {
                found = str(el.code_context);
            }
        }
        assert "server" in found , f"persisted archetype should anchor server, got {found}";
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "jaclang-internal imports pin the importing element server" {
    d = _proj(
        {
            "bridge.jac": (
                "import from jaclang.cli.console { console }\n"
                + "def:pub check_src(src: str) -> str {\n"
                + "    console.print(src);\n"
                + "    return src;\n"
                + "}\n"
            ),
            "main.jac": (
                "import from .bridge { check_src }\n"
                + "def:pub app -> JsxElement {\n"
                + "    <button onClick={lambda { check_src(\"x\"); }}>go</button>;\n"
                + "}\n"
            )
        }
    );
    try {
        prog = JacProgram();
        mod = prog.compile(os.path.join(d, "main.jac"));
        js = mod.gen.js;
        assert 'from "./bridge.js"' not in js , f"jaclang-importing module dual-emitted into the client bundle: {js[0:400]}";
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "unpinned rootless archetypes pull into client closures" {
    d = _proj(
        {
            "model.jac": (
                "node Block {\n    has opcode: str = \"\";\n}\n"
                + "def make_block(op: str) -> Block {\n"
                + "    return Block(opcode=op);\n"
                + "}\n"
            ),
            "main.jac": (
                "import from .model { Block, make_block }\n"
                + "def:pub app -> JsxElement {\n"
                + "    has items: list = [];\n"
                + "    <button onClick={lambda { items = items + [make_block(\"x\")]; }}>\n"
                + "        add\n"
                + "    </button>;\n"
                + "}\n"
            )
        }
    );
    try {
        prog = JacProgram();
        mod = prog.compile(os.path.join(d, "main.jac"));
        msgs = " ".join([str(e) for e in prog.errors_had]);
        assert "no client-side presence" not in msgs , f"rootless archetype closure should pull client, got: {msgs[0:500]}";
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

# Edge disconnect (`a del --> b`) lowers natively now (osp_disconn_between),
# so it no longer blocks native placement; inline ::py:: remains the
# statically-known native-incompatible construct.
test "solver does not propose native for capability-violating modules" {
    import from jaclang.jac0core.placement_solver { native_default_verdict }
    d = _proj(
        {
            "pymod.jac": (
                "def f -> int {\n"
                + "    ::py::\n"
                + "x = 1\n"
                + "::py::\n"
                + "    return 1;\n"
                + "}\n"
            )
        }
    );
    try {
        prog = JacProgram();
        mod = prog.compile(os.path.join(d, "pymod.jac"), no_cgen=True);
        (ok, reason) = native_default_verdict(mod);
        assert not ok , "capability-violating module must not prefer native";
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}
