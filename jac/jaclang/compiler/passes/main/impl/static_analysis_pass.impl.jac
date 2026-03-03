"""Static analysis pass implementation."""
import ast as ast3;
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes { UniPass }
import from jaclang.jac0core.constant { SymbolType }

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
            self.log_warning(f"'{name}' is defined but never used", sym.decl);
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
        if name_nd.sym is not None {
            continue;
        }
        # Only flag Load context (usage, not definition)
        if name_nd._py_ctx_func != ast3.Load {
            continue;
        }
        # Skip well-known builtins and special names
        if name_nd.value in (
            "self",
            "super",
            "True",
            "False",
            "None",
            "print",
            "len",
            "range",
            "int",
            "str",
            "float",
            "bool",
            "list",
            "dict",
            "set",
            "tuple",
            "type",
            "object",
            "isinstance",
            "issubclass",
            "hasattr",
            "getattr",
            "setattr",
            "input",
            "open",
            "enumerate",
            "zip",
            "map",
            "filter",
            "any",
            "all",
            "min",
            "max",
            "sum",
            "abs",
            "round",
            "sorted",
            "reversed",
            "iter",
            "next",
            "repr",
            "hash",
            "id",
            "callable",
            "staticmethod",
            "classmethod",
            "property",
            "Exception",
            "ValueError",
            "TypeError",
            "KeyError",
            "IndexError",
            "RuntimeError",
            "StopIteration",
            "NotImplementedError",
            "AttributeError",
            "OSError",
            "FileNotFoundError",
            "ImportError",
            "NameError",
            "AssertionError",
            "ZeroDivisionError",
            "OverflowError",
            "almostEqual"
        ) {
            continue;
        }
        # Skip dunder names
        if name_nd.value.startswith("__") and name_nd.value.endswith("__") {
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
        self.log_warning(f"Name '{name_nd.value}' may be undefined", name_nd);
    }
}

"""Detect unreachable code by scanning code blocks for statements after return/break/continue."""
impl StaticAnalysisPass._check_unreachable_code(mod: uni.Module) -> None {
    # Find all nodes that contain code body sequences
    all_abilities = mod.get_all_sub_nodes(typ=uni.Ability, brute_force=True);
    all_if_stmts = mod.get_all_sub_nodes(typ=uni.IfStmt, brute_force=True);
    all_else_stmts = mod.get_all_sub_nodes(typ=uni.ElseStmt, brute_force=True);
    all_elif_stmts = mod.get_all_sub_nodes(typ=uni.ElseIf, brute_force=True);
    all_while_stmts = mod.get_all_sub_nodes(typ=uni.WhileStmt, brute_force=True);
    all_for_stmts = mod.get_all_sub_nodes(typ=uni.InForStmt, brute_force=True);
    all_iter_for_stmts = mod.get_all_sub_nodes(typ=uni.IterForStmt, brute_force=True);

    # Collect all code body containers
    containers: list = [];
    containers.extend(all_abilities);
    containers.extend(all_if_stmts);
    containers.extend(all_else_stmts);
    containers.extend(all_elif_stmts);
    containers.extend(all_while_stmts);
    containers.extend(all_for_stmts);
    containers.extend(all_iter_for_stmts);

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
                self.log_warning("Unreachable code detected", stmt);
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
