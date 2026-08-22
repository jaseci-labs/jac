import from collections.abc { Sequence }
import from jaclang.jac0core.unitree {
    Ability,
    Archetype,
    Assignment,
    AtomTrailer,
    ConcurrentExpr,
    ContextAwareNode,
    ElementStmt,
    Enum,
    FuncCall,
    ImplDef,
    Import,
    Module,
    Name,
    UniNode
}
import from jaclang.jac0core.constant {
    CodeContext,
    NATIVE_ERASED_TYPE_MARKERS,
    TYPE_PARAM_CONSTRUCTORS
}
import from jaclang.jac0core.passes.transform { Transform }

obj ModuleCodegenPass(Transform) {
    has ir_in: Module;

    static def unwrap_body(nd: Archetype | Enum | Ability) -> (Sequence | None) {
        body = nd.body;
        if (isinstance(body, ImplDef) and isinstance(body.body, `list)) {
            return body.body;
        }
        if isinstance(body, `list) {
            return body;
        }
        return None;
    }

    static def iter_woven_segments(module: Module) -> list[tuple[list[UniNode], bool]] {
        own_path = module.loc.mod_path;
        annex_stmts: list[UniNode] = [
            stmt
            for stmt in module.body
            if stmt.loc.mod_path and stmt.loc.mod_path != own_path
        ];
        head_stmts: list[UniNode] = [
            stmt
            for stmt in module.body
            if not (stmt.loc.mod_path and stmt.loc.mod_path != own_path)
        ];
        return [(annex_stmts, True), (head_stmts, True)];
    }

    static def iter_context_stmts(
        module: Module, ctx: (CodeContext | None) = None
    ) -> list[ElementStmt] {
        result: list[ElementStmt] = [];
        for (body, _strip) in ModuleCodegenPass.iter_woven_segments(module) {
            for stmt in body {
                if not isinstance(stmt, ElementStmt) {
                    continue;
                }
                elem: ElementStmt = stmt;
                if ctx is None {
                    result.append(elem);
                } elif (
                    isinstance(stmt, ContextAwareNode) and stmt.code_context == ctx
                ) {
                    result.append(elem);
                } elif (
                    not isinstance(stmt, ContextAwareNode) and ctx == CodeContext.SERVER
                ) {
                    result.append(elem);
                }
            }
        }
        return result;
    }

    static def iter_module_imports(
        module: Module, ctx: (CodeContext | None) = None
    ) -> list[Import] {
        return [
            stmt
            for stmt in ModuleCodegenPass.iter_context_stmts(module, ctx)
            if isinstance(stmt, Import)
        ];
    }

    static def iter_nested_imports(
        module: Module, ctx: (CodeContext | None) = None
    ) -> list[Import] {
        result: list[Import] = [];
        seen: set[int] = set();
        for stmt in ModuleCodegenPass.iter_context_stmts(module, ctx) {
            if isinstance(stmt, Import) {
                continue;
            }
            for imp in stmt.get_all_sub_nodes(typ=Import) {
                if id(imp) not in seen {
                    seen.add(id(imp));
                    result.append(imp);
                }
            }
        }
        return result;
    }

    static def has_native_context_stmts(module: Module) -> bool {
        return bool(ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE));
    }

    static def is_type_alias_decl(assign: Assignment) -> bool {
        if assign.type_tag is None or assign.value is None {
            return False;
        }
        tag = assign.type_tag.tag;
        if isinstance(tag, AtomTrailer) {
            tag = tag.right;
        }
        return isinstance(tag, Name) and tag.value in NATIVE_ERASED_TYPE_MARKERS;
    }

    static def is_type_param_decl(assign: Assignment) -> bool {
        if assign.value is None or not isinstance(assign.value, FuncCall) {
            return False;
        }
        callee = assign.value.target;
        if isinstance(callee, AtomTrailer) {
            callee = callee.right;
        }
        return isinstance(callee, Name) and callee.value in TYPE_PARAM_CONSTRUCTORS;
    }

    static def is_erased_type_decl(assign: Assignment) -> bool {
        return ModuleCodegenPass.is_type_alias_decl(assign)
            or ModuleCodegenPass.is_type_param_decl(assign);
    }

    static def archetype_refs(nd: UniNode) -> list[str] {
        names: list[str] = [];
        for nm in nd.get_all_sub_nodes(Name) {
            sym = nm.sym;
            if (sym is not None) and sym.defn {
                cand = sym.defn[0].name_of;
                if (isinstance(cand, (Archetype, Enum)) and (cand.name is not None)) {
                    names.append(cand.name.value);
                }
            }
        }
        return names;
    }

    static def shared_archetypes_for_context(
        module: Module, ctx: CodeContext
    ) -> list[Archetype] {
        shared: dict[(str, Archetype)] = {};
        for arch in module.get_all_sub_nodes(Archetype) {
            if (arch.name is not None) and isinstance(arch.parent, Module) {
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
        result: dict[(str, Archetype)] = {};
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

def client_capability_violations(mod: Module) -> list[tuple[(UniNode, str)]] {
    out: list[tuple[(UniNode, str)]] = [];
    for _stmt in ModuleCodegenPass.iter_context_stmts(mod, CodeContext.CLIENT) {
        if isinstance(_stmt, ContextAwareNode) and _stmt.codespace_dual {
            continue;
        }
        for _nd in _stmt.get_all_sub_nodes(typ=ConcurrentExpr) {
            out.append((_nd, "flow/wait concurrency"));
        }
    }
    return out;
}
