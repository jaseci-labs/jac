import from jaclang.runtime.object_model { field }
import from jaclang.compiler.frontend.unitree {
    Ability,
    Archetype,
    Assignment,
    AtomTrailer,
    ConcurrentExpr,
    ContextAwareNode,
    ElementStmt,
    Enum,
    FuncCall,
    GlobalVars,
    ImplDef,
    Import,
    Module,
    ModuleCode,
    ModuleItem,
    ListVal,
    LambdaExpr,
    Name,
    literal_string_value,
    TupleVal,
    UniNode,
    YieldExpr
}
import from jaclang.compiler.frontend.constant {
    CodeContext,
    NATIVE_ERASED_TYPE_MARKERS,
    TYPE_PARAM_CONSTRUCTORS
}

obj ModuleFacts {
    static def ability_is_generator(ability: Ability) -> bool {
        pending = list(ModuleFacts.unwrap_body(ability) or []);
        while pending {
            current = pending.pop();
            if current.ct_pruned {
                continue;
            }
            if isinstance(current, YieldExpr) {
                return True;
            }
            if not isinstance(current, (Ability, ImplDef, Archetype, LambdaExpr)) {
                pending.extend(current.kid);
            }
        }
        return False;
    }

    static def literal_exports(module: Module) -> set[str] | None {
        assignments: list[Assignment] = [];
        for stmt in module.body {
            if isinstance(stmt, GlobalVars) {
                assignments.extend(stmt.assignments);
            } elif isinstance(stmt, ModuleCode) {
                for item in stmt.body {
                    if isinstance(item, Assignment) {
                        assignments.append(item);
                    }
                }
            }
        }
        for assignment in assignments {
            targets = assignment.target;
            if len(targets) != 1 {
                continue;
            }
            target = targets[0];
            value = assignment.value;
            if not isinstance(target, Name)
                or target.value != "__all__"
                or not isinstance(value, (ListVal, TupleVal)) {
                continue;
            }
            exports: set[str] = set();
            for element in value.values or [] {
                literal = literal_string_value(element);
                if literal is not None {
                    exports.add(literal);
                }
            }
            return exports;
        }
        return None;
    }

    static def exported_import_names(module: Module) -> dict[str, set[str]] {
        allowed = ModuleFacts.literal_exports(module);
        groups: dict[str, set[str]] = {};
        if allowed is None {
            return groups;
        }
        for statement in ModuleFacts.iter_module_imports(module) {
            source = statement.from_loc;
            if source is None {
                continue;
            }
            module_name = source.dot_path_str.lstrip(".");
            if not module_name {
                continue;
            }
            public: set[str] = set();
            for item in statement.items {
                if isinstance(item, ModuleItem) {
                    alias = item.alias;
                    name = alias.value if alias is not None else item.name.value;
                    if name in allowed {
                        public.add(name);
                    }
                }
            }
            if public {
                groups[module_name] = groups.get(module_name, set()) | public;
            }
        }
        return groups;
    }

    static def unwrap_body(
        nd: Archetype | Enum | Ability | ImplDef
    ) -> (Sequence[UniNode] | None) {
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
        for (body, _strip) in ModuleFacts.iter_woven_segments(module) {
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
            for stmt in ModuleFacts.iter_context_stmts(module, ctx)
            if isinstance(stmt, Import)
        ];
    }

    static def iter_nested_imports(
        module: Module, ctx: (CodeContext | None) = None
    ) -> list[Import] {
        result: list[Import] = [];
        seen: set[int] = set();
        for stmt in ModuleFacts.iter_context_stmts(module, ctx) {
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
        return bool(ModuleFacts.iter_context_stmts(module, CodeContext.NATIVE));
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
        return ModuleFacts.is_type_alias_decl(assign)
            or ModuleFacts.is_type_param_decl(assign);
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
        for stmt in ModuleFacts.iter_context_stmts(module, ctx) {
            worklist.extend(ModuleFacts.archetype_refs(stmt));
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
            worklist.extend(ModuleFacts.archetype_refs(arch));
        }
        return list(result.values());
    }
}

def client_capability_violations(mod: Module) -> list[tuple[(UniNode, str)]] {
    out: list[tuple[(UniNode, str)]] = [];
    for _stmt in ModuleFacts.iter_context_stmts(mod, CodeContext.CLIENT) {
        if isinstance(_stmt, ContextAwareNode) and _stmt.codespace_dual {
            continue;
        }
        for _nd in _stmt.get_all_sub_nodes(typ=ConcurrentExpr) {
            out.append((_nd, "flow/wait concurrency"));
        }
    }
    return out;
}
