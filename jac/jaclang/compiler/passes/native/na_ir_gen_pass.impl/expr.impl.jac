"""Expression codegen: binary, unary, comparisons, bool expressions."""
import os;
"""Generate IR for an expression, returning the resulting value.

Sets val.jac_loc = "file:line" on every non-None result so that downstream
helpers (_coerce_type, _box_value_tuple, etc.) can attribute RC allocations
to the originating source line without needing a loc parameter.
"""
impl NaIRGenPass._codegen_expr(nd: (uni.UniNode | None)) -> (ir.Value | None) {
    if nd is None {
        return None;
    }
    _jac_loc: str = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    if isinstance(nd, uni.Int) {
        # Handle hex, octal, binary literals based on name attribute
        tok_name = nd?.name;
        if tok_name == Tok.HEX {
            return ir.Constant(ir.IntType(64), int(nd.value, 16));
        } elif tok_name == Tok.OCT {
            return ir.Constant(ir.IntType(64), int(nd.value, 8));
        } elif tok_name == Tok.BIN {
            return ir.Constant(ir.IntType(64), int(nd.value, 2));
        } else {
            return ir.Constant(ir.IntType(64), int(nd.value, 0));
        }
    }
    if isinstance(nd, uni.Float) {
        return ir.Constant(ir.DoubleType(), float(nd.value));
    }
    if isinstance(nd, uni.Bool) {
        val = 1 if nd.value.lower() in ("true", "1") else 0;
        return ir.Constant(ir.IntType(1), val);
    }
    if isinstance(nd, uni.Null) {
        return ir.Constant(ir.IntType(8).as_pointer(), None);
    }
    # Unwrap CfgExpr (CFG-participating wrapper) to its inner expression.
    # CfgExpr nodes are introduced by cfg_build_pass to wrap BoolExpr operands
    # and IfElseExpr branches; native codegen treats them transparently.
    if isinstance(nd, uni.CfgExpr) {
        return self._codegen_expr(nd.expr);
    }
    _result: (ir.Value | None) = None;
    if isinstance(nd, uni.Name) {
        _result = self._codegen_name(nd);
    } elif isinstance(nd, uni.BinaryExpr) {
        _result = self._codegen_binary(nd);
    } elif isinstance(nd, uni.CompareExpr) {
        _result = self._codegen_compare(nd);
    } elif isinstance(nd, uni.UnaryExpr) {
        _result = self._codegen_unary(nd);
    } elif isinstance(nd, uni.FuncCall) {
        # Ownership of the pointer result is applied at the dispatch tail
        # below, from the central invariant.
        _result = self._codegen_call(nd);
    } elif isinstance(nd, uni.AtomTrailer) {
        _result = self._codegen_atom_trailer(nd);
    } elif isinstance(nd, uni.BoolExpr) {
        _result = self._codegen_bool_expr(nd);
    } elif isinstance(nd, uni.IfElseExpr) {
        _result = self._codegen_if_else_expr(nd);
    } elif isinstance(nd, uni.MultiString) {
        _result = self._codegen_multistring(nd);
    } elif isinstance(nd, uni.String) {
        _result = self._codegen_string(nd);
    } elif isinstance(nd, uni.FString) {
        _result = self._codegen_fstring(nd);
    } elif isinstance(nd, uni.ListVal) {
        _result = self._codegen_list_val(nd);
        # Check dict and set comprehensions BEFORE list comprehension
        # (DictCompr and SetCompr do NOT inherit from ListCompr)
    } elif isinstance(nd, uni.DictCompr) {
        _result = self._codegen_dict_compr(nd);
    } elif isinstance(nd, uni.SetCompr) {
        _result = self._codegen_set_compr(nd);
    } elif isinstance(nd, uni.ListCompr) {
        _result = self._codegen_list_compr(nd);
    } elif isinstance(nd, uni.TupleVal) {
        _result = self._codegen_tuple_val(nd);
    } elif isinstance(nd, uni.DictVal) {
        _result = self._codegen_dict_val(nd);
    } elif isinstance(nd, uni.SetVal) {
        _result = self._codegen_set_val(nd);
        # Handle parenthesized expressions: (expr) → AtomUnit
    } elif isinstance(nd, uni.AtomUnit) {
        _result = self._codegen_expr(nd.value);
        # Cast (`value as T`) is type-erased: it evaluates to the inner
        # value unchanged and only refines the static type. The narrowed
        # type lets `.attr` on a nullable archetype compile; a None value
        # then traps at the native deref just like any AttributeError.
    } elif isinstance(nd, uni.CastExpr) {
        _result = self._codegen_expr(nd.value);
        # Lambda expressions: emit an anonymous LLVM function and return
        # a function pointer to it.
    } elif isinstance(nd, uni.LambdaExpr) {
        _result = self._codegen_lambda(nd);
        # `await e`: native has no event loop, so an awaited coroutine has
        # already run in this synchronous model — await evaluates to the
        # value of its target. Correct for sequential async code; it does
        # not provide concurrency.
    } elif isinstance(nd, uni.AwaitExpr) {
        _result = self._codegen_expr(nd.target);
        # `flow e` / `wait e`: native has no threading runtime, so
        # concurrency runs sequentially. `flow e` evaluates `e` eagerly and
        # its value acts as the handle; `wait h` reads that already-computed
        # value. Both therefore reduce to evaluating the target. Correct for
        # independent tasks; no actual parallelism.
    } elif isinstance(nd, uni.ConcurrentExpr) {
        _result = self._codegen_expr(nd.target);
    } elif isinstance(nd, uni.EdgeRefTrailer) {
        # `[-->]` / `[->:Edge:->]`: query the native edge adjacency from `here`,
        # yielding a `list` of neighbor handles (the kernel's `visit` target
        # shape). issue #6146.
        _result = self._codegen_edge_ref_trailer(nd);
    } elif (
        isinstance(nd, uni.Slice)
        or isinstance(nd, uni.IndexSlice)
        or isinstance(nd, uni.KVPair)
        or isinstance(nd, uni.KWPair)
        or isinstance(nd, uni.InnerCompr)
        or isinstance(nd, uni.FormattedValue)
    ) {
        # Container/wrapper nodes — callers walk into them and call
        # _codegen_expr on the inner pieces (e.g. slice.start). When
        # one of these flows in directly, the convention is to return
        # None so the caller can fall back. NOT an error.
    } else {
        # Catch-all: any expression node we didn't recognize is a real
        # gap, not a no-op. Emit a structured error so silent-failure
        # bugs (yield, await, flow/wait, edge refs, JSX, ...) become
        # loud at compile time instead of returning 0 at runtime.
        self.emit(E5090, node_override=nd, kind="expression", name=type(nd).__name__);
    }
    # Stamp source location on every produced value so downstream helpers
    # (_coerce_type clib.box path, _box_value_tuple) can attribute RC
    # allocations without needing a loc parameter threaded through.
    if _result is not None {
        _result.jac_loc = _jac_loc;
        # The single seam where AST-result ownership is applied: the central
        # invariant (compiler/ownership.jac) says which expression results
        # arrive carrying a +1 reference; emission marks exactly those.
        # Emitter-created temporaries (boxing, coercions, concat buffers)
        # are marked by their own mechanics at creation.
        if isinstance(_result.type, ir.PointerType) {
            import from jaclang.compiler.ownership { Ownership, result_ownership }
            if result_ownership(nd) == Ownership.OWNED {
                self._mark_owned(_result);
            }
        }
    }
    return _result;
}

"""Lower a sub-expression that a statement *requires*, making failure loud.

Statement consumers (return value, assignment RHS, loop/if conditions, store
targets) must not silently drop a sub-expression that lowers to no value --
that is the #6470 silent-no-code class, where valid Jac compiles clean and
then misbehaves at runtime (empty body, dropped statement, default return).

Evaluate `nd`; if it yields no value AND no deeper diagnostic already fired
for it (e.g. `_codegen_atom_trailer` or `_codegen_call` reported the real
root), raise E5090 so the gap surfaces at compile time. The errors_had-delta
guard keeps a single, deepest diagnostic instead of one per enclosing layer.
"""
impl NaIRGenPass._codegen_required(nd: (uni.UniNode | None)) -> (ir.Value | None) {
    if nd is None {
        return None;
    }
    _errs_before = len(self.errors_had);
    val = self._codegen_expr(nd);
    if val is None and len(self.errors_had) == _errs_before {
        self.emit(E5090, node_override=nd, kind="expression", name=type(nd).__name__);
    }
    return val;
}

"""Generate IR for a lambda expression.

Emits an anonymous LLVM function from the lambda body and returns a
pointer to it. If the lambda references variables from the enclosing
scope (free variables), those are appended as extra hidden parameters
to the anonymous function, and the call site injects them automatically
via the lambda_captures side table.
"""
impl NaIRGenPass._codegen_lambda(nd: uni.LambdaExpr) -> (ir.Value | None) {
    # --- Resolve parameter types and return type from the signature ---
    sig = nd.signature;
    param_types: list[ir.Type] = [];
    param_names: list[str] = [];
    if sig is not None and sig.params {
        for p in sig.params {
            p_name = p.name.value if p?.name and p.name else f"arg{len(param_names)}";
            # ParamVar.type is checker-stamped; lower it directly.
            p_type = self._resolve_jac_type(p)
                if p?.type_tag and p.type_tag is not None
                else ir.IntType(64);
            param_types.append(p_type);
            param_names.append(p_name);
        }
    }
    ret_type = ir.IntType(64);  # default
    if sig is not None and sig.return_type is not None {
        ret_type = self._resolve_jac_type(sig.return_type);
    }
    # --- Detect captured (free) variables from the enclosing scope ---
    # Free variables come from the symbol-table-derived `captures` fact on
    # the lambda; the `local_vars` filter below keeps only names with live
    # allocas in the function currently being generated (e.g. it excludes
    # sibling nested functions, which live in func_symtab instead).
    captures: list[tuple] = [];  # list of (name, ir.Value, ir.Type)
    free_var_names: list[str] = [];
    for cap_sym in nd.captures {
        if cap_sym.sym_name not in free_var_names {
            free_var_names.append(cap_sym.sym_name);
        }
    }
    for fv_name in free_var_names {
        if fv_name in self.local_vars {
            alloca = self.local_vars[fv_name];
            val = self.builder.load(alloca, name=f"cap.{fv_name}");
            captures.append((fv_name, val, val.type));
        }
    }
    # Build the full parameter list: explicit params + captured vars
    all_param_types = list(param_types);
    all_param_names = list(param_names);
    for (cap_name, _cap_val, cap_type) in captures {
        all_param_types.append(cap_type);
        all_param_names.append(cap_name);
    }
    # --- Create the anonymous function ---
    self._str_count += 1;
    anon_name = f"__jac_lambda_{self._str_count}";
    fn_type = ir.FunctionType(ret_type, all_param_types);
    anon_fn = ir.Function(self.llvm_module, fn_type, name=anon_name);
    anon_fn.linkage = "private";
    for (i, arg) in enumerate(anon_fn.args) {
        if i < len(all_param_names) {
            arg.name = all_param_names[i];
        }
    }
    # --- Emit the lambda body ---
    saved_builder = self._builder;
    saved_locals = self.local_vars;
    saved_func_symtab = dict(self.func_symtab);
    entry_bb = anon_fn.append_basic_block("entry");
    self._builder = ir.IRBuilder(entry_bb);
    self.local_vars = {};
    # Allocate ALL parameters (explicit + captured) as local variables
    for (i, arg) in enumerate(anon_fn.args) {
        alloca = self._entry_alloca(arg.type, all_param_names[i]);
        self.builder.store(arg, alloca);
        self.local_vars[all_param_names[i]] = alloca;
    }
    # Codegen the body
    body = nd.body;
    if isinstance(body, list) {
        self._codegen_body(body);
    } else {
        val = self._codegen_expr(body);
        if val is not None {
            self.builder.ret(self._coerce_type(val, ret_type));
        } else {
            self.builder.ret(ir.Constant(ret_type, 0));
        }
    }
    # Ensure every basic block has a terminator
    for bb in anon_fn.basic_blocks {
        if not bb.is_terminated {
            term_builder = ir.IRBuilder(bb);
            if ret_type == ir.VoidType() {
                term_builder.ret_void();
            } else {
                term_builder.ret(ir.Constant(ret_type, 0));
            }
        }
    }
    # --- Restore parent context ---
    self._builder = saved_builder;
    self.local_vars = saved_locals;
    self.func_symtab = saved_func_symtab;
    # --- Record pending captures for the assignment to associate with a var name ---
    if captures {
        capture_info: list[tuple] = [];
        for (cap_name, _cap_val, _cap_type) in captures {
            # Store the alloca (not the loaded value) so it can be loaded at call time
            capture_info.append((cap_name, self.local_vars[cap_name]));
        }
        self._pending_lambda_captures = capture_info;
    } else {
        self._pending_lambda_captures = None;
    }
    return anon_fn;
}

"""Load a variable or return a function reference."""
impl NaIRGenPass._codegen_name(nd: uni.Name) -> (ir.Value | None) {
    var_name = nd.value;
    if var_name in self.local_vars {
        alloca = self.local_vars[var_name];
        return self.builder.load(alloca, name=var_name);
    }
    if var_name in self.func_symtab {
        return self.func_symtab[var_name];
    }
    # Check global variables
    if var_name in self.global_vars {
        global_var = self.global_vars[var_name];
        return self.builder.load(global_var, name=f"glob.{var_name}");
    }
    return None;
}

"""Generate pipe-forward `|>` expression.

`lhs |> f` is sugar for `f(lhs)`; a tuple lhs spreads into positional
arguments, so `(a, b) |> f` is `f(a, b)`. We desugar by synthesizing a
FuncCall (target = rhs, params = lhs / lhs.values) and delegating to the
normal call path, which reuses all builtin/method/user dispatch. This
mirrors how the Python pathway lowers pipe-forward.
"""
impl NaIRGenPass._codegen_pipe_fwd(nd: uni.BinaryExpr) -> (ir.Value | None) {
    if isinstance(nd.left, uni.TupleVal) and nd.left.values {
        call_params = list(nd.left.values);
    } else {
        call_params = [nd.left];
    }
    call = uni.FuncCall(
        target=nd.right,
        params=call_params,
        genai_call=None,
        kid=[nd.right, *call_params]
    );
    call.parent = nd.parent;
    return self._codegen_expr(call);
}

"""Generate walrus `:=` expression.

Binds `nd.left` (always a simple Name — the parser only accepts a Name
on the left of `:=`) to the value of `nd.right`, then evaluates to that
value so the enclosing expression can consume it, e.g. `if (n := f()) > 5`.

The binding is stored into the name's local alloca, created in the entry
block on first use. Pointer-typed values follow the same retain/release
discipline as a normal assignment: retain a borrowed value before storing,
release any prior occupant of an existing slot.
"""
impl NaIRGenPass._codegen_walrus(nd: uni.BinaryExpr) -> (ir.Value | None) {
    var_name = self._get_name(nd.left);
    if var_name is None {
        self.emit(E5090, node_override=nd, kind="binary operator", name="WALRUS_EQ");
        return None;
    }
    value = self._codegen_expr(nd.right);
    if value is None {
        return None;
    }
    _loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    if var_name in self.local_vars {
        # Rebind an existing local: coerce to the slot type, then release
        # the prior occupant (pointer slots only) after retaining the new one.
        alloca = self.local_vars[var_name];
        slot_type = alloca.type.pointee;
        value = self._coerce_type(value, slot_type);
        if isinstance(slot_type, ir.PointerType) {
            if not self._is_owned(value) {
                self._emit_rc_retain(value, op="walrus", loc=_loc);
            }
            old_val = self.builder.load(alloca, name=f"{var_name}.old");
            self._emit_rc_release_typed(old_val, op="overwrite", loc=_loc);
        }
        self.builder.store(value, alloca);
    } else {
        # First binding: allocate a slot in the entry block. The store
        # below always runs before any scope cleanup, so the slot is never
        # read uninitialized.
        var_type = value.type;
        alloca = self._entry_alloca(var_type, var_name);
        if isinstance(var_type, ir.PointerType) and not self._is_owned(value) {
            self._emit_rc_retain(value, op="walrus", loc=_loc);
        }
        self.builder.store(value, alloca);
        self.local_vars[var_name] = alloca;
    }
    # Evaluate to the bound value. This is a borrowed read of the slot the
    # local now owns — matching _codegen_name's borrow semantics.
    return self.builder.load(alloca, name=var_name);
}

"""Generate binary expression."""
impl NaIRGenPass._codegen_binary(nd: uni.BinaryExpr) -> (ir.Value | None) {
    # Edge connect (`a ++> b`, `a +>: Edge() :+> b`): the operator node is a
    # ConnectOp, not a Token. Lower to the native edge adjacency (issue #6146).
    if isinstance(nd.op, uni.ConnectOp) {
        return self._codegen_connect(nd);
    }
    op = nd.op.name if isinstance(nd.op, uni.Token) else str(nd.op);
    # Inspect the op before recursing into operands. Some operators
    # (walrus `:=`, pipe-forward `|>`) have non-standard evaluation
    # semantics: their left side is a binding target, not an rvalue.
    # Trying to evaluate `nd.left` first would return None, and the
    # function would silently exit returning None — masking the real
    # gap. Catch known-unsupported ops here so the error is loud.
    if op == Tok.WALRUS_EQ {
        return self._codegen_walrus(nd);
    }
    if op == Tok.PIPE_FWD {
        return self._codegen_pipe_fwd(nd);
    }
    if op == Tok.KW_SPAWN {
        return self._codegen_spawn(nd);
    }
    left = self._codegen_expr(nd.left);
    right = self._codegen_expr(nd.right);
    if left is None or right is None {
        return None;
    }
    result = self._emit_binary_op(op, left, right);
    # RC: for string concatenation (i8* + i8*), _emit_binary_op creates a new
    # owned buffer and returns it.  The input operands are borrowed — if the
    # caller owns them (e.g. freshly-allocated fstring or prior concat result),
    # release them here.  Mirrors the same release pattern in _codegen_multistring.
    if result is not None {
        i8p = ir.IntType(8).as_pointer();
        if op == Tok.PLUS and left.type == i8p and right.type == i8p {
            if self._is_owned(left) {
                self._emit_rc_release_typed(
                    left, op="binop_lhs", loc=getattr(left, 'jac_loc', '')
                );
            }
            if self._is_owned(right) {
                self._emit_rc_release_typed(
                    right, op="binop_rhs", loc=getattr(right, 'jac_loc', '')
                );
            }
        }
    }
    return result;
}

"""Lower the `spawn` operator: run a walker's entry abilities on a location.

Milestone scope: a direct `walker spawn node` (either operand order) with
compile-time dispatch and no traversal queue / `visit` yet. Identifies which
operand is the walker (by archetype kind) and emits direct calls to the
walker's entry abilities whose trigger matches the spawned location's type (or
are untyped). Returns the walker, matching `spawn`'s value.
"""
impl NaIRGenPass._codegen_spawn(nd: uni.BinaryExpr) -> (ir.Value | None) {
    left_val = self._codegen_expr(nd.left);
    right_val = self._codegen_expr(nd.right);
    if left_val is None or right_val is None {
        return None;
    }
    # Resolve each operand's archetype name from the AST (constructor call or
    # typed variable).
    left_name = self._spawn_operand_name(nd.left);
    right_name = self._spawn_operand_name(nd.right);
    left_is_walker = left_name is not None and self._is_walker_arch(left_name);
    right_is_walker = right_name is not None and self._is_walker_arch(right_name);
    (walker_name, walker_val, loc_val) = (None, None, None);
    if left_is_walker {
        (walker_name, walker_val, loc_val) = (left_name, left_val, right_val);
    } elif right_is_walker {
        (walker_name, walker_val, loc_val) = (right_name, right_val, left_val);
    } else {
        self.emit(E5090, node_override=nd, kind="binary operator", name="KW_SPAWN");
        return left_val;
    }
    # `walker spawn loc` lowers to the portable osp_kernel (issue #6146):
    # dispatch by the location's RUNTIME type tag, so computed locations,
    # subtype / tuple triggers, exit abilities, and nested spawns all work. The
    # kernel + descriptors are always registered for an OSP program (see
    # _register_archetypes Pass 4.7), so this is the single spawn path.
    if (walker_name in self.osp_tags)
    and (self._osp_rt_global is not None)
    and ("osp_spawn" in self.func_symtab) {
        return self._codegen_kernel_spawn(walker_name, walker_val, loc_val);
    }
    # Reaching here means the OSP kernel was not registered for a walker that
    # nonetheless has a type-tag -- an internal inconsistency rather than a user
    # error; surface it instead of silently no-op'ing.
    self.emit(E5090, node_override=nd, kind="binary operator", name="KW_SPAWN");
    return walker_val;
}

"""Lower `walker spawn loc` to `osp_spawn(rt, box(walker), wdesc, [loc])` after
a lazy `__osp_ensure_init()`. Dispatch happens at runtime in the kernel keyed on
the location's `__type_tag`, so the location may be any expression."""
impl NaIRGenPass._codegen_kernel_spawn(
    walker_name: str, walker_val: ir.Value, loc_val: ir.Value
) -> (ir.Value | None) {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    # Lazily build descriptors / init _walk_stack (idempotent).
    if self._osp_ensure_fn is not None {
        self.builder.call(self._osp_ensure_fn, []);
    }
    osp_spawn_fn = self.func_symtab.get("osp_spawn");
    if osp_spawn_fn is None {
        return walker_val;
    }
    _argtys = osp_spawn_fn.function_type.args;
    # starts: List.i64 carrying the start location as a ptrtoint'd handle (the
    # kernel boxes it through `any`; tag_of recovers the type at the field).
    _h = self.list_helpers.get("i64");
    _starts = self._rc_call_with_ctx(
        _h["new"], [], op="new", loc="", name="spawn.starts"
    );
    self._rc_call_with_ctx(
        _h["append"], [_starts, self._coerce_type(loc_val, i64)], op="append", loc=""
    );
    # wdesc = (WalkerDesc*) __ospDESC[walker_tag]
    _wtag = self.osp_tags.get(walker_name, 0);
    _descp = self.builder.load(
        self.builder.gep(
            self._osp_desc_global,
            [ir.Constant(i32, 0), ir.Constant(i32, _wtag)],
            name="spawn.descp"
        ),
        name="spawn.desc.i8"
    );
    _rt = self.builder.load(self._osp_rt_global, name="spawn.rt");
    self.builder.call(
        osp_spawn_fn,
        [
            self._coerce_type(_rt, _argtys[0]),
            self._coerce_type(walker_val, _argtys[1]),
            self._coerce_type(_descp, _argtys[2]),
            self._coerce_type(_starts, _argtys[3])
        ]
    );
    return walker_val;
}

"""Resolve a spawn operand to its archetype name (None if not determinable)."""
impl NaIRGenPass._spawn_operand_name(nd: uni.UniNode) -> (str | None) {
    if isinstance(nd, uni.FuncCall) {
        return self._get_name(nd.target);
    }
    if isinstance(nd, uni.Name) {
        return self._struct_name_of(nd);
    }
    return None;
}

"""True if `name` is a walker archetype (kind registered at OSP-tag time)."""
impl NaIRGenPass._is_walker_arch(name: str) -> bool {
    return self.osp_arch_kind.get(name) == "walker";
}

"""Generate comparison expression."""
impl NaIRGenPass._codegen_compare(nd: uni.CompareExpr) -> (ir.Value | None) {
    left = self._codegen_expr(nd.left);
    if left is None or not nd.rights or not nd.ops {
        return None;
    }
    right = self._codegen_expr(nd.rights[0]);
    if right is None {
        return None;
    }
    # Save originals before any type coercions (bitcast/promote) for cleanup.
    _cmp_left_orig = left;
    _cmp_right_orig = right;
    op = nd.ops[0].name if isinstance(nd.ops[0], uni.Token) else str(nd.ops[0]);
    # Handle "in" operator for dicts and sets: left in right
    if op == Tok.KW_IN or op == Tok.KW_NIN {
        is_not_in = op == Tok.KW_NIN;
        # Check if right is a dict
        for (dict_key, helpers) in self.dict_helpers.items() {
            dict_type = self.dict_types.get(dict_key);
            if dict_type is not None and right.type == dict_type.as_pointer() {
                key_type = helpers["key_type"];
                left_coerced = self._coerce_type(left, key_type);
                result = self.builder.call(
                    helpers["contains"], [right, left_coerced], name="dict.contains"
                );
                # Extend i1 result to i64 for consistency
                result = self.builder.zext(result, ir.IntType(64), name="contains.i64");
                if is_not_in {
                    result = self.builder.icmp_signed(
                        "==", result, ir.Constant(ir.IntType(64), 0), name="not.in"
                    );
                    result = self.builder.zext(
                        result, ir.IntType(64), name="notin.i64"
                    );
                }
                # Release `left_coerced` (not `_cmp_left_orig`): a value-tuple
                # key is boxed into a fresh owned heap tuple by _coerce_type, and
                # that box — borrowed by `contains` — is what leaks otherwise.
                self._release_owned_operands(
                    left_coerced, _cmp_right_orig, op="cmp_in_dict"
                );
                return result;
            }
        }
        # Check if right is a set
        for (set_key, helpers) in self.set_helpers.items() {
            set_type = self.set_types.get(set_key);
            if set_type is not None and right.type == set_type.as_pointer() {
                elem_type = helpers["elem_type"];
                left_coerced = self._coerce_type(left, elem_type);
                result = self.builder.call(
                    helpers["contains"], [right, left_coerced], name="set.contains"
                );
                result = self.builder.zext(result, ir.IntType(64), name="contains.i64");
                if is_not_in {
                    result = self.builder.icmp_signed(
                        "==", result, ir.Constant(ir.IntType(64), 0), name="not.in"
                    );
                    result = self.builder.zext(
                        result, ir.IntType(64), name="notin.i64"
                    );
                }
                # Release the boxed/coerced element (see dict path above).
                self._release_owned_operands(
                    left_coerced, _cmp_right_orig, op="cmp_in_set"
                );
                return result;
            }
        }
        # Check if right is a list
        for (list_key, helpers) in self.list_helpers.items() {
            list_type = self.list_types.get(list_key);
            if list_type is not None and right.type == list_type.as_pointer() {
                elem_type = helpers["elem_type"];
                left_coerced = self._coerce_type(left, elem_type);
                list_len = self.builder.call(
                    helpers["len"], [right], name="list.in.len"
                );
                i64 = ir.IntType(64);
                func = self.builder.basic_block.function;
                entry_bb = self.builder.basic_block;
                loop_bb = func.append_basic_block(name="list.in.loop");
                check_bb = func.append_basic_block(name="list.in.check");
                found_bb = func.append_basic_block(name="list.in.found");
                done_bb = func.append_basic_block(name="list.in.done");
                self.builder.branch(loop_bb);
                self.builder.position_at_start(loop_bb);
                idx = self.builder.phi(i64, name="list.in.idx");
                idx.add_incoming(ir.Constant(i64, 0), entry_bb);
                at_end = self.builder.icmp_unsigned(
                    ">=", idx, list_len, name="list.in.atend"
                );
                self.builder.cbranch(at_end, done_bb, check_bb);
                self.builder.position_at_start(check_bb);
                elem = self.builder.call(
                    helpers["get"], [right, idx], name="list.in.elem"
                );
                eq = self.builder.icmp_signed(
                    "==", elem, left_coerced, name="list.in.eq"
                );
                next_idx = self.builder.add(
                    idx, ir.Constant(i64, 1), name="list.in.next"
                );
                idx.add_incoming(next_idx, check_bb);
                self.builder.cbranch(eq, found_bb, loop_bb);
                self.builder.position_at_start(found_bb);
                self.builder.branch(done_bb);
                self.builder.position_at_start(done_bb);
                result = self.builder.phi(i64, name="list.in.result");
                result.add_incoming(ir.Constant(i64, 0), loop_bb);
                result.add_incoming(ir.Constant(i64, 1), found_bb);
                if is_not_in {
                    result = self.builder.icmp_signed(
                        "==", result, ir.Constant(i64, 0), name="not.in"
                    );
                    result = self.builder.zext(result, i64, name="notin.i64");
                }
                # Release the boxed/coerced element (see dict path above).
                self._release_owned_operands(
                    left_coerced, _cmp_right_orig, op="cmp_in_list"
                );
                return result;
            }
        }
        # Check if right is a tuple (value or pointer to LiteralStructType)
        tin_struct: (ir.LiteralStructType | None) = None;
        tin_val: (ir.Value | None) = None;
        if isinstance(right.type, ir.LiteralStructType) {
            tin_struct = right.type;
            tin_val = right;
        } elif isinstance(right.type, ir.PointerType)
        and isinstance(right.type.pointee, ir.LiteralStructType) {
            tin_struct = right.type.pointee;
            tin_val = self.builder.load(right, name="tuple.in.val");
        }
        if tin_struct is not None and tin_val is not None {
            n = len(tin_struct.elements);
            if n > 0 {
                i64 = ir.IntType(64);
                i1_t = ir.IntType(1);
                found = ir.Constant(i1_t, 0);
                for i in range(n) {
                    elem = self.builder.extract_value(tin_val, i, name=f"tuple.in.{i}");
                    left_c = self._coerce_type(left, elem.type);
                    if isinstance(elem.type, ir.IntType) {
                        eq = self.builder.icmp_signed(
                            "==", left_c, elem, name=f"tuple.in.{i}.eq"
                        );
                    } elif isinstance(elem.type, ir.DoubleType) {
                        eq = self.builder.fcmp_ordered(
                            "==", left_c, elem, name=f"tuple.in.{i}.eq"
                        );
                    } else {
                        i8p = ir.IntType(8).as_pointer();
                        strcmp_fn = self._get_or_declare_extern(
                            "strcmp", ir.IntType(32), [i8p, i8p]
                        );
                        cmp = self.builder.call(
                            strcmp_fn, [left_c, elem], name=f"tuple.in.{i}.cmp"
                        );
                        eq = self.builder.icmp_signed(
                            "==",
                            cmp,
                            ir.Constant(ir.IntType(32), 0),
                            name=f"tuple.in.{i}.eq"
                        );
                    }
                    found = self.builder.or_(found, eq, name=f"tuple.in.{i}.found");
                }
                result = self.builder.zext(found, i64, name="tuple.in.result");
                if is_not_in {
                    result = self.builder.icmp_signed(
                        "==", result, ir.Constant(i64, 0), name="tuple.notin"
                    );
                    result = self.builder.zext(result, i64, name="tuple.notin.i64");
                }
                return result;
            }
        }
        # Check if right is a range (JacRange*): val in range(...)
        if right.type == self.range_struct_type.as_pointer() {
            i64 = ir.IntType(64);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);
            val = self._coerce_type(left, i64);
            start = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 0)], name="rin.sp"),
                name="rin.start"
            );
            stop = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 1)], name="rin.ep"),
                name="rin.stop"
            );
            step = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 2)], name="rin.tp"),
                name="rin.step"
            );
            # Check: (val - start) % step == 0 and in bounds
            diff = self.builder.sub(val, start, name="rin.diff");
            rem = self.builder.srem(diff, step, name="rin.rem");
            rem_zero = self.builder.icmp_signed(
                "==", rem, ir.Constant(i64, 0), name="rin.remz"
            );
            # Check step > 0: start <= val < stop
            # Check step < 0: stop < val <= start
            step_pos = self.builder.icmp_signed(
                ">", step, ir.Constant(i64, 0), name="rin.spos"
            );
            ge_start = self.builder.icmp_signed(">=", val, start, name="rin.ges");
            lt_stop = self.builder.icmp_signed("<", val, stop, name="rin.lts");
            pos_ok = self.builder.and_(ge_start, lt_stop, name="rin.pok");
            le_start = self.builder.icmp_signed("<=", val, start, name="rin.les");
            gt_stop = self.builder.icmp_signed(">", val, stop, name="rin.gts");
            neg_ok = self.builder.and_(le_start, gt_stop, name="rin.nok");
            bounds = self.builder.select(step_pos, pos_ok, neg_ok, name="rin.bounds");
            found = self.builder.and_(rem_zero, bounds, name="rin.found");
            result = self.builder.zext(found, i64, name="rin.result");
            if is_not_in {
                result = self.builder.icmp_signed(
                    "==", result, ir.Constant(i64, 0), name="rin.notin"
                );
                result = self.builder.zext(result, i64, name="rin.notin.i64");
            }
            return result;
        }
        # Check if right is a string (i8*): left in right → strstr
        if isinstance(right.type, ir.PointerType)
        and isinstance(left.type, ir.PointerType) {
            i8p = ir.IntType(8).as_pointer();
            i64 = ir.IntType(64);
            strstr_fn = self._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
            found = self.builder.call(strstr_fn, [right, left], name="str.in.ptr");
            null_ptr = ir.Constant(i8p, None);
            is_found = self.builder.icmp_unsigned(
                "!=", found, null_ptr, name="str.in.found"
            );
            result = self.builder.zext(is_found, i64, name="str.in.i64");
            if is_not_in {
                result = self.builder.icmp_signed(
                    "==", result, ir.Constant(i64, 0), name="not.in"
                );
                result = self.builder.zext(result, i64, name="notin.i64");
            }
            return result;
        }
        return None;
    }
    # Handle identity operators: is / is not (pointer comparison)
    if op == Tok.KW_IS {
        # Coerce both to same pointer type for comparison
        if isinstance(left.type, ir.PointerType)
        and isinstance(right.type, ir.PointerType) {
            if left.type != right.type {
                right = self.builder.bitcast(right, left.type);
            }
            _is_result = self.builder.icmp_unsigned("==", left, right, name="is.eq");
            if isinstance(_cmp_left_orig.type, ir.PointerType)
            and self._is_owned(_cmp_left_orig) {
                self._emit_rc_release_simple(
                    _cmp_left_orig,
                    op="cmp_is",
                    loc=getattr(_cmp_left_orig, 'jac_loc', '')
                );
            }
            if isinstance(_cmp_right_orig.type, ir.PointerType)
            and self._is_owned(_cmp_right_orig) {
                self._emit_rc_release_simple(
                    _cmp_right_orig,
                    op="cmp_is",
                    loc=getattr(_cmp_right_orig, 'jac_loc', '')
                );
            }
            return _is_result;
        }
        # i64 is None: compare against -1 sentinel (for optional enum/int)
        if isinstance(left.type, ir.IntType)
        and isinstance(right.type, ir.PointerType) {
            sentinel = ir.Constant(left.type, -1);
            return self.builder.icmp_signed("==", left, sentinel, name="is.none");
        }
        return self._to_bool(left);
    }
    if op == Tok.KW_ISN {
        if isinstance(left.type, ir.PointerType)
        and isinstance(right.type, ir.PointerType) {
            if left.type != right.type {
                right = self.builder.bitcast(right, left.type);
            }
            _isn_result = self.builder.icmp_unsigned("!=", left, right, name="is.ne");
            if isinstance(_cmp_left_orig.type, ir.PointerType)
            and self._is_owned(_cmp_left_orig) {
                self._emit_rc_release_simple(
                    _cmp_left_orig,
                    op="cmp_isn",
                    loc=getattr(_cmp_left_orig, 'jac_loc', '')
                );
            }
            if isinstance(_cmp_right_orig.type, ir.PointerType)
            and self._is_owned(_cmp_right_orig) {
                self._emit_rc_release_simple(
                    _cmp_right_orig,
                    op="cmp_isn",
                    loc=getattr(_cmp_right_orig, 'jac_loc', '')
                );
            }
            return _isn_result;
        }
        # i64 is not None: compare against -1 sentinel (for optional enum/int)
        if isinstance(left.type, ir.IntType)
        and isinstance(right.type, ir.PointerType) {
            sentinel = ir.Constant(left.type, -1);
            return self.builder.icmp_signed("!=", left, sentinel, name="isnot.none");
        }
        return self._to_bool(left);
    }
    is_float = isinstance(left.type, ir.DoubleType)
    or isinstance(right.type, ir.DoubleType);
    if is_float {
        (left, right) = self._promote_to_float(left, right);
    }
    _cmp_result = self._emit_comparison(op, left, right, is_float);
    if isinstance(_cmp_left_orig.type, ir.PointerType)
    and self._is_owned(_cmp_left_orig) {
        self._emit_rc_release_simple(
            _cmp_left_orig, op="cmp_op", loc=getattr(_cmp_left_orig, 'jac_loc', '')
        );
    }
    if isinstance(_cmp_right_orig.type, ir.PointerType)
    and self._is_owned(_cmp_right_orig) {
        self._emit_rc_release_simple(
            _cmp_right_orig, op="cmp_op", loc=getattr(_cmp_right_orig, 'jac_loc', '')
        );
    }
    return _cmp_result;
}

"""Generate unary expression."""
impl NaIRGenPass._codegen_unary(nd: uni.UnaryExpr) -> (ir.Value | None) {
    operand = self._codegen_expr(nd.operand);
    if operand is None {
        return None;
    }
    op = nd.op.name if isinstance(nd.op, uni.Token) else str(nd.op);
    if op == Tok.MINUS {
        if isinstance(operand.type, ir.DoubleType) {
            return self.builder.fneg(operand, name="fneg");
        } elif isinstance(operand.type, ir.IntType) {
            return self.builder.neg(operand, name="neg");
        } elif operand.type == self.complex_struct_type.as_pointer() {
            # Complex negation: (-real, -imag)
            f64 = ir.DoubleType();
            i64 = ir.IntType(64);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);
            z1 = ir.Constant(i32, 1);
            r = self.builder.load(
                self.builder.gep(operand, [z0, z0], name="cneg.rp"), name="cneg.r"
            );
            im = self.builder.load(
                self.builder.gep(operand, [z0, z1], name="cneg.ip"), name="cneg.i"
            );
            nr = self.builder.fneg(r, name="cneg.nr");
            ni = self.builder.fneg(im, name="cneg.ni");
            raw = self.builder.call(
                self.rc_alloc_fn, [ir.Constant(i64, 16)], name="cneg.raw"
            );
            ptr = self.builder.bitcast(
                raw, self.complex_struct_type.as_pointer(), name="cneg.ptr"
            );
            self.builder.store(nr, self.builder.gep(ptr, [z0, z0], name="cneg.srp"));
            self.builder.store(ni, self.builder.gep(ptr, [z0, z1], name="cneg.sip"));
            return ptr;
        }
    } elif op == Tok.NOT {
        if isinstance(operand.type, ir.IntType) and operand.type.width == 1 {
            return self.builder.not_(operand, name="not");
        } elif isinstance(operand.type, ir.IntType) {
            zero = ir.Constant(operand.type, 0);
            return self.builder.icmp_signed("==", operand, zero, name="not");
        }
        # Everything else (containers, floats, pointers): negate the value's
        # truthiness so `not x` agrees with `if x` -- _to_bool implements
        # Python semantics (an EMPTY list/dict/set is falsy, not a null one).
        # Without this, `not <list>` fell through unhandled and the enclosing
        # statement was dropped, silently inverting kernel guards like
        # `if not filtered { return False; }` in osp_visit (visit-else).
        return self.builder.not_(self._to_bool(operand), name="not");
    } elif op == Tok.BW_NOT {
        # Bitwise NOT: ~x = x XOR -1 (all 1s)
        if isinstance(operand.type, ir.IntType) {
            all_ones = ir.Constant(operand.type, -1);
            return self.builder.xor(operand, all_ones, name="bwnot");
        }
    } elif op == Tok.PLUS {
        # Unary +: identity for numeric types
        if operand.type == self.complex_struct_type.as_pointer() {
            return operand;
        }
    }
    return None;
}

"""Generate short-circuit boolean and/or expression."""
impl NaIRGenPass._codegen_bool_expr(nd: uni.BoolExpr) -> (ir.Value | None) {
    if not nd.values {
        return None;
    }
    op_name = nd.op.name if isinstance(nd.op, uni.Token) else str(nd.op);
    is_and = op_name == Tok.KW_AND;
    # Evaluate first operand
    result = self._codegen_expr(nd.values[0]);
    if result is None {
        return None;
    }
    result = self._to_bool(result);
    # Short-circuit chain for remaining operands
    for i in range(1, len(nd.values)) {
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
        rhs_val = self._codegen_expr(nd.values[i]);
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
"""Generate ternary expression: value if condition else else_value."""
impl NaIRGenPass._codegen_if_else_expr(nd: uni.IfElseExpr) -> (ir.Value | None) {
    cond = self._codegen_expr(nd.condition);
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
    then_val = self._codegen_expr(nd.value);
    then_end_bb = self.builder.block;
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    # Else
    self.builder.position_at_end(else_bb);
    else_val = self._codegen_expr(nd.else_value);
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
            } elif isinstance(then_val.type, ir.IntType)
            and isinstance(else_val.type, ir.IntType) {
                # Widen the narrower int to match the wider one
                if then_val.type.width > else_val.type.width {
                    else_val = self.builder.zext(
                        else_val, then_val.type, name="ternary.widen"
                    );
                } else {
                    then_val = self.builder.zext(
                        then_val, else_val.type, name="ternary.widen"
                    );
                }
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
"""Generate code for attribute/subscript access (e.g. Color.WHITE, self.x)."""
impl NaIRGenPass._codegen_atom_trailer(nd: uni.AtomTrailer) -> (ir.Value | None) {
    if nd.is_attr {
        target_name = self._get_name(nd.target);
        right_name = self._get_name(nd.right);
        # Check .value / .name on a direct enum member: Priority.HIGH.value.
        # The member access nests as AtomTrailer(AtomTrailer(Enum, MEMBER), attr),
        # and _get_name(nd.target) is None for the inner trailer, so this must run
        # ahead of the target_name guard below.
        if (right_name == "value" or right_name == "name")
        and isinstance(nd.target, uni.AtomTrailer)
        and nd.target.is_attr {
            mem_enum = self._get_name(nd.target.target);
            mem_name = self._get_name(nd.target.right);
            if mem_enum is not None
            and mem_name is not None
            and f"{mem_enum}.{mem_name}" in self.enum_values {
                member_val = self.enum_values[f"{mem_enum}.{mem_name}"];
                if mem_enum in self.enum_string_values {
                    # String enum: member lowers to its ordinal; .value/.name
                    # index the runtime string tables.
                    return self._codegen_enum_value_lookup(
                        mem_enum, member_val, use_name=(right_name == "name")
                    );
                }
                # Integer enum: member lowers to its assigned value, so .value
                # is the member constant itself.
                if right_name == "value" {
                    return member_val;
                }
                # Integer enum .name: index the name table by the member's
                # static declaration ordinal (the table is built ordinal-keyed,
                # independent of the assigned int values).
                ordinal = self.enum_member_ordinal.get(f"{mem_enum}.{mem_name}");
                if ordinal is not None {
                    return self._codegen_enum_value_lookup(
                        mem_enum, ir.Constant(ir.IntType(64), ordinal), use_name=True
                    );
                }
            }
        }
        if target_name is not None and right_name is not None {
            # Check native stdlib module access: sys.argv, sys.platform
            if (
                target_name == "sys"
                and self?._native_stdlib_modules
                and "sys" in self._native_stdlib_modules
            ) {
                if right_name == "argv" {
                    return self._emit_sys_argv();
                }
                if right_name == "platform" {
                    import platform as _plat;
                    return self._make_global_string(_plat.system().lower());
                }
                if right_name == "maxsize" {
                    # Native int is i64, so maxsize is INT64_MAX (matches a
                    # 64-bit CPython build).
                    return ir.Constant(ir.IntType(64), 0x7FFFFFFFFFFFFFFF);
                }
                if right_name == "byteorder" {
                    # Resolved at compile time from the host (the AOT target is
                    # the host arch). CPython reports "little"/"big" the same way.
                    import sys as _sys;
                    return self._make_global_string(_sys.byteorder);
                }
            }
            # Native stdlib math constants: math.pi, math.e, math.tau, ...
            if (
                target_name == "math"
                and self?._native_stdlib_modules
                and "math" in self._native_stdlib_modules
            ) {
                _mc = self._emit_math_const(right_name);
                if _mc is not None {
                    return _mc;
                }
            }
            # Check enum member access: Color.WHITE
            full_name = f"{target_name}.{right_name}";
            if full_name in self.enum_values {
                return self.enum_values[full_name];
            }
            # Enum .value / .name attribute: kind.value, self.kind.name —
            # enum-ness comes from the checked type of the target expression
            # (covers bare vars, params, and chained field access alike).
            if (right_name == "value" or right_name == "name") {
                enum_name = self._enum_name_of(nd.target);
                if enum_name is not None and enum_name in self.enum_types {
                    ordinal_val = self._codegen_expr(nd.target);
                    if ordinal_val is not None {
                        use_name = right_name == "name";
                        return self._codegen_enum_value_lookup(
                            enum_name, ordinal_val, use_name=use_name
                        );
                    }
                }
            }
            # Check field access on a struct-typed target: self.x, p.x —
            # struct-ness comes from the checked type of the target expression.
            _fa_type_name = self._struct_name_of(nd.target);
            if _fa_type_name is not None {
                type_name = _fa_type_name;
                obj_val = self._codegen_expr(nd.target);
                if obj_val is not None {
                    return self._codegen_field_access(obj_val, right_name, type_name);
                }
            }
        }
        # Chained field access: expr.field where expr is a complex expression
        if right_name is not None {
            obj_val = self._codegen_expr(nd.target);
            if obj_val is not None {
                type_name = self._infer_type_name(obj_val);
                if type_name is not None {
                    return self._codegen_field_access(obj_val, right_name, type_name);
                }
            }
        }
    }
    # Handle slice/range attribute access: sl.start, sl.stop, sl.step
    if nd.is_attr and target_name is not None and right_name is not None {
        _slice_field_map: dict[(str, int)] = {"start": 0, "stop": 1, "step": 2};
        if (
            self._type_key_of(nd.target) == "slice" and right_name in _slice_field_map
        ) {
            obj_val = self._codegen_expr(nd.target);
            if obj_val is not None {
                i32 = ir.IntType(32);
                z0 = ir.Constant(i32, 0);
                fidx = ir.Constant(i32, _slice_field_map[right_name]);
                ptr = self.builder.gep(
                    obj_val, [z0, fidx], name=f"slice.{right_name}.ptr"
                );
                return self.builder.load(ptr, name=f"slice.{right_name}");
            }
        }
    }
    # Handle slice access: lst[1:3], s[1:3] (range-based slicing)
    if not nd.is_attr and nd.right?.slices and nd.right.is_range {
        target_name = self._get_name(nd.target);
        slices = nd.right.slices or [];
        if slices {
            s = slices[0];
            # List slicing — list-ness comes from the checked type; the spec
            # prefers the value's actual LLVM shape (bare `list` annotations).
            _slice_list_spec = self._list_spec_of(nd.target);
            if _slice_list_spec is not None {
                target_val = self._codegen_expr(nd.target);
                if target_val is not None {
                    _shape = self._infer_list_elem_type(target_val);
                    elem_type_name = _shape if _shape is not None else _slice_list_spec;
                    result = self._codegen_list_slice(target_val, s, elem_type_name);
                    if result is not None {
                        return result;
                    }
                }
            } else {
                # Chained target (e.g. field access b.items[:n]) or string slicing.
                # The target is not a simple list-typed name, so evaluate it and
                # dispatch on the produced LLVM value: i8* → string slice,
                # List.T* → list slice (mirrors the chained-index path below).
                target_val = self._codegen_expr(nd.target);
                if target_val is not None {
                    i8p = ir.IntType(8).as_pointer();
                    if target_val.type == i8p {
                        result = self._codegen_string_slice(target_val, s);
                        if result is not None {
                            return result;
                        }
                    } else {
                        elem_type_name = self._infer_list_elem_type(target_val);
                        if elem_type_name is not None {
                            result = self._codegen_list_slice(
                                target_val, s, elem_type_name
                            );
                            if result is not None {
                                return result;
                            }
                        }
                    }
                }
            }
        }
    }
    # Handle index access: items[i] or expr[i]
    if not nd.is_attr and nd.right?.slices {
        target_name = self._get_name(nd.target);
        # Simple name with a checked list type
        _idx_list_spec = self._list_spec_of(nd.target)
            if target_name is not None
            else None;
        if _idx_list_spec is not None {
            target_val = self._codegen_expr(nd.target);
            if target_val is not None {
                _shape = self._infer_list_elem_type(target_val);
                elem_type_name = _shape if _shape is not None else _idx_list_spec;
                slices = nd.right.slices or [];
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
                        # Bitcast ptr list elements to the checked inner type
                        if result is not None and elem_type_name == "ptr" {
                            cast_type = self._list_elem_llvm_of(nd.target);
                            if (
                                isinstance(cast_type, ir.PointerType)
                                and result.type != cast_type
                            ) {
                                result = self.builder.bitcast(
                                    result, cast_type, name="idx.cast"
                                );
                            }
                        }
                        return result;
                    }
                }
            }
        } else {
            # Chained index: evaluate target expression, infer list type or string
            target_val = self._codegen_expr(nd.target);
            if target_val is not None {
                # Check for string indexing: s[i] (only real i8* strings, not list ptrs)
                i8p = ir.IntType(8).as_pointer();
                if target_val.type == i8p {
                    # If the checked type says this is a list, don't string-index
                    is_known_list = self._list_spec_of(nd.target) is not None;
                    if not is_known_list {
                        slices = nd.right.slices or [];
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
                    slices = nd.right.slices or [];
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
                            # Bitcast ptr list elements using the checked
                            # element type of the target list expression.
                            if result is not None and elem_type_name == "ptr" {
                                cast_type = self._list_elem_llvm_of(nd.target);
                                if (
                                    isinstance(cast_type, ir.PointerType)
                                    and result.type != cast_type
                                ) {
                                    result = self.builder.bitcast(
                                        result, cast_type, name="chain.idx.cast"
                                    );
                                }
                            }
                            return result;
                        }
                    }
                }
                # Check for tuple indexing (value or pointer to LiteralStructType)
                tsub_struct: (ir.LiteralStructType | None) = None;
                if isinstance(target_val.type, ir.LiteralStructType) {
                    tsub_struct = target_val.type;
                } elif isinstance(target_val.type, ir.PointerType)
                and isinstance(target_val.type.pointee, ir.LiteralStructType) {
                    tsub_struct = target_val.type.pointee;
                }
                if tsub_struct is not None {
                    slices = nd.right.slices or [];
                    if slices {
                        idx_node = slices[0];
                        idx_val = self._codegen_expr(idx_node);
                        if idx_val is None and idx_node?.start {
                            idx_val = self._codegen_expr(idx_node.start);
                        }
                        if idx_val is not None {
                            return self._codegen_tuple_index(
                                target_val, idx_val, tsub_struct
                            );
                        }
                    }
                }
                # Check for dict indexing
                dict_type_info = self._infer_dict_type(target_val);
                if dict_type_info is not None {
                    (key_type_name, val_type_name) = dict_type_info;
                    slices = nd.right.slices or [];
                    if slices {
                        idx_node = slices[0];
                        key_val = self._codegen_expr(idx_node);
                        if key_val is None and idx_node?.start {
                            key_val = self._codegen_expr(idx_node.start);
                        }
                        if key_val is not None {
                            return self._codegen_dict_access(
                                target_val, key_val, key_type_name, val_type_name
                            );
                        }
                    }
                }
            }
        }
        # Check for typed dict access: d[key] where d's checked type is a dict
        dict_type_key = self._dict_key_of(nd.target);
        if dict_type_key is not None {
            parts = dict_type_key.split(":");
            if len(parts) == 2 {
                (key_type_name, val_type_name) = (parts[0], parts[1]);
                target_val = self._codegen_expr(nd.target);
                if target_val is not None {
                    slices = nd.right.slices or [];
                    if slices {
                        idx_node = slices[0];
                        key_val = self._codegen_expr(idx_node);
                        if key_val is None and idx_node?.start {
                            key_val = self._codegen_expr(idx_node.start);
                        }
                        if key_val is not None {
                            return self._codegen_dict_access(
                                target_val, key_val, key_type_name, val_type_name
                            );
                        }
                    }
                }
            }
        }
    }
    # Dead-end: a recognized attribute/index/slice form we could not resolve to
    # any load/gep. Returning None here used to let the caller silently drop the
    # enclosing statement (the #6470 silent-no-code class), so make it loud --
    # the receiver's type did not resolve to a native struct/container layout.
    self.emit(
        E5090,
        node_override=nd,
        kind="attribute access" if nd.is_attr else "subscript/index access",
        name=(self._get_name(nd.right) or "<expr>")
            if nd.is_attr
            else (self._get_name(nd.target) or "<expr>"),
        help_text="The receiver's type could not be resolved to a native struct/container layout, so the access lowered to no code. Give the value a concrete native type, or move this code to a @sv/Python context."
    );
    return None;
}

"""Infer dict type info from an LLVM value. Returns (key_type_name, val_type_name) or None."""
impl NaIRGenPass._infer_dict_type(val: ir.Value) -> (tuple | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (dict_key, dtype) in self.dict_types.items() {
        if val.type == dtype.as_pointer() {
            parts = dict_key.split(":");
            if len(parts) == 2 {
                return (parts[0], parts[1]);
            }
        }
    }
    return None;
}
# ─── Phase 1: Boolean Expressions (short-circuit) ────────────
