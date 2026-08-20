"""No waived seam is reachable from the sealed artifacts' entry points.

A waiver in `NATIVE_SEAL_DEMOTION_WAIVERS` ships an `abort()` stub into the
artifact, so a waived method that turns out to be reachable trades a wrong
answer for a process kill with no diagnostic. `test_unitree_seal_baseline.jac`
and `test_pass_seal_wave1_baseline.jac` pin that each waiver still names a real
seam; this pins the other half, that none of them can be called.

The closure below is a deliberate over-approximation, so "not in it" is a
proof and "in it" is only a warning:

  - **Seeds** are every module-level function in the sealed closure (a
    superset of the artifact's exports), every module-level statement and glob
    initializer (what `__jac_shared_init` runs), and every dunder plus
    `accept_enter` / `accept_exit` on every class -- the dispatch an operator,
    an f-string, iteration or a visitor performs with no `FuncCall` in the AST
    to see. A waived name is not a seed, for the same reason it is not one in
    a pass root's walk: it ships as an `abort()` stub, so it cannot begin
    executing and nothing it names can be entered through it. Anything a
    *live* seed reaches still counts, which is what makes the result a proof
    rather than an assumption.
  - **Call edges** ignore the receiver entirely: `x.m(...)` adds `C.m` for
    every class `C` that declares a method named `m`, so no amount of dynamic
    dispatch can escape the set.
  - **Accessor edges** are the ones this exists for: `x.a` adds
    `C.a.__get__`, `C.a.__set__` and `C.a.__del__` for every class declaring
    `a` as an accessor, again regardless of `x`'s type.
  - **Construction** of `Cls` adds `init`, `postinit` and the field-default
    expressions for every class in `Cls`'s MRO.

The last parser test is the load-bearing one for the other three: it asserts
the closure reaches accessors a parse demonstrably needs (`CodeLocInfo`'s
spans, `NameAtom.sym`). Without it a walker that silently found nothing would
report "no waived seam reachable" for the wrong reason.

**Wave-1 pass roots** get the same walk with two deliberate differences, both
of which follow from how a sealed pass runs (its own methods native,
traversal driven from Python):

  - **Seeds are the root's live entry surface**: every method the root
    module's own classes declare except the waived ones (a stub cannot begin
    executing), every un-waived module-level function of the root, the glob
    initializers, and the closure's dunders. The Python pipeline can call any
    live method through the layout registration, so all of them are entries.
  - **`accept_enter` / `accept_exit` are a Python-dispatch boundary, not an
    edge**: their bodies do nothing but call `v.enter_*` / `v.exit_*` on a
    `UniPass`-typed visitor, a class that stays Python-side, so those calls
    lower as bridge calls that resolve through Python attribute lookup -- and
    the binding never routes a demoted method back into the artifact. A
    *direct* `self.enter_x(...)` call in a live method still forms an edge
    through the ordinary name tables, so waived visitor methods are only
    unreachable while nothing calls them natively.

A waived name that shows up in a root's reachable set is a stop-the-line
finding: the artifact could abort at runtime, so the waiver must be removed
and the seam fixed instead. The two exceptions are written down as tables
with an argument each, `ACCESSOR_ARGUED` and `PASSENGER_ARGUED`, and both are
kept honest the same way: an entry that stops being flagged fails, and
nothing outside the table is ever excused.
"""

import os;
import jaclang;
import from pathlib { Path }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.main.layout_pass {
    archetype_accessors,
    get_layout_registry
}
import from jaclang.jac0core.sealed { native_artifact_for }
import from jaclang.utils.precompile_bytecode {
    _CLOSURE_SEAM_WAIVERS,
    NATIVE_SEAL_ROOTS,
    seal_waiver_names
}

glob PKG_PATH = Path(jaclang.__file__).parent,
     SEALED_ROOT = "jac0core/parser/parser.jac",
     WAVE1_ROOTS: tuple = (
         "jac0core/passes/annex_pass.jac",
         "jac0core/passes/module_codegen_pass.jac",
         "jac0core/passes/uni_pass.jac",
         "jac0core/passes/endpoint_effect_pass.jac"
     ),
     WAVE2_ROOTS: tuple = (
         "jac0core/passes/ast_validation_pass.jac",
         "jac0core/passes/semantic_analysis_pass.jac",
         "compiler/passes/main/sem_def_match_pass.jac"
     ),
     WAVE4_ROOTS: tuple = (
         "jac0core/passes/sym_tab_build_pass.jac",
         "jac0core/passes/decl_impl_match_pass.jac"
     ),
     WAVE5_ROOTS: tuple = (
         "compiler/passes/main/jsx_intrinsic_guard_pass.jac",
         "compiler/passes/main/access_check_pass.jac"
     ),
     JCIR_ROOT = "jac0core/passes/jcir_gen_pass.jac",
     # Documented carve-outs of the receiver-blind accessor rule: `x.a` adds
     # every class's `a` accessor, so a live read of a polymorphic slot flags
     # implementors the receiver's DECLARED type can never be. Each entry
     # argues one such slot for one root; anything reachable outside its
     # entry still fails. sem_def's `semdef.value` is typed MultiString and
     # parser-built, so the only lit_value a semdef can dispatch is the
     # (now live) MultiString decoder; the two entries below decode values
     # (a `type` object, `...`) that a MultiString can never hold.
     ACCESSOR_ARGUED: dict[(str, tuple)] = {
         "jac0core/passes/jcir_gen_pass.jac": (
             "BuiltinType.lit_value.__get__",
             "Ellipsis.lit_value.__get__"
         ),
         "compiler/passes/main/sem_def_match_pass.jac": (
             "BuiltinType.lit_value.__get__",
             "Ellipsis.lit_value.__get__"
         )
     },
     # The type system's passenger set, argued once for the closure walk.
     #
     # `types.jac` and `type_utils.jac` are in every sealed artifact because
     # `unitree`'s three `TypeBase`-typed fields are a layout dependency, not
     # because any sealed entry point calls them. Only a module in
     # `NATIVE_SEAL_ROOTS` gets a native artifact, and `native_artifact_for`
     # answers for those alone, so no importer can bind
     # `jaclang.compiler.type_system.*` to the artifact: its Python module
     # keeps serving those calls, and the linked copies are enterable only
     # from inside the artifact.
     #
     # That "only from inside" is measured rather than asserted. Every sealed
     # root's own walk below seeds the root's live entry surface and reaches
     # neither of these two -- the closure walk flags them because it seeds
     # every module-level function of every closure member as if it were an
     # entry, so what it finds here is one passenger calling another:
     #
     #   collect_member_syms                   <- lookup_symtab
     #   build_solution_from_specialized_class <- _specialize_for_base_recursive
     #
     # Each entry is checked below to be declared in a type-system module, so
     # this table can never quietly excuse a `unitree` seam, and a stale
     # entry fails the way every other carve-out does.
     PASSENGER_ARGUED: tuple = (
         "build_solution_from_specialized_class",
         "collect_member_syms"
     ),
     # A third table, BASE_CHAIN_ARGUED, lived here for one wave: the four
     # base-chain waivers (`is_canceled`, `ice`, the two generic statics)
     # became reachable when the chain joined every sealed closure, and the
     # table argued that the only path to them ran through a pass
     # construction no sealed entry performs -- naming itself as the fused
     # prefix's gate. It retired the way it promised: `is_canceled` reads
     # the `cancel_requested` scalar now, `ice` builds the message its
     # callers raise, and the generic-static shims were retired for the
     # `UniNode` methods they wrapped. Nothing construction-reachable is
     # waived anymore, so the walks below run against the plain argued
     # tables again.
     TYPE_SYSTEM_DIR = "compiler/type_system",
     _CLOSURE_MEMO: list = [],
     _PASS_MEMO: dict[(str, tuple)] = {};

"""Program tables for one sealed root: archetypes, functions, glob roots.

`own_paths` maps each archetype/function name to the module that declares
it, so a root's own entry surface can be told apart from the closure's.
"""
def _program_tables(rel: str) -> tuple {
    if native_artifact_for("jaclang.jac0core.unitree") is not None {
        testskip(
            "the sealed closure is served from this runtime's native seal; "
            "reachability is measured in source lanes and at seal time"
        );
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(PKG_PATH / rel),
        options=CompileOptions(
            aot_mode=True,
            type_check=False,
            force_codespace='native',
            force_target_program=True,
            na_gc_mode='cycles',
            no_ir_cache=True
        )
    );
    arch_of: dict = {};
    mod_funcs: dict = {};
    glob_roots: list = [];
    arch_mod: dict = {};
    func_mod: dict = {};
    for (_path, mod) in prog.mod.hub.items() {
        mod_path = os.path.realpath(mod.loc.mod_path) if mod?.loc else "";
        for st in ModuleCodegenPass.iter_context_stmts(mod, CodeContext.NATIVE) {
            if isinstance(st, uni.Archetype) and st.name is not None {
                nm = st.name.value;
                if nm not in arch_of or st.body is not None {
                    arch_of[nm] = st;
                    arch_mod[nm] = mod_path;
                }
            } elif isinstance(st, uni.Ability)
                and st.name_ref is not None
                and not st.is_method {
                mod_funcs[st.name_ref.sym_name] = st;
                func_mod[st.name_ref.sym_name] = mod_path;
            } elif isinstance(st, (uni.ModuleCode, uni.GlobalVars)) {
                glob_roots.append(st);
            }
        }
    }
    reg = get_layout_registry(ir, prog);
    return (arch_of, mod_funcs, glob_roots, reg, arch_mod, func_mod, );
}

"""Every node id reachable from `seeds`, over-approximated.

`boundary` names methods whose bodies dispatch through a Python-side
receiver; calls *to* them are followed, but no `C.<name>` edge is formed
for them, so their visitor calls do not count as native edges.

`halt` names the waived seams. A waived name is recorded as reached and
then walked no further: what ships for it is an `abort()` stub with no
body, so the process ends there and nothing its source calls can be
entered through it. Without that, one live edge into a waived cascade
reports the whole tail of the cascade as reachable and buries the single
edge that is the actual finding.
"""
def _walk_closure(
    tables: tuple, seeds: set, boundary: set, halt: (set | None) = None
) -> set {
    (arch_of, mod_funcs, glob_roots, reg, _am, _fm) = tables;

    methods_named: dict = {};
    accessors_named: dict = {};
    for (cls, arch) in arch_of.items() {
        for meth in arch.get_methods() {
            mname = meth.name_ref.sym_name if meth.name_ref else None;
            if mname is not None {
                methods_named.setdefault(mname, {})[cls] = meth;
            }
        }
        for (slot, _var, acc) in archetype_accessors(arch) {
            accessors_named.setdefault(slot, {})[cls] = acc;
        }
    }

    def roots_of(node_id: str) -> list {
        out: list = [];
        if node_id == "<module>" {
            return list(glob_roots);
        }
        if node_id in mod_funcs {
            body = ModuleCodegenPass.unwrap_body(mod_funcs[node_id]);
            if body is not None {
                out.extend(body);
            }
            if mod_funcs[node_id].signature is not None {
                out.append(mod_funcs[node_id].signature);
            }
            return out;
        }
        (cls, _dot, rest) = node_id.partition(".");
        arch = arch_of.get(cls);
        if arch is None or not rest {
            return out;
        }
        if rest == "<defaults>" {
            for var in arch.get_has_vars() {
                if var.value is not None {
                    out.append(var.value);
                }
            }
            return out;
        }
        for (slot, _var, acc) in archetype_accessors(arch) {
            if slot == rest {
                body = ModuleCodegenPass.unwrap_body(acc);
                if body is not None {
                    out.extend(body);
                }
            }
        }
        for meth in arch.get_methods() {
            if (meth.name_ref.sym_name if meth.name_ref else None) == rest {
                body = ModuleCodegenPass.unwrap_body(meth);
                if body is not None {
                    out.extend(body);
                }
                if meth.signature is not None {
                    out.append(meth.signature);
                }
            }
        }
        return out;
    }

    def construction_of(cls: str) -> list {
        out: list = [];
        for ancestor in reg.get_mro(cls) {
            if ancestor in arch_of {
                out.extend(
                    [
                        f"{ancestor}.init",
                        f"{ancestor}.__init__",
                        f"{ancestor}.postinit",
                        f"{ancestor}.__post_init__",
                        f"{ancestor}.<defaults>"
                    ]
                );
            }
        }
        return out;
    }

    def attr_of(trailer: uni.UniNode) -> (str | None) {
        right = trailer.right if trailer?.right is not None else None;
        if isinstance(right, uni.Name) {
            return right.value;
        }
        return right.sym_name if isinstance(right, uni.AstSymbolNode) else None;
    }

    def edges_of(node_id: str) -> set {
        out: set = set();
        stack: list = roots_of(node_id);
        walked: set = set();
        while stack {
            nd = stack.pop();
            if nd is None or id(nd) in walked {
                continue;
            }
            walked.add(id(nd));
            for kid in (nd.kid or []) {
                if kid is not None {
                    stack.append(kid);
                }
            }
            named: (str | None) = None;
            if isinstance(nd, uni.FuncCall) {
                target = nd.target;
                if isinstance(target, uni.Name) {
                    named = target.value;
                } elif isinstance(target, uni.AtomTrailer) {
                    named = attr_of(target);
                }
            }
            if named is not None and named not in boundary {
                if named in arch_of {
                    out.update(construction_of(named));
                }
                if named in mod_funcs {
                    out.add(named);
                }
                for cls in methods_named.get(named, {}) {
                    out.add(f"{cls}.{named}");
                }
            }
            if isinstance(nd, uni.AtomTrailer) and nd.is_attr {
                attr = attr_of(nd);
                if attr is not None {
                    for kind in ("__get__", "__set__", "__del__") {
                        slot = f"{attr}.{kind}";
                        for cls in accessors_named.get(slot, {}) {
                            out.add(f"{cls}.{slot}");
                        }
                    }
                }
            }
        }
        return out;
    }

    stop: set = halt if halt is not None else set();
    seen: set = set();
    work: list = list(seeds);
    while work {
        current = work.pop();
        if current in seen {
            continue;
        }
        seen.add(current);
        if current in stop {
            continue;
        }
        for callee in edges_of(current) {
            if callee not in seen {
                work.append(callee);
            }
        }
    }
    return seen;
}

"""The parser walk: (reachable node ids, the program tables it walked)."""
def sealed_walk -> tuple {
    if _CLOSURE_MEMO {
        return _CLOSURE_MEMO[0];
    }
    # Runs in dev trees AND inside the sealed payload lanes: sources ship in
    # the payload and match the checkout that built it, so the reachability
    # walk proves the same closure a payload build seals.
    tables = _program_tables(SEALED_ROOT);
    (arch_of, mod_funcs, _globs, _reg, _am, _fm) = tables;

    waived = _waived_names();
    seeds: set = {
        f
        for f in mod_funcs
        if f not in waived
    };
    seeds.add("<module>");
    for (cls, arch) in arch_of.items() {
        for meth in arch.get_methods() {
            mname = meth.name_ref.sym_name if meth.name_ref else "";
            if f"{cls}.{mname}" in waived {
                continue;
            }
            if (mname.startswith("__") and mname.endswith("__"))
                or mname in ("accept", "accept_enter", "accept_exit") {
                seeds.add(f"{cls}.{mname}");
            }
        }
    }
    result = (_walk_closure(tables, seeds, set(), waived), tables, );
    _CLOSURE_MEMO.append(result);
    return result;
}

"""Every node the sealed parse entry points can reach."""
def reachable -> set {
    return sealed_walk()[0];
}

"""One pass root's walk: (reachable set, waived bare names)."""
def pass_reachable(rel: str) -> tuple {
    if rel in _PASS_MEMO {
        return _PASS_MEMO[rel];
    }
    tables = _program_tables(rel);
    (arch_of, mod_funcs, _globs, _reg, arch_mod, func_mod) = tables;
    # The closure's own waivers hold for any root that links it, so they are
    # unioned in rather than read off the root's table alone. For a root
    # already in `NATIVE_SEAL_DEMOTION_WAIVERS` that is a no-op; for one being
    # prepared for a later wave it is the difference between a real walk and
    # one with nothing to look for.
    (_qualified, waived) = seal_waiver_names(rel);
    waived = set(waived) | _waived_names();
    root_path = os.path.realpath(str(PKG_PATH / rel));

    # Module-level functions seed only for the root: a pass artifact's entry
    # surface is the root's own declarations, and a closure module's free
    # functions (unitree's symbol binders) are covered seeded by the parser
    # walk above. They still join this walk the moment anything the root
    # reaches calls them, so nothing is lost -- only phantom entries that no
    # caller of the sealed pass can name.
    seeds: set = set();
    seeds.add("<module>");
    for fname in mod_funcs {
        if fname not in waived and func_mod.get(fname) == root_path {
            seeds.add(fname);
        }
    }
    for (cls, arch) in arch_of.items() {
        is_root_class = arch_mod.get(cls) == root_path;
        for meth in arch.get_methods() {
            mname = meth.name_ref.sym_name if meth.name_ref else "";
            if not mname {
                continue;
            }
            key = f"{cls}.{mname}";
            if key in waived {
                continue;
            }
            if is_root_class {
                seeds.add(key);
            } elif mname.startswith("__") and mname.endswith("__") {
                seeds.add(key);
            }
        }
    }

    seen = _walk_closure(tables, seeds, {"accept_enter", "accept_exit"}, waived);
    result = (seen, waived, );
    _PASS_MEMO[rel] = result;
    return result;
}

"""Waived seams, keyed the way `_seal_demotions` keys them, minus the module."""
def _waived_names -> set {
    return {`entry.split("::")[-1] for `entry in _CLOSURE_SEAM_WAIVERS};
}

"""One root's findings: (reachable waivers beyond the argued set, stale argued)."""
def _pass_findings(rel: str) -> tuple[(list, list)] {
    (seen, waived) = pass_reachable(rel);
    argued = set(ACCESSOR_ARGUED.get(rel, ()));
    hit = sorted(
        name
        for name in waived
        if name in seen and name not in argued
    );
    stale = sorted(
        name
        for name in argued
        if name not in seen or name not in waived
    );
    return (hit, stale, );
}

"""Every root's findings as report lines, so one run names them all."""
def _findings_report(roots: tuple) -> tuple[(list, list)] {
    hits: list = [];
    stale: list = [];
    for rel in roots {
        (rel_hits, rel_stale) = _pass_findings(rel);
        hits.extend(f"  {rel}: {name}" for name in rel_hits);
        stale.extend(f"  {rel}: {name}" for name in rel_stale);
    }
    return (hits, stale, );
}


test "the closure reaches accessors a parse demonstrably needs" {
    seen = reachable();
    for needed in (
        "CodeLocInfo.orig_src.__get__",
        "CodeLocInfo.first_line.__get__",
        "CodeLocInfo.pos_end.__get__",
        "NameAtom.sym.__get__",
        "NameAtom.sym.__set__",
        "AstSymbolNode.sym_name.__get__"
    ) {
        assert needed in seen , (
            f"'{needed}' is missing from the reachable set -- the walker found "
            "nothing, so a clean result below would be vacuous"
        );
    }
}


test "the closure reaches the parser itself" {
    seen = reachable();
    assert "parse_program" in seen , "the sealed entry point is not a seed";
    assert len(seen) > 500 , (
        f"only {len(seen)} reachable nodes; the walk is not expanding"
    );
}


test "no waived seam is reachable from the sealed entry points" {
    seen = reachable();
    waived = _waived_names();
    argued = set(PASSENGER_ARGUED);
    reachable_waivers = sorted(
        name
        for name in waived
        if name in seen and name not in argued
    );
    assert not reachable_waivers , (
        f"{len(reachable_waivers)} waived seam(s) are reachable, so the "
        "artifact can abort at runtime instead of returning a wrong value:\n"
        + "\n".join(f"  {name}" for name in reachable_waivers)
    );
    stale_argued = sorted(
        name
        for name in argued
        if name not in seen or name not in waived
    );
    assert not stale_argued , (
        "carve-out entries the walk no longer flags (or that stopped being "
        "waived) -- drop them, and say which mechanism cleared each:\n"
        + "\n".join(f"  {name}" for name in stale_argued)
    );
}


test "every passenger carve-out is declared in the type system" {
    (_seen, tables) = sealed_walk();
    (_arch_of, _mod_funcs, _globs, _reg, arch_mod, func_mod) = tables;
    for name in PASSENGER_ARGUED {
        (owner, dot, _rest) = name.partition(".");
        where = arch_mod.get(owner) if dot else func_mod.get(name);
        assert where is not None , (
            f"'{name}' is carved out as a type-system passenger but the walk "
            "cannot say which module declares it"
        );
        assert TYPE_SYSTEM_DIR in str(where).replace(os.sep, "/") , (
            f"'{name}' is carved out as a type-system passenger but is "
            f"declared in {where}. The argument is that no importer can bind "
            "these symbols, which holds only for modules no image serves -- "
            "it cannot excuse a seam in a module a sealed root is made of."
        );
    }
}


test "wave-1 roots: each walk reaches the pass's own machinery" {
    for (rel, needed) in (
        (
            "jac0core/passes/annex_pass.jac",
            ("JacAnnexPass._merge_annex", "UniNode.add_kids_right")
        ),
        (
            "jac0core/passes/module_codegen_pass.jac",
            ("ModuleCodegenPass.archetype_refs", "NameAtom.sym.__get__")
        ),
        ("jac0core/passes/uni_pass.jac", ("UniPass.traverse", "UniPass.enter_node")),
        (
            "jac0core/passes/endpoint_effect_pass.jac",
            ("EndpointEffectPass._callee_body", "Archetype._get_impl_resolved_body")
        )
    ) {
        (seen, _waived) = pass_reachable(rel);
        for name in needed {
            assert name in seen , (
                f"{rel}: '{name}' is missing from the reachable set -- the "
                "walk found nothing there, so a clean waiver verdict would "
                "be vacuous"
            );
        }
    }
}


test "wave-1 roots: no waived seam is native-reachable beyond the argued slots" {
    (hits, stale_argued) = _findings_report(WAVE1_ROOTS);
    assert not hits , (
        f"{len(hits)} waived seam(s) are reachable through native calls from "
        "a wave-1 root's live entry surface, so the sealed artifact can abort "
        "at runtime -- remove the waiver and fix the seam:\n"
        + "\n".join(hits)
    );
    assert not stale_argued , (
        "argued carve-out entries the walk no longer flags (or that stopped "
        "being waived) -- drop them:\n"
        + "\n".join(stale_argued)
    );
}


test "wave-2 roots: each walk reaches the pass's own machinery" {
    for (rel, needed) in (
        (
            "jac0core/passes/ast_validation_pass.jac",
            ("ASTValidationPass._returns_jsx", "AstSymbolNode.sym_name.__get__")
        ),
        (
            "jac0core/passes/semantic_analysis_pass.jac",
            ("SemanticAnalysisPass._check_archetype", "Archetype.get_methods")
        ),
        (
            "compiler/passes/main/sem_def_match_pass.jac",
            ("SemDefMatchPass.resolve_sem_target", "UniScopeNode.lookup")
        )
    ) {
        (seen, _waived) = pass_reachable(rel);
        for name in needed {
            assert name in seen , (
                f"{rel}: '{name}' is missing from the reachable set -- the "
                "walk found nothing there, so a clean waiver verdict would "
                "be vacuous"
            );
        }
    }
}


test "wave-2 roots: no waived seam is native-reachable beyond the argued slots" {
    (hits, stale_argued) = _findings_report(WAVE2_ROOTS);
    assert not hits , (
        f"{len(hits)} waived seam(s) are reachable through native calls from "
        "a wave-2 root's live entry surface, so the sealed artifact can abort "
        "at runtime -- remove the waiver and fix the seam:\n"
        + "\n".join(hits)
    );
    assert not stale_argued , (
        "argued carve-out entries the walk no longer flags (or that stopped "
        "being waived) -- drop them:\n"
        + "\n".join(stale_argued)
    );
}


test "wave-4 roots: each walk reaches the pass's own machinery" {
    # sym_tab_build was wave 2's stop-the-line refusal: live
    # exit_module_path read Import.is_jac, chaining into __jac_detected
    # and ModulePath.resolve_relative_path, the waived filesystem
    # import-resolution family. Import detection is driver-stamped data
    # now (Import.jac_detected, the #8242 absorbed_mod pattern), the
    # cleared-state pin held, and this wave replaces it with full
    # sealed-root membership for both declaration binders.
    for (rel, needed) in (
        (
            "jac0core/passes/sym_tab_build_pass.jac",
            ("SymTabBuildPass._bind_import_path_symbols", "UniScopeNode.def_insert")
        ),
        (
            "jac0core/passes/decl_impl_match_pass.jac",
            ("bind_assignment_targets", "UniScopeNode.lookup")
        )
    ) {
        (seen, _waived) = pass_reachable(rel);
        for name in needed {
            assert name in seen , (
                f"{rel}: '{name}' is missing from the reachable set -- the "
                "walk found nothing there, so a clean waiver verdict would "
                "be vacuous"
            );
        }
    }
}


test "wave-4 roots: no waived seam is native-reachable beyond the argued slots" {
    (hits, stale_argued) = _findings_report(WAVE4_ROOTS);
    assert not hits , (
        f"{len(hits)} waived seam(s) are reachable through native calls from "
        "a wave-4 root's live entry surface, so the sealed artifact can abort "
        "at runtime -- the import-detection stamp (or a new read) has "
        "regressed:\n"
        + "\n".join(hits)
    );
    assert not stale_argued , (
        "argued carve-out entries the walk no longer flags (or that stopped "
        "being waived) -- drop them:\n"
        + "\n".join(stale_argued)
    );
}


test "wave-5 roots: each walk reaches the pass's own machinery" {
    # Both roots used to answer a driver question themselves -- the jsx
    # guard resolved the client kind from config in before_pass, the
    # access checker read get_config and walked the filesystem for
    # project roots -- and both read the answer off a stamped Module
    # slot now. The names below are the work each pass does after the
    # stamp, so a clean waiver verdict is not vacuous.
    for (rel, needed) in (
        (
            "compiler/passes/main/jsx_intrinsic_guard_pass.jac",
            (
                "JsxIntrinsicGuardPass._check_element",
                "JsxIntrinsicGuardPass._is_exempt",
                "mobui_module_exempt"
            )
        ),
        (
            "compiler/passes/main/access_check_pass.jac",
            (
                "AccessCheckPass._check_use",
                "AccessCheckPass._is_subclass_of",
                "UniNode.find_parent_of_type"
            )
        )
    ) {
        (seen, _waived) = pass_reachable(rel);
        for name in needed {
            assert name in seen , (
                f"{rel}: '{name}' is missing from the reachable set -- the "
                "walk found nothing there, so a clean waiver verdict would "
                "be vacuous"
            );
        }
    }
}


test "wave-5 roots: no waived seam is native-reachable from the live surface" {
    for rel in WAVE5_ROOTS {
        (seen, waived) = pass_reachable(rel);
        hit = sorted(
            name
            for name in waived
            if name in seen
        );
        assert not hit , (
            f"{rel}: {len(hit)} waived seam(s) are reachable through native "
            "calls from the root's live entry surface, so the sealed artifact "
            "can abort at runtime -- remove the waiver and fix the seam:\n"
            + "\n".join(f"  {name}" for name in hit)
        );
    }
}


test "the jcir walk reaches the emitter's own machinery" {
    (seen, _waived) = pass_reachable(JCIR_ROOT);
    for name in (
        "JcirGenPass.resolve_stmt_block",
        "JcirGenPass.val",
        "CodegenIrWriter.emit_node",
        "CgNode.get"
    ) {
        assert name in seen , (
            f"{JCIR_ROOT}: '{name}' is missing from the reachable set -- the "
            "walk found nothing there, so a clean waiver verdict would be "
            "vacuous"
        );
    }
}


test "jcir: no waived seam is native-reachable from the live surface" {
    # This root was refused for three reachable stubs and now has none.
    # `_gen_native_interop_stubs` and unitree's `gen` accessor cleared when
    # the interop stub emission moved off `enter_node`; `exit_func_call`
    # cleared when its chunked-flow type question became a stamped field
    # instead of a live `TypeBase.mangle` call.
    #
    # The two `lit_value` accessors the walk flags are carve-outs of the
    # receiver-blind accessor rule, argued in ACCESSOR_ARGUED: the only live
    # read is `exit_string`'s `nd.lit_value` on a parser-built `String`, so
    # the only decoder a string can dispatch is the live one.
    assert JCIR_ROOT in NATIVE_SEAL_ROOTS , (
        f"{JCIR_ROOT} left NATIVE_SEAL_ROOTS; if it was refused again, the "
        "refusal belongs in NATIVE_SEAL_REFUSED_ROOTS with its blocker"
    );
    (seen, waived) = pass_reachable(JCIR_ROOT);
    argued = set(ACCESSOR_ARGUED.get(JCIR_ROOT, ()));
    hit = sorted(
        name
        for name in waived
        if name in seen and name not in argued
    );
    assert not hit , (
        f"{JCIR_ROOT}: {len(hit)} waived seam(s) are reachable through "
        "native calls from the root's live entry surface, so the sealed "
        "artifact can abort at runtime -- remove the waiver and fix the "
        "seam:\n"
        + "\n".join(f"  {name}" for name in hit)
    );
}
