"""Initialize the native IR generation pass."""
impl NaIRGenPass.init(
    ir_in: uni.Module, prog: object, cancel_token: (object | None) = None
) -> None {
    self.llvm_module = ir.Module(name="jac_native", context=ir.Context());
    self.builder: (ir.IRBuilder | None) = None;
    self.func_symtab: dict[(str, ir.Function)] = {};
    self.local_vars: dict[(str, ir.AllocaInstr)] = {};
    self.has_native_code = False;
    self.type_map: dict[(str, ir.Type)] = {
        "int": ir.IntType(64),
        "float": ir.DoubleType(),
        "bool": ir.IntType(1),
        "str": ir.IntType(8).as_pointer()
    };
    self._fmt_strings: dict[(str, ir.GlobalVariable)] = {};
    # External function cache (Phase 0)
    self.extern_funcs: dict[(str, ir.Function)] = {};
    # Enum support (Phase 1)
    self.enum_values: dict[(str, ir.Constant)] = {};
    self.enum_types: dict[(str, ir.IntType)] = {};
    # Loop stack for break/continue (Phase 1)
    self.loop_stack: list[tuple] = [];
    # String counter for unique global names (Phase 2)
    self._str_count: int = 0;
    # Object/struct support (Phase 3)
    self.struct_types: dict[(str, object)] = {};
    self.struct_field_indices: dict[(str, dict)] = {};
    self.struct_field_types: dict[(str, dict)] = {};
    self.struct_field_defaults: dict[(str, object)] = {};
    self.method_funcs: dict[(str, ir.Function)] = {};
    self.type_var_map: dict[(str, str)] = {};
    # List support (Phase 4)
    self.list_types: dict[(str, object)] = {};  # elem_type_name → list struct type
    self.list_helpers: dict[(str, dict)] = {};  # elem_type_name → {new, append, get, set, len}
    self.var_list_elem_type: dict[(str, str)] = {};  # var_name → elem_type_name
    # Jac-level type tracking for nested lists and ptr list element resolution
    self.field_type_node: dict[(str, dict)] = {};  # struct_name → {field → type AST node}
    self.var_type_node: dict[(str, object)] = {};  # var_name → type AST node
    self._list_type_hint: (str | None) = None;  # hint for empty list creation
    self._last_type_node_hint: (object | None) = None;  # Jac type AST of last evaluated expr
    # Inheritance / vtable support (Phase 5)
    self.class_hierarchy: dict[(str, str)] = {};  # child → parent
    self.has_vtable: dict[(str, bool)] = {};
    self.vtable_layouts: dict[(str, list[str])] = {};
    self.vtable_method_indices: dict[(str, dict)] = {};
    self.vtable_globals: dict[(str, ir.GlobalVariable)] = {};
    super.init(ir_in=ir_in, prog=prog, cancel_token=cancel_token);
}

# ─── Main Pass Logic ─────────────────────────────────────────
"""Forward-declare, codegen native abilities/entries, and store the LLVM module."""
impl NaIRGenPass.transform(ir_in: uni.Module) -> uni.Module {
    # Phase 0: Forward declarations (enums, archetypes, free functions)
    self._register_enums(self.ir_in);
    self._register_archetypes(self.ir_in);
    # Phase 1: Codegen native abilities and entry blocks
    for stmt in self.ir_in.body {
        if isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                if (
                    isinstance(inner, uni.Ability)
                    and isinstance(inner, uni.ContextAwareNode)
                    and inner.code_context == CodeContext.NATIVE
                    and inner.signature is not None
                    and isinstance(inner.signature, uni.FuncSignature)
                ) {
                    self._codegen_ability(inner);
                } elif (
                    isinstance(inner, uni.ModuleCode)
                    and isinstance(inner, uni.ContextAwareNode)
                    and inner.code_context == CodeContext.NATIVE
                ) {
                    self._codegen_entry(inner);
                }
            }
        } elif isinstance(stmt, uni.Ability) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
                and stmt.signature is not None
                and isinstance(stmt.signature, uni.FuncSignature)
            ) {
                self._codegen_ability(stmt);
            }
        } elif isinstance(stmt, uni.ModuleCode) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
            ) {
                self._codegen_entry(stmt);
            }
        }
    }
    # Store LLVM module on AST
    if self.has_native_code {
        self.ir_in.gen.llvm_ir = self.llvm_module;
    }
    return self.ir_in;
}

"""Walk the module and register all native enum types."""
impl NaIRGenPass._register_enums(module: uni.Module) -> None {
    for stmt in module.body {
        if isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                if isinstance(inner, uni.Enum) {
                    self._codegen_enum(inner);
                }
            }
        } elif isinstance(stmt, uni.Enum) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
            ) {
                self._codegen_enum(stmt);
            }
        }
    }
}

"""Walk the module and declare all native functions."""
impl NaIRGenPass._forward_declare_functions(module: uni.Module) -> None {
    for stmt in module.body {
        if isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                self._maybe_declare_ability(inner);
            }
        } elif isinstance(stmt, uni.Ability) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
            ) {
                self._maybe_declare_ability(stmt);
            }
        }
    }
}

"""Forward-declare a single ability if it's a function."""
impl NaIRGenPass._maybe_declare_ability(node: uni.ElementStmt) -> None {
    if not isinstance(node, uni.Ability) {
        return;
    }
    if node.signature is None or not isinstance(node.signature, uni.FuncSignature) {
        return;
    }
    name = node.name_ref.sym_name if node.name_ref else "unnamed";
    sig = node.signature;
    # Build parameter types
    param_types: list[ir.Type] = [];
    for p in sig.get_parameters() {
        if p.type_tag and p.type_tag.tag {
            param_types.append(self._resolve_jac_type(p.type_tag.tag));
        } else {
            param_types.append(ir.IntType(64));
        }
    }
    # Return type
    ret_type = self._resolve_jac_type(sig.return_type);
    # Create function
    fnty = ir.FunctionType(ret_type, param_types);
    func = ir.Function(self.llvm_module, fnty, name=name);
    # Name the parameters
    for (i, p) in enumerate(sig.get_parameters()) {
        func.args[i].name = p.name.value if p.name else f"arg{i}";
    }
    self.func_symtab[name] = func;
    self.has_native_code = True;
}

# ─── Ability (Function Definition) — Manual Codegen ──────────
"""Generate LLVM IR for a complete function definition."""
impl NaIRGenPass._codegen_ability(<>node: uni.Ability) -> None {
    name = (<>node).name_ref.sym_name if (<>node).name_ref else "unnamed";
    func = self.func_symtab.get(name);
    if func is None {
        return;
    }
    # Create entry block
    block = func.append_basic_block(name="entry");
    self.builder = ir.IRBuilder(block);
    self.local_vars = {};
    # Store parameters as local variables (alloca + store pattern)
    sig = (<>node).signature;
    for (i, p) in enumerate(sig.get_parameters()) {
        param_name = p.name.value if p.name else f"arg{i}";
        arg_val = func.args[i];
        alloca = self.builder.alloca(arg_val.type, name=param_name);
        self.builder.store(arg_val, alloca);
        self.local_vars[param_name] = alloca;
        # Track type annotations for parameters
        if p.type_tag and p.type_tag.tag {
            self.var_type_node[param_name] = p.type_tag.tag;
            for (ename, ltype) in self.list_types.items() {
                if arg_val.type == ltype.as_pointer() {
                    self.var_list_elem_type[param_name] = ename;
                    break;
                }
            }
            # Track struct types (including union T | None)
            tag_name = self._get_name(p.type_tag.tag);
            tag_node = p.type_tag.tag;
            if tag_name is None and isinstance(tag_node, uni.BinaryExpr) {
                op_val = getattr(tag_node.op, 'value', '');
                if op_val == "|" {
                    tag_name = self._get_name(tag_node.left);
                }
            }
            if tag_name is not None and tag_name in self.struct_types {
                self.type_var_map[param_name] = tag_name;
            }
        }
    }
    # Generate body via manual tree-walking
    if isinstance((<>node).body, (<>list, <>tuple)) {
        self._codegen_body((<>node).body);
    }
    # Ensure function has a terminator
    if not self.builder.block.is_terminated {
        ret_type = func.return_value.type;
        if isinstance(ret_type, ir.VoidType) {
            self.builder.ret_void();
        } elif isinstance(ret_type, ir.PointerType) {
            self.builder.ret(ir.Constant(ret_type, None));
        } else {
            self.builder.ret(ir.Constant(ret_type, 0));
        }
    }
    (<>node).gen.llvm_ir = func;
    self.builder = None;
}

# ─── Body / Statement Codegen ─────────────────────────────────
"""Generate IR for a sequence of statements."""
impl NaIRGenPass._codegen_body(stmts: (list | tuple)) -> None {
    for stmt in stmts {
        if self.builder.block.is_terminated {
            break;
        }
        self._codegen_stmt(stmt);
    }
}

"""Generate IR for a single statement."""
impl NaIRGenPass._codegen_stmt(node: uni.UniNode) -> None {
    if self.builder is None or self.builder.block.is_terminated {
        return;
    }
    if isinstance(node, uni.ReturnStmt) {
        self._codegen_return(node);
    } elif isinstance(node, uni.IfStmt) {
        self._codegen_if(node);
    } elif isinstance(node, uni.WhileStmt) {
        self._codegen_while(node);
    } elif isinstance(node, uni.InForStmt) {
        self._codegen_for(node);
    } elif isinstance(node, uni.Assignment) {
        self._codegen_assignment(node);
    } elif isinstance(node, uni.CtrlStmt) {
        self._codegen_ctrl(node);
    } elif isinstance(node, uni.ExprStmt) {
        self._codegen_expr(node.expr);
    }
}

"""Generate return statement."""
impl NaIRGenPass._codegen_return(node: uni.ReturnStmt) -> None {
    if node.expr is not None {
        val = self._codegen_expr(node.expr);
        if val is not None {
            func_ret_type = self.builder.function.return_value.type;
            val = self._coerce_type(val, func_ret_type);
            self.builder.ret(val);
        } else {
            self.builder.ret_void();
        }
    } else {
        self.builder.ret_void();
    }
}

"""Generate if/else/elif statement with proper basic blocks."""
impl NaIRGenPass._codegen_if(node: uni.IfStmt) -> None {
    cond = self._codegen_expr(node.condition);
    if cond is None {
        return;
    }
    # Ensure condition is i1 (bool)
    cond = self._to_bool(cond);
    func = self.builder.function;
    then_bb = func.append_basic_block(name="if.then");
    else_bb = func.append_basic_block(name="if.else");
    merge_bb = func.append_basic_block(name="if.end");
    self.builder.cbranch(cond, then_bb, else_bb);
    # Then block
    self.builder.position_at_end(then_bb);
    if isinstance(node.body, (<>list, <>tuple)) {
        self._codegen_body(node.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    # Else block
    self.builder.position_at_end(else_bb);
    if node.else_body is not None {
        if isinstance(node.else_body, uni.ElseIf) {
            self._codegen_if(node.else_body);
        } elif isinstance(node.else_body, uni.ElseStmt) {
            if isinstance(node.else_body.body, (<>list, <>tuple)) {
                self._codegen_body(node.else_body.body);
            }
        }
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    self.builder.position_at_end(merge_bb);
}

"""Generate while loop with proper basic blocks."""
impl NaIRGenPass._codegen_while(node: uni.WhileStmt) -> None {
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="while.cond");
    body_bb = func.append_basic_block(name="while.body");
    end_bb = func.append_basic_block(name="while.end");
    # Jump to condition check
    self.builder.branch(cond_bb);
    # Condition block
    self.builder.position_at_end(cond_bb);
    cond = self._codegen_expr(node.condition);
    if cond is not None {
        cond = self._to_bool(cond);
        self.builder.cbranch(cond, body_bb, end_bb);
    } else {
        self.builder.branch(end_bb);
    }
    # Body block — push loop context for break/continue
    self.loop_stack.append((cond_bb, end_bb));
    self.builder.position_at_end(body_bb);
    if isinstance(node.body, (<>list, <>tuple)) {
        self._codegen_body(node.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(cond_bb);
    }
    self.loop_stack.pop();
    # Continue after loop
    self.builder.position_at_end(end_bb);
}

"""Generate assignment statement."""
impl NaIRGenPass._codegen_assignment(node: uni.Assignment) -> None {
    # Set list type hint from context before evaluating expression
    # This helps _codegen_list_val create the correct empty list type
    self._list_type_hint = None;
    # 1. From explicit type annotation: var: list[T] = []
    if node.type_tag and node.type_tag.tag {
        hint = self._get_list_elem_from_type_node(node.type_tag.tag);
        if hint is not None {
            self._list_type_hint = hint;
        }
    }
    # 2. From field target: self.field = [] where field has known list type
    if self._list_type_hint is None {
        check_targets = node.target
        if isinstance(node.target, (<>list, <>tuple))
        else [(node.target)];
        for ct in check_targets {
            if isinstance(ct, uni.AtomTrailer) and ct.is_attr {
                ct_target_name = self._get_name(ct.target);
                ct_field_name = self._get_name(ct.right);
                if ct_target_name is not None and ct_field_name is not None {
                    ct_type_name = self.type_var_map.get(ct_target_name);
                    if ct_type_name is not None
                    and ct_type_name in self.field_type_node {
                        ftn = self.field_type_node[ct_type_name].get(ct_field_name);
                        if ftn is not None {
                            hint = self._get_list_elem_from_type_node(ftn);
                            if hint is not None {
                                self._list_type_hint = hint;
                            }
                        }
                    }
                }
            }
        }
    }
    value = self._codegen_expr(node.value) if node.value else None;
    self._list_type_hint = None;
    if value is None {
        return;
    }
    targets = node.target
    if isinstance(node.target, (<>list, <>tuple))
    else [(node.target)];
    for target_expr in targets {
        # Handle field assignment: self.x = val or obj.field = val
        if isinstance(target_expr, uni.AtomTrailer) and target_expr.is_attr {
            self._codegen_field_assign(target_expr, value);
            continue;
        }
        # Handle index assignment: items[i] = val or expr[i] = val
        if isinstance(target_expr, uni.AtomTrailer) and not target_expr.is_attr {
            idx_target_name = self._get_name(target_expr.target);
            elem_type_name: (str | None) = None;
            if idx_target_name is not None
            and idx_target_name in self.var_list_elem_type {
                elem_type_name = self.var_list_elem_type[idx_target_name];
            }
            target_val = self._codegen_expr(target_expr.target);
            if target_val is not None {
                if elem_type_name is None {
                    elem_type_name = self._infer_list_elem_type(target_val);
                }
                if elem_type_name is not None and target_expr.right?.slices {
                    slices = target_expr.right.slices or [];
                    if slices {
                        idx_node = slices[0];
                        idx_val = self._codegen_expr(idx_node);
                        if idx_val is None and idx_node?.start {
                            idx_val = self._codegen_expr(idx_node.start);
                        }
                        if idx_val is not None {
                            self._codegen_index_set(
                                target_val, idx_val, value, elem_type_name
                            );
                        }
                    }
                }
            }
            continue;
        }
        var_name = self._get_name(target_expr);
        if var_name is None {
            continue;
        }

        if var_name in self.local_vars {
            # Update existing variable
            alloca = self.local_vars[var_name];
            # Handle augmented assignment: +=, -=, *=, //=, %=
            if node.aug_op is not None {
                aug_op_val = node.aug_op.value;
                current = self.builder.load(alloca, name=f"{var_name}.cur");
                coerced = self._coerce_type(value, current.type);
                if aug_op_val == "+=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.add(
                            current, coerced, name=f"{var_name}.add"
                        );
                    } else {
                        value = self.builder.fadd(
                            current, coerced, name=f"{var_name}.fadd"
                        );
                    }
                } elif aug_op_val == "-=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.sub(
                            current, coerced, name=f"{var_name}.sub"
                        );
                    } else {
                        value = self.builder.fsub(
                            current, coerced, name=f"{var_name}.fsub"
                        );
                    }
                } elif aug_op_val == "*=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.mul(
                            current, coerced, name=f"{var_name}.mul"
                        );
                    } else {
                        value = self.builder.fmul(
                            current, coerced, name=f"{var_name}.fmul"
                        );
                    }
                } elif aug_op_val == "//=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.sdiv(
                            current, coerced, name=f"{var_name}.div"
                        );
                    } else {
                        value = self.builder.fdiv(
                            current, coerced, name=f"{var_name}.fdiv"
                        );
                    }
                } elif aug_op_val == "%=" {
                    if isinstance(current.type, ir.IntType) {
                        value = self.builder.srem(
                            current, coerced, name=f"{var_name}.mod"
                        );
                    } else {
                        value = self.builder.frem(
                            current, coerced, name=f"{var_name}.fmod"
                        );
                    }
                }
            }
            coerced = self._coerce_type(value, alloca.type.pointee);
            self.builder.store(coerced, alloca);
        } else {
            # New variable — allocate and store
            var_type = value.type;
            if node.type_tag and node.type_tag.tag {
                var_type = self._resolve_jac_type(node.type_tag.tag);
                value = self._coerce_type(value, var_type);
            }
            alloca = self._entry_alloca(var_type, var_name);
            self.builder.store(value, alloca);
            self.local_vars[var_name] = alloca;
        }
        # Track type info for variables pointing to structs
        if isinstance(value.type, ir.PointerType) {
            # Check if it's a known struct pointer type
            for (sname, stype) in self.struct_types.items() {
                if value.type == stype.as_pointer() {
                    self.type_var_map[var_name] = sname;
                    break;
                }
            }
        }
        # Track from type_tag annotation (supports T and T | None union types)
        if node.type_tag and node.type_tag.tag {
            tag_node = node.type_tag.tag;
            tag_name = self._get_name(tag_node);
            # Handle union type: T | None → extract T
            if tag_name is None and isinstance(tag_node, uni.BinaryExpr) {
                op_val = getattr(tag_node.op, 'value', '');
                if op_val == "|" {
                    tag_name = self._get_name(tag_node.left);
                }
            }
            if tag_name is not None and tag_name in self.struct_types {
                self.type_var_map[var_name] = tag_name;
            }
            # Store the full type AST node for nested type resolution
            self.var_type_node[var_name] = tag_node;
        }
        # Track list element type for list variables
        for (ename, ltype) in self.list_types.items() {
            if value.type == ltype.as_pointer() {
                self.var_list_elem_type[var_name] = ename;
                break;
            }
        }
    }
}

# ─── Expression Codegen ──────────────────────────────────────
"""Generate IR for an expression, returning the resulting value."""
impl NaIRGenPass._codegen_expr(node: (uni.UniNode | None)) -> (ir.Value | None) {
    if node is None {
        return None;
    }
    if isinstance(node, uni.Int) {
        return ir.Constant(ir.IntType(64), int(node.value));
    }
    if isinstance(node, uni.Float) {
        return ir.Constant(ir.DoubleType(), float(node.value));
    }
    if isinstance(node, uni.Bool) {
        val = 1 if node.value.lower() in ("true", "1") else 0;
        return ir.Constant(ir.IntType(1), val);
    }
    if isinstance(node, uni.Null) {
        return ir.Constant(ir.IntType(8).as_pointer(), None);
    }
    if isinstance(node, uni.Name) {
        return self._codegen_name(node);
    }
    if isinstance(node, uni.BinaryExpr) {
        return self._codegen_binary(node);
    }
    if isinstance(node, uni.CompareExpr) {
        return self._codegen_compare(node);
    }
    if isinstance(node, uni.UnaryExpr) {
        return self._codegen_unary(node);
    }
    if isinstance(node, uni.FuncCall) {
        return self._codegen_call(node);
    }
    if isinstance(node, uni.AtomTrailer) {
        return self._codegen_atom_trailer(node);
    }
    if isinstance(node, uni.BoolExpr) {
        return self._codegen_bool_expr(node);
    }
    if isinstance(node, uni.IfElseExpr) {
        return self._codegen_if_else_expr(node);
    }
    if isinstance(node, uni.MultiString) {
        return self._codegen_multistring(node);
    }
    if isinstance(node, uni.String) {
        return self._codegen_string(node);
    }
    if isinstance(node, uni.FString) {
        return self._codegen_fstring(node);
    }
    if isinstance(node, uni.ListVal) {
        return self._codegen_list_val(node);
    }
    # Handle parenthesized expressions: (expr) → AtomUnit
    if isinstance(node, uni.AtomUnit) {
        return self._codegen_expr(node.value);
    }
    return None;
}

"""Load a variable or return a function reference."""
impl NaIRGenPass._codegen_name(node: uni.Name) -> (ir.Value | None) {
    var_name = node.value;
    if var_name in self.local_vars {
        alloca = self.local_vars[var_name];
        # Set type node hint for subsequent chained access
        if var_name in self.var_type_node {
            self._last_type_node_hint = self.var_type_node[var_name];
        }
        return self.builder.load(alloca, name=var_name);
    }
    if var_name in self.func_symtab {
        return self.func_symtab[var_name];
    }
    return None;
}

"""Generate binary expression."""
impl NaIRGenPass._codegen_binary(node: uni.BinaryExpr) -> (ir.Value | None) {
    left = self._codegen_expr(node.left);
    right = self._codegen_expr(node.right);
    if left is None or right is None {
        return None;
    }
    op = node.op.name if isinstance(node.op, uni.Token) else str(node.op);
    return self._emit_binary_op(op, left, right);
}

"""Generate comparison expression."""
impl NaIRGenPass._codegen_compare(node: uni.CompareExpr) -> (ir.Value | None) {
    left = self._codegen_expr(node.left);
    if left is None or not node.rights or not node.ops {
        return None;
    }
    right = self._codegen_expr(node.rights[0]);
    if right is None {
        return None;
    }
    op = node.ops[0].name if isinstance(node.ops[0], uni.Token) else str(node.ops[0]);
    # Handle identity operators: is / is not (pointer comparison)
    if op == Tok.KW_IS {
        # Coerce both to same pointer type for comparison
        if isinstance(left.type, ir.PointerType)
        and isinstance(right.type, ir.PointerType) {
            if left.type != right.type {
                right = self.builder.bitcast(right, left.type);
            }
            return self.builder.icmp_unsigned("==", left, right, name="is.eq");
        }
        return self._to_bool(left);
    }
    if op == Tok.KW_ISN {
        if isinstance(left.type, ir.PointerType)
        and isinstance(right.type, ir.PointerType) {
            if left.type != right.type {
                right = self.builder.bitcast(right, left.type);
            }
            return self.builder.icmp_unsigned("!=", left, right, name="is.ne");
        }
        return self._to_bool(left);
    }
    is_float = isinstance(left.type, ir.DoubleType)
    or isinstance(right.type, ir.DoubleType);
    if is_float {
        (left, right) = self._promote_to_float(left, right);
    }
    return self._emit_comparison(op, left, right, is_float);
}

"""Generate unary expression."""
impl NaIRGenPass._codegen_unary(node: uni.UnaryExpr) -> (ir.Value | None) {
    operand = self._codegen_expr(node.operand);
    if operand is None {
        return None;
    }
    op = node.op.name if isinstance(node.op, uni.Token) else str(node.op);
    if op == Tok.MINUS {
        if isinstance(operand.type, ir.DoubleType) {
            return self.builder.fneg(operand, name="fneg");
        } elif isinstance(operand.type, ir.IntType) {
            return self.builder.neg(operand, name="neg");
        }
    } elif op == Tok.NOT {
        if isinstance(operand.type, ir.IntType) and operand.type.width == 1 {
            return self.builder.not_(operand, name="not");
        } elif isinstance(operand.type, ir.IntType) {
            zero = ir.Constant(operand.type, 0);
            return self.builder.icmp_signed("==", operand, zero, name="not");
        }
    }
    return None;
}

"""Generate function call."""
impl NaIRGenPass._codegen_call(node: uni.FuncCall) -> (ir.Value | None) {
    # Handle method calls: obj.method(args)
    if isinstance(node.target, uni.AtomTrailer) and node.target.is_attr {
        return self._codegen_method_call(node);
    }
    func_name = self._get_name(node.target);
    if func_name is None {
        return None;
    }
    # Handle print() specially
    if func_name == "print" {
        return self._emit_print(node);
    }
    # Handle len() builtin for lists and strings
    if func_name == "len" {
        params_l = node.params or [];
        if params_l {
            arg_name = self._get_name(params_l[0]);
            elem_type_name: (str | None) = None;
            if arg_name is not None and arg_name in self.var_list_elem_type {
                elem_type_name = self.var_list_elem_type[arg_name];
            }
            arg_val = self._codegen_expr(params_l[0]);
            if arg_val is not None {
                if elem_type_name is None {
                    elem_type_name = self._infer_list_elem_type(arg_val);
                }
                if elem_type_name is not None {
                    helpers = self.list_helpers.get(elem_type_name);
                    if helpers is not None {
                        return self.builder.call(
                            helpers["len"], [arg_val], name="list.len"
                        );
                    }
                }
                # String len: call strlen
                if arg_val.type == ir.IntType(8).as_pointer() {
                    strlen_fn = self._get_or_declare_extern(
                        "strlen", ir.IntType(64), [ir.IntType(8).as_pointer()]
                    );
                    return self.builder.call(strlen_fn, [arg_val], name="str.len");
                }
            }
        }
    }
    # Handle ord() builtin: load first byte, zero-extend to i64
    if func_name == "ord" {
        params_l = node.params or [];
        if params_l {
            arg_val = self._codegen_expr(params_l[0]);
            if arg_val is not None {
                byte_val = self.builder.load(arg_val, name="ord.byte");
                return self.builder.zext(byte_val, ir.IntType(64), name="ord.val");
            }
        }
    }
    # Handle int() builtin: call atoi
    if func_name == "int" {
        params_l = node.params or [];
        if params_l {
            arg_val = self._codegen_expr(params_l[0]);
            if arg_val is not None {
                atoi = self._get_or_declare_extern(
                    "atoi", ir.IntType(32), [ir.IntType(8).as_pointer()]
                );
                result32 = self.builder.call(atoi, [arg_val], name="atoi.result");
                return self.builder.sext(result32, ir.IntType(64), name="int.val");
            }
        }
    }
    # Handle input() builtin: printf prompt, fgets from stdin
    if func_name == "input" {
        i8p = ir.IntType(8).as_pointer();
        params_l = node.params or [];
        # Print prompt if provided
        if params_l {
            prompt_val = self._codegen_expr(params_l[0]);
            if prompt_val is not None {
                printf = self._get_printf();
                fmt = self._get_fmt_string("%s");
                fmt_ptr = self.builder.bitcast(fmt, i8p, name="fmt.ptr");
                # Ensure prompt is i8* (bitcast if needed)
                if isinstance(prompt_val.type, ir.PointerType)
                and prompt_val.type != i8p {
                    prompt_val = self.builder.bitcast(
                        prompt_val, i8p, name="prompt.cast"
                    );
                }
                self.builder.call(printf, [fmt_ptr, prompt_val]);
            }
        }
        # Allocate buffer, call fgets
        buf_size = 256;
        buf_type = ir.ArrayType(ir.IntType(8), buf_size);
        buf = self.builder.alloca(buf_type, name="input.buf");
        buf_ptr = self.builder.bitcast(buf, i8p, name="input.ptr");
        # Get stdin via fdopen or use __stdinp — use a simple approach with fgets(buf, size, stdin)
        # Declare stdin as external global
        stdin_name = "stdin";
        if stdin_name not in self.extern_funcs {
            stdin_type = i8p;
            stdin_global = ir.GlobalVariable(
                self.llvm_module, stdin_type, name=stdin_name
            );
            stdin_global.linkage = "external";
            self.extern_funcs[stdin_name] = stdin_global;
        }
        stdin_var = self.extern_funcs[stdin_name];
        stdin_val = self.builder.load(stdin_var, name="stdin.val");
        fgets = self._get_or_declare_extern("fgets", i8p, [i8p, ir.IntType(32), i8p]);
        size_val = ir.Constant(ir.IntType(32), buf_size);
        fgets_ret = self.builder.call(
            fgets, [buf_ptr, size_val, stdin_val], name="fgets.result"
        );
        # Check for EOF (fgets returns NULL)
        func = self.builder.function;
        eof_bb = func.append_basic_block(name="input.eof");
        ok_bb = func.append_basic_block(name="input.ok");
        merge_bb = func.append_basic_block(name="input.merge");
        null_ptr = ir.Constant(i8p, None);
        is_eof = self.builder.icmp_signed("==", fgets_ret, null_ptr, name="is.eof");
        self.builder.cbranch(is_eof, eof_bb, ok_bb);
        # EOF path: return empty string
        self.builder.position_at_start(eof_bb);
        gc_malloc_eof = self._get_or_declare_extern("GC_malloc", i8p, [ir.IntType(64)]);
        eof_str = self.builder.call(
            gc_malloc_eof, [ir.Constant(ir.IntType(64), 1)], name="eof.str"
        );
        self.builder.store(ir.Constant(ir.IntType(8), 0), eof_str);
        self.builder.branch(merge_bb);
        eof_bb_end = self.builder.block;
        # OK path: process input normally
        self.builder.position_at_start(ok_bb);
        # Strip trailing newline: find length, then set buf[len-1] = 0 if it's '\n'
        strlen_fn = self._get_or_declare_extern("strlen", ir.IntType(64), [i8p]);
        slen = self.builder.call(strlen_fn, [buf_ptr], name="input.len");
        # Copy to GC-allocated string
        gc_malloc = self._get_or_declare_extern("GC_malloc", i8p, [ir.IntType(64)]);
        alloc_size = self.builder.add(
            slen, ir.Constant(ir.IntType(64), 1), name="alloc.size"
        );
        result_ptr = self.builder.call(gc_malloc, [alloc_size], name="input.result");
        memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, ir.IntType(64)]);
        self.builder.call(memcpy, [result_ptr, buf_ptr, alloc_size]);
        # Strip trailing newline if present (only if slen > 0)
        has_len = self.builder.icmp_signed(
            ">", slen, ir.Constant(ir.IntType(64), 0), name="has.len"
        );
        strip_bb = func.append_basic_block(name="input.strip");
        nostrip_bb = func.append_basic_block(name="input.nostrip");
        self.builder.cbranch(has_len, strip_bb, nostrip_bb);
        self.builder.position_at_start(strip_bb);
        last_idx = self.builder.sub(
            slen, ir.Constant(ir.IntType(64), 1), name="last.idx"
        );
        last_ptr = self.builder.gep(result_ptr, [last_idx], name="last.ptr");
        last_byte = self.builder.load(last_ptr, name="last.byte");
        is_newline = self.builder.icmp_signed(
            "==", last_byte, ir.Constant(ir.IntType(8), 10), name="is.nl"
        );
        # Conditionally null-terminate at newline position
        null_byte = ir.Constant(ir.IntType(8), 0);
        store_val = self.builder.select(
            is_newline, null_byte, last_byte, name="strip.nl"
        );
        self.builder.store(store_val, last_ptr);
        self.builder.branch(nostrip_bb);
        self.builder.position_at_start(nostrip_bb);
        self.builder.branch(merge_bb);
        ok_bb_end = self.builder.block;
        # Merge: phi for result
        self.builder.position_at_start(merge_bb);
        phi = self.builder.phi(i8p, name="input.phi");
        phi.add_incoming(eof_str, eof_bb_end);
        phi.add_incoming(result_ptr, ok_bb_end);
        return phi;
    }
    # Handle object instantiation: ClassName(args)
    if func_name in self.struct_types {
        return self._codegen_instantiation(node);
    }
    func = self.func_symtab.get(func_name);
    if func is None {
        return None;
    }
    # Build arguments
    args: list[ir.Value] = [];
    params = node.params or [];
    for param in params {
        val = self._codegen_expr(param);
        if val is not None {
            args.append(val);
        }
    }
    # Type coerce arguments
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(func.args) {
            coerced.append(self._coerce_type(arg, func.args[i].type));
        } else {
            coerced.append(arg);
        }
    }
    return self.builder.call(func, coerced, name=f"call.{func_name}");
}

# ─── External Function Support ───────────────────────────────
"""Get or declare an external C function (cached)."""
impl NaIRGenPass._get_or_declare_extern(
    name: str, ret_type: ir.Type, arg_types: list[ir.Type], var_arg: bool = False
) -> ir.Function {
    if name in self.extern_funcs {
        return self.extern_funcs[name];
    }
    fnty = ir.FunctionType(ret_type, arg_types, var_arg=var_arg);
    func = ir.Function(self.llvm_module, fnty, name=name);
    self.extern_funcs[name] = func;
    return func;
}

# ─── Print Support ───────────────────────────────────────────
"""Get or create the printf external function declaration."""
impl NaIRGenPass._get_printf -> ir.Function {
    return self._get_or_declare_extern(
        "printf", ir.IntType(32), [ir.IntType(8).as_pointer()], var_arg=True
    );
}

"""Emit printf call for print()."""
impl NaIRGenPass._emit_print(node: uni.FuncCall) -> (ir.Value | None) {
    printf = self._get_printf();
    params = node.params or [];
    if not params {
        fmt = self._get_fmt_string("");
        fmt_ptr = self.builder.bitcast(fmt, ir.IntType(8).as_pointer());
        self.builder.call(printf, [fmt_ptr]);
        return ir.Constant(ir.IntType(64), 0);
    }
    val = self._codegen_expr(params[0]);
    if val is None {
        return ir.Constant(ir.IntType(64), 0);
    }
    if isinstance(val.type, ir.IntType) and val.type.width == 64 {
        fmt = self._get_fmt_string("%lld");
    } elif isinstance(val.type, ir.DoubleType) {
        fmt = self._get_fmt_string("%f");
    } elif isinstance(val.type, ir.IntType) and val.type.width == 1 {
        val = self.builder.zext(val, ir.IntType(64));
        fmt = self._get_fmt_string("%lld");
    } elif isinstance(val.type, ir.PointerType) {
        fmt = self._get_fmt_string("%s");
    } else {
        return ir.Constant(ir.IntType(64), 0);
    }
    fmt_ptr = self.builder.bitcast(fmt, ir.IntType(8).as_pointer());
    self.builder.call(printf, [fmt_ptr, val]);
    return ir.Constant(ir.IntType(64), 0);
}

"""Get or create a global format string for printf."""
impl NaIRGenPass._get_fmt_string(fmt: str) -> ir.GlobalVariable {
    if fmt in self._fmt_strings {
        return self._fmt_strings[fmt];
    }
    fmt_bytes = bytearray((fmt + "\n\0").encode("utf8"));
    c_fmt = ir.Constant(ir.ArrayType(ir.IntType(8), len(fmt_bytes)), fmt_bytes);
    global_fmt = ir.GlobalVariable(
        self.llvm_module, c_fmt.type, name=f".fmt.{len(self._fmt_strings)}"
    );
    global_fmt.linkage = "private";
    global_fmt.global_constant = True;
    global_fmt.initializer = c_fmt;
    self._fmt_strings[fmt] = global_fmt;
    return global_fmt;
}

# ─── Helper Methods ──────────────────────────────────────────
"""Resolve a Jac type expression to an LLVM type."""
impl NaIRGenPass._resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type {
    if type_expr is None {
        return ir.IntType(64);
    }
    # Handle Name nodes (type references like `int`, `float`, `Point`)
    if isinstance(type_expr, uni.Name) {
        type_name = type_expr.value;
        if type_name in self.type_map {
            return self.type_map[type_name];
        }
        # Check if it's a known struct type → pointer to struct
        if type_name in self.struct_types {
            return self.struct_types[type_name].as_pointer();
        }
        if type_name == "None" {
            return ir.VoidType();
        }
    }
    # Handle BuiltinType nodes
    if uni?.BuiltinType and isinstance(type_expr, uni.BuiltinType) {
        type_name = type_expr.value;
        if type_name in self.type_map {
            return self.type_map[type_name];
        }
    }
    # Generic fallback: any node with .value matching a known type (handles Tokens)
    if type_expr?.value and isinstance(getattr(type_expr, "value", None), str) {
        type_name = type_expr.value;
        if type_name in self.type_map {
            return self.type_map[type_name];
        }
        if type_name in self.struct_types {
            return self.struct_types[type_name].as_pointer();
        }
        if type_name == "None" {
            return ir.VoidType();
        }
    }
    # Handle union types: T | None → resolve T (BinaryExpr with BW_OR op)
    if isinstance(type_expr, uni.BinaryExpr) {
        op_val = getattr(type_expr.op, 'value', '');
        if op_val == "|" {
            # Resolve left side; right is typically None
            right_name = self._get_name(type_expr.right);
            left_type = self._resolve_jac_type(type_expr.left);
            if right_name == "None" {
                # T | None → just use T's type (pointers are nullable)
                return left_type;
            }
            # For non-None unions, use the left type (simplified)
            return left_type;
        }
    }
    # Handle list[T] type annotations (AtomTrailer: list[T])
    if isinstance(type_expr, uni.AtomTrailer) and not type_expr.is_attr {
        target_name = self._get_name(type_expr.target);
        if target_name == "list" {
            if type_expr?.right and type_expr.right?.slices {
                slices = type_expr.right.slices or [];
                if slices {
                    elem_node = slices[0];
                    if elem_node?.start and elem_node.start is not None {
                        elem_type = self._resolve_jac_type(elem_node.start);
                    } else {
                        elem_type = self._resolve_jac_type(elem_node);
                    }
                    elem_type_name = "i64";
                    if isinstance(elem_type, ir.DoubleType) {
                        elem_type_name = "f64";
                    } elif isinstance(elem_type, ir.PointerType) {
                        elem_type_name = "ptr";
                    }
                    self._emit_list_helpers(elem_type_name, elem_type);
                    return self.list_types[elem_type_name].as_pointer();
                }
            }
        }
    }
    # Try expr_type string
    if type_expr?.expr_type and type_expr.expr_type in self.type_map {
        return self.type_map[type_expr.expr_type];
    }
    return ir.IntType(64);
}

"""Extract name string from a Name or similar node."""
impl NaIRGenPass._get_name(node: (uni.UniNode | None)) -> (str | None) {
    if node is None {
        return None;
    }
    if isinstance(node, uni.Name) {
        return node.value;
    }
    if node?.sym_name {
        return node.sym_name;
    }
    if node?.value and isinstance(getattr(node, "value"), str) {
        return node.value;
    }
    return None;
}

"""Create an alloca in the function entry block (ensures dominance)."""
impl NaIRGenPass._entry_alloca(var_type: ir.Type, name: str) -> ir.Value {
    func = self.builder.function;
    entry_block = func.entry_basic_block;
    # Save current position
    cur_block = self.builder.block;
    # Position at the start of the entry block (before all instructions)
    if entry_block.instructions {
        self.builder.position_before(entry_block.instructions[0]);
    } else {
        self.builder.position_at_start(entry_block);
    }
    alloca = self.builder.alloca(var_type, name=name);
    # Restore position
    self.builder.position_at_end(cur_block);
    return alloca;
}

"""Convert a value to i1 (boolean)."""
impl NaIRGenPass._to_bool(val: ir.Value) -> ir.Value {
    if isinstance(val.type, ir.IntType) and val.type.width == 1 {
        return val;
    }
    if isinstance(val.type, ir.IntType) {
        return self.builder.icmp_unsigned(
            "!=", val, ir.Constant(val.type, 0), name="tobool"
        );
    }
    if isinstance(val.type, ir.DoubleType) {
        return self.builder.fcmp_ordered(
            "!=", val, ir.Constant(val.type, 0.0), name="tobool"
        );
    }
    return val;
}

"""Coerce a value to the target type if needed."""
impl NaIRGenPass._coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value {
    if val.type == target_type {
        return val;
    }
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.DoubleType) {
        return self.builder.sitofp(val, target_type, name="cast");
    }
    if isinstance(val.type, ir.DoubleType) and isinstance(target_type, ir.IntType) {
        return self.builder.fptosi(val, target_type, name="cast");
    }
    # Pointer-to-pointer bitcast (e.g., different struct pointer types)
    if isinstance(val.type, ir.PointerType) and isinstance(target_type, ir.PointerType) {
        return self.builder.bitcast(val, target_type, name="ptrcast");
    }
    # Int width coercion (i1 to i64, etc.)
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.IntType) {
        if val.type.width < target_type.width {
            return self.builder.zext(val, target_type, name="zext");
        } elif val.type.width > target_type.width {
            return self.builder.trunc(val, target_type, name="trunc");
        }
    }
    return val;
}

"""Promote both operands to float if either is float."""
impl NaIRGenPass._promote_to_float(
    left: ir.Value, right: ir.Value
) -> tuple[(ir.Value, ir.Value)] {
    if isinstance(left.type, ir.IntType) {
        left = self.builder.sitofp(left, ir.DoubleType(), name="cast");
    }
    if isinstance(right.type, ir.IntType) {
        right = self.builder.sitofp(right, ir.DoubleType(), name="cast");
    }
    return (left, right);
}

"""Emit a binary operation."""
impl NaIRGenPass._emit_binary_op(
    op: str, left: ir.Value, right: ir.Value
) -> (ir.Value | None) {
    # String concatenation (i8* + i8*) — check before numeric dispatch
    if op == Tok.PLUS
    and isinstance(left.type, ir.PointerType)
    and isinstance(right.type, ir.PointerType) {
        strlen_fn = self._get_or_declare_extern(
            "strlen", ir.IntType(64), [ir.IntType(8).as_pointer()]
        );
        gc_malloc = self._get_or_declare_extern(
            "GC_malloc", ir.IntType(8).as_pointer(), [ir.IntType(64)]
        );
        strcpy_fn = self._get_or_declare_extern(
            "strcpy",
            ir.IntType(8).as_pointer(),
            [ir.IntType(8).as_pointer(), ir.IntType(8).as_pointer()]
        );
        strcat_fn = self._get_or_declare_extern(
            "strcat",
            ir.IntType(8).as_pointer(),
            [ir.IntType(8).as_pointer(), ir.IntType(8).as_pointer()]
        );
        len1 = self.builder.call(strlen_fn, [left], name="len1");
        len2 = self.builder.call(strlen_fn, [right], name="len2");
        total = self.builder.add(len1, len2, name="total_len");
        buf_size = self.builder.add(
            total, ir.Constant(ir.IntType(64), 1), name="buf_size"
        );
        buf = self.builder.call(gc_malloc, [buf_size], name="concat.buf");
        self.builder.call(strcpy_fn, [buf, left]);
        self.builder.call(strcat_fn, [buf, right]);
        return buf;
    }
    is_float = isinstance(left.type, ir.DoubleType)
    or isinstance(right.type, ir.DoubleType);
    if is_float {
        (left, right) = self._promote_to_float(left, right);
    }
    if is_float {
        if op == Tok.PLUS {
            return self.builder.fadd(left, right, name="fadd");
        } elif op == Tok.MINUS {
            return self.builder.fsub(left, right, name="fsub");
        } elif op == Tok.STAR_MUL {
            return self.builder.fmul(left, right, name="fmul");
        } elif op == Tok.DIV {
            return self.builder.fdiv(left, right, name="fdiv");
        } elif op == Tok.MOD {
            return self.builder.frem(left, right, name="fmod");
        }
    } else {
        if op == Tok.PLUS {
            return self.builder.add(left, right, name="add");
        } elif op == Tok.MINUS {
            return self.builder.sub(left, right, name="sub");
        } elif op == Tok.STAR_MUL {
            return self.builder.mul(left, right, name="mul");
        } elif op == Tok.DIV {
            return self.builder.sdiv(left, right, name="div");
        } elif op == Tok.FLOOR_DIV {
            return self.builder.sdiv(left, right, name="floordiv");
        } elif op == Tok.MOD {
            return self.builder.srem(left, right, name="mod");
        }
    }
    # Logical operators
    if op == Tok.KW_AND {
        return self.builder.and_(left, right, name="and");
    }
    if op == Tok.KW_OR {
        return self.builder.or_(left, right, name="or");
    }
    return None;
}

"""Emit a comparison operation."""
impl NaIRGenPass._emit_comparison(
    op: str, left: ir.Value, right: ir.Value, is_float: bool
) -> (ir.Value | None) {
    # String comparison (i8* operands)
    if isinstance(left.type, ir.PointerType) and isinstance(right.type, ir.PointerType) {
        strcmp_fn = self._get_or_declare_extern(
            "strcmp",
            ir.IntType(32),
            [ir.IntType(8).as_pointer(), ir.IntType(8).as_pointer()]
        );
        cmp_result = self.builder.call(strcmp_fn, [left, right], name="strcmp");
        zero = ir.Constant(ir.IntType(32), 0);
        if op == Tok.EE {
            return self.builder.icmp_signed("==", cmp_result, zero, name="streq");
        } elif op == Tok.NE {
            return self.builder.icmp_signed("!=", cmp_result, zero, name="strne");
        }
        return None;
    }
    if is_float {
        fcmp_map: dict[(str, str)] = {
            Tok.EE: "==",
            Tok.NE: "!=",
            Tok.LT: "<",
            Tok.GT: ">",
            Tok.LTE: "<=",
            Tok.GTE: ">="
        };
        if op in fcmp_map {
            return self.builder.fcmp_ordered(fcmp_map[op], left, right, name="fcmp");
        }
    } else {
        icmp_map: dict[(str, str)] = {
            Tok.EE: "==",
            Tok.NE: "!=",
            Tok.LT: "<",
            Tok.GT: ">",
            Tok.LTE: "<=",
            Tok.GTE: ">="
        };
        if op in icmp_map {
            return self.builder.icmp_signed(icmp_map[op], left, right, name="icmp");
        }
    }
    return None;
}

# ─── Phase 1: Enums ──────────────────────────────────────────
"""Register an enum type — store each member as an i64 constant."""
impl NaIRGenPass._codegen_enum(<>node: uni.Enum) -> None {
    enum_name = (<>node).name.value if (<>node).name else "unknown_enum";
    self.enum_types[enum_name] = ir.IntType(64);
    self.type_map[enum_name] = ir.IntType(64);
    self.has_native_code = True;
    if (<>node).body is None {
        return;
    }
    for stmt in (<>node).body {
        if isinstance(stmt, uni.Assignment) {
            targets = stmt.target
            if isinstance(stmt.target, (<>list, <>tuple))
            else [stmt.target];
            for target_expr in targets {
                member_name = self._get_name(target_expr);
                if member_name is None {
                    continue;
                }
                # Evaluate the value (should be an integer literal)
                if stmt.value is not None and isinstance(stmt.value, uni.Int) {
                    val = int(stmt.value.value);
                } else {
                    val = 0;
                }
                full_name = f"{enum_name}.{member_name}";
                self.enum_values[full_name] = ir.Constant(ir.IntType(64), val);
            }
        }
    }
}

# ─── Phase 1: AtomTrailer (attribute access) ─────────────────
"""Generate code for attribute/subscript access (e.g. Color.WHITE, self.x)."""
impl NaIRGenPass._codegen_atom_trailer(node: uni.AtomTrailer) -> (ir.Value | None) {
    if node.is_attr {
        target_name = self._get_name(node.target);
        right_name = self._get_name(node.right);
        if target_name is not None and right_name is not None {
            # Check enum member access: Color.WHITE
            full_name = f"{target_name}.{right_name}";
            if full_name in self.enum_values {
                return self.enum_values[full_name];
            }
            # Check field access on a known-type variable: self.x, p.x
            if target_name in self.type_var_map {
                type_name = self.type_var_map[target_name];
                obj_val = self._codegen_expr(node.target);
                if obj_val is not None {
                    result = self._codegen_field_access(obj_val, right_name, type_name);
                    # Set type node hint for chained access
                    if type_name in self.field_type_node {
                        self._last_type_node_hint = self.field_type_node[type_name].get(
                            right_name
                        );
                    }
                    return result;
                }
            }
        }
        # Chained field access: expr.field where expr is a complex expression
        if right_name is not None {
            obj_val = self._codegen_expr(node.target);
            if obj_val is not None {
                type_name = self._infer_type_name(obj_val);
                if type_name is not None {
                    result = self._codegen_field_access(obj_val, right_name, type_name);
                    if type_name in self.field_type_node {
                        self._last_type_node_hint = self.field_type_node[type_name].get(
                            right_name
                        );
                    }
                    return result;
                }
            }
        }
    }
    # Handle index access: items[i] or expr[i]
    if not node.is_attr and node.right?.slices {
        target_name = self._get_name(node.target);
        # Simple name: use tracked list type
        if target_name is not None and target_name in self.var_list_elem_type {
            elem_type_name = self.var_list_elem_type[target_name];
            target_val = self._codegen_expr(node.target);
            if target_val is not None {
                slices = node.right.slices or [];
                if slices {
                    idx_node = slices[0];
                    idx_val = self._codegen_expr(idx_node);
                    if idx_val is None and idx_node?.start {
                        idx_val = self._codegen_expr(idx_node.start);
                    }
                    if idx_val is not None {
                        result = self._codegen_index(
                            target_val, idx_val, elem_type_name
                        );
                        # Bitcast ptr list elements to correct inner type
                        if result is not None and elem_type_name == "ptr" {
                            var_tn = self.var_type_node.get(target_name);
                            cast_type = self._resolve_ptr_elem_cast_type(var_tn);
                            if cast_type is not None and result.type != cast_type {
                                result = self.builder.bitcast(
                                    result, cast_type, name="idx.cast"
                                );
                            }
                            # Propagate inner type node for further chaining
                            if var_tn is not None {
                                (inner_node, inner_llvm, inner_elem) = self._peel_list_type(
                                    var_tn
                                );
                                self._last_type_node_hint = inner_node;
                            }
                        }
                        return result;
                    }
                }
            }
        } else {
            # Chained index: evaluate target expression, infer list type or string
            # Capture the type node hint before evaluating (set by field access in chain)
            pre_type_hint = self._last_type_node_hint;
            self._last_type_node_hint = None;
            target_val = self._codegen_expr(node.target);
            # Grab the hint set during target evaluation (e.g. field access sets it)
            chain_type_hint = self._last_type_node_hint;
            if chain_type_hint is None {
                chain_type_hint = pre_type_hint;
            }
            if target_val is not None {
                # Check for string indexing: s[i] (only real i8* strings, not list ptrs)
                i8p = ir.IntType(8).as_pointer();
                if target_val.type == i8p {
                    # If chain type hint indicates this is a list, don't string-index
                    is_list_from_hint = (
                        chain_type_hint is not None
                        and self._get_list_elem_from_type_node(chain_type_hint) is not None
                    );
                    inner_target_name = self._get_name(node.target)
                    if isinstance(node.target, uni.Name)
                    else None;
                    is_known_list = (
                        inner_target_name is not None
                        and inner_target_name in self.var_list_elem_type
                    );
                    if not is_known_list and not is_list_from_hint {
                        slices = node.right.slices or [];
                        if slices {
                            idx_node = slices[0];
                            idx_val = self._codegen_expr(idx_node);
                            if idx_val is None and idx_node?.start {
                                idx_val = self._codegen_expr(idx_node.start);
                            }
                            if idx_val is not None {
                                return self._codegen_string_index(target_val, idx_val);
                            }
                        }
                    }
                }
                # Check for list indexing (works with properly-typed List.T* pointers)
                elem_type_name = self._infer_list_elem_type(target_val);
                if elem_type_name is not None {
                    slices = node.right.slices or [];
                    if slices {
                        idx_node = slices[0];
                        idx_val = self._codegen_expr(idx_node);
                        if idx_val is None and idx_node?.start {
                            idx_val = self._codegen_expr(idx_node.start);
                        }
                        if idx_val is not None {
                            result = self._codegen_index(
                                target_val, idx_val, elem_type_name
                            );
                            # Bitcast ptr list elements using chain type hint
                            if result is not None
                            and elem_type_name == "ptr"
                            and chain_type_hint is not None {
                                cast_type = self._resolve_ptr_elem_cast_type(
                                    chain_type_hint
                                );
                                if cast_type is not None and result.type != cast_type {
                                    result = self.builder.bitcast(
                                        result, cast_type, name="chain.idx.cast"
                                    );
                                }
                                # Propagate inner type node for further chaining
                                (inner_node, inner_llvm, inner_elem) = self._peel_list_type(
                                    chain_type_hint
                                );
                                self._last_type_node_hint = inner_node;
                            }
                            return result;
                        }
                    }
                }
            }
        }
    }
    return None;
}

# ─── Phase 1: Boolean Expressions (short-circuit) ────────────
"""Generate short-circuit boolean and/or expression."""
impl NaIRGenPass._codegen_bool_expr(node: uni.BoolExpr) -> (ir.Value | None) {
    if not node.values {
        return None;
    }
    op_name = node.op.name if isinstance(node.op, uni.Token) else str(node.op);
    is_and = op_name == Tok.KW_AND;
    # Evaluate first operand
    result = self._codegen_expr(node.values[0]);
    if result is None {
        return None;
    }
    result = self._to_bool(result);
    # Short-circuit chain for remaining operands
    for i in range(1, len(node.values)) {
        func = self.builder.function;
        rhs_bb = func.append_basic_block(name=f"bool.rhs.{i}");
        merge_bb = func.append_basic_block(name=f"bool.merge.{i}");
        entry_bb = self.builder.block;
        if is_and {
            # AND: if first is false, skip rest (result = false)
            self.builder.cbranch(result, rhs_bb, merge_bb);
        } else {
            # OR: if first is true, skip rest (result = true)
            self.builder.cbranch(result, merge_bb, rhs_bb);
        }
        # RHS block
        self.builder.position_at_end(rhs_bb);
        rhs_val = self._codegen_expr(node.values[i]);
        if rhs_val is None {
            rhs_val = ir.Constant(ir.IntType(1), 0);
        }
        rhs_val = self._to_bool(rhs_val);
        rhs_end_bb = self.builder.block;
        if not self.builder.block.is_terminated {
            self.builder.branch(merge_bb);
        }
        # Merge block with phi
        self.builder.position_at_end(merge_bb);
        phi = self.builder.phi(ir.IntType(1), name="bool.result");
        if is_and {
            phi.add_incoming(ir.Constant(ir.IntType(1), 0), entry_bb);
        } else {
            phi.add_incoming(ir.Constant(ir.IntType(1), 1), entry_bb);
        }
        phi.add_incoming(rhs_val, rhs_end_bb);
        result = phi;
    }
    return result;
}

# ─── Phase 1: Break / Continue ───────────────────────────────
"""Generate break or continue statement."""
impl NaIRGenPass._codegen_ctrl(node: uni.CtrlStmt) -> None {
    if not self.loop_stack {
        return;
    }
    ctrl_name = node.ctrl.name if isinstance(node.ctrl, uni.Token) else str(node.ctrl);
    (continue_bb, break_bb) = self.loop_stack[-1];
    if ctrl_name == Tok.KW_BREAK {
        self.builder.branch(break_bb);
    } elif ctrl_name == Tok.KW_CONTINUE {
        self.builder.branch(continue_bb);
    }
}

# ─── Phase 1: For Loops ──────────────────────────────────────
"""Generate for loop (currently supports range(n) and range(start, stop))."""
impl NaIRGenPass._codegen_for(node: uni.InForStmt) -> None {
    # Extract loop variable name
    loop_var_name = self._get_name(node.target);
    if loop_var_name is None {
        return;
    }
    # Detect range() calls
    start_val: (ir.Value | None) = None;
    stop_val: (ir.Value | None) = None;
    if isinstance(node.collection, uni.FuncCall) {
        call_name = self._get_name(node.collection.target);
        if call_name == "range" {
            params = node.collection.params or [];
            if len(params) == 1 {
                start_val = ir.Constant(ir.IntType(64), 0);
                stop_val = self._codegen_expr(params[0]);
            } elif len(params) >= 2 {
                start_val = self._codegen_expr(params[0]);
                stop_val = self._codegen_expr(params[1]);
            }
        }
    }
    if start_val is not None and stop_val is not None {
        # Range-based for loop
        start_val = self._coerce_type(start_val, ir.IntType(64));
        stop_val = self._coerce_type(stop_val, ir.IntType(64));
        alloca = self.builder.alloca(ir.IntType(64), name=loop_var_name);
        self.builder.store(start_val, alloca);
        self.local_vars[loop_var_name] = alloca;
        func = self.builder.function;
        cond_bb = func.append_basic_block(name="for.cond");
        body_bb = func.append_basic_block(name="for.body");
        incr_bb = func.append_basic_block(name="for.incr");
        end_bb = func.append_basic_block(name="for.end");
        self.builder.branch(cond_bb);
        self.builder.position_at_end(cond_bb);
        i_val = self.builder.load(alloca, name=loop_var_name);
        cmp = self.builder.icmp_signed("<", i_val, stop_val, name="for.cmp");
        self.builder.cbranch(cmp, body_bb, end_bb);
        self.loop_stack.append((incr_bb, end_bb));
        self.builder.position_at_end(body_bb);
        if isinstance(node.body, (<>list, <>tuple)) {
            self._codegen_body(node.body);
        }
        if not self.builder.block.is_terminated {
            self.builder.branch(incr_bb);
        }
        self.loop_stack.pop();
        self.builder.position_at_end(incr_bb);
        i_cur = self.builder.load(alloca, name="for.cur");
        i_next = self.builder.add(
            i_cur, ir.Constant(ir.IntType(64), 1), name="for.next"
        );
        self.builder.store(i_next, alloca);
        self.builder.branch(cond_bb);
        self.builder.position_at_end(end_bb);
        return;
    }
    # ── List iteration: for x in items ──
    # Set list type hint in case collection is a list literal
    self._list_type_hint = None;
    coll_name = self._get_name(node.collection);
    # Infer elem type hint from collection variable's type node
    if coll_name is not None and coll_name in self.var_type_node {
        coll_type_node = self.var_type_node[coll_name];
        hint = self._get_list_elem_from_type_node(coll_type_node);
        if hint is not None {
            self._list_type_hint = hint;
        }
    }
    self._last_type_node_hint = None;
    collection_val = self._codegen_expr(node.collection);
    coll_type_hint = self._last_type_node_hint;
    self._list_type_hint = None;
    if collection_val is None {
        return;
    }
    # Determine element type of the list
    elem_type_name: (str | None) = None;
    if coll_name is not None and coll_name in self.var_list_elem_type {
        elem_type_name = self.var_list_elem_type[coll_name];
    } else {
        elem_type_name = self._infer_list_elem_type(collection_val);
    }
    if elem_type_name is None {
        return;
    }
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return;
    }
    i64 = ir.IntType(64);
    # Get list length
    len_val = self.builder.call(helpers["len"], [collection_val], name="forl.len");
    # Allocate loop index
    idx_alloca = self.builder.alloca(i64, name="forl.idx");
    self.builder.store(ir.Constant(i64, 0), idx_alloca);
    # Resolve actual element type for ptr lists (before allocating loop var)
    actual_elem_type = helpers["elem_type"];
    inner_type: (ir.Type | None) = None;
    # Get the type node for the collection (from variable or from field access hint)
    coll_type_node: (object | None) = None;
    if coll_name is not None and coll_name in self.var_type_node {
        coll_type_node = self.var_type_node[coll_name];
    } elif coll_type_hint is not None {
        coll_type_node = coll_type_hint;
    }
    if elem_type_name == "ptr" {
        inner_type = self._resolve_for_loop_elem_type(coll_name, node.collection);
        # Fallback: use coll_type_hint from field access
        if inner_type is None and coll_type_node is not None {
            (_, inner_type_from_hint, _) = self._peel_list_type(coll_type_node);
            if inner_type_from_hint is not None {
                inner_type = inner_type_from_hint;
            }
        }
        if inner_type is not None {
            actual_elem_type = inner_type;
            # Track inner type info on loop var
            for (sname, stype) in self.struct_types.items() {
                if inner_type == stype.as_pointer() {
                    self.type_var_map[loop_var_name] = sname;
                    break;
                }
            }
            for (ename, ltype) in self.list_types.items() {
                if inner_type == ltype.as_pointer() {
                    self.var_list_elem_type[loop_var_name] = ename;
                    break;
                }
            }
            # Propagate inner type node for nested access
            if coll_type_node is not None {
                (inner_node, _, _) = self._peel_list_type(coll_type_node);
                if inner_node is not None {
                    self.var_type_node[loop_var_name] = inner_node;
                }
            }
        }
    }
    # Allocate loop variable with resolved element type
    loop_alloca = self.builder.alloca(actual_elem_type, name=loop_var_name);
    self.local_vars[loop_var_name] = loop_alloca;
    func = self.builder.function;
    cond_bb = func.append_basic_block(name="forl.cond");
    body_bb = func.append_basic_block(name="forl.body");
    incr_bb = func.append_basic_block(name="forl.incr");
    end_bb = func.append_basic_block(name="forl.end");
    self.builder.branch(cond_bb);
    # Condition: idx < len
    self.builder.position_at_end(cond_bb);
    cur_idx = self.builder.load(idx_alloca, name="forl.cur.idx");
    cmp = self.builder.icmp_signed("<", cur_idx, len_val, name="forl.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);
    # Body: load element, store in loop var, execute body
    self.loop_stack.append((incr_bb, end_bb));
    self.builder.position_at_end(body_bb);
    body_idx = self.builder.load(idx_alloca, name="forl.body.idx");
    elem_val = self.builder.call(
        helpers["get"], [collection_val, body_idx], name="forl.elem"
    );
    # Bitcast ptr elements to the correct inner type if resolved
    if inner_type is not None {
        elem_val = self.builder.bitcast(elem_val, inner_type, name="forl.cast");
    }
    self.builder.store(elem_val, loop_alloca);
    if isinstance(node.body, (<>list, <>tuple)) {
        self._codegen_body(node.body);
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(incr_bb);
    }
    self.loop_stack.pop();
    # Increment: idx = idx + 1
    self.builder.position_at_end(incr_bb);
    inc_idx = self.builder.load(idx_alloca, name="forl.inc.idx");
    next_idx = self.builder.add(inc_idx, ir.Constant(i64, 1), name="forl.next.idx");
    self.builder.store(next_idx, idx_alloca);
    self.builder.branch(cond_bb);
    # Continue after loop
    self.builder.position_at_end(end_bb);
}

# ─── Phase 1: Ternary If-Else Expression ─────────────────────
"""Generate ternary expression: value if condition else else_value."""
impl NaIRGenPass._codegen_if_else_expr(node: uni.IfElseExpr) -> (ir.Value | None) {
    cond = self._codegen_expr(node.condition);
    if cond is None {
        return None;
    }
    cond = self._to_bool(cond);
    func = self.builder.function;
    then_bb = func.append_basic_block(name="ternary.then");
    else_bb = func.append_basic_block(name="ternary.else");
    merge_bb = func.append_basic_block(name="ternary.end");
    self.builder.cbranch(cond, then_bb, else_bb);
    # Then
    self.builder.position_at_end(then_bb);
    then_val = self._codegen_expr(node.value);
    then_end_bb = self.builder.block;
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    # Else
    self.builder.position_at_end(else_bb);
    else_val = self._codegen_expr(node.else_value);
    else_end_bb = self.builder.block;
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    # Merge with phi
    self.builder.position_at_end(merge_bb);
    if then_val is not None and else_val is not None {
        # Coerce both to same type
        if then_val.type != else_val.type {
            if isinstance(then_val.type, ir.DoubleType)
            or isinstance(else_val.type, ir.DoubleType) {
                (then_val, else_val) = self._promote_to_float(then_val, else_val);
            }
        }
        phi = self.builder.phi(then_val.type, name="ternary.result");
        phi.add_incoming(then_val, then_end_bb);
        phi.add_incoming(else_val, else_end_bb);
        return phi;
    }
    return None;
}

# ─── Phase 2: Strings ────────────────────────────────────────
"""Generate code for a MultiString node (wraps String/FString)."""
impl NaIRGenPass._codegen_multistring(node: uni.MultiString) -> (ir.Value | None) {
    if not node.strings {
        return None;
    }
    # Single string — delegate directly
    if len(node.strings) == 1 {
        part = node.strings[0];
        if isinstance(part, uni.FString) {
            return self._codegen_fstring(part);
        }
        return self._codegen_string(part);
    }
    # Multiple strings — concatenate via string concat
    result = None;
    for part in node.strings {
        if isinstance(part, uni.FString) {
            val = self._codegen_fstring(part);
        } else {
            val = self._codegen_string(part);
        }
        if val is None {
            continue;
        }
        if result is None {
            result = val;
        } else {
            result = self._emit_binary_op(Tok.PLUS, result, val);
        }
    }
    return result;
}

"""Create a global constant string and return an i8* pointer to it."""
impl NaIRGenPass._make_global_string(text: str, name_prefix: str = ".str") -> ir.Value {
    str_bytes = bytearray((text + "\0").encode("utf8"));
    c_str = ir.Constant(ir.ArrayType(ir.IntType(8), len(str_bytes)), str_bytes);
    global_str = ir.GlobalVariable(
        self.llvm_module, c_str.type, name=f"{name_prefix}.{self._str_count}"
    );
    self._str_count = self._str_count + 1;
    global_str.linkage = "private";
    global_str.global_constant = True;
    global_str.initializer = c_str;
    return self.builder.bitcast(global_str, ir.IntType(8).as_pointer());
}

"""Generate a string literal as a global constant, returning i8*."""
impl NaIRGenPass._codegen_string(node: uni.String) -> (ir.Value | None) {
    raw = node.value;
    # Strip quotes for standalone string literals
    if len(raw) >= 6 and (raw[:3] == '"""' or raw[:3] == "'''") {
        text = raw[3:-3];
    } elif len(raw) >= 2 and (raw[0] == '"' or raw[0] == "'") {
        text = raw[1:-1];
    } else {
        # F-string literal parts have no quotes
        text = raw;
    }
    # Handle common escape sequences
    text = text.replace("\\n", "\n");
    text = text.replace("\\t", "\t");
    text = text.replace("\\\\", "\\");
    text = text.replace('\\"', '"');
    text = text.replace("\\'", "'");
    return self._make_global_string(text);
}

"""Generate f-string by building a printf-style format string and calling snprintf."""
impl NaIRGenPass._codegen_fstring(node: uni.FString) -> (ir.Value | None) {
    fmt_parts: list[str] = [];
    args: list[ir.Value] = [];
    for part in node.parts {
        if isinstance(part, uni.String) {
            # Literal text portion — value has no quotes for fstring parts
            raw = part.value;
            if len(raw) >= 2 and (raw[0] == '"' or raw[0] == "'") {
                text = raw[1:-1];
            } else {
                text = raw;
            }
            text = text.replace("\\n", "\n");
            text = text.replace("\\t", "\t");
            text = text.replace("\\\\", "\\");
            # Escape % for printf format
            text = text.replace("%", "%%");
            fmt_parts.append(text);
        } elif isinstance(part, uni.FormattedValue) {
            val = self._codegen_expr(part.format_part);
            if val is None {
                continue;
            }
            if isinstance(val.type, ir.IntType) and val.type.width == 64 {
                fmt_parts.append("%lld");
                args.append(val);
            } elif isinstance(val.type, ir.IntType) and val.type.width == 1 {
                val = self.builder.zext(val, ir.IntType(64));
                fmt_parts.append("%lld");
                args.append(val);
            } elif isinstance(val.type, ir.DoubleType) {
                fmt_parts.append("%f");
                args.append(val);
            } elif isinstance(val.type, ir.PointerType) {
                fmt_parts.append("%s");
                args.append(val);
            }
        }
    }
    fmt_str = "".join(fmt_parts);
    # Allocate buffer via GC_malloc
    gc_malloc = self._get_or_declare_extern(
        "GC_malloc", ir.IntType(8).as_pointer(), [ir.IntType(64)]
    );
    buf_size = ir.Constant(ir.IntType(64), 1024);
    buf = self.builder.call(gc_malloc, [buf_size], name="fstr.buf");
    # Call snprintf(buf, 1024, fmt, args...)
    snprintf_fn = self._get_or_declare_extern(
        "snprintf",
        ir.IntType(32),
        [ir.IntType(8).as_pointer(), ir.IntType(64), ir.IntType(8).as_pointer()],
        var_arg=True
    );
    fmt_global = self._make_global_string(fmt_str, name_prefix=".fstr.fmt");
    call_args: list[ir.Value] = [buf, buf_size, fmt_global];
    for a in args {
        call_args.append(a);
    }
    self.builder.call(snprintf_fn, call_args, name="fstr.len");
    return buf;
}

# ─── Phase 3: Objects ─────────────────────────────────────────
"""Walk the module and register all native archetypes (obj definitions)."""
impl NaIRGenPass._register_archetypes(module: uni.Module) -> None {
    # Collect all archetype nodes, deduplicating forward declarations
    arch_map: dict[(str, uni.Archetype)] = {};
    for stmt in module.body {
        if isinstance(stmt, uni.NativeBlock) {
            for inner in stmt.body {
                if isinstance(inner, uni.Archetype) {
                    aname = inner.name.value if inner.name else "unknown";
                    # Full definition overrides forward declaration
                    if aname not in arch_map or inner.body is not None {
                        arch_map[aname] = inner;
                    }
                }
            }
        } elif isinstance(stmt, uni.Archetype) {
            if (
                isinstance(stmt, uni.ContextAwareNode)
                and stmt.code_context == CodeContext.NATIVE
            ) {
                aname = stmt.name.value if stmt.name else "unknown";
                if aname not in arch_map or stmt.body is not None {
                    arch_map[aname] = stmt;
                }
            }
        }
    }
    archetypes: list[uni.Archetype] = list(arch_map.values());
    # Pass 1: Create opaque identified struct types (handles forward refs)
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        struct_type = self.llvm_module.context.get_identified_type(arch_name);
        self.struct_types[arch_name] = struct_type;
        self.has_native_code = True;
    }
    # Pass 1.5: Build class hierarchy
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.base_classes {
            for base_expr in arch.base_classes {
                parent_name = self._get_name(base_expr);
                if parent_name is not None and parent_name in self.struct_types {
                    self.class_hierarchy[arch_name] = parent_name;
                    break;
                }
            }
        }
    }
    # Determine which classes need vtables (any class in the hierarchy)
    parents_set: set[str] = set();
    for (child, parent) in self.class_hierarchy.items() {
        parents_set.add(parent);
        self.has_vtable[child] = True;
    }
    for parent in parents_set {
        self.has_vtable[parent] = True;
    }
    # Pass 2: Define struct bodies (parents before children)
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch_name not in self.class_hierarchy {
            self._codegen_archetype(arch);
        }
    }
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch_name in self.class_hierarchy {
            self._codegen_archetype(arch);
        }
    }
    # Pass 3: Forward-declare all methods
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                    and isinstance(stmt.signature, uni.FuncSignature) {
                        self._forward_declare_method(arch_name, stmt);
                    }
                }
            }
        }
    }
    # Pass 3.5: Build vtable layouts (parents before children)
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch_name in self.has_vtable and arch_name not in self.class_hierarchy {
            self._build_vtable(arch_name);
        }
    }
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch_name in self.has_vtable and arch_name in self.class_hierarchy {
            self._build_vtable(arch_name);
        }
    }
    # Pass 4: Emit vtable globals
    for arch_name in self.has_vtable {
        self._emit_vtable_global(arch_name);
    }
    # Pass 4.5: Forward-declare free functions (must happen before method bodies)
    self._forward_declare_functions(module);
    # Pass 5: Generate method bodies
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                    and isinstance(stmt.signature, uni.FuncSignature) {
                        self._codegen_method(arch_name, stmt);
                    }
                }
            }
        }
    }
}

"""Register a struct type — define its field layout from has declarations."""
impl NaIRGenPass._codegen_archetype(<>node: uni.Archetype) -> None {
    arch_name = (<>node).name.value if (<>node).name else "unknown";
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None {
        return;
    }
    needs_vtable = arch_name in self.has_vtable;
    parent_name = self.class_hierarchy.get(arch_name);
    # Collect fields
    field_types: list[ir.Type] = [];
    field_index_map: dict[(str, int)] = {};
    field_type_map: dict[(str, ir.Type)] = {};
    field_default_map: dict[(str, object)] = {};
    # Add vtable pointer as field 0 if needed
    if needs_vtable {
        field_types.append(ir.IntType(8).as_pointer().as_pointer());
    }
    # Inherit parent fields (in order by index)
    if parent_name is not None and parent_name in self.struct_field_indices {
        parent_indices = self.struct_field_indices[parent_name];
        parent_types = self.struct_field_types[parent_name];
        parent_defaults = self.struct_field_defaults.get(parent_name, {});
        # Build reverse map: index → field name, then iterate in order
        idx_to_name: dict[(int, str)] = {};
        for (fname, pidx) in parent_indices.items() {
            idx_to_name[pidx] = fname;
        }
        sorted_idxs = sorted(idx_to_name.keys());
        for pidx in sorted_idxs {
            fname = idx_to_name[pidx];
            ftype = parent_types.get(fname, ir.IntType(64));
            field_types.append(ftype);
            field_index_map[fname] = pidx;
            field_type_map[fname] = ftype;
            if fname in parent_defaults {
                field_default_map[fname] = parent_defaults[fname];
            }
        }
    }
    # Add own fields from ArchHas nodes
    if (<>node).body is not None {
        for stmt in (<>node).body {
            if isinstance(stmt, uni.ArchHas) {
                for var in stmt.vars {
                    fname = var.name.value if var.name else "field";
                    ftype = ir.IntType(64);
                    if var.type_tag and var.type_tag.tag {
                        ftype = self._resolve_jac_type(var.type_tag.tag);
                        # Track Jac-level type AST for nested type resolution
                        if arch_name not in self.field_type_node {
                            self.field_type_node[arch_name] = {};
                        }
                        self.field_type_node[arch_name][fname] = var.type_tag.tag;
                    }
                    new_idx = len(field_types);
                    field_types.append(ftype);
                    field_index_map[fname] = new_idx;
                    field_type_map[fname] = ftype;
                    if var.value is not None {
                        field_default_map[fname] = var.value;
                    }
                }
            }
        }
    }
    # Define the struct body
    if field_types {
        struct_type.set_body(*field_types);
    }
    self.struct_field_indices[arch_name] = field_index_map;
    self.struct_field_types[arch_name] = field_type_map;
    self.struct_field_defaults[arch_name] = field_default_map;
}

"""Forward-declare a method with self pointer as first parameter."""
impl NaIRGenPass._forward_declare_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    sig = method.signature;
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None or sig is None {
        return;
    }
    # Build parameter types: self pointer + declared params
    param_types: list[ir.Type] = [struct_type.as_pointer()];
    for p in sig.get_parameters() {
        if p.type_tag and p.type_tag.tag {
            param_types.append(self._resolve_jac_type(p.type_tag.tag));
        } else {
            param_types.append(ir.IntType(64));
        }
    }
    # Return type
    ret_type = self._resolve_jac_type(sig.return_type);
    if isinstance(ret_type, ir.VoidType) {
        ;  # keep void
    }
    fnty = ir.FunctionType(ret_type, param_types);
    func = ir.Function(self.llvm_module, fnty, name=full_name);
    # Name the parameters
    func.args[0].name = "self";
    for (i, p) in enumerate(sig.get_parameters()) {
        func.args[i + 1].name = p.name.value if p.name else f"arg{i}";
    }
    self.method_funcs[full_name] = func;
    self.func_symtab[full_name] = func;
}

"""Generate LLVM IR for a method body."""
impl NaIRGenPass._codegen_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    if func is None {
        return;
    }
    # Create entry block
    block = func.append_basic_block(name="entry");
    saved_builder = self.builder;
    saved_locals = self.local_vars;
    saved_type_map = dict(self.type_var_map);
    self.builder = ir.IRBuilder(block);
    self.local_vars = {};
    # Store self pointer
    self_alloca = self.builder.alloca(func.args[0].type, name="self");
    self.builder.store(func.args[0], self_alloca);
    self.local_vars["self"] = self_alloca;
    self.type_var_map["self"] = arch_name;
    # Store other parameters
    sig = method.signature;
    for (i, p) in enumerate(sig.get_parameters()) {
        param_name = p.name.value if p.name else f"arg{i}";
        arg_val = func.args[i + 1];
        alloca = self.builder.alloca(arg_val.type, name=param_name);
        self.builder.store(arg_val, alloca);
        self.local_vars[param_name] = alloca;
        # Track type info for struct pointer parameters
        if isinstance(arg_val.type, ir.PointerType) {
            for (sname, stype) in self.struct_types.items() {
                if arg_val.type == stype.as_pointer() {
                    self.type_var_map[param_name] = sname;
                    break;
                }
            }
        }
        # Track Jac type annotation for parameters (enables nested list resolution)
        if p.type_tag and p.type_tag.tag {
            self.var_type_node[param_name] = p.type_tag.tag;
            # Also track list elem type from annotation
            for (ename, ltype) in self.list_types.items() {
                if arg_val.type == ltype.as_pointer() {
                    self.var_list_elem_type[param_name] = ename;
                    break;
                }
            }
            # Handle union types T | None for struct tracking
            tag_name = self._get_name(p.type_tag.tag);
            tag_node = p.type_tag.tag;
            if tag_name is None and isinstance(tag_node, uni.BinaryExpr) {
                op_val = getattr(tag_node.op, 'value', '');
                if op_val == "|" {
                    tag_name = self._get_name(tag_node.left);
                }
            }
            if tag_name is not None and tag_name in self.struct_types {
                self.type_var_map[param_name] = tag_name;
            }
        }
    }
    # Generate body
    if isinstance(method.body, (<>list, <>tuple)) {
        self._codegen_body(method.body);
    }
    # Ensure function has a terminator
    if not self.builder.block.is_terminated {
        ret_type = func.return_value.type;
        if isinstance(ret_type, ir.VoidType) {
            self.builder.ret_void();
        } elif isinstance(ret_type, ir.PointerType) {
            self.builder.ret(ir.Constant(ret_type, None));
        } else {
            self.builder.ret(ir.Constant(ret_type, 0));
        }
    }
    method.gen.llvm_ir = func;
    # Restore saved state
    self.builder = saved_builder;
    self.local_vars = saved_locals;
    self.type_var_map = saved_type_map;
}

"""Generate object instantiation: allocate struct, init fields, call postinit."""
impl NaIRGenPass._codegen_instantiation(node: uni.FuncCall) -> (ir.Value | None) {
    type_name = self._get_name(node.target);
    if type_name is None or type_name not in self.struct_types {
        return None;
    }
    struct_type = self.struct_types[type_name];
    struct_ptr_type = struct_type.as_pointer();
    # Compute sizeof using GEP-from-null trick
    null_ptr = ir.Constant(struct_ptr_type, None);
    size_gep = self.builder.gep(
        null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
    );
    size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
    # Allocate via GC_malloc
    gc_malloc = self._get_or_declare_extern(
        "GC_malloc", ir.IntType(8).as_pointer(), [ir.IntType(64)]
    );
    raw_ptr = self.builder.call(gc_malloc, [size], name="raw.ptr");
    obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
    # Store vtable pointer if class has vtable
    if type_name in self.vtable_globals {
        vtable_global = self.vtable_globals[type_name];
        vtable_base = self.builder.gep(
            vtable_global,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="vtable.base"
        );
        vtable_slot = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="vtable.slot"
        );
        self.builder.store(vtable_base, vtable_slot);
    }
    # Initialize fields from keyword arguments
    field_indices = self.struct_field_indices.get(type_name, {});
    field_types = self.struct_field_types.get(type_name, {});
    field_defaults = self.struct_field_defaults.get(type_name, {});
    # Track which fields were explicitly set
    set_fields: set[str] = set();
    params = node.params or [];
    for param in params {
        if isinstance(param, uni.KWPair) {
            key_name = param.key.sym_name if param.key else None;
            if key_name is None or key_name not in field_indices {
                continue;
            }
            val = self._codegen_expr(param.value);
            if val is None {
                continue;
            }
            idx = field_indices[key_name];
            ftype = field_types[key_name];
            val = self._coerce_type(val, ftype);
            field_ptr = self.builder.gep(
                obj_ptr,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                name=f"field.{key_name}"
            );
            self.builder.store(val, field_ptr);
            set_fields.add(key_name);
        }
    }
    # Initialize unset fields with defaults
    for (fname, default_expr) in field_defaults.items() {
        if fname not in set_fields {
            val = self._codegen_expr(default_expr);
            if val is not None {
                idx = field_indices[fname];
                ftype = field_types[fname];
                val = self._coerce_type(val, ftype);
                field_ptr = self.builder.gep(
                    obj_ptr,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                    name=f"default.{fname}"
                );
                self.builder.store(val, field_ptr);
                set_fields.add(fname);
            }
        }
    }
    # Zero-initialize any remaining unset fields
    for (fname, idx) in field_indices.items() {
        if fname not in set_fields {
            ftype = field_types[fname];
            if isinstance(ftype, ir.PointerType) {
                zero_val = ir.Constant(ftype, None);
            } else {
                zero_val = ir.Constant(ftype, 0);
            }
            field_ptr = self.builder.gep(
                obj_ptr,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                name=f"zero.{fname}"
            );
            self.builder.store(zero_val, field_ptr);
        }
    }
    # Call postinit if it exists (Jac renames postinit → __post_init__)
    for pname in [f"{type_name}.__post_init__", f"{type_name}.postinit"] {
        if pname in self.method_funcs {
            postinit_fn = self.method_funcs[pname];
            self.builder.call(postinit_fn, [obj_ptr]);
            break;
        }
    }
    return obj_ptr;
}

"""Generate method call: obj.method(args)."""
impl NaIRGenPass._codegen_method_call(node: uni.FuncCall) -> (ir.Value | None) {
    trailer = node.target;
    if not isinstance(trailer, uni.AtomTrailer) or not trailer.is_attr {
        return None;
    }
    target_name = self._get_name(trailer.target);
    method_name = self._get_name(trailer.right);
    if method_name is None {
        return None;
    }
    # Handle list methods: append (simple name target)
    if target_name is not None and target_name in self.var_list_elem_type {
        elem_type_name = self.var_list_elem_type[target_name];
        helpers = self.list_helpers.get(elem_type_name);
        if helpers is not None and method_name == "append" {
            list_val = self._codegen_expr(trailer.target);
            if list_val is None {
                return None;
            }
            params = node.params or [];
            if params {
                val = self._codegen_expr(params[0]);
                if val is not None {
                    elem_type = helpers["elem_type"];
                    val = self._coerce_type(val, elem_type);
                    self.builder.call(helpers["append"], [list_val, val]);
                }
            }
            return ir.Constant(ir.IntType(64), 0);
        }
    }
    # Handle string methods: strip, split (on any target expression)
    if method_name in ("strip", "split") {
        str_val = self._codegen_expr(trailer.target);
        if str_val is not None and str_val.type == ir.IntType(8).as_pointer() {
            if method_name == "strip" {
                return self._codegen_str_strip(str_val);
            }
            if method_name == "split" {
                params = node.params or [];
                if params {
                    sep_val = self._codegen_expr(params[0]);
                    if sep_val is not None {
                        return self._codegen_str_split(str_val, sep_val);
                    }
                }
            }
        }
    }
    # Determine type_name and obj_val (supports chained access)
    type_name: (str | None) = None;
    obj_val: (ir.Value | None) = None;
    if target_name is not None {
        type_name = self.type_var_map.get(target_name);
    }
    if type_name is None {
        # Complex expression target (chained access) — evaluate and infer
        obj_val = self._codegen_expr(trailer.target);
        if obj_val is not None {
            type_name = self._infer_type_name(obj_val);
            # Handle list methods on complex targets (e.g. g.items.append(x))
            if type_name is None {
                elem_type_name = self._infer_list_elem_type(obj_val);
                if elem_type_name is not None and method_name == "append" {
                    helpers = self.list_helpers.get(elem_type_name);
                    if helpers is not None {
                        params = node.params or [];
                        if params {
                            val = self._codegen_expr(params[0]);
                            if val is not None {
                                elem_type = helpers["elem_type"];
                                val = self._coerce_type(val, elem_type);
                                self.builder.call(helpers["append"], [obj_val, val]);
                            }
                        }
                        return ir.Constant(ir.IntType(64), 0);
                    }
                }
            }
        }
    }
    if type_name is None {
        return None;
    }
    # Find method: check this class and walk up hierarchy
    func = None;
    check_name = type_name;
    while check_name is not None {
        full_name = f"{check_name}.{method_name}";
        if full_name in self.method_funcs {
            func = self.method_funcs[full_name];
            break;
        }
        check_name = self.class_hierarchy.get(check_name);
    }
    if func is None {
        return None;
    }
    # Get the object pointer (reuse if already computed in chained path)
    if obj_val is None {
        obj_val = self._codegen_expr(trailer.target);
    }
    if obj_val is None {
        return None;
    }
    # Build args: [self_ptr, arg1, arg2, ...]
    args: list[ir.Value] = [obj_val];
    params = node.params or [];
    for param in params {
        val = self._codegen_expr(param);
        if val is not None {
            args.append(val);
        }
    }
    # Virtual dispatch if type has vtable
    if type_name in self.has_vtable {
        result = self._codegen_virtual_call(obj_val, method_name, args, type_name);
        if result is not None {
            if isinstance(func.return_value.type, ir.VoidType) {
                return ir.Constant(ir.IntType(64), 0);
            }
            return result;
        }
    }
    # Direct call (for non-vtable types or fallback)
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(func.args) {
            coerced.append(self._coerce_type(arg, func.args[i].type));
        } else {
            coerced.append(arg);
        }
    }
    result = self.builder.call(func, coerced, name=f"call.{method_name}");
    # Return void calls as None
    if isinstance(func.return_value.type, ir.VoidType) {
        return ir.Constant(ir.IntType(64), 0);
    }
    return result;
}

"""Generate field access: GEP into struct + load."""
impl NaIRGenPass._codegen_field_access(
    obj_val: ir.Value, field_name: str, type_name: str
) -> (ir.Value | None) {
    field_indices = self.struct_field_indices.get(type_name);
    if field_indices is None or field_name not in field_indices {
        return None;
    }
    idx = field_indices[field_name];
    field_ptr = self.builder.gep(
        obj_val,
        [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
        name=f"field.{field_name}.ptr"
    );
    return self.builder.load(field_ptr, name=f"field.{field_name}");
}

"""Generate field assignment: GEP into struct + store."""
impl NaIRGenPass._codegen_field_assign(
    target: uni.AtomTrailer, value: ir.Value
) -> None {
    target_name = self._get_name(target.target);
    field_name = self._get_name(target.right);
    if field_name is None {
        return;
    }
    # Resolve the type: try simple name first, then infer from expression
    type_name: (str | None) = None;
    if target_name is not None {
        type_name = self.type_var_map.get(target_name);
    }
    obj_val = self._codegen_expr(target.target);
    if obj_val is None {
        return;
    }
    if type_name is None {
        type_name = self._infer_type_name(obj_val);
    }
    if type_name is None {
        return;
    }
    field_indices = self.struct_field_indices.get(type_name);
    field_types = self.struct_field_types.get(type_name);
    if field_indices is None or field_name not in field_indices {
        return;
    }
    idx = field_indices[field_name];
    ftype = field_types[field_name];
    value = self._coerce_type(value, ftype);
    field_ptr = self.builder.gep(
        obj_val,
        [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
        name=f"field.{field_name}.ptr"
    );
    self.builder.store(value, field_ptr);
}

# ─── Phase 4: Lists ──────────────────────────────────────────
"""Emit LLVM IR helper functions for a list with given element type."""
impl NaIRGenPass._emit_list_helpers(elem_type_name: str, elem_type: ir.Type) -> None {
    if elem_type_name in self.list_helpers {
        return;
    }
    # For "ptr" variant, always use i8* so all pointer types are interchangeable
    if elem_type_name == "ptr" {
        elem_type = ir.IntType(8).as_pointer();
    }
    # Create list struct type: { i64 len, i64 cap, elem_type* data }
    list_struct = self.llvm_module.context.get_identified_type(
        f"List.{elem_type_name}"
    );
    list_struct.set_body(ir.IntType(64), ir.IntType(64), elem_type.as_pointer());
    self.list_types[elem_type_name] = list_struct;
    list_ptr_type = list_struct.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();
    gc_malloc = self._get_or_declare_extern("GC_malloc", i8_ptr, [i64]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    # --- __list_new_T: create an empty list with capacity 8 ---
    new_fnty = ir.FunctionType(list_ptr_type, []);
    new_fn = ir.Function(
        self.llvm_module, new_fnty, name=f"__list_new_{elem_type_name}"
    );
    new_fn.linkage = "private";
    bb = new_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    # Allocate list struct
    null_ptr = ir.Constant(list_ptr_type, None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="sizeof");
    struct_size = b.ptrtoint(size_gep, i64, name="size");
    raw = b.call(gc_malloc, [struct_size], name="raw");
    list_ptr = b.bitcast(raw, list_ptr_type, name="list");
    # len = 0
    len_p = b.gep(list_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    b.store(ir.Constant(i64, 0), len_p);
    # cap = 8
    cap_p = b.gep(list_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr");
    b.store(ir.Constant(i64, 8), cap_p);
    # Allocate data: 8 * sizeof(elem)
    elem_null = ir.Constant(elem_type.as_pointer(), None);
    elem_gep = b.gep(elem_null, [ir.Constant(i32, 1)], name="elem.sizeof");
    elem_size = b.ptrtoint(elem_gep, i64, name="elem.size");
    data_bytes = b.mul(ir.Constant(i64, 8), elem_size, name="data.bytes");
    data_raw = b.call(gc_malloc, [data_bytes], name="data.raw");
    data = b.bitcast(data_raw, elem_type.as_pointer(), name="data");
    data_p = b.gep(
        list_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr"
    );
    b.store(data, data_p);
    b.ret(list_ptr);
    # --- __list_append_T: append an element, growing if needed ---
    append_fnty = ir.FunctionType(ir.VoidType(), [list_ptr_type, elem_type]);
    append_fn = ir.Function(
        self.llvm_module, append_fnty, name=f"__list_append_{elem_type_name}"
    );
    append_fn.linkage = "private";
    append_fn.args[0].name = "list";
    append_fn.args[1].name = "val";
    entry_bb = append_fn.append_basic_block("entry");
    grow_bb = append_fn.append_basic_block("grow");
    store_bb = append_fn.append_basic_block("store");
    b = ir.IRBuilder(entry_bb);
    l_arg = append_fn.args[0];
    v_arg = append_fn.args[1];
    len_p2 = b.gep(l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr");
    cap_p2 = b.gep(l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="cap.ptr");
    cur_len = b.load(len_p2, name="len");
    cur_cap = b.load(cap_p2, name="cap");
    need_grow = b.icmp_unsigned(">=", cur_len, cur_cap, name="need.grow");
    b.cbranch(need_grow, grow_bb, store_bb);
    # Grow block
    b.position_at_end(grow_bb);
    new_cap = b.mul(cur_cap, ir.Constant(i64, 2), name="new.cap");
    b.store(new_cap, cap_p2);
    elem_null2 = ir.Constant(elem_type.as_pointer(), None);
    elem_gep2 = b.gep(elem_null2, [ir.Constant(i32, 1)], name="elem.sizeof");
    elem_sz = b.ptrtoint(elem_gep2, i64, name="elem.size");
    new_bytes = b.mul(new_cap, elem_sz, name="new.bytes");
    new_data_raw = b.call(gc_malloc, [new_bytes], name="new.data.raw");
    new_data = b.bitcast(new_data_raw, elem_type.as_pointer(), name="new.data");
    data_p_g = b.gep(
        l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr.g"
    );
    old_data = b.load(data_p_g, name="old.data");
    old_bytes = b.mul(cur_len, elem_sz, name="old.bytes");
    old_i8 = b.bitcast(old_data, i8_ptr, name="old.i8");
    new_i8 = b.bitcast(new_data, i8_ptr, name="new.i8");
    b.call(memcpy_fn, [new_i8, old_i8, old_bytes]);
    b.store(new_data, data_p_g);
    b.branch(store_bb);
    # Store block
    b.position_at_end(store_bb);
    data_p_s = b.gep(
        l_arg, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr.s"
    );
    cur_data = b.load(data_p_s, name="data");
    slot = b.gep(cur_data, [cur_len], name="slot");
    b.store(v_arg, slot);
    new_len = b.add(cur_len, ir.Constant(i64, 1), name="new.len");
    b.store(new_len, len_p2);
    b.ret_void();
    # --- __list_get_T: return data[index] ---
    get_fnty = ir.FunctionType(elem_type, [list_ptr_type, i64]);
    get_fn = ir.Function(
        self.llvm_module, get_fnty, name=f"__list_get_{elem_type_name}"
    );
    get_fn.linkage = "private";
    get_fn.args[0].name = "list";
    get_fn.args[1].name = "index";
    bb_g = get_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb_g);
    dp = b.gep(
        get_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr"
    );
    d = b.load(dp, name="data");
    ep = b.gep(d, [get_fn.args[1]], name="elem.ptr");
    elem_val = b.load(ep, name="elem");
    b.ret(elem_val);
    # --- __list_set_T: data[index] = val ---
    set_fnty = ir.FunctionType(ir.VoidType(), [list_ptr_type, i64, elem_type]);
    set_fn = ir.Function(
        self.llvm_module, set_fnty, name=f"__list_set_{elem_type_name}"
    );
    set_fn.linkage = "private";
    set_fn.args[0].name = "list";
    set_fn.args[1].name = "index";
    set_fn.args[2].name = "val";
    bb_s = set_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb_s);
    dp2 = b.gep(
        set_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="data.ptr"
    );
    d2 = b.load(dp2, name="data");
    ep2 = b.gep(d2, [set_fn.args[1]], name="elem.ptr");
    b.store(set_fn.args[2], ep2);
    b.ret_void();
    # --- __list_len_T: return len field ---
    len_fnty = ir.FunctionType(i64, [list_ptr_type]);
    len_fn = ir.Function(
        self.llvm_module, len_fnty, name=f"__list_len_{elem_type_name}"
    );
    len_fn.linkage = "private";
    len_fn.args[0].name = "list";
    bb_l = len_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb_l);
    lp = b.gep(
        len_fn.args[0], [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="len.ptr"
    );
    length = b.load(lp, name="len");
    b.ret(length);
    # Store helpers
    self.list_helpers[elem_type_name] = {
        "new": new_fn,
        "append": append_fn,
        "get": get_fn,
        "set": set_fn,
        "len": len_fn,
        "elem_type": elem_type
    };
}

"""Generate code for a list literal [a, b, c, ...]."""
impl NaIRGenPass._codegen_list_val(node: uni.ListVal) -> (ir.Value | None) {
    if not node.values {
        # Empty list: infer type from context
        elem_type_name = "i64";
        # 1. Check the type hint set by assignment/field context
        if self._list_type_hint is not None {
            elem_type_name = self._list_type_hint;
        } elif self.builder and self.builder.function {
            # 2. Fallback: infer from function return type
            ret_type = self.builder.function.return_value.type;
            if isinstance(ret_type, ir.PointerType) {
                # Check if it's a list pointer type
                for (tn, lt) in self.list_types.items() {
                    if lt.as_pointer() == ret_type {
                        elem_type_name = tn;
                        break;
                    }
                }
            }
        }
        # Ensure helpers exist for this elem type
        if elem_type_name == "ptr" {
            self._emit_list_helpers("ptr", ir.IntType(8).as_pointer());
        } elif elem_type_name == "f64" {
            self._emit_list_helpers("f64", ir.DoubleType());
        } else {
            self._emit_list_helpers("i64", ir.IntType(64));
        }
        helpers = self.list_helpers.get(elem_type_name);
        if helpers is not None {
            return self.builder.call(helpers["new"], [], name="list.empty");
        }
        return None;
    }
    # Codegen first element to determine type
    first_val = self._codegen_expr(node.values[0]);
    if first_val is None {
        return None;
    }
    elem_type = first_val.type;
    elem_type_name = "i64";
    if isinstance(elem_type, ir.DoubleType) {
        elem_type_name = "f64";
    } elif isinstance(elem_type, ir.PointerType) {
        elem_type_name = "ptr";
    }
    # Ensure helpers exist
    self._emit_list_helpers(elem_type_name, elem_type);
    helpers = self.list_helpers[elem_type_name];
    i8p = ir.IntType(8).as_pointer();
    # Create new list
    list_val = self.builder.call(helpers["new"], [], name="list.new");
    # Append first element (bitcast pointers to i8* for ptr lists)
    append_val = first_val;
    if elem_type_name == "ptr" and isinstance(first_val.type, ir.PointerType) {
        append_val = self.builder.bitcast(first_val, i8p, name="elem.cast");
    }
    self.builder.call(helpers["append"], [list_val, append_val]);
    # Append remaining elements
    for i in range(1, len(node.values)) {
        val = self._codegen_expr(node.values[i]);
        if val is not None {
            if elem_type_name == "ptr" and isinstance(val.type, ir.PointerType) {
                val = self.builder.bitcast(val, i8p, name="elem.cast");
            } else {
                val = self._coerce_type(val, elem_type);
            }
            self.builder.call(helpers["append"], [list_val, val]);
        }
    }
    return list_val;
}

"""Get element at index from a list."""
impl NaIRGenPass._codegen_index(
    target_val: ir.Value, index_val: ir.Value, elem_type_name: str
) -> (ir.Value | None) {
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return None;
    }
    index_val = self._coerce_type(index_val, ir.IntType(64));
    return self.builder.call(helpers["get"], [target_val, index_val], name="list.get");
}

"""Set element at index in a list."""
impl NaIRGenPass._codegen_index_set(
    target_val: ir.Value, index_val: ir.Value, value: ir.Value, elem_type_name: str
) -> None {
    helpers = self.list_helpers.get(elem_type_name);
    if helpers is None {
        return;
    }
    index_val = self._coerce_type(index_val, ir.IntType(64));
    elem_type = helpers["elem_type"];
    value = self._coerce_type(value, elem_type);
    self.builder.call(helpers["set"], [target_val, index_val, value]);
}

# ─── Phase 5: Inheritance and Vtables ────────────────────────
"""Build vtable layout for a class (parent layout + own methods)."""
impl NaIRGenPass._build_vtable(arch_name: str) -> None {
    parent_name = self.class_hierarchy.get(arch_name);
    layout: list[str] = [];
    # Start with parent's layout
    if parent_name is not None and parent_name in self.vtable_layouts {
        layout = list(self.vtable_layouts[parent_name]);
    }
    # Find own methods (those forward-declared with this class name)
    prefix = f"{arch_name}.";
    for full_name in self.method_funcs {
        if full_name.startswith(prefix) {
            method_name = full_name[len(prefix):];
            if method_name not in layout {
                layout.append(method_name);
            }
        }
    }
    self.vtable_layouts[arch_name] = layout;
    self.vtable_method_indices[arch_name] = {};
    for (i, name) in enumerate(layout) {
        self.vtable_method_indices[arch_name][name] = i;
    }
}

"""Emit a vtable global constant for a class."""
impl NaIRGenPass._emit_vtable_global(arch_name: str) -> None {
    layout = self.vtable_layouts.get(arch_name);
    if layout is None or not layout {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    vtable_type = ir.ArrayType(i8_ptr, len(layout));
    entries: list[ir.Constant] = [];
    for method_name in layout {
        # Resolve: check this class then walk up hierarchy
        func = None;
        check_name = arch_name;
        while check_name is not None {
            full_name = f"{check_name}.{method_name}";
            if full_name in self.method_funcs {
                func = self.method_funcs[full_name];
                break;
            }
            check_name = self.class_hierarchy.get(check_name);
        }
        if func is not None {
            entries.append(func.bitcast(i8_ptr));
        } else {
            entries.append(ir.Constant(i8_ptr, None));
        }
    }
    vtable_init = ir.Constant(vtable_type, entries);
    vtable_global = ir.GlobalVariable(
        self.llvm_module, vtable_type, name=f"{arch_name}.__vtable"
    );
    vtable_global.global_constant = True;
    vtable_global.linkage = "private";
    vtable_global.initializer = vtable_init;
    self.vtable_globals[arch_name] = vtable_global;
}

"""Generate a virtual method call via vtable lookup."""
impl NaIRGenPass._codegen_virtual_call(
    obj_val: ir.Value, method_name: str, args: list[ir.Value], obj_type_name: str
) -> (ir.Value | None) {
    indices = self.vtable_method_indices.get(obj_type_name);
    if indices is None or method_name not in indices {
        return None;
    }
    method_idx = indices[method_name];
    i32 = ir.IntType(32);
    i8_ptr = ir.IntType(8).as_pointer();
    # Load vtable pointer from field 0
    vtable_ptr_ptr = self.builder.gep(
        obj_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="vtable.ptr.ptr"
    );
    vtable_ptr = self.builder.load(vtable_ptr_ptr, name="vtable.ptr");
    # GEP to method index
    method_slot = self.builder.gep(
        vtable_ptr, [ir.Constant(i32, method_idx)], name=f"vt.{method_name}"
    );
    method_i8 = self.builder.load(method_slot, name=f"fn.{method_name}.raw");
    # Find function type to cast to (walk hierarchy)
    func = None;
    check_name = obj_type_name;
    while check_name is not None {
        full_name = f"{check_name}.{method_name}";
        if full_name in self.method_funcs {
            func = self.method_funcs[full_name];
            break;
        }
        check_name = self.class_hierarchy.get(check_name);
    }
    if func is None {
        return None;
    }
    # Bitcast to expected function type and call
    fn_type = func.function_type;
    typed_fn = self.builder.bitcast(
        method_i8, fn_type.as_pointer(), name=f"fn.{method_name}"
    );
    # Coerce args to expected types
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(fn_type.args) {
            coerced.append(self._coerce_type(arg, fn_type.args[i]));
        } else {
            coerced.append(arg);
        }
    }
    return self.builder.call(typed_fn, coerced, name=f"vcall.{method_name}");
}

# ─── Phase 6: Type Inference Helpers ──────────────────────────
"""Infer the struct type name from an LLVM value's type."""
impl NaIRGenPass._infer_type_name(val: ir.Value) -> (str | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (sname, stype) in self.struct_types.items() {
        if val.type == stype.as_pointer() {
            return sname;
        }
    }
    return None;
}

"""Infer the list element type name from an LLVM value's type."""
impl NaIRGenPass._infer_list_elem_type(val: ir.Value) -> (str | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (ename, ltype) in self.list_types.items() {
        if val.type == ltype.as_pointer() {
            return ename;
        }
    }
    return None;
}

"""Peel one layer from a list type annotation: list[T] → (T_node, T_llvm_type, T_elem_type_name).
For list[list[int]], returns (ast_node_for_list[int], List.i64*, 'ptr').
For list[Piece|None], returns (ast_node_for_Piece|None, Piece*, 'ptr').
For list[int], returns (ast_node_for_int, i64, 'i64').
Returns (None, None, None) if not a list type."""
impl NaIRGenPass._peel_list_type(type_node: (object | None)) -> tuple {
    if type_node is None {
        return (None, None, None);
    }
    # Handle union: T | None → peel T
    if isinstance(type_node, uni.BinaryExpr) {
        op_val = getattr(type_node.op, 'value', '');
        if op_val == "|" {
            return self._peel_list_type(type_node.left);
        }
    }
    # Handle list[T] → return (T_node, resolve(T))
    if isinstance(type_node, uni.AtomTrailer) and not type_node.is_attr {
        target_name = self._get_name(type_node.target);
        if target_name == "list" {
            if type_node?.right and type_node.right?.slices {
                slices = type_node.right.slices or [];
                if slices {
                    elem_node = slices[0];
                    if elem_node?.start and elem_node.start is not None {
                        inner = elem_node.start;
                    } else {
                        inner = elem_node;
                    }
                    inner_type = self._resolve_jac_type(inner);
                    inner_elem_name = "i64";
                    if isinstance(inner_type, ir.DoubleType) {
                        inner_elem_name = "f64";
                    } elif isinstance(inner_type, ir.PointerType) {
                        inner_elem_name = "ptr";
                    }
                    return (inner, inner_type, inner_elem_name);
                }
            }
        }
    }
    return (None, None, None);
}

"""Get the list element type name from a Jac type annotation AST node.
Returns the elem_type_name string ('i64', 'f64', 'ptr') or None."""
impl NaIRGenPass._get_list_elem_from_type_node(
    type_node: (object | None)
) -> (str | None) {
    (inner, inner_type, elem_name) = self._peel_list_type(type_node);
    return elem_name;
}

"""Resolve the LLVM type of elements in a ptr list for a for-loop variable.
Uses Jac type annotations (var_type_node or field_type_node) to determine
what i8* elements should be bitcast to."""
impl NaIRGenPass._resolve_for_loop_elem_type(
    coll_name: (str | None), coll_node: (object | None)
) -> (ir.Type | None) {
    # Check variable type annotation first
    type_node: (object | None) = None;
    if coll_name is not None and coll_name in self.var_type_node {
        type_node = self.var_type_node[coll_name];
    }
    if type_node is not None {
        (inner, inner_type, inner_elem) = self._peel_list_type(type_node);
        if inner_type is not None {
            return inner_type;
        }
    }
    return None;
}

"""Resolve the LLVM type that ptr list elements should be bitcast to,
given a Jac type AST node for the list variable/field.
For list[list[int]], returns List.i64* (the type of each element).
For list[Piece|None], returns Piece* (the type of each element)."""
impl NaIRGenPass._resolve_ptr_elem_cast_type(
    type_node: (object | None)
) -> (ir.Type | None) {
    if type_node is None {
        return None;
    }
    (inner, inner_type, inner_elem) = self._peel_list_type(type_node);
    if inner_type is not None and isinstance(inner_type, ir.PointerType) {
        return inner_type;
    }
    return None;
}

# ─── Phase 7: String Methods and Builtins ─────────────────────
"""String character access: s[i] -> new single-char string."""
impl NaIRGenPass._codegen_string_index(
    target_val: ir.Value, index_val: ir.Value
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    # GEP to the character
    char_ptr = self.builder.gep(target_val, [index_val], name="char.ptr");
    char_val = self.builder.load(char_ptr, name="char.val");
    # Allocate a 2-byte string: [char, null]
    gc_malloc = self._get_or_declare_extern("GC_malloc", i8p, [i64]);
    two = ir.Constant(i64, 2);
    new_str = self.builder.call(gc_malloc, [two], name="char.str");
    self.builder.store(char_val, new_str);
    # Store null terminator at index 1
    one_ptr = self.builder.gep(new_str, [ir.Constant(i64, 1)], name="null.ptr");
    self.builder.store(ir.Constant(i8, 0), one_ptr);
    return new_str;
}

"""String strip: remove leading/trailing whitespace."""
impl NaIRGenPass._codegen_str_strip(str_val: ir.Value) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    i1 = ir.IntType(1);
    func = self.builder.function;
    # Get string length
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    slen = self.builder.call(strlen_fn, [str_val], name="strip.len");
    # Find start index: skip whitespace from beginning
    # We use a simple loop: start = 0; while start < len and (s[start] == ' ' or s[start] == '\t' or s[start] == '\n'): start++
    start_alloca = self.builder.alloca(i64, name="strip.start");
    self.builder.store(ir.Constant(i64, 0), start_alloca);
    # Loop to find start: skip leading whitespace
    start_check_bb = func.append_basic_block(name="strip.start.check");
    start_body_bb = func.append_basic_block(name="strip.start.body");
    start_inc_bb = func.append_basic_block(name="strip.start.inc");
    start_done_bb = func.append_basic_block(name="strip.start.done");
    self.builder.branch(start_check_bb);
    self.builder.position_at_end(start_check_bb);
    start_val = self.builder.load(start_alloca, name="start.cur");
    in_range = self.builder.icmp_signed("<", start_val, slen, name="start.inrange");
    self.builder.cbranch(in_range, start_body_bb, start_done_bb);
    self.builder.position_at_end(start_body_bb);
    ch_ptr = self.builder.gep(str_val, [start_val], name="start.ch.ptr");
    ch = self.builder.load(ch_ptr, name="start.ch");
    is_space = self.builder.icmp_signed("==", ch, ir.Constant(i8, 32), name="is.space");
    is_tab = self.builder.icmp_signed("==", ch, ir.Constant(i8, 9), name="is.tab");
    is_nl = self.builder.icmp_signed("==", ch, ir.Constant(i8, 10), name="is.nl");
    is_cr = self.builder.icmp_signed("==", ch, ir.Constant(i8, 13), name="is.cr");
    is_ws = self.builder.or_(is_space, is_tab, name="ws1");
    is_ws = self.builder.or_(is_ws, is_nl, name="ws2");
    is_ws = self.builder.or_(is_ws, is_cr, name="ws3");
    self.builder.cbranch(is_ws, start_inc_bb, start_done_bb);
    # Only increment when whitespace
    self.builder.position_at_end(start_inc_bb);
    next_start = self.builder.add(start_val, ir.Constant(i64, 1), name="next.start");
    self.builder.store(next_start, start_alloca);
    self.builder.branch(start_check_bb);
    # Find end index: skip trailing whitespace
    self.builder.position_at_end(start_done_bb);
    final_start = self.builder.load(start_alloca, name="final.start");
    end_alloca = self.builder.alloca(i64, name="strip.end");
    self.builder.store(slen, end_alloca);
    end_check_bb = func.append_basic_block(name="strip.end.check");
    end_body_bb = func.append_basic_block(name="strip.end.body");
    end_dec_bb = func.append_basic_block(name="strip.end.dec");
    end_done_bb = func.append_basic_block(name="strip.end.done");
    self.builder.branch(end_check_bb);
    self.builder.position_at_end(end_check_bb);
    end_val = self.builder.load(end_alloca, name="end.cur");
    end_gt_start = self.builder.icmp_signed(
        ">", end_val, final_start, name="end.gt.start"
    );
    self.builder.cbranch(end_gt_start, end_body_bb, end_done_bb);
    self.builder.position_at_end(end_body_bb);
    prev_end = self.builder.sub(end_val, ir.Constant(i64, 1), name="prev.end");
    ech_ptr = self.builder.gep(str_val, [prev_end], name="end.ch.ptr");
    ech = self.builder.load(ech_ptr, name="end.ch");
    e_space = self.builder.icmp_signed("==", ech, ir.Constant(i8, 32), name="e.space");
    e_tab = self.builder.icmp_signed("==", ech, ir.Constant(i8, 9), name="e.tab");
    e_nl = self.builder.icmp_signed("==", ech, ir.Constant(i8, 10), name="e.nl");
    e_cr = self.builder.icmp_signed("==", ech, ir.Constant(i8, 13), name="e.cr");
    e_ws = self.builder.or_(e_space, e_tab, name="ews1");
    e_ws = self.builder.or_(e_ws, e_nl, name="ews2");
    e_ws = self.builder.or_(e_ws, e_cr, name="ews3");
    self.builder.cbranch(e_ws, end_dec_bb, end_done_bb);
    # Only decrement when whitespace
    self.builder.position_at_end(end_dec_bb);
    self.builder.store(prev_end, end_alloca);
    self.builder.branch(end_check_bb);
    self.builder.position_at_end(end_done_bb);
    final_end = self.builder.load(end_alloca, name="final.end");
    # Allocate result: end - start + 1 (for null terminator)
    result_len = self.builder.sub(final_end, final_start, name="result.len");
    alloc_size = self.builder.add(result_len, ir.Constant(i64, 1), name="alloc.size");
    gc_malloc = self._get_or_declare_extern("GC_malloc", i8p, [i64]);
    result_ptr = self.builder.call(gc_malloc, [alloc_size], name="strip.result");
    # memcpy from str_val + start to result
    src_ptr = self.builder.gep(str_val, [final_start], name="src.ptr");
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    self.builder.call(memcpy, [result_ptr, src_ptr, result_len]);
    # Null-terminate
    null_ptr = self.builder.gep(result_ptr, [result_len], name="null.ptr");
    self.builder.store(ir.Constant(i8, 0), null_ptr);
    return result_ptr;
}

"""String split by separator, returns list[str]."""
impl NaIRGenPass._codegen_str_split(
    str_val: ir.Value, sep_val: ir.Value
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    func = self.builder.function;
    # Ensure list[str] helpers exist (str = i8* = "ptr" element type)
    self._emit_list_helpers("ptr", i8p);
    helpers = self.list_helpers.get("ptr");
    if helpers is None {
        return None;
    }
    # Create a new list
    new_list = self.builder.call(helpers["new"], [], name="split.list");
    # Get lengths
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    str_len = self.builder.call(strlen_fn, [str_val], name="str.len");
    sep_len = self.builder.call(strlen_fn, [sep_val], name="sep.len");
    gc_malloc = self._get_or_declare_extern("GC_malloc", i8p, [i64]);
    memcpy = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    strncmp_fn = self._get_or_declare_extern(
        "strncmp", ir.IntType(32), [i8p, i8p, i64]
    );
    # Loop: scan through string, find separator matches
    # i = current position, token_start = start of current token
    i_alloca = self.builder.alloca(i64, name="split.i");
    token_start_alloca = self.builder.alloca(i64, name="split.token.start");
    self.builder.store(ir.Constant(i64, 0), i_alloca);
    self.builder.store(ir.Constant(i64, 0), token_start_alloca);
    loop_check_bb = func.append_basic_block(name="split.check");
    loop_body_bb = func.append_basic_block(name="split.body");
    match_bb = func.append_basic_block(name="split.match");
    no_match_bb = func.append_basic_block(name="split.nomatch");
    loop_done_bb = func.append_basic_block(name="split.done");
    self.builder.branch(loop_check_bb);
    # Check: i <= str_len - sep_len (can still find separator)
    self.builder.position_at_end(loop_check_bb);
    cur_i = self.builder.load(i_alloca, name="cur.i");
    # Check if i + sep_len <= str_len
    i_plus_sep = self.builder.add(cur_i, sep_len, name="i.plus.sep");
    can_match = self.builder.icmp_signed("<=", i_plus_sep, str_len, name="can.match");
    self.builder.cbranch(can_match, loop_body_bb, loop_done_bb);
    # Body: compare substring
    self.builder.position_at_end(loop_body_bb);
    substr_ptr = self.builder.gep(str_val, [cur_i], name="substr.ptr");
    cmp_result = self.builder.call(
        strncmp_fn, [substr_ptr, sep_val, sep_len], name="cmp"
    );
    is_match = self.builder.icmp_signed(
        "==", cmp_result, ir.Constant(ir.IntType(32), 0), name="is.match"
    );
    self.builder.cbranch(is_match, match_bb, no_match_bb);
    # Match: extract token from token_start to i, append to list
    self.builder.position_at_end(match_bb);
    ts = self.builder.load(token_start_alloca, name="token.start");
    token_len = self.builder.sub(cur_i, ts, name="token.len");
    alloc_len = self.builder.add(token_len, ir.Constant(i64, 1), name="token.alloc");
    token_ptr = self.builder.call(gc_malloc, [alloc_len], name="token.ptr");
    src = self.builder.gep(str_val, [ts], name="token.src");
    self.builder.call(memcpy, [token_ptr, src, token_len]);
    null_pos = self.builder.gep(token_ptr, [token_len], name="token.null");
    self.builder.store(ir.Constant(i8, 0), null_pos);
    # Append token to list
    self.builder.call(helpers["append"], [new_list, token_ptr]);
    # Advance i past separator, update token_start
    new_i = self.builder.add(cur_i, sep_len, name="new.i");
    self.builder.store(new_i, i_alloca);
    self.builder.store(new_i, token_start_alloca);
    self.builder.branch(loop_check_bb);
    # No match: advance i by 1
    self.builder.position_at_end(no_match_bb);
    next_i = self.builder.add(cur_i, ir.Constant(i64, 1), name="next.i");
    self.builder.store(next_i, i_alloca);
    self.builder.branch(loop_check_bb);
    # Done: append the last token (from token_start to end)
    self.builder.position_at_end(loop_done_bb);
    final_ts = self.builder.load(token_start_alloca, name="final.ts");
    last_len = self.builder.sub(str_len, final_ts, name="last.len");
    last_alloc = self.builder.add(last_len, ir.Constant(i64, 1), name="last.alloc");
    last_ptr = self.builder.call(gc_malloc, [last_alloc], name="last.ptr");
    last_src = self.builder.gep(str_val, [final_ts], name="last.src");
    self.builder.call(memcpy, [last_ptr, last_src, last_len]);
    last_null = self.builder.gep(last_ptr, [last_len], name="last.null");
    self.builder.store(ir.Constant(i8, 0), last_null);
    self.builder.call(helpers["append"], [new_list, last_ptr]);
    return new_list;
}

# ─── Phase 8: Entry Block ────────────────────────────────────
"""Generate jac_entry() function for with entry { ... } blocks."""
impl NaIRGenPass._codegen_entry(<>node: uni.ModuleCode) -> None {
    i64 = ir.IntType(64);
    # Create jac_entry function: void jac_entry()
    fnty = ir.FunctionType(ir.VoidType(), []);
    func = ir.Function(self.llvm_module, fnty, name="jac_entry");
    self.func_symtab["jac_entry"] = func;
    # Create entry block
    block = func.append_basic_block(name="entry");
    self.builder = ir.IRBuilder(block);
    self.local_vars = {};
    # Generate body statements
    if (<>node).body {
        self._codegen_body((<>node).body);
    }
    # Ensure function has a terminator
    if not self.builder.block.is_terminated {
        self.builder.ret_void();
    }
    self.has_native_code = True;
    self.builder = None;
}
