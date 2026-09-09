"""The analysis cache serves warm work; recompute happens only on a miss.

Acceptance shape of jaseci-labs/jac#8836, asserted through the pass and
cache-event counters rather than timing: a warm no-edit check replays
persisted diagnostics with zero passes; dependency ingestion hydrates
from SEC_IFACE without touching the dep's source pipeline; a body-only
dep edit recompiles the dep but does not cascade (interface hash
cutoff); an interface edit does cascade; JAC_REBUILD recomputes and
rewrites with identical results; verify mode recomputes what was served
and fails loudly when the cache lies.

Every test builds its own throwaway project in a tempdir, whose cache
lands in <srcdir>/.jac/cache, so tests are isolated from each other and
from the user's real cache.
"""

import json;
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.jir {
    HEADER_SIZE,
    SEC_BYTECODE,
    SEC_DEPS,
    SEC_DIAG,
    SEC_IFACE,
    SECTIONS_MAGIC,
    compiler_source_digest,
    get_module_cache_path,
    parse_header,
    read_section_bytes,
    read_sections,
    write_module_cache,
    write_precompiled_jir,
    _manifest_compiler_digest
}
import from jaclang.compiler.types.stubcat.modiface { read_iface_hash }

glob DEP_V1: str = "def f() -> int { return 1; }\n",
     DEP_V1_BODY_EDIT: str = "def f() -> int { return 2; }\n",
     DEP_V2_SIGNATURE: str = "def f(x: int) -> int { return x; }\n",
     MAIN_SRC: str = "import from depmod { f }\n\nwith entry { print(f()); }\n";

def _project(dep_body: str = "") -> tuple[str, str] {
    tmp = tempfile.mkdtemp();
    dep = os.path.join(tmp, "depmod.jac");
    with open(dep, "w") as fh {
        fh.write(dep_body or DEP_V1);
    }
    main = os.path.join(tmp, "mainmod.jac");
    with open(main, "w") as fh {
        fh.write(MAIN_SRC);
    }
    return (os.path.realpath(main), os.path.realpath(dep), );
}

def _check_opts -> CompileOptions {
    return CompileOptions(
        no_cgen=True, native_parity=True, force_target_program=True, iface_ok=True
    );
}

def _check(main: str) -> tuple[JacProgram, list[str]] {
    prog = JacProgram();
    prog.compile(main, options=_check_opts());
    rendered = sorted(
        [a.pretty_print() for a in prog.errors_had]
            + [a.pretty_print() for a in prog.warnings_had]
    );
    return (prog, rendered, );
}

def _rewrite(path: str, content: str) {
    import time;
    with open(path, "w") as fh {
        fh.write(content);
    }
    future = time.time() + 2.0;
    os.utime(path, (future, future));
}

test "a checked module persists interface, deps, and diagnostics sections" {
    (main, dep) = _project();
    (prog, _diags) = _check(main);
    main_jir = get_module_cache_path(main);
    dep_jir = get_module_cache_path(dep);
    assert main_jir.exists() , "the checked module wrote no cache JIR";
    assert dep_jir.exists() , "the dependency wrote no cache JIR";
    main_data = main_jir.read_bytes();
    assert read_section_bytes(main_data, SEC_IFACE) is not None , "no SEC_IFACE";
    assert read_section_bytes(main_data, SEC_DIAG) is not None , "no SEC_DIAG";
    deps_raw = read_section_bytes(main_data, SEC_DEPS);
    assert deps_raw is not None , "no SEC_DEPS";
    assert dep.encode() in deps_raw , "SEC_DEPS does not record the dependency";
    dep_iface = read_section_bytes(dep_jir.read_bytes(), SEC_IFACE);
    assert dep_iface is not None , "the dependency persisted no interface";
}

test "a warm no-edit check replays diagnostics and runs zero passes" {
    (main, dep) = _project();
    (cold_prog, cold_diags) = _check(main);
    assert cold_prog.analysis.pass_runs , "the cold run should have run passes";
    (warm_prog, warm_diags) = _check(main);
    events = warm_prog.analysis.cache_events;
    assert events.get("analysis_replay", 0) == 1 , (
        f"warm check did not replay (events: {events})"
    );
    assert not warm_prog.analysis.pass_runs , (
        f"warm no-edit check ran passes: {sorted(warm_prog.analysis.pass_runs)}"
    );
    assert warm_diags == cold_diags , "warm diagnostics diverge from cold";
}

test "dependency ingestion hydrates from the interface, not the source" {
    (main, dep) = _project();
    _check(main);
    prog = JacProgram();
    mod = prog.load_dependency_module(dep);
    events = prog.analysis.cache_events;
    assert events.get("dep_hydrate", 0) == 1 , (
        f"the dependency was not hydrated (events: {events})"
    );
    assert "SymTabBuildPass" not in prog.analysis.pass_runs , (
        "hydrating a dependency ran its frontend"
    );
    assert mod.stub_only , "a hydrated dependency should be interface-only";
    assert "f" in mod.names_in_scope , "the hydrated interface lost a symbol";
}

test "a body-only dependency edit does not cascade to the importer" {
    (main, dep) = _project();
    (_cold, cold_diags) = _check(main);
    _rewrite(dep, DEP_V1_BODY_EDIT);
    (warm_prog, warm_diags) = _check(main);
    events = warm_prog.analysis.cache_events;
    assert events.get("dep_miss_compile", 0) >= 1 , (
        "the edited dependency was not recompiled"
    );
    assert events.get("analysis_replay", 0) == 1 , (
        f"a body-only dep edit cascaded into the importer (events: {events})"
    );
    assert "TypeCheckPass" not in warm_prog.analysis.pass_runs , (
        "a body-only dep edit re-analyzed the importer"
    );
    assert warm_diags == cold_diags , "diagnostics changed on a body-only edit";
}

test "an interface edit re-analyzes the importer" {
    (main, dep) = _project();
    (_cold, cold_diags) = _check(main);
    assert not cold_diags , f"expected a clean cold check, got {cold_diags}";
    _rewrite(dep, DEP_V2_SIGNATURE);
    (warm_prog, _warm_diags) = _check(main);
    events = warm_prog.analysis.cache_events;
    assert events.get("analysis_replay", 0) == 0 , (
        "a signature change was served from the stale analysis cache"
    );
    assert "TypeCheckPass" in warm_prog.analysis.pass_runs , (
        "the importer was not re-analyzed after a signature change"
    );
    assert len(warm_prog.errors_had) > 0 , (
        "the arity error from the signature change was not reported"
    );
}

test "JAC_REBUILD recomputes, rewrites, and matches the cold results" {
    (main, dep) = _project();
    (_cold, cold_diags) = _check(main);
    prior = os.environ.get("JAC_REBUILD");
    os.environ["JAC_REBUILD"] = "1";
    try {
        (rebuild_prog, rebuild_diags) = _check(main);
    } finally {
        if prior is None {
            del os.environ["JAC_REBUILD"];
        } else {
            os.environ["JAC_REBUILD"] = prior;
        }
    }
    events = rebuild_prog.analysis.cache_events;
    assert events.get("analysis_replay", 0) == 0 , (
        "JAC_REBUILD still served from the analysis cache"
    );
    assert rebuild_prog.analysis.pass_runs , "JAC_REBUILD ran no passes";
    assert rebuild_diags == cold_diags , "JAC_REBUILD changed the results";
    (warm_prog, _d) = _check(main);
    assert warm_prog.analysis.cache_events.get("analysis_replay", 0) == 1 , (
        "the rebuild did not leave a hydratable cache behind"
    );
}

test "bytecode and analysis sections share one merged cache JIR" {
    (main, _dep) = _project();
    _check(main);
    wrote = write_module_cache(main, b"fake-bytecode");
    assert wrote , "the merge write was refused";
    data = get_module_cache_path(main).read_bytes();
    assert read_section_bytes(data, SEC_BYTECODE) == b"fake-bytecode";
    assert read_section_bytes(data, SEC_IFACE) is not None , (
        "writing bytecode dropped the analysis sections"
    );
    assert read_section_bytes(data, SEC_DIAG) is not None , (
        "writing bytecode dropped the diagnostics section"
    );
}

test "verify mode accepts an honest cache and rejects a corrupted one" {
    (main, dep) = _project();
    _check(main);
    prior = os.environ.get("JAC_IFACE_VERIFY");
    os.environ["JAC_IFACE_VERIFY"] = "1";
    try {
        (honest_prog, _d) = _check(main);
        assert honest_prog.analysis.cache_events.get("analysis_replay", 0) == 1 , (
            "verify mode must still serve from the cache"
        );

        cache_path = get_module_cache_path(main);
        data = cache_path.read_bytes();
        header = parse_header(data[:HEADER_SIZE]);
        assert header is not None;
        magic: any = SECTIONS_MAGIC;
        pos = data.find(magic, HEADER_SIZE);
        secs = read_sections(data, pos + len(magic));
        payload = json.loads(secs[SEC_DIAG].decode("utf-8"));
        for prof in payload["profiles"].values() {
            prof["errors"].append(
                {
                    "msg": "planted divergence",
                    "code": None,
                    "help": None,
                    "span": [main, 1, 1, 0, 0, 0, 0, "", 0, 0],
                    "related": []
                }
            );
        }
        secs[SEC_DIAG] = json.dumps(payload).encode("utf-8");
        cache_path.write_bytes(write_precompiled_jir(None, "", header.flags, secs));
        caught = False;
        try {
            _check(main);
        } except RuntimeError {
            caught = True;
        }
        assert caught , "verify mode accepted diagnostics the compiler never made";
    } finally {
        if prior is None {
            del os.environ["JAC_IFACE_VERIFY"];
        } else {
            os.environ["JAC_IFACE_VERIFY"] = prior;
        }
    }
}

test "the compiler digest manifest reproduces the full sweep exactly" {
    pkg = tempfile.mkdtemp();
    comp = Path(pkg) / "compiler";
    comp.mkdir();
    (comp / "a.jac").write_text("with entry { print(1); }\n");
    (comp / "b.py").write_text("x = 1\n");
    full = compiler_source_digest(pkg);
    assert _manifest_compiler_digest(pkg) == full , "manifest digest diverged";
    assert _manifest_compiler_digest(pkg) == full , "second (stat-only) run diverged";
    import time;
    (comp / "a.jac").write_text("with entry { print(2); }\n");
    future = time.time() + 2.0;
    os.utime(comp / "a.jac", (future, future));
    changed = compiler_source_digest(pkg);
    assert changed != full;
    assert _manifest_compiler_digest(pkg) == changed , (
        "manifest digest missed an edited file"
    );
}

test "a third-party Python dependency is fingerprinted, never compiled as a target" {
    # A byllm fixture imports litellm, and the sealed in-package lane died
    # on it: `.py` under site-packages counted as a cacheable dependency, so
    # a cache miss compiled it as an interface target, whose interface walk
    # loaded everything it imported, each of which missed and compiled in
    # turn -- 1,450 litellm modules and 14 GB on a 16 GB runner. Third-party
    # Python is opaque to the cutoff now, the way typeshed stubs are: its
    # row carries a content digest, no miss ever compiles it, and it is
    # never served or persisted as an interface target.
    import sys;
    import from jaclang.compiler.driver.jir { compute_stub_module_key }
    tmp = tempfile.mkdtemp();
    sp = os.path.join(tmp, "site-packages");
    pkg = os.path.join(sp, "thirdmod");
    os.makedirs(pkg);
    with open(os.path.join(pkg, "__init__.py"), "w") as fh {
        fh.write("from .sub import helper\n\n__all__ = ['helper']\n");
    }
    with open(os.path.join(pkg, "sub.py"), "w") as fh {
        fh.write("from .deep import base\n\ndef helper() -> int:\n    return base()\n");
    }
    with open(os.path.join(pkg, "deep.py"), "w") as fh {
        fh.write("def base() -> int:\n    return 7\n");
    }
    main = os.path.join(tmp, "usesthird.jac");
    with open(main, "w") as fh {
        fh.write(
            "import from thirdmod { helper }\n\nwith entry { print(helper()); }\n"
        );
    }
    main = os.path.realpath(main);
    init_py = os.path.realpath(os.path.join(pkg, "__init__.py"));
    sys.path.insert(0, sp);
    try {
        (prog, rendered) = _check(main);
        assert not prog.errors_had , f"the third-party import did not check clean: {rendered}";
        events = prog.analysis.cache_events;
        assert events.get("dep_miss_compile", 0) == 0 , (
            f"a site-packages module was compiled as a dependency target (events: {events})"
        );
        for name in ("__init__.py", "sub.py", "deep.py") {
            leaf = os.path.realpath(os.path.join(pkg, name));
            assert not get_module_cache_path(leaf).exists() , (
                f"{name} got its own cache entry; third-party Python must stay opaque"
            );
        }
        reg = prog.iface_registry();
        compiler = prog._get_compiler();
        assert not reg.eligible(compiler, init_py, _check_opts()) , "a site-packages module must never be served or persisted as an interface target";
        before = dict(reg.prog.analysis.cache_events);
        assert reg.ensure(init_py) is None , "ensure() must not manufacture an entry for third-party Python";
        assert reg.prog.analysis.cache_events.get("dep_miss_compile", 0)
            == before.get("dep_miss_compile", 0) , "ensure() compiled a site-packages module on a miss";
        assert not get_module_cache_path(init_py).exists() , "ensure() wrote a cache entry for third-party Python";
        reg.frame_push(main);
        try {
            reg.note_dep(init_py);
        } finally {
            reg.frame_pop();
        }
        rows = reg.direct_deps.get(main, {});
        assert rows.get(init_py) == compute_stub_module_key(init_py) , f"a third-party Python dependency is fingerprinted by content, like a stub (rows: {rows})";
    } finally {
        if sp in sys.path {
            sys.path.remove(sp);
        }
    }
}

test "an analysis that ended in errors is not memoized for replay" {
    (main, dep) = _project();
    _rewrite(
        main,
        "import from depmod { f }\n\nwith entry { print(f() + undefined_name); }\n"
    );
    (cold_prog, cold_diags) = _check(main);
    assert cold_prog.errors_had , "the fixture must fail analysis to be meaningful";
    (warm_prog, warm_diags) = _check(main);
    events = warm_prog.analysis.cache_events;
    assert events.get("analysis_replay", 0) == 0 , (
        f"a failed analysis was replayed from cache (events: {events})"
    );
    assert warm_prog.analysis.pass_runs , "the warm check of a failed module must re-run analysis";
    assert len(warm_prog.errors_had) == len(cold_prog.errors_had) , (
        "re-analysis must report the same errors as the cold run"
    );
}

test "a compile acting on an inferred native verdict persists no interface" {
    # Only the codegen flavor runs the native verdict for a marker-less
    # module in a native-default project, and a module analyzed under it
    # exports native typing that dependency ingestion and jac check never
    # see. Its persist must leave the analysis-flavor interface on disk, or
    # every importer's cutoff row flips with whichever flavor ran last.
    (main, dep) = _project();
    ana = JacProgram();
    ana.compile(dep, options=_check_opts());
    before = read_iface_hash(
        read_section_bytes(get_module_cache_path(dep).read_bytes(), SEC_IFACE)
    );
    gen = JacProgram();
    gen.compile(dep);
    after = read_iface_hash(
        read_section_bytes(get_module_cache_path(dep).read_bytes(), SEC_IFACE)
    );
    mod = gen.mod.hub.get(dep);
    assert mod is not None , "the codegen compile left no module in the hub";
    if mod.decided_codespace == "native" {
        assert mod.codespace_inferred , "a marker-less native verdict must be marked inferred";
    }
    assert before == after , (
        f"a codegen compile rewrote the interface: {before} vs {after}"
    );
    # The rule itself, on a machine whose native toolchain may not let the
    # verdict pass: an inferred verdict skips the interface, a declared one
    # reaches it through the analysis flavor; codegen never encodes.
    reg = gen.iface_registry();
    encodes = reg.prog.analysis.cache_events.get("iface_encode", 0);
    mod.decided_codespace = "native";
    mod.codespace_inferred = True;
    reg.persist_after_compile(dep, mod, CompileOptions(), 0, 0);
    assert reg.prog.analysis.cache_events.get("iface_encode", 0) == encodes , "an inferred verdict was encoded into an interface";
    assert read_iface_hash(
        read_section_bytes(get_module_cache_path(dep).read_bytes(), SEC_IFACE)
    )
        == before , "an inferred verdict overwrote the persisted interface";
    mod.codespace_inferred = False;
    reg.persist_after_compile(dep, mod, CompileOptions(), 0, 0);
    assert read_iface_hash(
        read_section_bytes(get_module_cache_path(dep).read_bytes(), SEC_IFACE)
    )
        == before , "a codegen persist of a declared placement encoded an interface";
    reg.persist_after_compile(dep, mod, _check_opts(), 0, 0);
    assert read_iface_hash(
        read_section_bytes(get_module_cache_path(dep).read_bytes(), SEC_IFACE)
    )
        != before , "a declared native placement must reach the interface";
}

test "the interface-bytes memo outlives the compile closure" {
    # Encoding an interface forces every exported symbol's type, which pulls
    # the module's dependencies in; re-persisting an unchanged module (the
    # client-boundary walk re-enters package modules dozens of times per
    # unit) must reuse the encoded bytes across closures instead of paying
    # that again.
    (main, dep) = _project();
    prog = JacProgram();
    mod = prog.compile(dep, options=_check_opts());
    reg = prog.iface_registry();
    events = prog.analysis.cache_events;
    assert events.get("iface_encode", 0) == 1 , f"the cold persist did not encode (events: {events})";
    prog.release_compile_closure();
    reg.persist_after_compile(dep, mod, _check_opts(), 0, 0);
    events = prog.analysis.cache_events;
    assert events.get("iface_persist", 0) == 2 , f"expected a second persist of the unchanged module (events: {events})";
    assert events.get("iface_encode", 0) == 1 , f"the unchanged module was re-encoded after closure release (events: {events})";
}

glob NARROW_DEP: str = """
obj Info {
    has help_text: str = "";
}

obj Alert {
    has code: (Info | None) = None,
        help_text: (str | None) = None;

    def postinit {
        if (self.help_text is None) and self.code {
            self.help_text = self.code.help_text;
        }
    }
}
""",
     NARROW_MAIN: str = "import type from depmod { Alert }\n\ndef show(a: Alert) -> str { return str(a.help_text); }\n\nwith entry { print(show); }\n";

test "persisting a dependency interface neither reports nor mistypes its narrowing sites" {
    (main, dep) = _project(NARROW_DEP);
    with open(main, "w") as fh {
        fh.write(NARROW_MAIN);
    }
    (prog, rendered) = _check(main);
    assert rendered == [] , (
        "a type-only import compiled its dependency lazily inside the type "
        f"checker and persisting that interface leaked diagnostics: {rendered}"
    );
    events = prog.analysis.cache_events;
    assert events.get("iface_encode", 0) >= 2 , (
        f"expected both modules to be encoded on a cold cache (events: {events})"
    );
    assert events.get("iface_cfg", 0) >= 1 , (
        f"the dependency's flow graph must be built before its interface is forced (events: {events})"
    );
}

test "a tree-demanding closure does not disable hydration for later compiles" {
    # need_full_ast is a closure's demand (code intelligence, native-decided
    # targets): it must flow to that closure's dependency ingestion and stop
    # there. It was read from the program's last options instead, so one
    # such compile turned hydration off for the rest of the program's life;
    # in the check pool that is every target after the first native one.
    (main, dep) = _project();
    _check(main);
    prog = JacProgram();
    prog.compile(
        main,
        options=CompileOptions(
            no_cgen=True, force_target_program=True, need_full_ast=True
        )
    );
    assert prog.analysis.cache_events.get("dep_hydrate", 0) == 0 , "a tree-demanding closure must not hydrate its dependencies";
    prog.release_compile_closure();
    prog.load_dependency_module(dep);
    events = prog.analysis.cache_events;
    assert events.get("dep_hydrate", 0) == 1 , (
        f"hydration stayed off after the tree-demanding closure ended (events: {events})"
    );
}

test "a module-level comprehension variable is not part of the interface" {
    # Comprehension scopes are Python scopes; their loop variables must not
    # be exported as module members (the writer walked them as block scopes,
    # and name-level verify flagged every such module as diverging).
    (main, dep) = _project(
        "glob NAMES: set = {v for v in ['a', 'b']};\ndef f() -> int { return 1; }\n"
    );
    _check(main);
    prog = JacProgram();
    mod = prog.load_dependency_module(dep);
    assert prog.analysis.cache_events.get("dep_hydrate", 0) == 1 , "the dependency was not hydrated";
    names = set(mod.names_in_scope.keys());
    assert "NAMES" in names and "f" in names , f"exports lost: {sorted(names)}";
    assert "v" not in names , "a comprehension variable leaked into the interface";
}

test "an interface is identical however many twins of its module are reachable" {
    # A long-lived program (the compiler's own, here) can hold an older tree
    # of a module through memoized types when the module is compiled again in
    # a fresh program; the writer keyed scopes and symbols by object identity
    # while judging the boundary by path, so both twins were emitted and the
    # second interface carried every name twice with a different digest.
    import from tests.support { JAC_ROOT }
    import from jaclang.compiler.types.stubcat.locate { jaclang_pkg_dir }
    import from jaclang.compiler.types.stubcat.modiface {
        build_module_iface,
        open_module_iface,
        iface_module
    }
    target = os.path.join(
        JAC_ROOT,
        "jaclang",
        "compiler",
        "backends",
        "native",
        "llvm",
        "ir",
        "__init__.jac"
    );
    pkg = jaclang_pkg_dir();
    digests: list[str] = [];
    names: list[int] = [];
    for i in range(2) {
        prog = JacProgram();
        mod = prog.compile(
            target,
            options=CompileOptions(
                no_cgen=True,
                symtab_ir_only=True,
                force_target_program=True,
                need_full_ast=True
            )
        );
        payload = build_module_iface(mod, prog.get_type_evaluator(), pkg);
        digests.append(read_iface_hash(payload) or "");
        cat = open_module_iface(payload, pkg);
        served = iface_module(cat) if cat is not None else None;
        names.append(len(served.names_in_scope) if served is not None else -1);
    }
    assert digests[0] == digests[1] , f"the interface digest changed between two compiles of one module: {digests}";
    assert names[0] == names[1] , f"the interface's name count changed between compiles: {names}";
}

test "a comptime import takes the dependency's tree and rides its edits" {
    # A comptime import needs the dependency's values, which an interface
    # does not carry: served from the cache, the initializer was "not known
    # at compile time" (false E0033s on every warm check). And a value edit
    # that leaves the interface unchanged must still re-analyze the importer.
    tmp = tempfile.mkdtemp();
    dep = os.path.join(tmp, "routes.jac");
    main = os.path.join(tmp, "app.jac");
    with open(dep, "w") as fh {
        fh.write('comptime ROUTES: list[str] = ["home", "about"];\n');
    }
    with open(main, "w") as fh {
        fh.write(
            "comptime import from routes { ROUTES }\n"
            "comptime NAMES: list[str] = ROUTES;\n"
            "comptime assert len(NAMES) == 2;\n"
            "with entry { print(NAMES); }\n"
        );
    }
    main = os.path.realpath(main);
    dep = os.path.realpath(dep);
    (cold, cold_diags) = _check(main);
    assert not cold.errors_had , f"cold: {cold_diags}";
    _rewrite(main, open(main).read() + "# touched\n");
    (warm, warm_diags) = _check(main);
    assert not warm.errors_had , f"the importer re-analyzed against the cached dependency: {warm_diags}";
    assert warm.analysis.cache_events.get("dep_hydrate", 0) == 0 , (
        f"a comptime import was served from the interface (events: {warm.analysis.cache_events})"
    );
    _rewrite(dep, 'comptime ROUTES: list[str] = ["home", "about", "help"];\n');
    (edited, edited_diags) = _check(main);
    assert edited.errors_had , "a comptime value edit that keeps the interface did not re-analyze the importer";
    assert edited.analysis.cache_events.get("analysis_replay", 0) == 0 , (
        f"the importer replayed stale diagnostics after a comptime input changed (events: {edited.analysis.cache_events})"
    );
}

glob TWIN_MODEL: str = (
         "obj Cfg {\n" "    has x: int = 1,\n" "        name: str = \"cfg\";\n" "}\n"
     ),
     TWIN_ENV: str = (
         "import from models { Cfg }\n\n"
         "obj Env {\n"
         "    has config: Cfg;\n\n"
         "    def get -> Cfg {\n"
         "        return self.config;\n"
         "    }\n"
         "}\n"
     ),
     TWIN_PROVIDER: str = (
         "import from env { Env }\n"
         "import from models { Cfg }\n\n"
         "obj Prov(Env) {\n"
         "    def make -> Cfg {\n"
         "        return Cfg(x=self.config.x + 1);\n"
         "    }\n"
         "}\n"
     ),
     TWIN_MAIN: str = (
         "import from provider { Prov }\n"
         "import from models { Cfg }\n\n"
         "with entry {\n"
         "    p = Prov(config=Cfg());\n"
         "    print(p.make().x, p.get().name);\n"
         "}\n"
     );

def _twin_project -> dict[str, str] {
    tmp = tempfile.mkdtemp();
    paths: dict[str, str] = {};
    for (name, body) in (
        ("models", TWIN_MODEL),
        ("env", TWIN_ENV),
        ("provider", TWIN_PROVIDER),
        ("main", TWIN_MAIN)
    ) {
        path = os.path.join(tmp, f"{name}.jac");
        with open(path, "w") as fh {
            fh.write(body);
        }
        paths[name] = os.path.realpath(path);
    }
    return paths;
}

def _class_scope(prog: JacProgram, path: str, name: str) -> any {
    import from jaclang.compiler.types.types { ClassType }
    mod = prog.mod.hub[path];
    sym = mod.names_in_scope[name];
    typ = prog.get_type_evaluator().get_type_of_symbol(sym);
    assert isinstance(typ, ClassType) , f"{name} is not a class: {typ}";
    return typ.shared.symbol_table;
}

test "a class shared follows the tree the program holds for its module" {
    # A runtime import recompiles a dependency that analysis loaded as a
    # symbol-table-only tree: the old tree leaves the hub and is collected,
    # which severs its scopes from their module. The evaluator interns one
    # shared per class site, so every type handed out so far points at the
    # class scope of that dead tree; an interface written afterwards could
    # neither cross-reference it (no module) nor record it locally (no
    # scope), and read back as a class without members (jac#8909).
    import gc;
    paths = _twin_project();
    prog = JacProgram();
    prog.compile(paths["main"], options=CompileOptions());
    first = _class_scope(prog, paths["models"], "Cfg");
    assert first is prog.mod.hub[paths["models"]].find_scope("Cfg") , "the interned class does not point at the hub's tree after the first compile";
    prog.invalidate_module(paths["models"]);
    gc.collect();
    prog.compile(paths["models"], options=CompileOptions());
    live = prog.mod.hub[paths["models"]].find_scope("Cfg");
    assert live is not first , "the recompile did not produce a new tree";
    assert _class_scope(prog, paths["models"], "Cfg") is live , "the interned class still points at the evicted tree's scope";
    prog.invalidate_module(paths["provider"]);
    gc.collect();
    prog.compile(paths["provider"], options=CompileOptions());
    assert not prog.errors_had , [a.pretty_print() for a in prog.errors_had];
    # Interfaces are written by analysis-driven closures, so the program that
    # holds the intern encodes each module itself; a fresh check of the
    # importer must then hydrate those interfaces and see every member.
    for name in ("models", "env", "provider") {
        prog.compile(paths[name], options=_check_opts());
    }
    assert not prog.errors_had , [a.pretty_print() for a in prog.errors_had];
    (warm, diags) = _check(paths["main"]);
    assert not warm.errors_had , f"the importer read a member-less class from the cache: {diags}";
    assert warm.analysis.cache_events.get("dep_hydrate", 0) > 0 , (
        f"the dependencies were not served from the interface cache (events: {warm.analysis.cache_events})"
    );
}

test "an interface that cannot place a class is not persisted" {
    # The writer decides between a cross-reference and a local record by
    # the module above the class scope. With no module there is no honest
    # record, and a record with an empty scope is a lie every later compile
    # would trust (the dependency digests still match). The builder refuses,
    # and the persist step leaves the cache untouched for this compile.
    import from jaclang.compiler.types.stubcat.locate { jaclang_pkg_dir }
    import from jaclang.compiler.types.stubcat.modiface {
        IncoherentInterface,
        build_module_iface
    }
    paths = _twin_project();
    prog = JacProgram();
    prog.compile(
        paths["provider"],
        options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    _class_scope(prog, paths["models"], "Cfg").parent_scope = None;
    provider = prog.mod.hub[paths["provider"]];
    refused = False;
    try {
        build_module_iface(provider, prog.get_type_evaluator(), jaclang_pkg_dir());
    } except IncoherentInterface as exc {
        refused = True;
        assert any("Cfg" in o for o in exc.orphans) , f"the refusal does not name the unplaceable class: {exc.orphans}";
    }
    assert refused , "an interface with an unplaceable class was built";
    cache_path = get_module_cache_path(paths["provider"]);
    before = cache_path.read_bytes() if cache_path.exists() else b"";
    reg = prog.iface_registry();
    reg.forget(paths["provider"]);
    reg.persist_after_compile(paths["provider"], provider, prog.options, 0, 0);
    assert prog.analysis.cache_events.get("iface_incoherent", 0) == 1 , (
        f"the persist step did not record the refusal (events: {prog.analysis.cache_events})"
    );
    after = cache_path.read_bytes() if cache_path.exists() else b"";
    assert after == before , "an incoherent interface was written to the cache";
}

test "a cross-reference into a stub is answered by the catalog" {
    # A hub can hold a source-parsed tree of a typeshed stub (the compiler's
    # own bootstrap keeps those); its module scope lacks the names a
    # version guard declares, so resolving a cross-reference through it
    # produced an orphan class. The catalog is the authority for stubs.
    import from jaclang.compiler.types.stubcat.locate { jaclang_pkg_dir }
    stub = os.path.join(jaclang_pkg_dir(), "vendor", "typeshed", "stdlib", "types.pyi");
    prog = JacProgram();
    served = prog.iface_registry().resolve_module(stub);
    assert served is not None , "the stub could not be resolved";
    assert served.names_in_scope.get("NoneType") is not None , (
        f"the stub resolved to a tree without NoneType: {type(served).__name__}"
    );
    shared = prog.iface_registry().resolve_shared(stub, "NoneType", "NoneType");
    assert shared is not None , "NoneType did not resolve to a class";
}

test "a codegen compile records dependency rows but encodes no interface" {
    (main, dep) = _project();
    prog = JacProgram();
    prog.compile(main, options=CompileOptions(force_target_program=True));
    data = get_module_cache_path(main).read_bytes();
    assert read_section_bytes(data, SEC_DEPS) is not None , "no SEC_DEPS after codegen";
    assert read_section_bytes(data, SEC_IFACE) is None , (
        "a codegen compile encoded an interface; encoding belongs to the frontier"
    );
    assert prog.analysis.cache_events.get("iface_encode", 0) == 0 , (
        f"codegen compile encoded (events: {prog.analysis.cache_events})"
    );
    _check(main);
    data = get_module_cache_path(main).read_bytes();
    assert read_section_bytes(data, SEC_IFACE) is not None , (
        "the frontier compile did not add the interface to the merged JIR"
    );
    assert read_section_bytes(data, SEC_DEPS) is not None , (
        "the frontier merge dropped the dependency rows"
    );
}
