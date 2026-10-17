"""archwire.jac wiring: wires generate imports, an archwire.jac closes the directory it
sits in, rules restrict flows, and the file is the single source of truth for
every import relationship below it.

Each test writes a small project under a fresh temp dir with a jac.toml, an
archwire.jac and a few modules, compiles one module through JacProgram and reads
the diagnostic codes back. The wiring spec is content-keyed per project root,
so every test gets its own root.
"""

import os;
import shutil;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.parser.frontend { parse }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.frontend.unitree { ModuleItem }
import from jaclang.cli.commands.architecture { _arch_init, _arch_sync }

glob _UTIL: str = "def now -> str {\n    return \"t\";\n}\n",
     _OTHER: str = "def helper -> int {\n    return 1;\n}\n",
     _SVC: str = "def serve -> str {\n    return now();\n}\n",
     _MAIN: str = (
         "def greet -> str {\n"
         "    return serve() + when();\n"
         "}\n"
         "\n"
         "with entry {\n"
         "    print(greet());\n"
         "}\n"
     ),
     _ARCH: str = (
         "graph import {\n"
         "    edge AppInternal: app.* --> app.*;\n"
         "    edge AppOverCore: core.* --> app.*;\n"
         "    edge CoreInternal: core.* --> core.*;\n"
         "\n"
         "    core.svc ++> app.main { serve }\n"
         "    core.util ++> app.main { now as when }\n"
         "}\n"
         "\n"
         "graph import core {\n"
         "    util ++> svc { now }\n"
         "}\n"
     );


def _project(files: dict[str, str], toml_extra: str = "") -> str {
    base = tempfile.mkdtemp(prefix="jac_wiring_");
    with open(os.path.join(base, "jac.toml"), "w") as f {
        f.write("[project]\nname = \"wired\"\n" + toml_extra);
    }
    for (rel, text) in files.items() {
        path = os.path.join(base, rel);
        os.makedirs(os.path.dirname(path), exist_ok=True);
        with open(path, "w") as f {
            f.write(text);
        }
    }
    return base;
}


def _standard(arch: str = _ARCH, svc: str = _SVC, main: str = _MAIN) -> str {
    return _project(
        {
            "archwire.jac": arch,
            "core/util.jac": _UTIL,
            "core/other.jac": _OTHER,
            "core/svc.jac": svc,
            "app/main.jac": main
        }
    );
}


def _write(base: str, rel: str, text: str) {
    path = os.path.join(base, rel);
    os.makedirs(os.path.dirname(path), exist_ok=True);
    with open(path, "w") as f {
        f.write(text);
    }
}


def _read(base: str, rel: str) -> str {
    with open(os.path.join(base, rel)) as f {
        return f.read();
    }
}


def _compile(base: str, rel: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(os.path.join(base, rel), options=CompileOptions(no_cgen=True));
    return prog;
}


def _errors(prog: JacProgram) -> list[str] {
    return [
        e.code.code
        for e in prog.errors_had
        if e.code is not None
    ];
}


def _warnings(prog: JacProgram) -> list[str] {
    return [
        w.code.code
        for w in prog.warnings_had
        if w.code is not None
    ];
}


def _formatted(base: str, rel: str) -> str {
    prog = JacProgram.jac_file_formatter(os.path.join(base, rel));
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    return prog.mod.main.gen.jac;
}


test "wires generate the consumer's imports and a scoped block is relative on both sides" {
    base = _standard();
    try {
        prog = _compile(base, "app/main.jac");
        assert _errors(prog) == [] , _errors(prog);
        assert "W2001" not in _warnings(prog) , _warnings(prog);
        assert "W1051" not in _warnings(prog) , _warnings(prog);
        svc = _compile(base, "core/svc.jac");
        assert _errors(svc) == [] , _errors(svc);
        assert "W2001" not in _warnings(svc) , _warnings(svc);
        arch = _compile(base, "archwire.jac");
        assert _errors(arch) == [] , _errors(arch);
        assert "W1051" not in _warnings(arch) , _warnings(arch);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a wire-bound name resolves to the provider's declaration" {
    import from jaclang.compiler.frontend.unitree { Archetype, FuncCall, Module, Name }
    base = _project(
        {
            "archwire.jac": (
                "graph import {\n"
                "    edge CoreInternal: core.* --> core.*;\n"
                "}\n"
                "\n"
                "graph import core {\n"
                "    util ++> svc { Spark }\n"
                "}\n"
            ),
            "core/util.jac": "obj Spark {\n    has x: int = 0;\n}\n",
            "core/svc.jac": ("def serve -> int {\n" "    return Spark(x=1).x;\n" "}\n")
        }
    );
    try {
        prog = JacProgram();
        mod = prog.compile(
            os.path.join(base, "core/svc.jac"), options=CompileOptions(no_cgen=True)
        );
        assert _errors(prog) == [] , _errors(prog);
        assert isinstance(mod, Module);
        uses = [
            call.target
            for call in mod.get_all_sub_nodes(FuncCall)
            if isinstance(call.target, Name) and call.target.sym_name == "Spark"
        ];
        assert len(uses) == 1 , uses;
        sym = uses[0].sym;
        assert sym is not None;
        assert sym.parent_tab is not None and sym.parent_tab.scope_name == "util" , (
            sym.parent_tab.scope_name if sym.parent_tab else None
        );
        assert sym.decl is not None
            and sym.decl.find_parent_of_type(Archetype) is not None , sym.decl;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a covered module's own imports are matched item by item" {
    base = _standard(
        svc=(
            "import from core.util { now }\n"
            "import from core.other { helper }\n"
            "import os;\n"
            "\n"
            "def serve -> str {\n"
            "    return now() + str(helper()) + os.sep;\n"
            "}\n"
        )
    );
    try {
        prog = _compile(base, "core/svc.jac");
        assert _errors(prog) == ["E1144", "E1144"] , _errors(prog);
        shown = [
            str(e.pretty_print())
            for e in prog.errors_had
            if e.code and e.code.code == "E1144"
        ];
        assert "already injects it" in shown[0] , shown[0];
        assert "other ++> svc { helper }" in shown[1] , shown[1];
        assert "graph import core" in shown[1] , shown[1];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a module archwire.jac never names is still sealed and still ruled" {
    base = _standard();
    try {
        _write(
            base,
            "extra/rogue.jac",
            "import from app.main { greet }\n\ndef x -> str {\n    return greet();\n}\n"
        );
        prog = _compile(base, "extra/rogue.jac");
        assert sorted(_errors(prog)) == ["E1144", "E2090"] , _errors(prog);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a payload rule admits only the names it lists" {
    arch = (
        "graph import {\n"
        "    edge CoreApi: core.* --> app.* { now }\n"
        "\n"
        "    core.util ++> app.main { now as when, serve }\n"
        "}\n"
    );
    base = _standard(
        arch=arch, main="def greet -> str {\n    return when() + serve();\n}\n"
    );
    try {
        _write(
            base,
            "core/util.jac",
            _UTIL + "\ndef serve -> str {\n    return now();\n}\n"
        );
        prog = _compile(base, "archwire.jac");
        assert _errors(prog) == ["E2091"] , _errors(prog);
        _write(
            base,
            "app/main.jac",
            "import core.util;\n\ndef greet -> str {\n    return when() + serve();\n}\n"
        );
        prog2 = _compile(base, "app/main.jac");
        assert "E2091" in _errors(prog2) , _errors(prog2);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "archwire.jac itself is checked for its scope, endpoints and rules" {
    arch = (
        "graph import {\n"
        "    edge Dead: core.missing --> app.*;\n"
        "    edge Dup: core.* --> app.*;\n"
        "    edge Dup: app.* --> app.*;\n"
        "\n"
        "    core.util ++> core;\n"
        "    core.util ++> core.absent { now }\n"
        "    core.util ++> core.util;\n"
        "    gone ++> core.absent { now }\n"
        "    os ++> core.svc;\n"
        "}\n"
        "\n"
        "graph import nowhere {\n"
        "    thing ++> svc { x }\n"
        "}\n"
    );
    base = _standard(arch=arch);
    try {
        prog = _compile(base, "archwire.jac");
        codes = sorted(_errors(prog));
        assert codes
            == [
                "E1141",
                "E1141",
                "E1141",
                "E1142",
                "E1143",
                "E2092",
                "E2097",
                "E2097",
                "E2097",
                "E2097",
                "E2098"
            ] , codes;
        assert "W2083" not in _warnings(prog) , _warnings(prog);
        assert "W2084" not in _warnings(prog) , _warnings(prog);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "wiring aimed at modules that do not exist is an error" {
    base = _standard(arch=_ARCH + "\ngraph import vanished {\n    x ++> y { z }\n}\n");
    try {
        arch = _compile(base, "archwire.jac");
        assert sorted(_errors(arch)) == ["E1141", "E2097", "E2097"] , _errors(arch);
        assert _errors(_compile(base, "app/main.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "wiring blocks belong in archwire.jac and nothing else belongs there" {
    base = _standard(
        arch=_ARCH + "\nimport os;\n\nglob X: int = 1;\n",
        svc="graph import {\n    core.util ++> core.svc { now }\n}\n\n" + _SVC
    );
    try {
        arch = _compile(base, "archwire.jac");
        assert sorted(_errors(arch)) == ["E2089", "E2089"] , _errors(arch);
        svc = _compile(base, "core/svc.jac");
        assert "E2088" in _errors(svc) , _errors(svc);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "archwire.jac holds facts only, so a comment or docstring is an error" {
    base = _standard(
        arch="\"\"\"The wiring.\"\"\"\n\n# core first\n"
            + _ARCH.replace(
                "    util ++> svc { now }\n", "    util ++> svc { now }  # the clock\n"
            )
    );
    try {
        arch = _compile(base, "archwire.jac");
        assert sorted(_errors(arch)) == ["E2089", "E2089", "E2089"] , _errors(arch);
        assert _errors(_compile(base, "app/main.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "wiring syntax has its own diagnostics" {
    cases = [
        ("graph import { a <-- b { x } }", "E0086"),
        ("graph import { a | b ++> c { x } }", "E0087"),
        ("graph import { any ++> c { x } }", "E0087"),
        ("graph import { a ++> b.* { x } }", "E0088"),
        ("graph import { a as p ++> b { x } }", "E0089"),
        ("graph import { a ++> b { x, x } }", "E0090"),
        ("graph import { include a ++> b { x } }", "E0091"),
        ("graph import { edge a.* --> b.*; }", "E0092"),
        ("graph import \"pkg\" { a ++> b { x } }", "E0093"),
        ("graph import { 42; }", "E0094"),
        ("graph import { a ++> b { *, x } }", "E0095"),
        ("graph import { edge R: a.* --> b.* { x as y } }", "E0096"),
        ("graph import { edge R: a.* --> any; }", "E0098"),
        ("impl import { a ++> b { x } }", "E0099"),

    ];
    for (src, code) in cases {
        prog = JacProgram();
        parse(src, "archwire.jac", prog=prog);
        assert code in _errors(prog) , (src, _errors(prog));
    }
}


test "a broken archwire.jac still applies the wires that parsed and says so" {
    base = _standard(arch=_ARCH + "\ngraph import {\n    a <-- b;\n}\n");
    try {
        prog = _compile(base, "app/main.jac");
        assert _errors(prog) == ["E2093"] , _errors(prog);
        assert "W2001" not in _warnings(prog) , _warnings(prog);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "lint autofix removes wired imports" {
    base = _standard(
        svc="import from core.util { now }\nimport from core.other { helper }\n\n"
            + _SVC
    );
    try {
        fixed = JacProgram.jac_file_formatter(
            os.path.join(base, "core", "svc.jac"), auto_lint=True
        );
        text = fixed.mod.main.gen.jac;
        assert "import from core.util" not in text , text;
        assert "import from core.other { helper }" in text , text;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "jac fmt renders archwire.jac in its one canonical layout" {
    messy = (
        "graph import {\n"
        "    core.util ++> core.svc { now }\n"
        "    core.svc ++> app.main { serve }\n"
        "    core.svc ++> app.main { serve }\n"
        "}\n"
        "\n"
        "graph import core {\n"
        "    edge CoreInternal: * --> *;\n"
        "    util ++> other { now }\n"
        "}\n"
        "\n"
        "graph import {\n"
        "    edge AppOverCore: core.* --> app.*;\n"
        "    core.util ++> app.main { now as when }\n"
        "    core.util ++> app.main { serve as serve_now }\n"
        "}\n"
    );
    canonical = (
        "graph import {\n"
        "    edge AppOverCore: core.* --> app.*;\n"
        "    edge CoreInternal: core.* --> core.*;\n"
        "\n"
        "    core.svc ++> app.main { serve }\n"
        "    core.util ++> app.main { now as when, serve as serve_now }\n"
        "}\n"
        "\n"
        "graph import core {\n"
        "    util ++> other | svc { now }\n"
        "}\n"
    );
    base = _standard(arch=messy);
    try {
        first = _formatted(base, "archwire.jac");
        assert first == canonical , first;
        _write(base, "archwire.jac", first);
        assert _formatted(base, "archwire.jac") == canonical;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a provider feeding consumers different names is written once, as a list" {
    base = _standard(
        arch=(
            "graph import {\n"
            "    core.util ++> core.svc { now }\n"
            "    core.util ++> core.other { now as clock }\n"
            "    core.util ++> core.svc { later }\n"
            "}\n"
        )
    );
    try {
        _write(
            base,
            "core/util.jac",
            _UTIL + "\ndef later -> str {\n    return now();\n}\n"
        );
        text = _formatted(base, "archwire.jac");
        assert text
            == (
                "graph import core {\n"
                "    util ++> [\n"
                "        other { now as clock },\n"
                "        svc { later, now },\n"
                "    ]\n"
                "}\n"
            ) , text;
        _write(base, "archwire.jac", text);
        assert _formatted(base, "archwire.jac") == text;
        _write(
            base, "core/svc.jac", "def serve -> str {\n    return now() + later();\n}\n"
        );
        _write(base, "core/other.jac", "def tick -> str {\n    return clock();\n}\n");
        assert _errors(_compile(base, "core/svc.jac")) == [];
        assert _errors(_compile(base, "core/other.jac")) == [];
        assert _errors(_compile(base, "archwire.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "jac fmt breaks a long fan-out one consumer per line" {
    consumers = [f"app.screen_{i}" for i in range(8)];
    files = {
        "archwire.jac": (
            "graph import {\n"
            + "".join([f"    core.util ++> {c} {{ now }}\n" for c in consumers])
            + "}\n"
        ),
        "core/util.jac": _UTIL
    };
    for c in consumers {
        files[c.replace(".", "/") + ".jac"] = "def show -> str {\n    return now();\n}\n";
    }
    base = _project(files);
    try {
        text = _formatted(base, "archwire.jac");
        assert all([len(line) <= 88 for line in text.split("\n")]) , text;
        assert text.count("++> ") == 1 , text;
        for c in consumers {
            assert text.count(c) == 1 , (c, text);
        }
        _write(base, "archwire.jac", text);
        assert _formatted(base, "archwire.jac") == text;
        assert _errors(_compile(base, "app/screen_3.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a wired name its consumer never uses is an error at the wire" {
    base = _standard(
        arch=_ARCH.replace(
            "    core.util ++> app.main { now as when }\n",
            "    core.util ++> app.main { now as when }\n"
            "    core.other ++> app.main { helper }\n"
        )
    );
    try {
        prog = _compile(base, "app/main.jac");
        assert _errors(prog) == ["E1146"] , _errors(prog);
        err = [
            e
            for e in prog.errors_had
            if e.code and e.code.code == "E1146"
        ][0];
        assert err.loc.mod_path.endswith("archwire.jac") , err.loc.mod_path;
        assert _read(base, "archwire.jac").split("\n")[err.loc.first_line - 1].strip()
            == "core.other ++> app.main { helper }";
        assert "helper" in str(err.pretty_print());
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a name listed in __all__ is a declared export, not an unused wire" {
    base = _standard(
        arch=_ARCH.replace(
            "    core.util ++> app.main { now as when }\n",
            "    core.util ++> app.main { now as when }\n"
            "    core.other ++> app.main { helper }\n"
        ),
        main=_MAIN + "\nglob __all__ = [\"greet\", \"helper\"];\n"
    );
    try {
        assert _errors(_compile(base, "app/main.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "an unaliased module wire loads for effect; an aliased one must be used" {
    base = _standard(
        arch=_ARCH.replace(
            "    core.util ++> app.main { now as when }\n",
            "    core.util ++> app.main { now as when }\n"
            "    core.other ++> app.main;\n"
            "    core.other as other_mod ++> app.main;\n"
        )
    );
    try {
        prog = _compile(base, "app/main.jac");
        assert _errors(prog) == ["E1146"] , _errors(prog);
        assert "other_mod" in str(prog.errors_had[0].pretty_print());
        _write(
            base,
            "app/main.jac",
            _MAIN.replace(
                "serve() + when()", "serve() + when() + str(other_mod.helper())"
            )
        );
        assert _errors(_compile(base, "app/main.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a scoped wire's name unused in its function is an error" {
    base = _standard(
        arch=_ARCH
            + "\ngraph import {\n    core.other ++> app.main.greet { helper }\n}\n"
    );
    try {
        assert _errors(_compile(base, "app/main.jac")) == ["E1146"];
        _write(
            base,
            "app/main.jac",
            _MAIN.replace("serve() + when()", "serve() + when() + str(helper())")
        );
        assert _errors(_compile(base, "app/main.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a name used only in an impl annex counts as used" {
    base = _standard(
        main=("def greet -> str;\n" "\n" "with entry {\n" "    print(greet());\n" "}\n")
    );
    try {
        _write(
            base,
            "app/main.impl.jac",
            "impl greet -> str {\n    return serve() + when();\n}\n"
        );
        assert _errors(_compile(base, "app/main.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "jac arch init derives the canonical wiring that covers the project" {
    base = _project(
        {
            "core/util.jac": _UTIL,
            "core/svc.jac": "import from core.util { now }\n\n" + _SVC,
            "app/main.jac": (
                "import from core.svc { serve }\n"
                "import from core.util { now as when }\n"
                "import os;\n"
                "\n"
                + _MAIN
            )
        }
    );
    try {
        assert _arch_init(False, True, base) == 0;
        assert _read(base, "archwire.jac")
            == (
                "graph import {\n"
                "    core.svc ++> app.main { serve }\n"
                "    core.util ++> app.main { now as when }\n"
                "}\n"
                "\n"
                "graph import core {\n"
                "    util ++> svc { now }\n"
                "}\n"
            ) , _read(base, "archwire.jac");
        prog = _compile(base, "app/main.jac");
        assert _errors(prog) == [] , _errors(prog);
        assert "import from core" not in _read(base, "app/main.jac");
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "jac arch sync adds missing wires and --prune drops unused ones" {
    base = _standard(
        arch=_ARCH.replace(
            "    core.util ++> app.main { now as when }\n",
            "    core.util ++> app.main { now as when }\n"
            "    core.other ++> app.main { helper }\n"
        ),
        svc="import from core.other { helper }\n\n"
            + "def serve -> str {\n    return now() + str(helper());\n}\n"
    );
    try {
        assert _arch_sync(False, base, False) == 0;
        synced = _read(base, "archwire.jac");
        assert "    other ++> svc { helper }\n" in synced , synced;
        assert "    util ++> svc { now }\n" in synced , synced;
        assert "core.other ++> app.main { helper }" in synced , synced;
        assert _arch_sync(False, base, True) == 0;
        pruned = _read(base, "archwire.jac");
        assert "core.other ++> app.main" not in pruned , pruned;
        assert "    other ++> svc { helper }\n" in pruned , pruned;
        assert _formatted(base, "archwire.jac") == pruned;
        assert _errors(_compile(base, "app/main.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "rules are optional: a provider no rule names flows anywhere under archwire.jac" {
    base = _standard(
        arch=(
            "graph import {\n"
            "    core.svc ++> app.main { serve }\n"
            "    core.util ++> app.main { now as when }\n"
            "}\n"
            "\n"
            "graph import core {\n"
            "    util ++> svc { now }\n"
            "}\n"
        )
    );
    try {
        assert _errors(_compile(base, "archwire.jac")) == [];
        assert _errors(_compile(base, "app/main.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a rule restricts only the providers it names" {
    base = _standard(
        arch=(
            "graph import {\n"
            "    edge AppOverCore: core.* --> app.*;\n"
            "    edge CoreInternal: core.* --> core.*;\n"
            "}\n"
        ),
        main="import from core.svc { serve }\n\ndef greet -> str {\n    return serve();\n}\n",
        svc="import from core.util { now }\n\n" + _SVC
    );
    try {
        prog = _compile(base, "app/main.jac");
        assert _errors(prog) == ["E1144"] , _errors(prog);
        svc = _compile(base, "core/svc.jac");
        assert _errors(svc) == ["E1144"] , _errors(svc);
        _write(
            base,
            "extra/free.jac",
            "import from core.util { now }\n\ndef t -> str {\n    return now();\n}\n"
        );
        free = _compile(base, "extra/free.jac");
        assert sorted(_errors(free)) == ["E1144", "E2090"] , _errors(free);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a rule's targets are relative to its block, like a wire's consumers" {
    base = _standard(
        arch=(
            "graph import core {\n"
            "    edge CoreInternal: * --> *;\n"
            "\n"
            "    util ++> svc { now }\n"
            "}\n"
        ),
        main="import from core.svc { serve }\n\ndef greet -> str {\n    return serve();\n}\n"
    );
    try {
        assert _errors(_compile(base, "archwire.jac")) == [];
        assert "E2090" in _errors(_compile(base, "app/main.jac"));
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a directory without archwire.jac is ordinary code, and [arch] in jac.toml is an error" {
    import from jaclang.project.config { JacConfig }
    base = _project(
        {
            "core/util.jac": _UTIL,
            "core/svc.jac": "import from core.util { now }\n\n" + _SVC
        }
    );
    try {
        assert _errors(_compile(base, "core/svc.jac")) == [];
        raised = "";
        try {
            JacConfig.from_toml_str(
                "[project]\nname = \"x\"\n\n[arch]\nclosed = [\"*\"]\n"
            );
        } except ValueError as e {
            raised = str(e);
        }
        assert "archwire.jac" in raised , raised;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a function-level project import in a sealed module is an error" {
    base = _standard(
        main=(
            "def greet -> str {\n"
            "    import from core.other { helper }\n"
            "    return serve() + when() + str(helper());\n"
            "}\n"
        )
    );
    try {
        prog = _compile(base, "app/main.jac");
        assert _errors(prog) == ["E2094"] , _errors(prog);
        shown = str(prog.errors_had[0].pretty_print());
        assert "other ++> app.main.greet { helper }" in shown , shown;
        _write(
            base,
            "archwire.jac",
            _ARCH.replace(
                "    edge CoreInternal: core.* --> core.*;\n",
                "    edge CoreInternal: core.* --> core.*;\n"
                "    edge Lazy: core.other --> extra.*;\n"
            ).replace(
                "    core.util ++> app.main { now as when }\n",
                "    core.other ++> extra.lazy.t { helper }\n"
                "    core.util ++> app.main { now as when }\n"
            )
        );
        _write(base, "extra/lazy.jac", "def t -> int {\n    return helper();\n}\n");
        lazy = _compile(base, "extra/lazy.jac");
        assert _errors(lazy) == [] , _errors(lazy);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "wiring diagnostics ignore inline suppression" {
    base = _standard(
        svc=(
            "import from core.other { helper }  # jac:ignore[E1144]\n"
            "\n"
            "def serve -> str {\n"
            "    return now() + str(helper());\n"
            "}\n"
        )
    );
    try {
        prog = _compile(base, "core/svc.jac");
        assert _errors(prog) == ["E1144"] , _errors(prog);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a nested archwire.jac is its own boundary with names relative to it" {
    base = _standard(
        svc="import from lib.a { f }\n\ndef serve -> str {\n    return now() + str(f());\n}\n"
    );
    try {
        _write(base, "lib/archwire.jac", "graph import {\n    a ++> b { f }\n}\n");
        _write(base, "lib/a.jac", "def f -> int {\n    return 1;\n}\n");
        _write(base, "lib/b.jac", "def g -> int {\n    return f();\n}\n");
        assert _errors(_compile(base, "lib/b.jac")) == [];
        assert _errors(_compile(base, "core/svc.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a written import a wire injects is an error that says to delete it" {
    base = _standard(svc="import from core.util { now }\n\n" + _SVC);
    try {
        prog = _compile(base, "core/svc.jac");
        assert _errors(prog) == ["E1144"] , _errors(prog);
        assert "already injects it" in str(prog.errors_had[0].pretty_print());
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "an import that runs where it is written is declared by a --> wire" {
    guarded = (
        "def greet -> str {\n"
        "    if True {\n"
        "        import from core.other { helper }\n"
        "        return serve() + when() + str(helper());\n"
        "    }\n"
        "    return serve() + when();\n"
        "}\n"
    );
    base = _standard(main=guarded);
    try {
        prog = _compile(base, "app/main.jac");
        assert _errors(prog) == ["E2094"] , _errors(prog);
        assert "core.other --> app.main.greet { helper }"
            in str(prog.errors_had[0].pretty_print());
        _write(
            base,
            "archwire.jac",
            _ARCH
                + "\ngraph import {\n    core.other ++> app.main.greet { helper }\n}\n"
        );
        injected = _compile(base, "app/main.jac");
        assert _errors(injected) == ["E2094"] , _errors(injected);
        assert "instead of injecting it" in str(injected.errors_had[0].pretty_print());
        _write(
            base,
            "archwire.jac",
            _ARCH
                + "\ngraph import {\n    core.other --> app.main.greet { helper }\n}\n"
        );
        assert _errors(_compile(base, "app/main.jac")) == [];
        _write(base, "app/main.jac", _MAIN);
        missing = _compile(base, "app/main.jac");
        assert _errors(missing) == ["E1147"] , _errors(missing);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "an import after other statements runs where it is written too" {
    base = _standard(
        arch=_ARCH
            + "\ngraph import {\n    core.other --> app.main.greet { helper }\n}\n",
        main=(
            "def greet -> str {\n"
            "    first = serve() + when();\n"
            "    import from core.other { helper }\n"
            "    return first + str(helper());\n"
            "}\n"
        )
    );
    try {
        assert _errors(_compile(base, "app/main.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "jac arch init refuses a directory whose modules a parent archwire.jac feeds" {
    base = _standard();
    try {
        assert _arch_init(False, False, os.path.join(base, "core")) == 1;
        assert not os.path.exists(os.path.join(base, "core", "archwire.jac"));
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a nested function takes its own wire, not its parent's" {
    base = _standard(
        arch=(
            "graph import {\n"
            "    core.util ++> app.main.greet { now as when }\n"
            "    core.util ++> app.main.greet.inner { now as when }\n"
            "}\n"
        ),
        main=(
            "def greet -> str {\n"
            "    def inner -> str {\n"
            "        return when();\n"
            "    }\n"
            "    return when() + inner();\n"
            "}\n"
            "\n"
            "with entry {\n"
            "    print(greet());\n"
            "}\n"
        )
    );
    try {
        prog = _compile(base, "app/main.jac");
        assert _errors(prog) == [] , _errors(prog);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "the strip removes a function's wired import that a nested function repeats" {
    base = _standard(
        arch="graph import {\n    core.util ++> app.main.greet { now as when }\n}\n",
        main=(
            "def greet -> str {\n"
            "    import from core.util { now as when }\n"
            "    def inner -> str {\n"
            "        import from core.util { now as when }\n"
            "        return when();\n"
            "    }\n"
            "    return when() + inner();\n"
            "}\n"
            "\n"
            "with entry {\n"
            "    print(greet());\n"
            "}\n"
        )
    );
    try {
        prog = JacProgram.jac_file_formatter(
            os.path.join(base, "app", "main.jac"), auto_lint=True
        );
        text = prog.mod.main.gen.jac;
        assert text.count("import from core.util") == 1 , text;
        assert text.index("def inner") < text.index("import from core.util") , text;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a name read inside an import from c block counts as used" {
    base = _standard(
        arch=_ARCH.replace(
            "    core.util ++> app.main { now as when }\n",
            "    core.util ++> app.main { now as when }\n"
            "    core.other ++> app.main { helper }\n"
        ),
        main=_MAIN
            + "\nimport from c {\n    glob:priv handlers: list[int] = [helper()];\n}\n"
    );
    try {
        assert "E1146" not in _errors(_compile(base, "app/main.jac"));
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "grouped targets on one line each reach their own function" {
    base = _standard(
        arch=_ARCH
            + "\ngraph import {\n"
            + "    core.other ++> [app.main.greet { helper }, app.main.again { helper as h }]\n"
            + "}\n",
        main=(
            "def greet -> str {\n"
            "    return serve() + when() + str(helper());\n"
            "}\n"
            "\n"
            "def again -> int {\n"
            "    return h();\n"
            "}\n"
        )
    );
    try {
        assert _errors(_compile(base, "app/main.jac")) == [];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "jac fmt keeps the escape on a wired name that is a keyword" {
    base = _standard(
        arch=_ARCH.replace(
            "    core.util ++> app.main { now as when }\n",
            "    core.util ++> app.main { `return as result, now as when }\n"
        )
    );
    try {
        text = _formatted(base, "archwire.jac");
        assert "`return as result" in text , text;
        _write(base, "archwire.jac", text);
        assert _formatted(base, "archwire.jac") == text;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a local name that shadows a wired one does not count as its use" {
    base = _standard(
        arch=_ARCH.replace(
            "    core.util ++> app.main { now as when }\n",
            "    core.util ++> app.main { now as when }\n"
            "    core.other ++> app.main { helper }\n"
        ),
        main=_MAIN + "\ndef twice(helper: int) -> int {\n    return helper * 2;\n}\n"
    );
    try {
        assert _errors(_compile(base, "app/main.jac")) == ["E1146"];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a name a --> wire declares but the function never reads is unused too" {
    base = _standard(
        arch=_ARCH
            + "\ngraph import {\n    core.other --> app.main.greet { helper }\n}\n",
        main=(
            "def greet -> str {\n"
            "    if True {\n"
            "        import from core.other { helper }\n"
            "    }\n"
            "    return serve() + when();\n"
            "}\n"
        )
    );
    try {
        assert _errors(_compile(base, "app/main.jac")) == ["E1146"];
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a module's own archetype shadows one an included module brings in" {
    base = _project(
        {
            "archwire.jac": "graph import {\n    include core.shared ++> core.host;\n}\n",
            "core/shared.jac": "obj Pair {\n    has a: int = 0;\n}\n\ndef make -> Pair {\n    return Pair(a=1);\n}\n",
            "core/host.jac": (
                "obj Pair {\n    has a: int = 0;\n}\n\n"
                "def use -> int {\n    return Pair(a=2).a + make().a;\n}\n"
            )
        }
    );
    try {
        assert "E0077" not in _errors(_compile(base, "core/host.jac"));
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a wired keyword-named function read in code counts as used" {
    base = _standard(
        arch=_ARCH.replace(
            "    core.util ++> app.main { now as when }\n",
            "    core.util ++> app.main { `init, now as when }\n"
        ),
        main="cl def boot -> str {\n    return init() + when();\n}\n"
    );
    try {
        _write(
            base,
            "core/util.jac",
            _UTIL + "\ncl def `init -> str {\n    return now();\n}\n"
        );
        assert "E1146" not in _errors(_compile(base, "app/main.jac"));
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}
