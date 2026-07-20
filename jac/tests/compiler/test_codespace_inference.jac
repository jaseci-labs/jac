"""Tests for markerless codespace inference.

Covers the full pipeline: parse-time seeding (JSX / string-path imports),
symbol-based propagation in CodespacePullPass (scope-aware, exclusion policy),
the placement-vs-boundary edge model for `sv` imports, and the
default_codespace-driven whole-module native inference (native by default,
server signals and closure poison opt modules back out).
"""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURE_DIR = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "codespace"
     );

"""Compile a codespace fixture; stamps only (no codegen) unless cgen=True."""
def compile_fixture(name: str, cgen: bool = False) -> object {
    prog = JacProgram();
    mod = prog.compile(os.path.join(FIXTURE_DIR, name), no_cgen=not cgen);
    assert not prog.errors_had , f"{name}: {[str(e) for e in prog.errors_had]}";
    return mod;
}

"""Find a top-level element by declared name and return its stamped context."""
def stamp_of(mod: uni.Module, name: str) -> str {
    for stmt in mod.body {
        found = False;
        if (isinstance(stmt, uni.Ability) and isinstance(stmt.name_ref, uni.Name)) {
            found = stmt.name_ref.value == name;
        } elif isinstance(stmt, (uni.Archetype, uni.Enum)) {
            found = stmt.name.value == name;
        } elif isinstance(stmt, uni.GlobalVars) {
            for assign in stmt.assignments {
                for tgt in assign.target {
                    if (isinstance(tgt, uni.Name) and tgt.value == name) {
                        found = True;
                    }
                }
            }
        } elif isinstance(stmt, uni.Import) {
            if (stmt.from_loc is not None and stmt.from_loc.base_module_name == name) {
                found = True;
            }
            for item in stmt.items {
                if (
                    isinstance(item, uni.ModuleItem)
                    and isinstance(item.name, uni.Name)
                    and item.name.value == name
                ) {
                    found = True;
                } elif (
                    isinstance(item, uni.ModulePath)
                    and item.path
                    and isinstance(item.path[0], uni.Name)
                    and item.path[0].value == name
                ) {
                    found = True;
                }
            }
        }
        if found {
            return str(stmt.code_context);
        }
    }
    return 'missing';
}

test "markerless client module seeds and pulls" {
    mod = compile_fixture("infer_client_app.jac");
    assert stamp_of(mod, "clsx") == 'client' , "npm import should seed client";
    assert stamp_of(mod, "app") == 'client' , "JSX def should seed client";
    assert stamp_of(mod, "css_helper") == 'client' , "helper using npm import should be pulled client";
    assert stamp_of(mod, "click_count") == 'client' , "glob referenced from client should be pulled client";
}

test "three codespaces in one markerless module" {
    mod = compile_fixture("infer_three_spaces.jac");
    assert stamp_of(mod, "app") == 'client' , "JSX def should infer client";
    assert stamp_of(mod, "server_stats") == 'server' , "def:pub is a server endpoint, not relocated by client calls";
    assert stamp_of(mod, "Item") == 'server' , "node archetype stays server (auto-shared, never pulled)";
    assert stamp_of(mod, "list_items") == 'server' , "walker stays server (spawned via RPC)";
    assert stamp_of(mod, "os") == 'server' , "python import stays server";
    has_native_block = False;
    for stmt in mod.body {
        if isinstance(stmt, uni.NativeBlock) {
            has_native_block = True;
            for inner in stmt.body {
                if isinstance(inner, uni.ContextAwareNode) {
                    assert str(inner.code_context) == 'native' , "na block contents are native";
                }
            }
        }
    }
    assert has_native_block , "explicit na block should be preserved";
}

test "mixed module generates rpc bridges in js" {
    mod = compile_fixture("infer_three_spaces.jac", cgen=True);
    js = mod.gen.js;
    assert js.strip() , "client side of mixed module should generate JS";
    assert '__jacCallFunction("server_stats"' in js , "client call to def:pub becomes RPC";
    assert '__jacSpawn("list_items"' in js , "client spawn of walker becomes RPC spawn";
    assert 'fast_add' not in js , "native block must not leak into JS";
}

test "sv import placement is inferred while boundary fact stays" {
    mod = compile_fixture("infer_sv_client.jac", cgen=True);
    assert stamp_of(mod, "fetch_items") == 'client' , "client-consumed sv import is placed client";
    assert stamp_of(mod, "app") == 'client';
    assert stamp_of(mod, "local_report") == 'server' , "using an sv-imported name must not pull the caller client";
    js = mod.gen.js;
    assert '__jacCallFunction("fetch_items"' in js , "sv import in client placement generates RPC stub";
}

test "locals shadowing client names do not pull" {
    mod = compile_fixture("infer_shadowing.jac");
    assert stamp_of(mod, "styled") == 'client' , "real use of npm import pulls client";
    assert stamp_of(mod, "server_side") == 'server' , "shadowed names resolve to locals - no pull";
}

test "pure modules infer native under the shipped default" {
    import from jaclang.jac0core.codeinfo {
        set_effective_default_codespace,
        get_effective_default_codespace_override
    }
    _prev = get_effective_default_codespace_override();
    set_effective_default_codespace('');
    try {
        mod = compile_fixture("pure_stays_server.jac", cgen=True);
        assert mod.decided_codespace == 'native' , "the shipped default prefers native for pure modules";
        assert stamp_of(mod, "add") == 'native';
        assert stamp_of(mod, "mul_add") == 'native';
    } finally {
        set_effective_default_codespace(_prev);
    }
}

test "test blocks lower native under native default" {
    mod = compile_with_default("nadefault_with_tests.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native' , (
        "test blocks no longer block native inference"
    );
    assert mod.gen.native_engine is not None;
    names = [t.name for t in mod.gen.native_layout.tests];
    assert "test_double_works" in names;
}

test "pure modules infer native under an explicit native default" {
    mod = compile_with_default("pure_stays_server.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native' , "native default coerces pure modules";
    assert stamp_of(mod, "add") == 'native';
    assert stamp_of(mod, "mul_add") == 'native';
}

test "module-level pub endpoints keep a module server under native default" {
    mod = compile_with_default("infer_native_ffi.jac", "native");
    assert mod.decided_codespace == '' , "def:pub is a serve endpoint, a server signal";
}

test "extern decl imports seed native and pull the module" {
    mod = compile_fixture("infer_native_ffi.jac");
    assert stamp_of(mod, "fakelib") == 'native' , "extern-decl import seeds native";
    assert stamp_of(mod, "frame_count") == 'native' , "glob used by native code follows";
    assert stamp_of(mod, "Particle") == 'native' , "obj used by native code follows (no client-style auto-share for native)";
    assert stamp_of(mod, "step") == 'native';
    assert stamp_of(mod, "boot") == 'native';
    assert stamp_of(mod, "server_info") == 'server' , "unreferenced def:pub stays a server endpoint";
}

test "two colors infer independently and conflicts stay server" {
    mod = compile_fixture("infer_mixed_colors.jac");
    assert stamp_of(mod, "clsx") == 'client';
    assert stamp_of(mod, "fastlib") == 'native';
    assert stamp_of(mod, "native_calc") == 'native' , "uses extern names, joins native";
    assert stamp_of(mod, "app") == 'client';
    assert stamp_of(mod, "shared_const") == 'server' , "referenced by both colors: conflict resolves to server";
    assert stamp_of(mod, "styled_len") == 'client' , "uses npm names transitively, hard client";
    assert stamp_of(mod, "render_mixed") == 'server' , "hard-native seed use plus hard-client callee: indirect conflict resolves to server";
}

"""Compile a fixture under an explicit default codespace; resets the
process-wide effective default afterwards so later tests are unaffected."""
def compile_with_default(name: str, dcs: str, cgen: bool = False) -> object {
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.jac0core.codeinfo {
        set_effective_default_codespace,
        get_effective_default_codespace_override
    }
    _prev_dcs = get_effective_default_codespace_override();
    prog = JacProgram();
    try {
        mod = prog.compile(
            os.path.join(FIXTURE_DIR, name),
            options=CompileOptions(
                default_codespace=dcs, no_cgen=not cgen, type_check=False
            )
        );
    } finally {
        set_effective_default_codespace(_prev_dcs);
    }
    assert not prog.errors_had , f"{name}: {[str(e) for e in prog.errors_had]}";
    return mod;
}

test "pure markerless module infers native under native default" {
    mod = compile_with_default("nadefault_pure.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native' , "pure module should coerce whole-module native";
    assert stamp_of(mod, "add") == 'native';
}

test "structural match no longer forces server under native default" {
    mod = compile_with_default("nadefault_match.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native' , (
        "structural match patterns lower natively and are not server signals"
    );
}

test "pure markerless module stays server under server default" {
    mod = compile_with_default("nadefault_pure.jac", "server");
    assert mod.decided_codespace == '' , "server default keeps markerless modules undecided";
    assert stamp_of(mod, "add") == 'server';
}

test "python import keeps module server under native default" {
    mod = compile_with_default("nadefault_pyimport.jac", "native");
    assert mod.decided_codespace == '' , "python import is a server signal";
    assert stamp_of(mod, "helper") == 'server';
}

test "pure import chain infers native under native default" {
    mod = compile_with_default("nadefault_chain.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native' , "closure of pure plain modules is native";
}

test "server signal poisons the import closure" {
    mod = compile_with_default("nadefault_uses_sv.jac", "native");
    assert mod.decided_codespace == '' , "importing a server-classified module keeps the importer server";
    assert stamp_of(mod, "helper") == 'server';
}

test "import cycles infer native under native default" {
    mod = compile_with_default("nadefault_cyc_a.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native' , "cyclic pure closures lower natively";
    assert stamp_of(mod, "fa") == 'native';
    assert mod.gen.native_engine is not None , (
        "cyclic closure should produce a native engine"
    );
}

test "osp constructs keep module server under native default" {
    mod = compile_with_default("nadefault_walker.jac", "native");
    assert mod.decided_codespace == '' , "walker/node archetypes are server signals";
    assert stamp_of(mod, "Visitor") == 'server';
}

test "native default produces a native engine for pure modules" {
    mod = compile_with_default("nadefault_pure.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native';
    assert mod.gen.native_engine is not None , "inferred-native module should lower to a native engine";
}

test "variadic defs infer native under native default" {
    mod = compile_with_default("nadefault_varargs.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native' , "variadic params are native-lowerable; no demotion";
    assert mod.gen.native_engine is not None , "variadic module should lower to a native engine";
    assert stamp_of(mod, "pack_sum") == 'native';
}

test "non-lowerable pure module demotes to server under native default" {
    mod = compile_with_default("nadefault_nolower.jac", "native", cgen=True);
    assert mod.decided_codespace == '' , "demotion recompiles in the server codespace";
    assert stamp_of(mod, "build") == 'server';
}

test "implicit-ctor positional args lower natively under native default" {
    mod = compile_with_default("nadefault_posctor.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native' , (
        "positional implicit-ctor args map onto has-field order and lower"
    );
    assert mod.gen.native_engine is not None;
    assert stamp_of(mod, "make") == 'native';
}

test "cascade: importer of a demoted module demotes with it" {
    mod = compile_with_default("nadefault_uses_nolower.jac", "native", cgen=True);
    assert mod.decided_codespace == '' , "importer of a demoted dep must demote too";
}

test "closure cap exceeded skips native inference with a note" {
    import io;
    import sys;
    import from jaclang.jac0core.codeinfo { set_native_closure_cap }
    set_native_closure_cap(1);
    buf = io.StringIO();
    old_stderr = sys.stderr;
    sys.stderr = buf;
    try {
        mod = compile_with_default("nadefault_capchain_a.jac", "native", cgen=True);
    } finally {
        sys.stderr = old_stderr;
        set_native_closure_cap(0);
    }
    assert mod.decided_codespace == '' , "cap-exceeded root must stay server";
    assert stamp_of(mod, "fa") == 'server';
    assert "native_closure_cap" in buf.getvalue() , (
        f"note must name the knob, got: {buf.getvalue()!r}"
    );
}

test "capped chain still infers native under the default cap" {
    mod = compile_with_default("nadefault_capchain_a.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native' , "3-module pure chain fits default cap";
    assert mod.gen.native_engine is not None;
}

test "transitive import chain infers native under native default" {
    mod = compile_with_default("nadefault_transchain_a.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native' , (
        "a -> b -> c transitive pure chain must lower native"
    );
    assert mod.gen.native_engine is not None;
}

test "census records demotion with first error code" {
    import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
    na_census_begin();
    try {
        compile_with_default("nadefault_nolower.jac", "native", cgen=True);
    } finally {
        census = na_census_end();
    }
    rec = census.get(
        os.path.realpath(os.path.join(FIXTURE_DIR, "nadefault_nolower.jac"))
    );
    assert rec is not None , "demoted module missing from census";
    assert rec['outcome'] == 'demoted' , f"expected demoted, got {rec}";
    assert rec['code'] == 'E5092' , f"expected first-error code, got {rec}";
}

test "census records native and server outcomes" {
    import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
    na_census_begin();
    try {
        compile_with_default("nadefault_pure.jac", "native", cgen=True);
        compile_with_default("nadefault_walker.jac", "native", cgen=True);
    } finally {
        census = na_census_end();
    }
    pure = census.get(
        os.path.realpath(os.path.join(FIXTURE_DIR, "nadefault_pure.jac"))
    );
    blocked = census.get(
        os.path.realpath(os.path.join(FIXTURE_DIR, "nadefault_walker.jac"))
    );
    assert pure is not None and pure['outcome'] == 'native' , f"got {pure}";
    assert blocked is not None and blocked['outcome'] == 'server' , f"got {blocked}";
    assert blocked['detail'] != '' , "server record must carry the classifier reason";
}

test "include chain infers native under native default" {
    mod = compile_with_default("nadefault_star_main.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native' , (
        "from-import of an include re-exporter must lower native"
    );
    assert mod.gen.native_engine is not None;
}

test "include chain stays server under server default" {
    mod = compile_with_default("nadefault_star_main.jac", "server");
    assert mod.decided_codespace == '' , (
        "server default keeps include chains undecided"
    );
}

test "bare jac import infers native under native default" {
    mod = compile_with_default("nadefault_bare.jac", "native", cgen=True);
    assert mod.decided_codespace == 'native' , (
        "bare import of a resolvable plain .jac module is a dep edge, not a "
        "server signal"
    );
    assert mod.gen.native_engine is not None;
}

test "aliased bare jac import stays server under native default" {
    mod = compile_with_default("nadefault_bare_alias.jac", "native");
    assert mod.decided_codespace == '' , (
        "aliased bare imports are not lowered natively (call sites key on the "
        "alias, which never matches the module symbol set)"
    );
}

test "bare import of a cl module stays server under native default" {
    mod = compile_with_default("nadefault_bare_cl.jac", "native");
    assert mod.decided_codespace == '' , (
        "a .cl.jac sibling is a cl/sv server signal even when its body has no "
        "other signals"
    );
}

test "explicit .na.jac mandate still fails loudly" {
    import from jaclang.jac0core.compile_options { CompileOptions }
    prog = JacProgram();
    prog.compile(
        os.path.join(FIXTURE_DIR, "nadefault_mandate.na.jac"),
        options=CompileOptions(type_check=False)
    );
    assert prog.errors_had , "explicit native modules must surface lowering errors";
}
