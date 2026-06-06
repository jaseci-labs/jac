"""Shared base for codegen passes that operate on Module AST."""
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.passes.transform { Transform }
import type from jaclang.jac0core.program { JacProgram }

"""Base for all module-level codegen passes.

Provides static helpers for context-block unwrapping and body
extraction, used by PyastGenPass, EsastGenPass, and NaIRGenPass.
"""
obj ModuleCodegenPass(Transform[uni.Module, uni.Module]) {
    """Unwrap ImplDef wrapper to get body statements.

    Returns the body as a Sequence, handling both direct list bodies
    and ImplDef-wrapped bodies. Returns None if body is not a list.
    """
    static def unwrap_body(
        nd: uni.Archetype | uni.Enum | uni.Ability
    ) -> (Sequence | None) {
        body = nd.body;
        if (isinstance(body, uni.ImplDef) and isinstance(body.body, `list)) {
            return body.body;
        }
        if isinstance(body, `list) {
            return body;
        }
        return None;
    }

    """Populate module-level code-context indexes once for all codegen passes."""
    static def index_code_contexts(module: uni.Module) {
        facts = module.gen.analysis.code_contexts;
        facts.all_stmts = [];
        facts.stmts_by_context = {
            CodeContext.SERVER: [],
            CodeContext.CLIENT: [],
            CodeContext.NATIVE: []
        };
        for stmt in module.body {
            if isinstance(stmt, uni.NativeBlock) {
                facts.all_stmts.extend(stmt.body);
                facts.stmts_by_context[CodeContext.NATIVE].extend(stmt.body);
            } elif isinstance(stmt, uni.ClientBlock) {
                facts.all_stmts.extend(stmt.body);
                facts.stmts_by_context[CodeContext.CLIENT].extend(stmt.body);
            } elif isinstance(stmt, uni.ServerBlock) {
                facts.all_stmts.extend(stmt.body);
                facts.stmts_by_context[CodeContext.SERVER].extend(stmt.body);
            } else {
                facts.all_stmts.append(stmt);
                if isinstance(stmt, uni.ContextAwareNode) {
                    facts.stmts_by_context[stmt.code_context].append(stmt);
                } else {
                    # Undecorated top-level nodes default to SERVER context.
                    facts.stmts_by_context[CodeContext.SERVER].append(stmt);
                }
            }
        }
        symbols = module.gen.analysis.symbols;
        symbols.archetypes_by_name = {};
        symbols.top_level_archetypes_by_name = {};
        for arch in module.get_all_sub_nodes(uni.Archetype, brute_force=True) {
            aname = arch.name.value if arch.name else None;
            if aname is None {
                continue;
            }
            if aname not in symbols.archetypes_by_name or arch.body is not None {
                symbols.archetypes_by_name[aname] = arch;
            }
            if isinstance(arch.parent, uni.Module) {
                if aname not in symbols.top_level_archetypes_by_name
                or arch.body is not None {
                    symbols.top_level_archetypes_by_name[aname] = arch;
                }
            }
        }
        facts.shared_archetypes_by_context = {};
        for ctx in [CodeContext.SERVER, CodeContext.CLIENT, CodeContext.NATIVE] {
            facts.shared_archetypes_by_context[ctx] = (
                ModuleCodegenPass._shared_archetypes_from_index(
                    module, ctx, symbols.top_level_archetypes_by_name
                )
            );
        }
    }

    """Iterate top-level statements for a given context.

    Unwraps NativeBlock/ClientBlock/ServerBlock and yields their
    children matching the given CodeContext. When ctx is None, yields
    all statements from all blocks (flat iteration).
    """
    static def iter_context_stmts(
        module: uni.Module, ctx: (CodeContext | None) = None
    ) -> list[uni.ElementStmt] {
        facts = module.gen.analysis.code_contexts;
        if not facts.all_stmts and module.body {
            ModuleCodegenPass.index_code_contexts(module);
        }
        if ctx is None {
            return facts.all_stmts;
        }
        return facts.stmts_by_context.get(ctx, []);
    }

    """Names of archetypes referenced anywhere under `nd` (constructors, type
    annotations, and `with X entry` triggers all surface as resolved `Name`s
    whose symbol declares an Archetype). Backend-agnostic.
    """
    static def archetype_refs(nd: uni.UniNode) -> list[str] {
        names: list[str] = [];
        for nm in nd.get_all_sub_nodes(uni.Name, brute_force=True) {
            sym = nm.sym;
            if (sym is not None) and sym.defn {
                cand = sym.defn[0].name_of;
                if isinstance(cand, uni.Archetype) and (cand.name is not None) {
                    names.append(cand.name.value);
                }
            }
        }
        return names;
    }

    """Module-level (shared) archetypes transitively referenced by code in the
    given codespace context. `obj`/`node`/`edge`/`walker` declared at module
    level (direct children of the Module) are shared across all backends; a
    backend compiles the ones its own code references. Declarations nested in a
    codespace block, an `import from "lib" { ... }` clib block, or another
    archetype have a non-Module parent and are owned by a different registration
    path, so they are never returned here.
    """
    static def shared_archetypes_for_context(
        module: uni.Module, ctx: CodeContext
    ) -> list[uni.Archetype] {
        facts = module.gen.analysis.code_contexts;
        if ctx not in facts.shared_archetypes_by_context {
            ModuleCodegenPass.index_code_contexts(module);
        }
        return facts.shared_archetypes_by_context.get(ctx, []);
    }

    static def _shared_archetypes_from_index(
        module: uni.Module, ctx: CodeContext, shared: dict[(str, uni.Archetype)]
    ) -> list[uni.Archetype] {
        worklist: list[str] = [];
        for stmt in ModuleCodegenPass.iter_context_stmts(module, ctx) {
            worklist.extend(ModuleCodegenPass.archetype_refs(stmt));
        }
        result: dict[(str, uni.Archetype)] = {};
        visited: set[str] = set();
        while worklist {
            name = worklist.pop();
            if name in visited {
                continue;
            }
            visited.add(name);
            arch = shared.get(name);
            if arch is None {
                continue;
            }
            result[name] = arch;
            worklist.extend(ModuleCodegenPass.archetype_refs(arch));
        }
        return list(result.values());
    }
}
