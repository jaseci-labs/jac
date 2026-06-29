import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.passes.transform { Transform }
import type from jaclang.jac0core.program { JacProgram }

obj ModuleCodegenPass(Transform[uni.Module, uni.Module]) {
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
                    result.append(stmt);
                }
            }
        }
        return result;
    }

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
