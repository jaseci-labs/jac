"""A declaration and its impl are one element (jaseci-labs/jac#10211).

Every body-relative question (the enclosing function, the owning archetype,
the codespace, the scope a name binds in, the placement element) is asked
through the declaration, so a body behaves the same inline, in an `impl` in
the same file, and in an annex. Each repro has an inline twin that already
works; the parity test compiles a corpus all three ways and diffs the
artifacts.
"""

import io;
import os;
import re;
import shutil;
import sys;
import tempfile;
import from pathlib { Path }
import from tests.support { JAC_ROOT }
import jaclang;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang { JacRuntime as Jac }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    push_native_target,
    pop_native_target
}
import from jaclang.compiler.backends.py.codegen_shim { generated_python }
import from jaclang.project.config { JacConfig, CheckConfig, LintConfig, set_config }
import from jaclang.compiler.placement.placement_export { collect_placement_rows }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "decl_impl"
     ),
     PARITY = os.path.join(FIXTURES, "parity"),
     COMPILER_ROOT = os.path.join(JAC_ROOT, "jaclang");

def compile_fixture(path: str) -> tuple[JacProgram, uni.Module] {
    prog = JacProgram();
    mod = prog.compile(path, options=CompileOptions(skip_native_engine=True));
    return (prog, mod);
}

def error_texts(prog: JacProgram) -> list[str] {
    return [e.pretty_print() for e in prog.errors_had];
}

def stamp_of(mod: uni.Module, name: str) -> str {
    for stmt in mod.body {
        if isinstance(stmt, uni.Ability)
            and isinstance(stmt.name_ref, uni.Name)
            and stmt.name_ref.value == name {
            return str(stmt.code_context);
        }
        if isinstance(stmt, uni.Archetype) and stmt.name.value == name {
            return str(stmt.code_context);
        }
    }
    return "missing";
}

def run_and_capture(path: str) -> str {
    old_stdout = sys.stdout;
    buf = io.StringIO();
    sys.stdout = buf;
    try {
        Jac.jac_import(
            target=Path(path).stem,
            base_path=str(Path(path).parent),
            override_name="__main__"
        );
    } finally {
        sys.stdout = old_stdout;
    }
    return buf.getvalue();
}

test "a client component with an impl body is placed with its declaration" {
    (prog, mod) = compile_fixture(os.path.join(FIXTURES, "app", "main.jac"));
    assert not prog.errors_had , error_texts(prog);
    assert stamp_of(mod, "app") == stamp_of(mod, "inline_app") == "client";
    js = mod.gen.js;
    assert "function App(props)" in js , js;
    assert "__jacCallFunction(\"app\"" not in js , js;
    assert "def app(" not in generated_python(mod.gen);
}

test "component state written from a lambda compiles in an impl body" {
    (prog, mod) = compile_fixture(os.path.join(FIXTURES, "pinned_component.jac"));
    assert not prog.errors_had , error_texts(prog);
    assert stamp_of(mod, "Editor") == "client";
    assert "function Editor(" in mod.gen.js;
}

test "a lambda rebinding a local of an impl'd function binds in that function" {
    path = os.path.join(FIXTURES, "lambda_rebind.jac");
    (prog, mod) = compile_fixture(path);
    assert not prog.errors_had , error_texts(prog);
    assert run_and_capture(path).strip() == "6 6";
}

test "a client-pinned helper type-checks in the client codespace from an annex" {
    (prog, mod) = compile_fixture(os.path.join(FIXTURES, "client_helper.jac"));
    assert not prog.errors_had , error_texts(prog);
    assert stamp_of(mod, "helper") == "client";
}

test "an archetype with an impl'd method is pulled to the client like its inline twin" {
    (prog, mod) = compile_fixture(os.path.join(FIXTURES, "client_archetype.jac"));
    assert not prog.errors_had , error_texts(prog);
    assert stamp_of(mod, "Painter") == "client";
    assert "class Painter" in mod.gen.js;
}

test "a linked impl has no placement or scope of its own" {
    (prog, mod) = compile_fixture(os.path.join(FIXTURES, "client_archetype.jac"));
    impls = [
        stmt
        for stmt in mod.body
        if isinstance(stmt, uni.ImplDef)
    ];
    assert impls;
    for impl_def in impls {
        decl = impl_def.decl_link;
        assert isinstance(decl, uni.Ability);
        assert impl_def.top_element is decl.top_element;
        assert impl_def.code_context == decl.code_context;
        assert impl_def.folded;
        for stmt in impl_def.get_all_sub_nodes(uni.ReturnStmt) {
            assert stmt.enclosing_decl(uni.Ability) is decl;
            assert stmt.enclosing_decl(uni.Archetype) is decl.method_owner;
            assert stmt.sym_tab is decl;
        }
    }
}

test "a generic function's impl restates its type parameters" {
    path = os.path.join(FIXTURES, "generic_impl.jac");
    (prog, mod) = compile_fixture(path);
    assert not prog.errors_had , error_texts(prog);
    assert run_and_capture(path).strip() == "a 11";
}

test "an impl whose type parameters differ from its declaration's is an error" {
    (prog, mod) = compile_fixture(os.path.join(FIXTURES, "generic_impl_mismatch.jac"));
    codes = [
        e.code.code
        for e in prog.errors_had
        if e.code is not None
    ];
    assert codes == ["E2030"] , error_texts(prog);
}

test "placement report rows keep their own element after a linked impl" {
    path = os.path.join(FIXTURES, "placement_rows.jac");
    prog = JacProgram();
    prog.compile(path, options=CompileOptions(skip_native_engine=True));
    rows = collect_placement_rows(prog)[os.path.abspath(path)]["rows"];
    assert [row["name"] for row in rows] == ["alpha", "beta", "gamma"] , rows;
    beta = rows[1];
    assert "DOM: jsx construction" in beta["evidence"] , beta;
    assert "DOM: jsx construction" not in rows[2]["evidence"] , rows[2];
}

"""The corpus file written three ways: inline, impls at the bottom of the
module (the separate-impls fixer), and the same impls moved to an annex.
Each maps to the files that make it up, relative to the project directory."""
def corpus_variants(name: str) -> dict[str, dict[str, str]] {
    source = Path(PARITY, name).read_text();
    config = JacConfig();
    config.check = CheckConfig(lint=LintConfig(select=["separate-impls"]));
    set_config(config);
    try {
        separated = JacProgram.jac_file_formatter(
            os.path.join(PARITY, name), auto_lint=True
        ).mod.main.gen.jac;
    } finally {
        set_config(None);
    }
    assert "\nimpl " in separated , f"{name}: the fixer separated nothing";
    cut = separated.index("\nimpl ");
    return {
        "inline": {name: source},
        "same": {name: separated},
        "annex": {
            name: separated[:cut + 1],
            os.path.join("impl", name.replace(".jac", ".impl.jac")): separated[cut + 1:]
        }
    };
}

"""Write one variant into the project directory, replacing the last one, so
every variant compiles from the same path."""
def write_variant(workdir: str, files: dict[str, str]) {
    if os.path.isdir(workdir) {
        shutil.rmtree(workdir);
    }
    os.makedirs(workdir);
    shutil.copy(os.path.join(PARITY, "jac.toml"), workdir);
    for (rel, text) in files.items() {
        target = Path(workdir, rel);
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_text(text);
    }
}

"""Generated Python with the annex marker removed: a cross-file impl is
tagged with the file its body came from, which is the one intended difference."""
def py_artifact(mod: uni.Module) -> str {
    kept: list[str] = [];
    for ln in generated_python(mod.gen).splitlines() {
        if "impl_patch_filename" not in ln {
            kept.append(ln);
            continue;
        }
        if ln.lstrip().startswith("@") {
            continue;
        }
        trimmed = re.sub(r",?\s*impl_patch_filename( as \w+)?", "", ln);
        if not trimmed.rstrip().endswith("import") {
            kept.append(trimmed.replace("import , ", "import "));
        }
    }
    return "\n".join(kept);
}

def diag_artifact(prog: JacProgram) -> list[str] {
    found = [
        f"{a.code.code if a.code else ''}:{a.msg}"
        for a in (list(prog.errors_had) + list(prog.warnings_had))
    ];
    return sorted(found);
}

def ir_artifact(path: str) -> str {
    prev = push_native_target("wasm32-unknown-unknown");
    try {
        prog = JacProgram();
        mod = prog.compile(file_path=path, options=CompileOptions(aot_mode=True));
        assert not prog.errors_had , error_texts(prog);
        text = str(mod.gen.llvm_ir);
    } finally {
        pop_native_target(prev);
    }
    kept: list[str] = [];
    for ln in text.splitlines() {
        if ln.startswith("!")
            or ln.startswith("source_filename")
            or ln.startswith("; ModuleID") {
            continue;
        }
        kept.append(re.sub(r", !dbg ![0-9]+", "", ln));
    }
    return "\n".join(kept);
}

test "a corpus compiles to the same artifacts inline, impl'd, and annexed" {
    with tempfile.TemporaryDirectory() as tmp {
        workdir = os.path.join(tmp, "parity");
        for name in ["funcs.jac", "graph.jac", "client.jac"] {
            arts: dict[str, tuple[str, str, list[str]]] = {};
            for (variant, files) in corpus_variants(name).items() {
                write_variant(workdir, files);
                (prog, mod) = compile_fixture(os.path.join(workdir, name));
                arts[variant] = (
                    py_artifact(mod),
                    mod.gen.js or "",
                    diag_artifact(prog)
                );
            }
            inline = arts["inline"];
            assert not [
                d
                for d in inline[2]
                if d.startswith("E")
            ] , (name, inline[2]);
            for variant in ["same", "annex"] {
                got = arts[variant];
                assert got[0] == inline[0] , (
                    name,
                    variant,
                    "python",
                    got[0],
                    inline[0]
                );
                assert got[1] == inline[1] , (name, variant, "js", got[1], inline[1]);
                assert got[2] == inline[2] , (
                    name,
                    variant,
                    "diagnostics",
                    got[2],
                    inline[2]
                );
            }
        }
        irs: dict[str, str] = {};
        for (variant, files) in corpus_variants("funcs.jac").items() {
            write_variant(workdir, files);
            irs[variant] = ir_artifact(os.path.join(workdir, "funcs.jac"));
        }
        assert irs["inline"].strip();
        assert irs["same"] == irs["inline"] , "native ir differs for same-file impls";
        assert irs["annex"] == irs["inline"] , "native ir differs for annexed impls";
    }
}

test "the compiler asks the declaration, never the syntax parent, for its owner" {
    raw = re.compile(
        r"(find_parent_of_type|parent_of_type)\(\s*(uni\.)?"
        r"(Ability|Archetype|Enum|UniEnum|ArchSpec|AstImplNeedingNode)\s*\)"
    );
    offenders: list[str] = [];
    for path in sorted(Path(COMPILER_ROOT).rglob("*.jac")) {
        rel = str(path.relative_to(COMPILER_ROOT));
        if not path.is_file() or "/tests/" in f"/{rel}" or rel.startswith("vendor/") {
            continue;
        }
        for (lineno, line) in enumerate(path.read_text().splitlines(), start=1) {
            if raw.search(line) {
                offenders.append(f"{rel}:{lineno}: {line.strip()}");
            }
        }
    }
    assert not offenders , "use enclosing_decl(...) instead:\n" + "\n".join(offenders);
}
