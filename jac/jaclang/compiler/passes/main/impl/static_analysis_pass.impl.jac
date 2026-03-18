"""Static analysis pass implementation."""

impl StaticAnalysisPass.init(
    ir_in: uni.Module, prog: Any, cancel_token: Any = None
) -> None {
    super.init(ir_in, prog, cancel_token);
}

"""Run all static analyses after the full tree traversal."""
impl StaticAnalysisPass.after_pass -> None {
    self._checked_scopes: set[int] = set();
    self._check_unused_symbols(self.ir_in);
    self._check_undefined_names(self.ir_in);
    self._check_unreachable_code(self.ir_in);
    self._check_semantic_patterns(self.ir_in);
    for annex_mod in self.ir_in.impl_mod + self.ir_in.test_mod + self.ir_in.variant_mod {
        self._check_undefined_names(annex_mod);
        self._check_unreachable_code(annex_mod);
        self._check_semantic_patterns(annex_mod);
    }
}

"""Walk all scopes and warn on symbols that are defined but never used."""
impl StaticAnalysisPass._check_unused_symbols(scope: uni.UniScopeNode) -> None {
    if id(scope) in self._checked_scopes {
        return;
    }
    self._checked_scopes.add(id(scope));

    for (name, sym) in scope.names_in_scope.items() {
        # Skip imported symbols
        if sym.imported {
            continue;
        }
        # Skip underscore-prefixed names (conventionally unused)
        if name.startswith("_") {
            continue;
        }
        # Skip structural symbol types that are not user variables
        if sym.sym_type in (
            SymbolType.MODULE,
            SymbolType.MOD_VAR,
            SymbolType.IMPL,
            SymbolType.SEM,
            SymbolType.TEST,
            SymbolType.HAS_VAR,
            SymbolType.CONSTRUCTOR,
            SymbolType.ENUM_MEMBER,
            SymbolType.ABILITY,
            SymbolType.METHOD
        ) {
            continue;
        }
        # Skip archetype and enum definitions (they are types, not variables)
        if sym.sym_type in (
            SymbolType.OBJECT_ARCH,
            SymbolType.NODE_ARCH,
            SymbolType.EDGE_ARCH,
            SymbolType.WALKER_ARCH,
            SymbolType.ENUM_ARCH
        ) {
            continue;
        }
        # Skip self/super
        if name in ("self", "super", "init", "postinit") {
            continue;
        }
        # Skip parameters of abstract abilities (no body to use them in)
        if sym.sym_type == SymbolType.VAR and isinstance(scope, uni.Ability) {
            if scope.needs_impl {
                continue;
            }
        }
        # Check unused: defined but never referenced
        if len(sym.uses) == 0 {
            self.emit(W2003, node_override=sym.decl, name=name);
        }
    }
    # Recurse into child scopes
    for kid in scope.kid_scope {
        self._check_unused_symbols(kid);
    }
}

"""Walk all Name nodes and warn if a name reference was never resolved."""
impl StaticAnalysisPass._check_undefined_names(mod: uni.Module) -> None {
    all_names = mod.get_all_sub_nodes(typ=uni.Name, brute_force=True);
    for name_nd in all_names {
        if name_nd.sym {
            continue;
        }
        # Only flag Load context (usage, not definition)
        if name_nd._py_ctx_func != ast3.Load {
            continue;
        }
        # Skip well-known builtins and special names
        import builtins;
        if name_nd.value in dir(builtins)
        or name_nd.value in ("self", "super", "almostEqual") {
            continue;
        }
        # root is a Jac ambient builtin — warn if used bare (not as root() call)
        if name_nd.value == "root" {
            is_root_call = (
                isinstance(name_nd.parent, uni.FuncCall)
                and name_nd.parent.target is name_nd
            );
            if not is_root_call {
                self.emit(W0062, node_override=name_nd);
            }
            continue;
        }
        # Skip dunder names
        if name_nd.value.startswith("__") and name_nd.value.endswith("__") {
            continue;
        }
        # Skip attribute access names (right side of x.attr)
        parent = name_nd.parent;
        if isinstance(parent, uni.AtomTrailer) and parent.is_attr {
            continue;
        }
        # Skip names that are part of import statements
        if name_nd.find_parent_of_type(uni.Import) is not None {
            continue;
        }
        # Skip names that are part of module paths
        if name_nd.find_parent_of_type(uni.ModulePath) is not None {
            continue;
        }
        self.emit(W2001, node_override=name_nd, name=name_nd.value);
    }
}

"""Detect unreachable code by scanning code blocks for statements after return/break/continue."""
impl StaticAnalysisPass._check_unreachable_code(mod: uni.Module) -> None {
    # Collect all code body containers
    container_types = [
        uni.Ability,
        uni.ImplDef,
        uni.IfStmt,
        uni.ElseStmt,
        uni.ElseIf,
        uni.WhileStmt,
        uni.InForStmt,
        uni.IterForStmt
    ];
    containers: list = [];
    for typ in container_types {
        containers.extend(mod.get_all_sub_nodes(typ=typ, brute_force=True));
    }

    for container in containers {
        body = getattr(container, 'body', None);
        if not body or not isinstance(body, Sequence) {
            continue;
        }
        found_terminator = False;
        for stmt in body {
            if found_terminator {
                # Skip Semi nodes
                if isinstance(stmt, uni.Semi) {
                    continue;
                }
                self.emit(W2002, node_override=stmt);
                break;
            }
            if isinstance(stmt, (uni.ReturnStmt, uni.RaiseStmt)) {
                found_terminator = True;
            }
            if isinstance(stmt, uni.CtrlStmt) {
                found_terminator = True;
            }
        }
    }
}

"""Check semantic patterns: division by zero, None comparison, self-assignment,
f-string without placeholders, redundant boolean comparison, overly broad except,
return in finally, disengage outside walker."""
impl StaticAnalysisPass._check_semantic_patterns(mod: uni.Module) -> None {
    # W2070: division by zero
    for nd in mod.get_all_sub_nodes(typ=uni.BinaryExpr, brute_force=True) {
        if nd.op is not None and isinstance(nd.op, uni.Token) {
            if nd.op.value in ("/", "//", "%") {
                if isinstance(nd.right, uni.Int) and nd.right.value == "0" {
                    self.emit(W2070, node_override=nd);
                } elif isinstance(nd.right, uni.Float) and nd.right.value == "0.0" {
                    self.emit(W2070, node_override=nd);
                }
            }
        }
    }

    # W2058: None comparison with == or !=
    for nd in mod.get_all_sub_nodes(typ=uni.CompareExpr, brute_force=True) {
        for (i, op) in enumerate(nd.ops) {
            if op.value in ("==", "!=") {
                right = nd.rights[i] if i < len(nd.rights) else None;
                left = nd.left if i == 0 else (nd.rights[i - 1] if i > 0 else None);
                if isinstance(right, uni.Null) or isinstance(left, uni.Null) {
                    self.emit(W2058, node_override=nd);
                }
            }
        }
    }

    # W2063: self-assignment (x = x)
    for nd in mod.get_all_sub_nodes(typ=uni.Assignment, brute_force=True) {
        if nd.aug_op is not None or nd.value is None {
            continue;
        }
        if len(nd.target) == 1 {
            target = nd.target[0];
            if isinstance(target, uni.Name) and isinstance(nd.value, uni.Name) {
                if target.value == nd.value.value {
                    self.emit(W2063, node_override=nd, name=target.value);
                }
            }
        }
    }

    # W2074: f-string with no placeholders
    for nd in mod.get_all_sub_nodes(typ=uni.FString, brute_force=True) {
        has_expr = False;
        for part in nd.parts {
            if isinstance(part, uni.FormattedValue) {
                has_expr = True;
                break;
            }
        }
        if not has_expr {
            self.emit(W2074, node_override=nd);
        }
    }

    # W2075: redundant boolean comparison (x == True, x == False)
    for nd in mod.get_all_sub_nodes(typ=uni.CompareExpr, brute_force=True) {
        for (i, op) in enumerate(nd.ops) {
            if op.value in ("==", "!=", "is", "is not") {
                right = nd.rights[i] if i < len(nd.rights) else None;
                if isinstance(right, uni.Bool) {
                    self.emit(W2075, node_override=nd);
                }
            }
        }
    }

    # W2052: overly broad except (catching Exception or BaseException)
    for nd in mod.get_all_sub_nodes(typ=uni.Except, brute_force=True) {
        if nd.ex_type is not None and isinstance(nd.ex_type, uni.Name) {
            if nd.ex_type.value in ("Exception", "BaseException") {
                self.emit(W2052, node_override=nd.ex_type, type=nd.ex_type.value);
            }
        }
    }

    # E2055: return in finally block
    for nd in mod.get_all_sub_nodes(typ=uni.FinallyStmt, brute_force=True) {
        for stmt in nd.body {
            if isinstance(stmt, uni.ReturnStmt) {
                self.emit(E2055, node_override=stmt);
            }
        }
    }

    # E2083: disengage outside walker
    for nd in mod.get_all_sub_nodes(typ=uni.DisengageStmt, brute_force=True) {
        # Walk up to find if we're inside a walker ability
        in_walker = False;
        parent = nd.parent;
        while parent is not None {
            if isinstance(parent, uni.Archetype) {
                if parent.arch_type is not None
                and isinstance(parent.arch_type, uni.Token)
                and parent.arch_type.value == "walker" {
                    in_walker = True;
                }
                break;
            }
            parent = parent.parent;
        }
        if not in_walker {
            self.emit(E2083, node_override=nd);
        }
    }
}
