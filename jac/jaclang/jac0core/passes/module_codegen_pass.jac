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

    """Ordered (body, strip_impl_defs) segments that contribute top-level
    statements to a module's codegen.

    This is the single source of truth for annex weaving, shared by both
    backends -- `iter_context_stmts` (native) and
    `BaseAstGenPass._merge_module_bodies` (@sv/ecmascript) -- each of which then
    applies its own context filter. Annex (.impl/.test) and variant bodies are
    spliced into the head module's own `body` by JacAnnexPass, so every
    annex-declared construct (a `glob`, `enum`, standalone `def`/archetype, ...)
    is already present in it (issue #6754).

    Annex-origin statements are woven BEFORE head-origin ones (partitioned by
    `loc.mod_path`): a head module's top-level executable code (e.g. a
    `with entry { ... }` that calls a function whose standalone definition lives
    in an impl annex) runs at module load, so the annex's definitions must be
    emitted first or the call hits an undefined name. (This restores the
    impl-before-head order the pre-merge weave produced.)

    `strip_impl_defs` is True: matched `ImplDef`s are reached through the decls
    DeclImplMatchPass connects them to (the decl emits the construct from the
    impl's body), so the standalone `ImplDef` node is redundant in the merged
    list. Only `_merge_module_bodies` consults the flag; `iter_context_stmts`
    type-dispatches and ignores `ImplDef`s anyway.
    """
    static def iter_woven_segments(module: uni.Module) -> list[tuple[Sequence, bool]] {
        own = module.loc.mod_path;
        annex_stmts = [
            stmt
            for stmt in module.body
            if stmt.loc.mod_path and stmt.loc.mod_path != own
        ];
        head_stmts = [
            stmt
            for stmt in module.body
            if not (stmt.loc.mod_path and stmt.loc.mod_path != own)
        ];
        return [(annex_stmts, True), (head_stmts, True)];
    }

    """Iterate top-level statements for a given context (see iter_woven_segments).

    Unwraps NativeBlock/ClientBlock/ServerBlock and yields their children
    matching the given CodeContext. When ctx is None, yields all statements from
    all blocks (flat iteration). Annex statements are merged into the head body
    and coerced to the head's context by JacAnnexPass, so e.g. a native module
    only ever sees its NATIVE-context statements -- the annex's globals/defs
    survive the filter.
    """
    static def iter_context_stmts(
        module: uni.Module, ctx: (CodeContext | None) = None
    ) -> list[uni.ElementStmt] {
        result: list[uni.ElementStmt] = [];
        for (body, _strip) in ModuleCodegenPass.iter_woven_segments(module) {
            for stmt in body {
                if isinstance(stmt, uni.NativeBlock) {
                    if (ctx is None or ctx == CodeContext.NATIVE) {
                        result.extend(stmt.body);
                    }
                } elif isinstance(stmt, uni.ClientBlock) {
                    if (ctx is None or ctx == CodeContext.CLIENT) {
                        result.extend(stmt.body);
                    }
                } elif isinstance(stmt, uni.ServerBlock) {
                    if (ctx is None or ctx == CodeContext.SERVER) {
                        result.extend(stmt.body);
                    }
                } elif ctx is None {
                    result.append(stmt);
                } elif (
                    isinstance(stmt, uni.ContextAwareNode) and stmt.code_context == ctx
                ) {
                    result.append(stmt);
                } elif (
                    not isinstance(stmt, uni.ContextAwareNode)
                    and ctx == CodeContext.SERVER
                ) {
                    # Undecorated top-level nodes default to SERVER context
                    result.append(stmt);
                }
            }
        }
        return result;
    }

    """Names of archetypes referenced anywhere under `nd` (constructors, type
    annotations, and `with X entry` triggers all surface as resolved `Name`s
    whose symbol declares an Archetype). Backend-agnostic.
    """
    static def archetype_refs(nd: uni.UniNode) -> list[str] {
        names: list[str] = [];
        for nm in nd.get_all_sub_nodes(uni.Name) {
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
        shared: dict[(str, uni.Archetype)] = {};
        for arch in module.get_all_sub_nodes(uni.Archetype) {
            if (arch.name is not None) and isinstance(arch.parent, uni.Module) {
                shared[arch.name.value] = arch;
            }
        }
        if not shared {
            return [];
        }
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
