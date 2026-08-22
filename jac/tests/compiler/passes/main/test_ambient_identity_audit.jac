"""Per-name identity audit: ambient typing names vs their explicit imports.

The ambient set (type_system/typing_ambient.pyi) merges 17 names into the
builtins scope so user code can write `Callable[[int], str]` without an
import. W1103 advises dropping the redundant import. Before that advisory
can escalate to an error, each name must be certified: the explicitly
imported spelling and the ambient spelling must resolve to the *same*
type, with the same assignability behavior and the same diagnostic
stream. Likewise for the two PEP-604 exclusions (Optional/Union), whose
remedy is a rewrite to `X | None` / `X | Y` rather than an ambient name.

Harness design notes (why this probe is trustworthy where earlier
attempts were not):

* Types are never stamped onto AST nodes in this compiler -- there is no
  `.type` attribute on unitree expressions. The TypeEvaluator computes
  types on demand. A probe that reads `node.type` measures the harness
  (getattr fallback), not the language. The observable channel is
  `program.get_type_evaluator().get_type_of_symbol(sym)` after
  TypeCheckPass has run.
* An import of an ambient name shadows the ambient binding for the whole
  module, so "both spellings in one file" is not measurable for a single
  name: every reference resolves through the import. Each spelling gets
  its own module, compiled in its own JacProgram.
* Cross-program type identity uses ClassDetailsShared.canonical_key()
  (realpath, line, col, class name) -- the compiler's own identity law --
  so two programs agreeing on a fingerprint means both spellings reached
  the same declaration, not merely two same-named strings.
* Both spellings share one body with a one-line header, so declaration
  line numbers align and fixture-local canonical keys stay comparable;
  the temp-dir path component is normalized out.

Audit verdicts this file pins (2026-08-18):

* All 17 ambient names, from both source modules, and Optional/Union
  against their PEP-604 rewrites: IDENTICAL at the checker tier --
  same canonical declaration (the typeshed typing.pyi symbol, reached
  through the collections.abc re-export chain as well), same
  assignability verdicts, same diagnostic stream. The ambient merge
  injects the typing-stub symbol into builtins, and the stub hub
  memoizes by resolved path, so every spelling funnels to one
  declaration per program.
* The real spelling divergence lives in *placement*, not typing: an
  `import from typing { ... }` whose names are not all in the
  native-erased set (TypeVar/ParamSpec/TypeVarTuple/cast/TypeAlias/
  ClassVar) makes native_default_verdict refuse the module
  ("unresolved import 'typing'"), silently landing it in the server
  codespace. collections.abc imports are placement-neutral
  (NATIVE_SUPPORTED_STDLIB), as is the ambient spelling. A module off
  the native pathway skips the stamping tier and the whole native
  diagnostic rim (LayoutPass W5032 among them) -- which is why an
  earlier probe generation read "Optional[X] suppresses a layout error
  that X | None raises": the typing import had demoted its probe
  module; the type system never disagreed.
* Within one pipeline, Optional[X]/Union[X, Y] and their PEP-604
  rewrites stamp and lower identically; the layout probe below pins
  the equal diagnostic streams, and the placement probe pins the
  demotion map the migration blast radius rests on.
"""

import os;
import tempfile;
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.main.type_checker_pass { TypeCheckPass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { run_pass }
import from jaclang.compiler.type_system.types { ClassType, FunctionType, UnionType }

glob NO_TC = CompileOptions(type_check=False, default_codespace='server');

def fingerprint(t: object, base_dir: str, depth: int = 0) -> str {
    if depth > 5 {
        return "<depth>";
    }
    if t is None {
        return "none";
    }
    if isinstance(t, ClassType) {
        key = t.shared.canonical_key();
        loc = "nokey";
        if key is not None {
            path = key[0].replace(os.path.realpath(base_dir), "<T>");
            loc = path + ":" + str(key[1]) + ":" + str(key[2]) + ":" + key[3];
        }
        args = t.private.type_args;
        args_s = "";
        if args {
            args_s = ",".join([fingerprint(a, base_dir, depth + 1) for a in args]);
        }
        return "C(" + loc + ")i=" + str(t.is_instance()) + "[" + args_s + "]";
    }
    if isinstance(t, UnionType) {
        members = sorted(
            [fingerprint(m, base_dir, depth + 1) for m in (t.types or [])]
        );
        return "U[" + "|".join(members) + "]";
    }
    if isinstance(t, FunctionType) {
        ps = ",".join(
            [
                fingerprint(p.param_type, base_dir, depth + 1)
                for p in (t.parameters or [])
            ]
        );
        ret = fingerprint(t.return_type, base_dir, depth + 1);
        return "F(" + ps + ")->" + ret + "/fl=" + str(t.function_flags);
    }
    return type(t).__name__ + ":" + str(t);
}

obj ProbeResult {
    has fps: dict[str, str] = {},
        diags: list[str] = [];
}

def run_probe(header: str, body: str, probe_syms: list[str]) -> ProbeResult {
    tmpdir = tempfile.mkdtemp(prefix="ambient_audit_");
    path = os.path.join(tmpdir, "probe.jac");
    with open(path, "w") as f {
        f.write(header + "\n" + body);
    }
    program = JacProgram();
    mod = program.compile(path, options=NO_TC);
    run_pass(TypeCheckPass, mod, program);
    evaluator = program.get_type_evaluator();
    result = ProbeResult();
    for name in probe_syms {
        sym = None;
        if "::" in name {
            parts = name.split("::");
            cls_sym = mod.sym_tab.lookup(parts[0]);
            if cls_sym is not None {
                scope = cls_sym.decl.name_of;
                sym = scope.lookup(parts[1], deep=False);
            }
        } else {
            sym = mod.sym_tab.lookup(name);
        }
        if sym is None {
            result.fps[name] = "<no-symbol>";
        } else {
            result.fps[name] = fingerprint(evaluator.get_type_of_symbol(sym), tmpdir);
        }
    }
    rp = os.path.realpath(tmpdir);
    for alert in (program.errors_had + program.warnings_had) {
        code = alert.code.code if alert.code is not None else "?";
        if code == "W1103" {
            continue;
        }
        msg = alert.msg.replace(rp, "<T>").replace(tmpdir, "<T>");
        result.diags.append(code + "@" + str(alert.loc.first_line) + ":" + msg);
    }
    result.diags.sort();
    return result;
}

def compare(a: ProbeResult, b: ProbeResult) -> list[str] {
    deltas: list[str] = [];
    for key in a.fps.keys() {
        if a.fps.get(key) != b.fps.get(key) {
            deltas.append(
                "fp["
                    + key
                    + "]: "
                    + str(a.fps.get(key))
                    + "  !=  "
                    + str(b.fps.get(key))
            );
        }
    }
    if a.diags != b.diags {
        deltas.append("diags: " + str(a.diags) + "  !=  " + str(b.diags));
    }
    return deltas;
}

glob REPORT: list[str] = [];

def audit_name(
    name: str, source_mods: list[str], body: str, probe_syms: list[str]
) -> list[str] {
    ambient = run_probe("# ambient spelling probe", body, probe_syms);
    all_deltas: list[str] = [];
    REPORT.append("== " + name + " ==");
    REPORT.append("  ambient: " + str(ambient.fps) + " diags=" + str(ambient.diags));
    for mod_name in source_mods {
        header = "import from " + mod_name + " { " + name + " }";
        imported = run_probe(header, body, probe_syms);
        deltas = compare(ambient, imported);
        REPORT.append(
            "  " + mod_name + ": " + str(imported.fps) + " diags=" + str(imported.diags)
        );
        if deltas {
            REPORT.append("  DIVERGES(" + mod_name + "):");
            for d in deltas {
                REPORT.append("    " + d);
            }
            all_deltas.extend([mod_name + ": " + d for d in deltas]);
        } else {
            REPORT.append("  IDENTICAL(" + mod_name + ")");
        }
    }
    return all_deltas;
}

def audit_pep604(
    name: str, typed_body: str, native_body: str, probe_syms: list[str]
) -> list[str] {
    native = run_probe("# native spelling probe", native_body, probe_syms);
    header = "import from typing { " + name + " }";
    imported = run_probe(header, typed_body, probe_syms);
    deltas = compare(native, imported);
    REPORT.append("== " + name + " (PEP 604) ==");
    REPORT.append("  native: " + str(native.fps) + " diags=" + str(native.diags));
    REPORT.append("  typing: " + str(imported.fps) + " diags=" + str(imported.diags));
    if deltas {
        REPORT.append("  DIVERGES:");
        for d in deltas {
            REPORT.append("    " + d);
        }
    } else {
        REPORT.append("  IDENTICAL");
    }
    return deltas;
}

def flush_report {
    out = os.environ.get("AMBIENT_AUDIT_REPORT");
    if out {
        with open(out, "a") as f {
            f.write("\n".join(REPORT) + "\n");
        }
    }
    REPORT.clear();
}

glob ABC_MODS: list[str] = ["typing", "collections.abc"],
     TYPING_MODS: list[str] = ["typing"];

test "audit_callable" {
    deltas = audit_name(
        "Callable",
        ABC_MODS,
        (
            "def cbimpl(x: int) -> str {\n"
            + "    return \"s\";\n"
            + "}\n"
            + "def probe(cb: Callable[[int], str]) -> str {\n"
            + "    return cb(1);\n"
            + "}\n"
            + "with entry {\n"
            + "    probe(cbimpl);\n"
            + "    probe(42);\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_sequence" {
    deltas = audit_name(
        "Sequence",
        ABC_MODS,
        (
            "def probe(xs: Sequence[int]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe([1, 2]);\n"
            + "    probe({\"a\": 1});\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_iterable" {
    deltas = audit_name(
        "Iterable",
        ABC_MODS,
        (
            "def probe(xs: Iterable[int]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe([1, 2]);\n"
            + "    probe(42);\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_iterator" {
    deltas = audit_name(
        "Iterator",
        ABC_MODS,
        (
            "def probe(xs: Iterator[int]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe(iter([1, 2]));\n"
            + "    probe([1, 2]);\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_mapping" {
    deltas = audit_name(
        "Mapping",
        ABC_MODS,
        (
            "def probe(m: Mapping[str, int]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe({\"a\": 1});\n"
            + "    probe([1]);\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_mutable_mapping" {
    deltas = audit_name(
        "MutableMapping",
        ABC_MODS,
        (
            "def probe(m: MutableMapping[str, int]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe({\"a\": 1});\n"
            + "    probe(\"x\");\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_mutable_sequence" {
    deltas = audit_name(
        "MutableSequence",
        ABC_MODS,
        (
            "def probe(xs: MutableSequence[int]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe([1, 2]);\n"
            + "    probe((1, 2));\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_awaitable" {
    deltas = audit_name(
        "Awaitable",
        ABC_MODS,
        (
            "def probe(a: Awaitable[int]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe(5);\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_coroutine" {
    deltas = audit_name(
        "Coroutine",
        ABC_MODS,
        (
            "def probe(c: Coroutine[any, any, int]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe(5);\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_async_iterable" {
    deltas = audit_name(
        "AsyncIterable",
        ABC_MODS,
        (
            "def probe(a: AsyncIterable[int]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe([1]);\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_async_iterator" {
    deltas = audit_name(
        "AsyncIterator",
        ABC_MODS,
        (
            "def probe(a: AsyncIterator[int]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe([1]);\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_annotated" {
    deltas = audit_name(
        "Annotated",
        TYPING_MODS,
        (
            "glob good: Annotated[int, \"meta\"] = 5;\n"
            + "def probe(x: Annotated[str, \"m2\"]) -> str {\n"
            + "    return x;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe(\"ok\");\n"
            + "    probe(3);\n"
            + "}\n"
        ),
        ["good", "probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_classvar" {
    deltas = audit_name(
        "ClassVar",
        TYPING_MODS,
        (
            "obj Holder {\n"
            + "    has count: ClassVar[int] = 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    ok: int = Holder.count;\n"
            + "    no: str = Holder.count;\n"
            + "}\n"
        ),
        ["Holder::count"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_generic" {
    deltas = audit_name(
        "Generic",
        TYPING_MODS,
        (
            "glob T = TypeVar(\"T\");\n"
            + "class Box(Generic[T]) {\n"
            + "    has item: T | None = None;\n"
            + "}\n"
            + "def probe(b: Box[int]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_literal" {
    deltas = audit_name(
        "Literal",
        TYPING_MODS,
        (
            "def probe(mode: Literal[\"r\", \"w\"]) -> str {\n"
            + "    return mode;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe(\"r\");\n"
            + "    probe(\"x\");\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_protocol" {
    deltas = audit_name(
        "Protocol",
        TYPING_MODS,
        (
            "obj Runnable(Protocol) {\n"
            + "    def run() -> None {\n"
            + "        return;\n"
            + "    }\n"
            + "}\n"
            + "obj Thread {\n"
            + "    def run() -> None {\n"
            + "        return;\n"
            + "    }\n"
            + "}\n"
            + "def probe(r: Runnable) -> None {\n"
            + "    r.run();\n"
            + "}\n"
            + "with entry {\n"
            + "    probe(Thread());\n"
            + "    probe(42);\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_typevar" {
    deltas = audit_name(
        "TypeVar",
        TYPING_MODS,
        (
            "glob T = TypeVar(\"T\");\n"
            + "def ident(x: T) -> T {\n"
            + "    return x;\n"
            + "}\n"
            + "with entry {\n"
            + "    a: int = ident(5);\n"
            + "    b: str = ident(7);\n"
            + "}\n"
        ),
        ["T", "ident"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "audit_optional_pep604" {
    deltas = audit_pep604(
        "Optional",
        (
            "def probe(x: Optional[int]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe(5);\n"
            + "    probe(None);\n"
            + "    probe(\"s\");\n"
            + "}\n"
        ),
        (
            "def probe(x: int | None) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe(5);\n"
            + "    probe(None);\n"
            + "    probe(\"s\");\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}

test "typing_import_flips_native_placement" {
    import from jaclang.jac0core.placement_solver { native_default_verdict }
    import from jaclang.jac0core.compiler { native_pipeline_available }
    (env_ok, env_reason) = native_pipeline_available();
    if not env_ok {
        print("skipping placement audit: " + env_reason);
        return;
    }
    body = "obj Point {\n" + "    has x: int = 0;\n" + "}\n";
    cases = [
        ("# ambient", True),
        ("import from collections.abc { Sequence }", True),
        ("import from typing { TypeVar }", True),
        ("import from typing { ClassVar }", True),
        ("import from typing { Sequence }", False),
        ("import from typing { Callable }", False),
        ("import from typing { Optional }", False),
        ("import from typing { TypeVar, Sequence }", False)
    ];
    for (header, expect_native) in cases {
        tmpdir = tempfile.mkdtemp(prefix="ambient_audit_place_");
        path = os.path.join(tmpdir, "probe.jac");
        with open(path, "w") as f {
            f.write(header + "\n" + body);
        }
        program = JacProgram();
        mod = program.compile(path, options=NO_TC);
        (na_ok, na_why) = native_default_verdict(mod);
        REPORT.append(
            "placement: " + header + " -> ok=" + str(na_ok) + " why=" + na_why
        );
        assert na_ok == expect_native , (
            "placement verdict changed for '"
            + header
            + "': ok="
            + str(na_ok)
            + " why="
            + na_why
            + " -- the ambient-import escalation rests on"
            + " this map; re-measure the migration blast radius"
        );
    }
    flush_report();
}

test "optional_layout_signal" {
    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    native_body = (
        "obj Point {\n"
        + "    has x: int = 0;\n"
        + "}\n"
        + "obj Wrap {\n"
        + "    has inner: Point | None = None;\n"
        + "}\n"
    );
    typed_body = (
        "obj Point {\n"
        + "    has x: int = 0;\n"
        + "}\n"
        + "obj Wrap {\n"
        + "    has inner: Optional[Point] = None;\n"
        + "}\n"
    );
    results: dict[str, tuple] = {};
    for (tag, header, body) in [
        ("native", "# native spelling probe", native_body),
        ("typing", "import from typing { Optional }", typed_body)
    ] {
        tmpdir = tempfile.mkdtemp(prefix="ambient_audit_layout_");
        path = os.path.join(tmpdir, "probe.jac");
        with open(path, "w") as f {
            f.write(header + "\n" + body);
        }
        program = JacProgram();
        mod = program.compile(path);
        registry = get_layout_registry(mod, program);
        lay = registry.get_layout("Wrap");
        field_tags = [(fi.name, fi.type_tag) for fi in lay.fields]
            if lay is not None
            else [];
        stamped = "<no-var>";
        for arch in mod.get_all_sub_nodes(typ=uni.Archetype) {
            if arch.name and arch.name.value == "Wrap" {
                for var in arch.get_has_vars() {
                    ann = var.type_tag.tag if var.type_tag else None;
                    on_demand = "<no-sym>";
                    if var.sym is not None {
                        on_demand = fingerprint(
                            program.get_type_evaluator().get_type_of_symbol(var.sym),
                            tmpdir
                        );
                    }
                    stamped = (
                        "var.type="
                        + fingerprint(var?.type, tmpdir)
                        + " ann.type="
                        + fingerprint(ann?.type, tmpdir)
                        + " ann.kind="
                        + type(ann).__name__
                        + " sym="
                        + str(var.sym is not None)
                        + " on_demand="
                        + on_demand
                    );
                }
            }
        }
        REPORT.append("layout[" + tag + "] stamped: " + stamped);
        codes = sorted(
            [
                (a.code.code if a.code is not None else "?")
                for a in (program.errors_had + program.warnings_had)
                if (a.code is None or a.code.code != "W1103")
            ]
        );
        results[tag] = (field_tags, codes);
        REPORT.append(
            "layout[" + tag + "]: fields=" + str(field_tags) + " codes=" + str(codes)
        );
    }
    flush_report();
    (native_fields, native_codes) = results["native"];
    (typed_fields, typed_codes) = results["typing"];
    assert ("inner", "Point | None") in native_fields;
    assert ("inner", "Optional [ Point ]") in typed_fields;
    assert native_codes == typed_codes , (
        "layout diagnostic streams diverge: native="
        + str(native_codes)
        + " typing="
        + str(typed_codes)
    );
}

test "audit_union_pep604" {
    deltas = audit_pep604(
        "Union",
        (
            "def probe(x: Union[int, str]) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe(5);\n"
            + "    probe(\"s\");\n"
            + "    probe([1]);\n"
            + "}\n"
        ),
        (
            "def probe(x: int | str) -> int {\n"
            + "    return 0;\n"
            + "}\n"
            + "with entry {\n"
            + "    probe(5);\n"
            + "    probe(\"s\");\n"
            + "    probe([1]);\n"
            + "}\n"
        ),
        ["probe"]
    );
    flush_report();
    assert not deltas , "\n".join(deltas);
}
