"""The front end's Python-isms, and the plain-Jac forms that replaced them.

The #8039 coverage sweep showed the compiler front end's native gaps were not
backend omissions but source idioms: constructs the native capability
authority rejects, reached for where Jac (or plain data) already said the
same thing. This file pins the replacements behaviorally, and guards the
native boundary each one was crossing.

Scope note: the sweep's original table over-collected by globbing
`jac0core/*.jac`. `archetype.jac` and `runtime.jac` are NOT imported by the
front end -- they are the object-spatial runtime and the driver -- so their
`@cached_property` / `object.__new__` / `cls` uses are outside the native
closure and are deliberately untouched.
"""

import os;
import types;
import jaclang.compiler.frontend.helpers as helpers_mod;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.codeinfo { native_safe_sym }
import from jaclang.compiler.frontend.helpers { pascal_to_snake }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Run a snippet through the front-end check schedule with the native
capability authority on -- the `jac check` path that surfaces E5090."""
def check_na_inline(label: str, code: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, f"_idiom_{label}.jac"),
        use_str=code,
        options=CompileOptions(
            no_cgen=True, force_codespace="native", force_target_program=True
        )
    );
    return prog;
}

"""Return True if the program emitted at least one alert with the given code."""
def has_error_code(prog: JacProgram, code: str) -> bool {
    for alrt in prog.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}

"""Format errors for assertion messages."""
def fmt_errors(prog: JacProgram) -> str {
    return str([str(e) for e in prog.errors_had]);
}

# ─────────────────────────────────────────────────────────────────────
# pascal_to_snake: @lru_cache -> an explicit module-level dict cache
# ─────────────────────────────────────────────────────────────────────

test "pascal_to_snake converts the shapes the compiler actually feeds it" {
    assert pascal_to_snake("FuncCall") == "func_call";
    assert pascal_to_snake("Name") == "name";
    assert pascal_to_snake("KWPair") == "k_w_pair";
    assert pascal_to_snake("JsxElement") == "jsx_element";
    assert pascal_to_snake("") == "";
}

# The `@lru_cache(maxsize=256)` this function used to carry was sized to the
# ~150 unitree node types, the fingerprint of the old reflective visitor
# dispatch (`getattr(self, f"enter_{pascal_to_snake(type(nd).__name__)}")`).
# Static accept dispatch replaced that, and pass hooks are now typed OSP
# abilities dispatched by the walker kernel, so the hot loop the cache
# existed for is gone: what remains are the generators and the `jac tool`
# surface, both of which call it a bounded number of times. The cache was
# dropped rather than re-spelled -- a dict memo is three lines if
# measurement ever asks.
test "pascal_to_snake is deterministic across repeat calls without a cache" {
    probe = "AVeryDistinctArchetypeName";
    first = pascal_to_snake(probe);
    assert first == "a_very_distinct_archetype_name";
    assert pascal_to_snake(probe) == first;
}

# ─────────────────────────────────────────────────────────────────────
# pascal_to_snake / native_safe_sym: `re.sub` -> explicit character loops
# ─────────────────────────────────────────────────────────────────────

# Both functions used `re.sub` with an ASCII-only character class, so their
# real contract is code-point ranges, not the Unicode-aware `str` predicates
# an eyeballed rewrite reaches for: `"É".isupper()` and `"é".isalnum()` are
# both True, while `[A-Z]` and `[a-zA-Z0-9_]` match neither. These pin the
# regex semantics so a loop that drifts to `isupper`/`isalnum` fails here.
test "pascal_to_snake splits on ASCII capitals only" {
    assert pascal_to_snake("") == "";
    assert pascal_to_snake("A") == "a";
    assert pascal_to_snake("a") == "a";
    assert pascal_to_snake("AB") == "a_b";
    assert pascal_to_snake("HTTPServer") == "h_t_t_p_server";
    assert pascal_to_snake("Foo2Bar") == "foo2_bar";
    assert pascal_to_snake("2Fast") == "2_fast";
    assert pascal_to_snake("foo_bar") == "foo_bar";
    assert pascal_to_snake("_Leading") == "__leading";
    assert pascal_to_snake("Multi\nLine") == "multi\n_line";
}

test "pascal_to_snake never splits before a non-ASCII capital" {
    assert pascal_to_snake("FooÉbar") == "fooébar";
    assert pascal_to_snake("Éclair") == "éclair";
    assert pascal_to_snake("CaféBar") == "café_bar";
}

"""Strip the sha1 disambiguator native_safe_sym appends to its sanitized stem."""
def safe_sym_stem(src: str) -> str {
    return native_safe_sym(src).rsplit("_", 1)[0];
}

test "native_safe_sym replaces every non-ASCII-word character with underscore" {
    assert safe_sym_stem("plain") == "plain";
    assert safe_sym_stem("pkg.mod") == "pkg_mod";
    assert safe_sym_stem("a/b\\c.d-e f") == "a_b_c_d_e_f";
    assert safe_sym_stem("Mixed_CASE09") == "Mixed_CASE09";
    assert safe_sym_stem("") == "";
    assert safe_sym_stem("trailing.") == "trailing_";
}

test "native_safe_sym treats non-ASCII letters as unsafe" {
    assert safe_sym_stem("café") == "caf_";
    assert safe_sym_stem("naïve_mod") == "na_ve_mod";
}

test "native_safe_sym keeps the kernel modules unhashed" {
    assert native_safe_sym("osp_kernel") == "osp_kernel";
    assert native_safe_sym("fmt_kernel") == "fmt_kernel";
}

test "native_safe_sym keeps distinct sources distinct after sanitizing" {
    assert native_safe_sym("a.b") != native_safe_sym("a_b");
    assert safe_sym_stem("a.b") == safe_sym_stem("a_b");
    assert native_safe_sym("a.b") == native_safe_sym("a.b");
}

# ─────────────────────────────────────────────────────────────────────
# helpers.jac: the Python-only tenants moved to their own modules
# ─────────────────────────────────────────────────────────────────────

# `helpers.jac` sits under most of the front end, so every module-scope
# import it carried was inherited by every closure above it. The debugger
# (`pdb`/`dis`/`marshal`), the jac.toml reader (`tomllib`), and the traceback
# renderer (`traceback`) each moved to their own module, leaving `os` as the
# only module object bound at helpers' module scope. This is the acceptance
# criterion for that move, spelled so re-adding an import fails here.
test "helpers module scope binds os and nothing else" {
    bound = sorted(
        [
            nm
            for (nm, val) in vars(helpers_mod).items()
            if isinstance(val, types.ModuleType) and not nm.startswith("__")
        ]
    );
    assert bound == ["os"] , f"helpers.jac module scope grew imports: {bound}";
}

# Sitting under most of the front end only pays if the module can be linked.
# It could not: `format_related_spans` took its location as `object`, the
# underline narrowed to `LiteralString`, `path_matches_exclude` took a bare
# `list`, and `read_file_with_encoding` asked `open` for an `encoding`. Those
# are type errors, and a type error in a native module refuses the module --
# there is no callable to demote a signature to. Every one of them is fixed
# or demotable now, so the module reaches the backend and the constructs that
# genuinely cannot lower become seams instead of a whole-module refusal.
test "helpers.jac lowers when a native unit reaches it" {
    import jaclang;
    import from jaclang.compiler.driver.na_coverage {
        na_coverage_begin,
        na_coverage_end
    }
    helpers_path = os.path.join(
        os.path.dirname(jaclang.__file__), "compiler", "frontend", "helpers.jac"
    );
    prog = JacProgram();
    opts = CompileOptions(
        aot_mode=True,
        force_codespace='native',
        force_target_program=True,
        no_ir_cache=True
    ).clone_for_native_import();
    na_coverage_begin();
    try {
        ir = prog.compile(file_path=helpers_path, options=opts);
    } finally {
        coverage = na_coverage_end();
    }
    assert not prog.errors_had , (
        f"helpers.jac must reach the backend, not refuse on a signature no "
        f"callable owns: {[str(e) for e in prog.errors_had]}"
    );
    assert ir is not None and ir.gen.llvm_ir is not None , (
        "no LLVM IR for helpers.jac, so every consumer that links it inherits "
        "a module-level refusal"
    );
    rec = coverage.get(os.path.realpath(helpers_path));
    assert rec is not None , "the coverage recorded nothing for helpers.jac";
    seams = [str(s) for s in (rec["seams"] or [])];
    reader = [
        s
        for s in seams
        if s.startswith("read_file_with_encoding: ")
    ];
    assert len(reader) == 1 and "open" in reader[0] , (
        f"`open(path, encoding=...)` has to demote its own function and name "
        f"the construct it refused, got: {seams}"
    );
}

test "helpers no longer exports the moved symbols" {
    for gone in [
        "Jdb",
        "MalformedJacTomlError",
        "TracebackException",
        "debugger",
        "dump_traceback",
        "read_toml_with_encoding"
    ] {
        assert not hasattr(helpers_mod, gone) , (
            f"{gone} is still reachable from helpers.jac"
        );
    }
}

test "the moved symbols resolve from their new modules" {
    import from jaclang.runtime.debugger { Jdb, debugger }
    import from jaclang.project.tomlio {
        MalformedJacTomlError,
        read_toml_with_encoding
    }
    import from jaclang.runtime.traceback_render { dump_traceback }
    assert isinstance(debugger, Jdb);
    assert callable(read_toml_with_encoding);
    assert callable(dump_traceback);
    assert issubclass(MalformedJacTomlError, Exception);
}

# The exception crosses a module boundary into `tomllib`, and existing
# `except MalformedJacTomlError` sites catch by identity, so the move has to
# leave exactly one class object reachable under exactly one base.
test "MalformedJacTomlError keeps its identity and its tomllib base" {
    import tempfile;
    import tomllib;
    import from jaclang.project.tomlio {
        MalformedJacTomlError,
        read_toml_with_encoding
    }
    assert issubclass(MalformedJacTomlError, tomllib.TOMLDecodeError);
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", suffix=".toml", delete=False
    ) as f {
        f.write("this is not valid toml [[[\n");
        temp_path = f.name;
    }
    raised: (Exception | None) = None;
    try {
        try {
            read_toml_with_encoding(temp_path);
        } except tomllib.TOMLDecodeError as exc {
            raised = exc;
        }
    } finally {
        os.unlink(temp_path);
    }
    assert type(raised) is MalformedJacTomlError , (
        f"malformed toml must raise the one MalformedJacTomlError, got {raised!r}"
    );
    assert getattr(raised, "file_path") == temp_path;
}

# ─────────────────────────────────────────────────────────────────────
# runtime reflection -> frozen name tables
# ─────────────────────────────────────────────────────────────────────

# Two passes asked the running interpreter what names exist -- `dir(builtins)`
# for the undefined-name check, `dir(TestCase())` for the assert stubs a
# `test` block gets. Both are now tables generated from CPython 3.14. These
# are the drift alarms: if a CPython upgrade changes either surface, they
# fail here with the exact delta, and the tables get regenerated.
test "the frozen builtins table matches the running interpreter" {
    import builtins;
    import from jaclang.compiler.passes.static_analysis_pass { BUILTIN_NAMES }
    live = set(dir(builtins));
    assert BUILTIN_NAMES == live , (
        f"regenerate BUILTIN_NAMES: missing {sorted(live - BUILTIN_NAMES)}, "
        f"stale {sorted(BUILTIN_NAMES - live)}"
    );
}

test "the frozen TestCase assert table matches the running interpreter" {
    import from unittest { TestCase }
    import from jaclang.compiler.passes.sym_tab_build_pass { TEST_ASSERT_METHOD_NAMES }
    live = [
        j
        for j in dir(TestCase())
        if j.startswith('assert')
    ];
    assert list(TEST_ASSERT_METHOD_NAMES) == live , (
        f"regenerate TEST_ASSERT_METHOD_NAMES: live surface is {live}"
    );
}

test "a test block still binds the assert names to symbols" {
    import from jaclang.compiler.frontend.unitree { Name }
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "_idiom_test_asserts.jac"),
        use_str="test \"probe\" {\n"
        "    assertEqual(1, 1);\n"
        "    assertNotIn(2, [1]);\n"
        "}\n",
        options=CompileOptions()
    );
    bound = {
        nd.value: (nd.sym is not None)
        for nd in ir.get_all_sub_nodes(typ=Name)
        if nd.value.startswith("assert")
    };
    assert bound == {"assertEqual": True, "assertNotIn": True} , (
        f"assert stubs did not bind: {bound}"
    );
}

# ─────────────────────────────────────────────────────────────────────
# operator / platform: stdlib indirections Jac already expresses
# ─────────────────────────────────────────────────────────────────────

# evaluate_version_condition dispatched through a dict of `operator.*`
# callables. Jac compares tuples directly, so the dict is a comparison chain.
# Both spellings are pinned against the same `(major, minor)` arithmetic.
test "version-condition comparisons match the operator table they replaced" {
    import sys;
    import ast as py_ast;
    import from jaclang.compiler.frontend.unitree { IfStmt, PythonModuleAst, Source }
    import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }
    import from jaclang.compiler.frontend.helpers { evaluate_version_condition }
    code = "import sys\n"
    "if sys.version_info >= (3, 11):\n    a = 1\n"
    "if sys.version_info > (3, 11):\n    b = 1\n"
    "if sys.version_info <= (3, 11):\n    c = 1\n"
    "if sys.version_info < (3, 11):\n    d = 1\n"
    "if sys.version_info == (3, 11):\n    e = 1\n"
    "if sys.version_info != (3, 11):\n    f = 1\n"
    "if sys.version_info >= (99, 0):\n    g = 1\n"
    "if sys.platform == 'linux':\n    h = 1\n";
    prog = JacProgram();
    mod = PyastBuildPass(
        ir_in=PythonModuleAst(
            py_ast.parse(code), orig_src=Source(code, "test_version_ops.py")
        )
    ).ir_out;
    got = [
        evaluate_version_condition(nd.condition)
        for nd in mod.get_all_sub_nodes(typ=IfStmt)
    ];
    cur = (sys.version_info.major, sys.version_info.minor);
    expected = [
        cur >= (3, 11),
        cur > (3, 11),
        cur <= (3, 11),
        cur < (3, 11),
        cur == (3, 11),
        cur != (3, 11),
        cur >= (99, 0),
        None
    ];
    assert got == expected , f"version guards evaluated as {got}";
}

# native_target_os read platform.system() ('Linux'/'Darwin'/'Windows') where
# sys.platform ('linux'/'darwin'/'win32') already answers. This runs the old
# mapping beside the new one, so every CI platform proves the pair agrees.
test "native_target_os agrees with the platform.system mapping it replaced" {
    import platform;
    import from jaclang.compiler.frontend.codeinfo {
        native_target_os,
        set_native_target_override,
        _native_target_ctx
    }
    prior = set_native_target_override("");
    try {
        sysname = platform.system();
        legacy = "linux";
        if sysname == "Darwin" {
            legacy = "darwin";
        } elif sysname == "Windows" {
            legacy = "windows";
        }
        assert native_target_os() == legacy , (
            f"platform.system()={sysname!r} mapped to {legacy!r} but "
            f"native_target_os() said {native_target_os()!r}"
        );
    } finally {
        _native_target_ctx.set(prior);
    }
}

test "native_target_os honors the native target override" {
    import from jaclang.compiler.frontend.codeinfo {
        native_target_os,
        set_native_target_override,
        _native_target_ctx
    }
    prior = set_native_target_override("");
    try {
        for (raw, want) in [
            ("aarch64-apple-darwin", "darwin"),
            ("x86_64-windows-msvc", "windows"),
            ("x86_64-unknown-linux-gnu", "linux")
        ] {
            set_native_target_override(raw);
            assert native_target_os() == want , f"{raw} mapped wrong";
        }
    } finally {
        _native_target_ctx.set(prior);
    }
}

test "Jdb.has_breakpoint still reads the compiled bytecode" {
    import marshal;
    import from jaclang.runtime.debugger { debugger }
    with_bp = compile("breakpoint()\n", "<probe>", "exec");
    without_bp = compile("x = 1\n", "<probe>", "exec");
    assert debugger.has_breakpoint(marshal.dumps(with_bp));
    assert not debugger.has_breakpoint(marshal.dumps(without_bp));
}

# ─────────────────────────────────────────────────────────────────────
# placement: typ.__name__ -> the name carried beside the type
# ─────────────────────────────────────────────────────────────────────

# `scan_native_blockers` read `typ.__name__` off entries of a constant class
# list purely to name the offender in a diagnostic string. The name now rides
# beside the type so the runtime does no reflection. Reflection is fine HERE --
# a test is never lowered natively -- so this pins the pair against drift.
test "placement blocker tables carry the real class name" {
    import from jaclang.compiler.placement.placement {
        PLACEMENT_NATIVE_REJECT_NODES,
        PLACEMENT_SV_SIGNAL_NODES
    }
    tables = [PLACEMENT_SV_SIGNAL_NODES, PLACEMENT_NATIVE_REJECT_NODES];
    seen = 0;
    for table in tables {
        for (nd_name, typ) in table {
            assert nd_name == typ.__name__ , (
                f"placement table name {nd_name!r} drifted from {typ.__name__!r}"
            );
            seen += 1;
        }
    }
    assert seen == 3 , f"expected 3 tabled node types, saw {seen}";
}

test "scan_native_blockers names the offending node from the table" {
    import from jaclang.compiler.placement.placement { scan_native_blockers }
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "_idiom_jsx_blocker.jac"),
        use_str="def view -> any {\n    return <div>hi</div>;\n}\n",
        options=CompileOptions()
    );
    (reason, _deps) = scan_native_blockers(ir, os.path.dirname(FIXTURES));
    assert reason == "contains JsxElement" , f"got reason {reason!r}";
}

test "guardrail: @lru_cache refuses where a dict cache does not" {
    import from tests.support { native_force_opts }
    dec = JacProgram();
    dec_ir = dec.compile(
        file_path=os.path.join(FIXTURES, "_idiom_lru_cache.jac"),
        use_str="import from functools { lru_cache }\n"
        "@lru_cache(maxsize=8)\n"
        "def twice(n: int) -> int { return n * 2; }\n",
        options=native_force_opts()
    );
    errs = fmt_errors(dec);
    assert "decorator 'on twice'" in errs , (
        f"the capability gate must still name the dynamic decorator: {errs}"
    );
    assert "Python module import 'functools'" in errs , (
        "the decorator cannot be written without importing it, and a "
        "module-scope Python import has no owning callable to absorb it as "
        "a seam, so it refuses the module exactly as a bare "
        f"`import functools;` does: {errs}"
    );
    assert dec_ir.gen.llvm_ir is None , (
        "a module-fatal violation must withhold the LLVM IR"
    );
    memo = check_na_inline(
        "dict_memo",
        "glob _MEMO: dict[int, int] = {};\n"
        "def twice(n: int) -> int {\n"
        "    got = _MEMO.get(n);\n"
        "    if got is not None { return got; }\n"
        "    out = n * 2;\n"
        "    _MEMO[n] = out;\n"
        "    return out;\n"
        "}\n"
        "with entry { print(twice(3)); }\n"
    );
    assert not has_error_code(memo, "E5090") , (
        f"dict memo should clear the gate: {fmt_errors(memo)}"
    );
}
