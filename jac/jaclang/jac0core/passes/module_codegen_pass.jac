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

    """Iterate top-level statements for a given context.

    Unwraps NativeBlock/ClientBlock/ServerBlock and yields their
    children matching the given CodeContext. When ctx is None, yields
    all statements from all blocks (flat iteration).
    """
    static def iter_context_stmts(
        module: uni.Module, ctx: (CodeContext | None) = None
    ) -> list[uni.ElementStmt] {
        result: list[uni.ElementStmt] = [];
        for stmt in module.body {
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
                not isinstance(stmt, uni.ContextAwareNode) and ctx == CodeContext.SERVER
            ) {
                # Undecorated top-level nodes default to SERVER context
                result.append(stmt);
            }
        }
        return result;
    }

    """Flatten a module's woven codegen body: impl-annex bodies + head body, plus
    (optionally) variant and test bodies. The single fold shared by all three
    backends -- @sv (PyastGenPass), @cl (EsastGenPass) and @na (NaIRGenPass) --
    replacing the old split between `BaseAstGenPass._merge_module_bodies` (sv/cl)
    and a native-only annex walk that missed `.na.impl.jac` globals/enums (#6754).

    Top-level constructs declared in an `*.impl.jac` annex (a `glob`, `enum`, an
    `impl`) live in `impl_mod` sub-modules, never the head's `body` (decl_impl_match
    only connects their symbols), so a head-only sweep misses them. This folds them
    back in.

    `ctx` selects the gather mode:
      - `ctx is None` (sv/cl): take statements verbatim, dropping only the head's
        own `ImplDef` wrappers (the woven annex supplies the real bodies). Context
        separation then happens per node inside each AST-gen backend (PyastGen
        prunes foreign blocks; EsastGen filters to CLIENT).
      - `ctx` set (native): unwrap `na`/`sv`/`cl` blocks and keep only `ctx`
        statements of the head; a wholly-native annex contributes all of its
        top-level decls.

    Annex bodies come first: an sv/cl head statement may call an annex-defined
    function at module-load time, so the impl must precede it. Native glob/enum
    registration is order-free, so this shared ordering is safe for it too.

    `include_tests` / `include_variants` let native drop `test`/variant bodies that
    never belong in a compiled binary."""
    static def collect_codegen_bodies(
        module: uni.Module,
        ctx: (CodeContext | None) = None,
        include_tests: bool = True,
        include_variants: bool = True
    ) -> list {
        result: list = [];
        for annex in module.impl_mod {
            result.extend(ModuleCodegenPass._ctx_body(annex, ctx, is_head=False));
        }
        result.extend(ModuleCodegenPass._ctx_body(module, ctx, is_head=True));
        if include_variants {
            for variant in module.variant_mod {
                for vimpl in variant.impl_mod {
                    result.extend(
                        ModuleCodegenPass._ctx_body(vimpl, ctx, is_head=False)
                    );
                }
                result.extend(ModuleCodegenPass._ctx_body(variant, ctx, is_head=True));
            }
        }
        if include_tests {
            for tmod in module.test_mod {
                result.extend(ModuleCodegenPass._ctx_body(tmod, ctx, is_head=False));
            }
        }
        return result;
    }

    """One module's contribution to `collect_codegen_bodies` (see there). The head
    is special: in verbatim mode (`ctx is None`) it sheds its `ImplDef` wrappers;
    in context mode it filters to `ctx` (a sub-module/annex instead contributes all
    of its statements, `ctx=None`)."""
    static def _ctx_body(
        mod: uni.Module, ctx: (CodeContext | None), is_head: bool
    ) -> list {
        if ctx is None {
            if is_head {
                return [
                    stmt
                    for stmt in mod.body
                    if not isinstance(stmt, uni.ImplDef)
                ];
            }
            return list(mod.body);
        }
        return ModuleCodegenPass.iter_context_stmts(mod, ctx if is_head else None);
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
