"""Per-compilation GraphMend facts: they live on the compiled module's gen."""
import ast;
import os;
import jaclang.jac0core.unitree as uni;
import from tests.support { GRAPHMEND_FIXTURES as FIXTURES }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { JacCompiler }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.main.graphmend.graph_break_detect_pass {
    GraphBreakDetectPass
}

"""Compile a fixture with graphmend on under a fresh program and return the
compiled module; its facts are read straight off `mod.gen`."""
def _compile_gm(name: str) -> any {
    return JacProgram().compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(graphmend=True, type_check=False)
    );
}

"""Unparse a compiled module's generated Python source."""
def _unparse(mod: any) -> str {
    pa = mod.gen.py_ast;
    return ast.unparse(pa[0] if isinstance(pa, list) else pa);
}

"""Find the single top-level ability named `f` in a compiled module."""
def _entry_ability(mod: any) -> uni.Ability {
    found: (uni.Ability | None) = None;
    for ab in mod.get_all_sub_nodes(uni.Ability) {
        if ab.sym_name == 'f' {
            found = ab;
        }
    }
    assert found is not None;
    return found;
}

test "an interleaved compile does not clobber the in-flight break table" {
    # Splits the codegen schedule after detection and runs a second graphmend
    # compile on the same program, the shape of concurrent language-server
    # compiles; the outer compile's guard must still lower.
    prog = JacProgram();
    orig = JacCompiler.run_schedule;
    state = {"interleaved": False};
    def _spy(
        self: any, mod: any, target_program: any, passes: any, cancel_token: any = None
    ) {
        is_entry = str(mod.loc.mod_path).endswith("val_guard.jac");
        if state["interleaved"]
            or (GraphBreakDetectPass not in passes)
            or not is_entry {
            orig(self, mod, target_program, passes, cancel_token);
            return;
        }
        state["interleaved"] = True;
        i = passes.index(GraphBreakDetectPass);
        orig(self, mod, target_program, passes[:i + 1], cancel_token);
        target_program.get_bytecode(os.path.join(FIXTURES, "side_effect.jac"));
        orig(self, mod, target_program, passes[i + 1:], cancel_token);
    }
    JacCompiler.run_schedule = _spy;
    try {
        mod = prog.compile(
            file_path=os.path.join(FIXTURES, "val_guard.jac"),
            options=CompileOptions(graphmend=True, type_check=False)
        );
    } finally {
        JacCompiler.run_schedule = orig;
    }
    assert state["interleaved"] , "the interleaved compile never ran";
    src = _unparse(mod);
    assert "__jac_tensor_eq_assert__" in src , (
        "the interleaved compile wiped the outer break table"
    );
}

test "an interleaved compile records its facts on its own module" {
    prog = JacProgram();
    orig = JacCompiler.run_schedule;
    state = {"interleaved": False};
    def _spy(
        self: any, mod: any, target_program: any, passes: any, cancel_token: any = None
    ) {
        is_entry = str(mod.loc.mod_path).endswith("val_guard.jac");
        if state["interleaved"]
            or (GraphBreakDetectPass not in passes)
            or not is_entry {
            orig(self, mod, target_program, passes, cancel_token);
            return;
        }
        state["interleaved"] = True;
        i = passes.index(GraphBreakDetectPass);
        orig(self, mod, target_program, passes[:i + 1], cancel_token);
        # compile() rather than get_bytecode(): a bytecode-cache hit would skip
        # the passes entirely and leave nothing to observe on the inner module
        target_program.compile(
            file_path=os.path.join(FIXTURES, "side_effect.jac"),
            options=CompileOptions(graphmend=True, type_check=False)
        );
        orig(self, mod, target_program, passes[i + 1:], cancel_token);
    }
    JacCompiler.run_schedule = _spy;
    try {
        mod = prog.compile(
            file_path=os.path.join(FIXTURES, "val_guard.jac"),
            options=CompileOptions(graphmend=True, type_check=False)
        );
    } finally {
        JacCompiler.run_schedule = orig;
    }
    assert state["interleaved"] , "the interleaved compile never ran";
    facts = mod.gen.graphmend_facts;
    assert facts is not None , "the outer compile left no facts on its module";
    kinds = [k.value for k in facts.breaks.values()];
    assert "val_guard" in kinds;
    assert "side_effect" not in kinds , (
        "the interleaved compile leaked its facts onto the outer module"
    );
    side_mod: any = None;
    for (path, m) in prog.mod.hub.items() {
        if str(path).endswith("side_effect.jac") {
            side_mod = m;
        }
    }
    assert side_mod is not None , "the interleaved module never reached the hub";
    side_facts = side_mod.gen.graphmend_facts;
    assert side_facts is not None , "the interleaved compile left no facts";
    side_kinds = [k.value for k in side_facts.breaks.values()];
    assert "side_effect" in side_kinds , (
        "the interleaved compile's facts did not land on its own module"
    );
}

test "boundary entries key on nodes and helpers collapse to a set" {
    import from jaclang.jac0core.constant { GraphMendHelper }
    mod = _compile_gm("val_guard.jac");
    facts = mod.gen.graphmend_facts;
    assert facts is not None , "the compile left no facts on the module";
    assert facts.boundary , "the compile seeded no boundary entries";
    for (k, v) in facts.boundary.items() {
        assert isinstance(k, uni.Ability) , (
            "boundary entries are keyed by a recyclable address, not by node"
        );
        assert isinstance(v, uni.Ability);
    }
    assert facts.helpers , "the compile recorded no helper needs";
    assert isinstance(facts.helpers, set) , (
        "helpers regrew a module-keyed map instead of the per-module set"
    );
    for h in facts.helpers {
        assert isinstance(h, GraphMendHelper);
    }
    seed = _entry_ability(mod);
    assert facts.boundary.get(seed) is seed , (
        "the compiled entry does not resolve to itself by node identity"
    );
}

test "a distinct node with an equal shape does not resolve in the boundary" {
    mod_a = _compile_gm("val_guard.jac");
    mod_b = _compile_gm("val_guard.jac");
    twin = _entry_ability(mod_b);
    facts_a = mod_a.gen.graphmend_facts;
    facts_b = mod_b.gen.graphmend_facts;
    assert facts_b is not None;
    assert facts_b.boundary.get(twin) is twin;
    assert facts_a is not None;
    assert facts_a.boundary.get(twin) is None , (
        "a boundary lookup resolved a node the compile never saw"
    );
}

test "facts live on the compiled module and not in a process-wide context" {
    import jaclang.jac0core.codeinfo as codeinfo;
    mod = _compile_gm("val_guard.jac");
    assert mod.gen.graphmend_facts is not None , (
        "the facts are not reachable from the unit that was compiled"
    );
    for hook in [
        "swap_graphmend_facts",
        "installed_graphmend_facts",
        "current_graphmend_facts",
        "_graphmend_facts_ctx"
    ] {
        assert not hasattr(codeinfo, hook) , (
            f"codeinfo still exposes the context-variable hook {hook}"
        );
    }
}

test "a module outside every compiled region records itself as a noop" {
    mod = _compile_gm("region_no_compile.jac");
    facts = mod.gen.graphmend_facts;
    assert facts is not None , "detection left no facts on the module";
    assert facts.noop is True , (
        "a module with no compiled region did not record the noop fact"
    );
    active = _compile_gm("val_guard.jac");
    active_facts = active.gen.graphmend_facts;
    assert active_facts is not None;
    assert active_facts.noop is False , (
        "a module with a compiled region recorded itself as a noop"
    );
}

test "a recompile after invalidation starts from fresh facts" {
    prog = JacProgram();
    opts = CompileOptions(graphmend=True, type_check=False);
    path = os.path.join(FIXTURES, "val_guard.jac");
    mod_1 = prog.compile(file_path=path, options=opts);
    facts_1 = mod_1.gen.graphmend_facts;
    assert facts_1 is not None;
    assert facts_1.breaks;
    hub_key: any = None;
    for p in prog.mod.hub.keys() {
        if str(p).endswith("val_guard.jac") {
            hub_key = p;
        }
    }
    assert hub_key is not None;
    prog.invalidate_module(hub_key);
    mod_2 = prog.compile(
        file_path=path, options=CompileOptions(graphmend=True, type_check=False)
    );
    assert mod_2 is not mod_1 , "the recompile reused the stale module object";
    facts_2 = mod_2.gen.graphmend_facts;
    assert facts_2 is not None;
    assert facts_2 is not facts_1 , (
        "the recompiled module inherited the previous compile's facts"
    );
    stale_ids = {id(k) for k in facts_1.breaks};
    for k in facts_2.breaks {
        assert id(k) not in stale_ids , (
            "the fresh facts carry a node from the invalidated parse"
        );
    }
}
