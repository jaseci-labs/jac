"""arch.jac wiring: wires generate imports, a module arch.jac names is sealed in
both directions, and rules constrain flows.

Each test writes a small project under a fresh temp dir with a jac.toml, an
arch.jac and a few modules, compiles one module through JacProgram and reads
the diagnostic codes back. The wiring spec is content-keyed per project root,
so every test gets its own root.
"""

import os;
import shutil;
import tempfile;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.wiring { WiringSpec }
import from jaclang.compiler.frontend.parser.frontend { parse }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.frontend.unitree { ModuleItem }
import from jaclang.cli.commands.arch {
    _collect_rows,
    _dependency_cone,
    _derive_rules,
    _render_blocks,
    _render_rules
}

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
         "impl import {\n"
         "    edge CoreInternal: core.* --> core.*;\n"
         "    edge AppOverCore: core.* --> app.*;\n"
         "    edge AppInternal: app.* --> app.*;\n"
         "}\n"
         "\n"
         "impl import core {\n"
         "    util --> core.svc { now }\n"
         "    svc --> app.main { serve }\n"
         "    util --> app.main { now as when }\n"
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
            "arch.jac": arch,
            "core/util.jac": _UTIL,
            "core/other.jac": _OTHER,
            "core/svc.jac": svc,
            "app/main.jac": main
        }
    );
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


test "wires generate the consumer's imports and a scoped block is relative on the left" {
    base = _standard();
    try {
        prog = _compile(base, "app/main.jac");
        assert _errors(prog) == [] , _errors(prog);
        assert "W2001" not in _warnings(prog) , _warnings(prog);
        assert "W1051" not in _warnings(prog) , _warnings(prog);
        arch = _compile(base, "arch.jac");
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
            "arch.jac": (
                "impl import {\n"
                "    edge CoreInternal: core.* --> core.*;\n"
                "}\n"
                "\n"
                "impl import core {\n"
                "    util --> core.svc { Spark }\n"
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
        assert _errors(prog) == ["E1144"] , _errors(prog);
        e1144 = [
            e
            for e in prog.errors_had
            if e.code and e.code.code == "E1144"
        ][0];
        assert "core.other --> core.svc { helper }" in str(e1144.pretty_print()) , str(
            e1144.pretty_print()
        );
        assert _warnings(prog).count("W3053") == 1 , _warnings(prog);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "an unmentioned module is left alone but rules still apply to it" {
    base = _standard(
        main=(
            "import from core.svc { serve }\n"
            "import from core.util { now as when }\n"
            "\n"
            "def greet -> str {\n"
            "    return serve() + when();\n"
            "}\n"
        )
    );
    try {
        os.makedirs(os.path.join(base, "extra"), exist_ok=True);
        with open(os.path.join(base, "extra", "rogue.jac"), "w") as f {
            f.write(
                "import from app.main { greet }\n\ndef x -> str {\n    return greet();\n}\n"
            );
        }
        prog = _compile(base, "extra/rogue.jac");
        assert _errors(prog) == ["E2090"] , _errors(prog);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a payload rule admits only the names it lists" {
    arch = (
        "impl import {\n"
        "    edge CoreApi: core.* --> app.* { now }\n"
        "}\n"
        "\n"
        "impl import core {\n"
        "    util --> app.main { now as when }\n"
        "    util --> app.main { serve }\n"
        "}\n"
    );
    base = _standard(arch=arch, main="def greet -> str {\n    return when();\n}\n");
    try {
        with open(os.path.join(base, "core", "util.jac"), "w") as f {
            f.write(_UTIL + "\ndef serve -> str {\n    return now();\n}\n");
        }
        prog = _compile(base, "arch.jac");
        assert _errors(prog) == ["E2091"] , _errors(prog);
        with open(os.path.join(base, "app", "main.jac"), "w") as f {
            f.write("import core.util;\n\ndef greet -> str {\n    return when();\n}\n");
        }
        prog2 = _compile(base, "app/main.jac");
        assert "E2091" in _errors(prog2) , _errors(prog2);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "arch.jac itself is checked for its scope, endpoints, rules and cycles" {
    arch = (
        "impl import nowhere {\n"
        "    thing --> core.svc { x }\n"
        "}\n"
        "\n"
        "impl import {\n"
        "    edge Dup: core.* --> app.*;\n"
        "    edge Dup: app.* --> app.*;\n"
        "    edge Dead: core.missing --> app.*;\n"
        "    os --> core.svc;\n"
        "    core.util --> core.util;\n"
        "    core.util --> core.absent { now }\n"
        "    core.util --> core;\n"
        "}\n"
    );
    base = _standard(arch=arch);
    try {
        prog = _compile(base, "arch.jac");
        codes = sorted(_errors(prog));
        assert codes
            == ["E1140", "E1141", "E1141", "E1142", "E1142", "E1143", "E2092"] , codes;
        assert _warnings(prog).count("W2083") == 1 , _warnings(prog);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "wiring blocks belong in arch.jac and nothing else belongs there" {
    base = _standard(
        arch=_ARCH + "\nimport os;\n\nglob X: int = 1;\n",
        svc="impl import {\n    core.util --> core.svc { now }\n}\n\n" + _SVC
    );
    try {
        arch = _compile(base, "arch.jac");
        assert sorted(_errors(arch)) == ["E2089", "E2089"] , _errors(arch);
        svc = _compile(base, "core/svc.jac");
        assert "E2088" in _errors(svc) , _errors(svc);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "wiring syntax has its own diagnostics" {
    cases = [
        ("impl import { a <-- b { x } }", "E0086"),
        ("impl import { a | b --> c { x } }", "E0087"),
        ("impl import { any --> c { x } }", "E0087"),
        ("impl import { a --> b.* { x } }", "E0088"),
        ("impl import { a as p --> b { x } }", "E0089"),
        ("impl import { a --> b { x, x } }", "E0090"),
        ("impl import { include a --> b { x } }", "E0091"),
        ("impl import { edge a.* --> b.*; }", "E0092"),
        ("impl import \"pkg\" { a --> b { x } }", "E0093"),
        ("impl import { 42; }", "E0094"),
        ("impl import { a --> b { *, x } }", "E0095"),
        ("impl import { edge R: a.* --> b.* { x as y } }", "E0096"),

    ];
    for (src, code) in cases {
        prog = JacProgram();
        parse(src, "arch.jac", prog=prog);
        assert code in _errors(prog) , (src, _errors(prog));
    }
}


test "a broken arch.jac still applies the wires that parsed and says so" {
    base = _standard(arch=_ARCH + "\nimpl import {\n    a <-- b;\n}\n");
    try {
        prog = _compile(base, "app/main.jac");
        assert _errors(prog) == ["E2093"] , _errors(prog);
        assert "W2001" not in _warnings(prog) , _warnings(prog);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "lint autofix removes wired imports and duplicate wires" {
    base = _standard(
        arch=_ARCH.replace(
            "    svc --> app.main { serve }\n",
            "    svc --> app.main { serve }\n    svc --> app.main { serve }\n"
        ),
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
        arch = JacProgram.jac_file_formatter(
            os.path.join(base, "arch.jac"), auto_lint=True
        );
        assert "W3052"
            in [
                w.code.code
                for w in arch.warnings_had
                if w.code
            ] , [
            w.code.code
            for w in arch.warnings_had
            if w.code
        ];
        assert arch.mod.main.gen.jac.count("svc --> app.main { serve }") == 1 , arch.mod.main.gen.jac;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "jac arch init derives a wiring that covers the project" {
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
        spec = WiringSpec(
            root_dir=base, path=os.path.join(base, "arch.jac"), source=""
        );
        modules = [
            (name, spec.module_file(name) or "") for name in spec.project_modules()
        ];
        rows = _collect_rows(spec, modules, False);
        rules = _derive_rules(spec, rows);
        assert rules == ["edge CoreFlows: core.* --> app.* | core.*;"] , rules;
        text = _render_rules(rules) + "\n" + _render_blocks(rows);
        assert "impl import core {" in text , text;
        assert "util --> app.main { now as when }" in text , text;
        assert "util --> core.svc { now }" in text , text;
        assert "os" not in text , text;
        with open(os.path.join(base, "arch.jac"), "w") as f {
            f.write(text);
        }
        prog = _compile(base, "app/main.jac");
        assert _errors(prog) == [] , _errors(prog);
        assert _warnings(prog).count("W3053") == 2 , _warnings(prog);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a wire seals its provider, so a provider no rule names admits nothing" {
    base = _standard(
        arch=(
            "impl import core {\n"
            "    util --> core.svc { now }\n"
            "    svc --> app.main { serve }\n"
            "    util --> app.main { now as when }\n"
            "}\n"
        )
    );
    try {
        prog = _compile(base, "arch.jac");
        assert _errors(prog) == ["E2090", "E2090", "E2090"] , _errors(prog);
        text = str(prog.errors_had[0].pretty_print());
        assert "no rule names it" in text , text;
        assert "edge CoreFlows: core.* --> core.*;" in text , text;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a rule pattern seals the modules it matches in both directions" {
    base = _standard(
        arch=(
            "impl import {\n"
            "    edge CoreInternal: core.* --> core.*;\n"
            "    edge AppOverCore: core.* --> app.*;\n"
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
        os.makedirs(os.path.join(base, "extra"), exist_ok=True);
        with open(os.path.join(base, "extra", "free.jac"), "w") as f {
            f.write(
                "import from core.util { now }\n\ndef t -> str {\n    return now();\n}\n"
            );
        }
        free = _compile(base, "extra/free.jac");
        assert _errors(free) == ["E2090"] , _errors(free);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "[arch] closed seals modules arch.jac never names, even before arch.jac exists" {
    base = _project(
        {
            "core/util.jac": _UTIL,
            "core/svc.jac": "import from core.util { now }\n\n" + _SVC
        },
        toml_extra="\n[arch]\nclosed = [\"core.*\"]\n"
    );
    try {
        prog = _compile(base, "core/svc.jac");
        assert _errors(prog) == ["E1144", "E2090"] , _errors(prog);
        with open(os.path.join(base, "arch.jac"), "w") as f {
            f.write(
                "impl import {\n    edge CoreFlows: core.* --> core.*;\n}\n"
                "\nimpl import core {\n    util --> core.svc { now }\n}\n"
            );
        }
        with open(os.path.join(base, "core", "svc.jac"), "w") as f {
            f.write(_SVC);
        }
        prog2 = _compile(base, "core/svc.jac");
        assert _errors(prog2) == [] , _errors(prog2);
        os.makedirs(os.path.join(base, "extra"), exist_ok=True);
        with open(os.path.join(base, "extra", "open.jac"), "w") as f {
            f.write(
                "import from core.util { now }\n\ndef t -> str {\n    return now();\n}\n"
            );
        }
        prog3 = _compile(base, "extra/open.jac");
        assert _errors(prog3) == ["E2090"] , _errors(prog3);
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
        with open(os.path.join(base, "arch.jac"), "w") as f {
            f.write(
                _ARCH.replace(
                    "}\n\nimpl import core",
                    "    edge Lazy: core.other --> any;\n}\n\nimpl import core"
                )
            );
        }
        os.makedirs(os.path.join(base, "extra"), exist_ok=True);
        with open(os.path.join(base, "extra", "lazy.jac"), "w") as f {
            f.write(
                "def t -> int {\n    import from core.other { helper }\n    return helper();\n}\n"
            );
        }
        lazy = _compile(base, "extra/lazy.jac");
        assert _errors(lazy) == [] , _errors(lazy);
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "sealing diagnostics ignore inline suppression" {
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


test "jac arch init with a scope wires a package's dependency cone" {
    base = _project(
        {
            "core/util.jac": _UTIL,
            "core/other.jac": _OTHER,
            "core/svc.jac": "import from core.util { now }\n\n" + _SVC,
            "app/main.jac": "import from core.svc { serve }\n\ndef greet -> str {\n    return serve();\n}\n",
            "extra/tool.jac": "import from core.other { helper }\n\ndef t -> int {\n    return helper();\n}\n"
        }
    );
    try {
        spec = WiringSpec(
            root_dir=base, path=os.path.join(base, "arch.jac"), source=""
        );
        modules = [
            (name, spec.module_file(name) or "") for name in spec.project_modules()
        ];
        cone = sorted([name for (name, _p) in _dependency_cone(spec, modules, "app")]);
        assert cone == ["app.main", "core.svc", "core.util"] , cone;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}


test "a written import a wire duplicates is emitted once" {
    base = _standard(svc="import from core.util { now }\n\n" + _SVC);
    try {
        prog = JacProgram();
        mod = prog.compile(
            os.path.join(base, "core", "svc.jac"), options=CompileOptions(no_cgen=True)
        );
        bound = [
            item.name.value for imp in ModuleFacts.iter_module_imports(mod)
            for item in imp.items
            if isinstance(item, ModuleItem)
        ];
        assert bound == ["now"] , bound;
        assert [
            w.code.code
            for w in prog.warnings_had
            if w.code is not None
        ].count(
            "W3053"
        )
            == 1;
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}
