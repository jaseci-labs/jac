# AST validation for the P4 back track (INTEGRATION_PLAN Phase 2).
#
# Owns language legality independent of scope resolution: placement of return,
# break, continue, and yield; expression contexts on names, attributes, and
# subscripts; legal store and delete targets. Codegen receives validated AST
# only via product_compile.jac.

import from jaclang.compiler.frontend.python.ast_nodes {
    ImportFrom,
    ast_node,
    Is,
    IsNot,
    Assert,
    expr,
    stmt,
    Constant,
    Name,
    BinOp,
    UnaryOp,
    Call,
    Compare,
    BoolOp,
    Assign,
    Expr,
    Pass,
    Return,
    AugAssign,
    AnnAssign,
    NamedExpr,
    Delete,
    Attribute,
    Subscript,
    Slice,
    Tuple,
    List,
    Dict,
    Starred,
    Load,
    Store,
    Del,
    Break,
    Continue,
    Yield,
    YieldFrom,
    Global,
    Nonlocal,
    For,
    While,
    If,
    Try,
    TryStar,
    With,
    FunctionDef,
    ClassDef,
    AsyncFunctionDef,
    TypeAlias,
    AsyncFor,
    AsyncWith,
    Await,
    Lambda,
    ListComp,
    SetComp,
    DictComp,
    GeneratorExp,
}
import jaclang.compiler.frontend.python.ast_nodes as nodes;

# Feature versions constrain source grammar; AST inputs are already parsed.
def validate_feature_version(value: any, version: int) {
    if version >= 14 {
        return;
    }
    if isinstance(value, list) {
        for item in value {
            validate_feature_version(item, version);
        }
        return;
    }
    if not isinstance(value, nodes.ast_node) {
        return;
    }
    minimum = 0;
    feature = "";
    if isinstance(value, nodes.AsyncFunctionDef) {
        minimum = 5;
        feature = "Async functions are";
    } elif isinstance(value, nodes.AsyncFor) {
        minimum = 5;
        feature = "Async for loops are";
    } elif isinstance(value, nodes.AsyncWith) {
        minimum = 5;
        feature = "Async with statements are";
    } elif isinstance(value, nodes.Await) {
        minimum = 5;
        feature = "Await expressions are";
    } elif isinstance(value, (nodes.BinOp, nodes.AugAssign))
        and isinstance(value.op, nodes.MatMult) {
        minimum = 5;
        feature = "The '@' operator is";
    } elif isinstance(value, nodes.AnnAssign) {
        minimum = 6;
        feature = "Variable annotation syntax is";
    } elif isinstance(value, nodes.comprehension) and value.is_async {
        minimum = 6;
        feature = "Async comprehensions are";
    } elif isinstance(value, nodes.arguments) and value.posonlyargs {
        minimum = 8;
        feature = "Positional-only parameters are";
    } elif isinstance(value, nodes.NamedExpr) {
        minimum = 8;
        feature = "Assignment expressions are";
    } elif isinstance(value, nodes.Match) {
        minimum = 10;
        feature = "Pattern matching is";
    } elif isinstance(value, nodes.TryStar) {
        minimum = 11;
        feature = "Exception groups are";
    } elif isinstance(value, nodes.TypeAlias) {
        minimum = 12;
        feature = "Type statement is";
    } elif isinstance(value, nodes.TemplateStr) {
        minimum = 14;
        feature = "t-strings are";
    }
    if isinstance(value, (nodes.FunctionDef, nodes.AsyncFunctionDef, nodes.ClassDef))
        and value.type_params
        and minimum < 12 {
        minimum = 12;
        feature = "Type parameter lists are";
    }
    if isinstance(value, (nodes.TypeVar, nodes.TypeVarTuple, nodes.ParamSpec))
        and value.default_value is not None {
        minimum = 13;
        feature = "Type parameter defaults are";
    }
    if version < minimum {
        line = getattr(value, "lineno", 1);
        column = getattr(value, "col_offset", 0);
        raise SyntaxError(
            f"{feature} only supported in Python 3.{minimum} and greater",
            ("<unknown>", line, column + 1, None)
        );
    }
    for child in vars(value).values() {
        validate_feature_version(child, version);
    }
}

import from jaclang.compiler.frontend.python.compiler_diagnostics {
    compiler_diagnostic,
    validation_diagnostic,
    compiler_diag_kind,
    syntax_warning,
}

# Diagnose the source AST once, before lowering duplicates finally bodies or
# folds constant branches. Traversal follows only AST fields, never Jac anchors.
def check_ast_warnings(tree: ast_node, filename: str) {
    pending = [(tree, False, False)];
    while pending {
        (item_node, return_in_finally, loop_exit_in_finally) = pending.pop();
        exit_name = None;
        if isinstance(item_node, Return) and return_in_finally {
            exit_name = "return";
        } elif isinstance(item_node, Break) and loop_exit_in_finally {
            exit_name = "break";
        } elif isinstance(item_node, Continue) and loop_exit_in_finally {
            exit_name = "continue";
        }
        if exit_name is not None and isinstance(item_node, stmt) {
            syntax_warning(
                f"'{exit_name}' in a 'finally' block",
                filename,
                item_node.lineno,
                item_node.col_offset
            );
        }
        if isinstance(item_node, Compare) {
            left = item_node.left;
            for (op, right) in zip(item_node.ops, item_node.comparators) {
                if isinstance(op, (Is, IsNot)) {
                    literal = None;
                    for candidate in (left, right) {
                        if isinstance(candidate, Constant)
                            and candidate.value.t not in ("none", "bool", "ellipsis") {
                            literal = candidate.value.t;
                            break;
                        }
                    }
                    if literal is not None {
                        spelling = "is" if isinstance(op, Is) else "is not";
                        comparison = "==" if isinstance(op, Is) else "!=";
                        syntax_warning(
                            f'"{spelling}" with \'{literal}\' literal. Did you mean "{comparison}"?',
                            filename,
                            item_node.lineno,
                            item_node.col_offset
                        );
                    }
                }
                left = right;
            }
        } elif isinstance(item_node, Assert)
            and isinstance(item_node.`test, Tuple)
            and item_node.`test.elts {
            syntax_warning(
                "assertion is always true, perhaps remove parentheses?",
                filename,
                item_node.lineno,
                item_node.col_offset
            );
        }
        children = [];
        for (key, value) in vars(item_node).items() {
            child_return = return_in_finally;
            child_loop_exit = loop_exit_in_finally;
            if isinstance(item_node, (FunctionDef, AsyncFunctionDef, ClassDef)) {
                child_return = False;
                child_loop_exit = False;
            } elif isinstance(item_node, (Try, TryStar)) and key == "finalbody" {
                child_return = True;
                child_loop_exit = True;
            } elif isinstance(item_node, (For, AsyncFor, While)) and key == "body" {
                child_loop_exit = False;
            }
            if isinstance(value, ast_node) {
                children.append((value, child_return, child_loop_exit));
            } elif isinstance(value, list) {
                children.extend(
                    (item, child_return, child_loop_exit)
                    for item in value
                    if isinstance(item, ast_node)
                );
            }
        }
        pending.extend(reversed(children));
    }
}

obj validation_result {
    has diag: compiler_diagnostic | None = None;
}

def validation_ok -> validation_result {
    return validation_result();
}

def validation_error(
    kind: str, message: str, lineno: int = -1, col_offset: int = -1
) -> validation_result {
    return validation_result(
        diag=validation_diagnostic(
            kind=kind, message=message, lineno=lineno, col_offset=col_offset
        )
    );
}

# --- expression context ---

def validate_load_expr(e: expr, in_function: bool) -> validation_result {
    if isinstance(e, Yield) or isinstance(e, YieldFrom) {
        if not in_function {
            lineno = 1;
            col = 0;
            if isinstance(e, Yield) {
                yy = e as Yield;
                lineno = yy.lineno;
                col = yy.col_offset;
            }
            if isinstance(e, YieldFrom) {
                yf = e as YieldFrom;
                lineno = yf.lineno;
                col = yf.col_offset;
            }
            return validation_error(
                "SyntaxError", "'yield' outside function", lineno, col
            );
        }
        if isinstance(e, Yield) {
            y = e as Yield;
            if y.value is not None {
                return validate_load_expr(y.value, in_function);
            }
            return validation_ok();
        }
        return validate_load_expr((e as YieldFrom).value, in_function);
    }
    if isinstance(e, Name) {
        n = e as Name;
        if not isinstance(n.ctx, Load) {
            return validation_error(
                "SyntaxError",
                "name '" + n.id + "' is not defined",
                n.lineno,
                n.col_offset
            );
        }
        return validation_ok();
    }
    if isinstance(e, Attribute) {
        a = e as Attribute;
        if not isinstance(a.ctx, Load) {
            return validation_error(
                "SyntaxError", "illegal expression context", a.lineno, a.col_offset
            );
        }
        inner = validate_load_expr(a.value, in_function);
        if inner.diag is not None {
            return inner;
        }
        return validation_ok();
    }
    if isinstance(e, Subscript) {
        s = e as Subscript;
        if not isinstance(s.ctx, Load) {
            return validation_error(
                "SyntaxError", "illegal expression context", s.lineno, s.col_offset
            );
        }
        inner = validate_load_expr(s.value, in_function);
        if inner.diag is not None {
            return inner;
        }
        return validate_subscript_slice(s.slice, in_function);
    }
    if isinstance(e, Constant) {
        return validation_ok();
    }
    if isinstance(e, BinOp) {
        b = e as BinOp;
        left = validate_load_expr(b.left, in_function);
        if left.diag is not None {
            return left;
        }
        return validate_load_expr(b.right, in_function);
    }
    if isinstance(e, UnaryOp) {
        return validate_load_expr((e as UnaryOp).operand, in_function);
    }
    if isinstance(e, Compare) {
        c = e as Compare;
        left = validate_load_expr(c.left, in_function);
        if left.diag is not None {
            return left;
        }
        ci = 0;
        while ci < len(c.comparators) {
            cmp = validate_load_expr(c.comparators[ci], in_function);
            if cmp.diag is not None {
                return cmp;
            }
            ci = ci + 1;
        }
        return validation_ok();
    }
    if isinstance(e, Call) {
        ca = e as Call;
        func = validate_load_expr(ca.func, in_function);
        if func.diag is not None {
            return func;
        }
        args = ca.args;
        if args is None {
            args = [];
        }
        ai = 0;
        while ai < len(args) {
            arg = validate_load_expr(args[ai], in_function);
            if arg.diag is not None {
                return arg;
            }
            ai = ai + 1;
        }
        return validation_ok();
    }
    if isinstance(e, BoolOp) {
        bo = e as BoolOp;
        vi = 0;
        while vi < len(bo.values) {
            vr = validate_load_expr(bo.values[vi], in_function);
            if vr.diag is not None {
                return vr;
            }
            vi = vi + 1;
        }
        return validation_ok();
    }
    if isinstance(e, List) {
        li = e as List;
        li_elts = li.elts if li.elts is not None else [];
        ei = 0;
        while ei < len(li_elts) {
            vr = validate_load_expr(li_elts[ei], in_function);
            if vr.diag is not None {
                return vr;
            }
            ei = ei + 1;
        }
        return validation_ok();
    }
    if isinstance(e, Tuple) {
        tu = e as Tuple;
        tu_elts = tu.elts if tu.elts is not None else [];
        ei = 0;
        while ei < len(tu_elts) {
            vr = validate_load_expr(tu_elts[ei], in_function);
            if vr.diag is not None {
                return vr;
            }
            ei = ei + 1;
        }
        return validation_ok();
    }
    if isinstance(e, Starred) {
        return validate_load_expr((e as Starred).value, in_function);
    }
    if isinstance(e, Slice) {
        return validate_subscript_slice(e, in_function);
    }
    return validation_ok();
}

def validate_stmt_list(
    body: list[stmt], in_function: bool, in_loop: bool, in_async: bool
) -> validation_result {
    si = 0;
    while si < len(body) {
        r = validate_stmt(body[si], in_function, in_loop, in_async);
        if r.diag is not None {
            return r;
        }
        si = si + 1;
    }
    return validation_ok();
}

def validate_subscript_slice(key: expr, in_function: bool) -> validation_result {
    if isinstance(key, Slice) {
        sl = key as Slice;
        if sl.lower is not None {
            lo = validate_load_expr(sl.lower, in_function);
            if lo.diag is not None {
                return lo;
            }
        }
        if sl.upper is not None {
            up = validate_load_expr(sl.upper, in_function);
            if up.diag is not None {
                return up;
            }
        }
        if sl.step is not None {
            st = validate_load_expr(sl.step, in_function);
            if st.diag is not None {
                return st;
            }
        }
        return validation_ok();
    }
    return validate_load_expr(key, in_function);
}

# --- store / delete targets ---

def validate_store_target(t: expr, in_function: bool) -> validation_result {
    if isinstance(t, Name) {
        n = t as Name;
        if n.id == "__debug__" {
            return validation_error(
                "SyntaxError", "cannot assign to __debug__", n.lineno, n.col_offset
            );
        }
        if not isinstance(n.ctx, Store) {
            return validation_error(
                "SyntaxError", "cannot assign to " + n.id, n.lineno, n.col_offset
            );
        }
        return validation_ok();
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        if a.attr == "__debug__" {
            return validation_error(
                "SyntaxError", "cannot assign to __debug__", a.lineno, a.col_offset
            );
        }
        if not isinstance(a.ctx, Store) {
            return validation_error(
                "SyntaxError", "illegal target for assignment", a.lineno, a.col_offset
            );
        }
        return validate_load_expr(a.value, in_function);
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        if not isinstance(s.ctx, Store) {
            return validation_error(
                "SyntaxError", "illegal target for assignment", s.lineno, s.col_offset
            );
        }
        inner = validate_load_expr(s.value, in_function);
        if inner.diag is not None {
            return inner;
        }
        return validate_subscript_slice(s.slice, in_function);
    }
    # Unsupported but syntactically valid targets (tuple unpacking, etc.) are
    # codegen's job with NotImplementedError, not validation SyntaxError.
    return validation_ok();
}

def validate_delete_target(t: expr, in_function: bool) -> validation_result {
    if isinstance(t, Name) {
        n = t as Name;
        if not isinstance(n.ctx, Del) {
            return validation_error(
                "SyntaxError", "cannot delete " + n.id, n.lineno, n.col_offset
            );
        }
        return validation_ok();
    }
    if isinstance(t, Attribute) {
        a = t as Attribute;
        if not isinstance(a.ctx, Del) {
            return validation_error(
                "SyntaxError", "illegal target for deletion", a.lineno, a.col_offset
            );
        }
        return validate_load_expr(a.value, in_function);
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        if not isinstance(s.ctx, Del) {
            return validation_error(
                "SyntaxError", "illegal target for deletion", s.lineno, s.col_offset
            );
        }
        inner = validate_load_expr(s.value, in_function);
        if inner.diag is not None {
            return inner;
        }
        return validate_subscript_slice(s.slice, in_function);
    }
    return validation_ok();
}

# --- statements ---

def validate_stmt(
    s: stmt, in_function: bool, in_loop: bool, in_async: bool = False
) -> validation_result {
    if isinstance(s, Return) {
        r = s as Return;
        if not in_function {
            return validation_error(
                "SyntaxError", "'return' outside function", r.lineno, r.col_offset
            );
        }
        if r.value is not None {
            return validate_load_expr(r.value, in_function);
        }
        return validation_ok();
    }
    if isinstance(s, Break) {
        b = s as Break;
        if not in_loop {
            return validation_error(
                "SyntaxError", "'break' outside loop", b.lineno, b.col_offset
            );
        }
        return validation_ok();
    }
    if isinstance(s, Continue) {
        c = s as Continue;
        if not in_loop {
            return validation_error(
                "SyntaxError", "'continue' not properly in loop", c.lineno, c.col_offset
            );
        }
        return validation_ok();
    }
    if isinstance(s, Yield) or isinstance(s, YieldFrom) {
        if not in_function {
            lineno = 1;
            col = 0;
            if isinstance(s, Yield) {
                yy = s as Yield;
                lineno = yy.lineno;
                col = yy.col_offset;
            }
            if isinstance(s, YieldFrom) {
                yf = s as YieldFrom;
                lineno = yf.lineno;
                col = yf.col_offset;
            }
            return validation_error(
                "SyntaxError", "'yield' outside function", lineno, col
            );
        }
        return validation_ok();
    }
    if isinstance(s, Assign) {
        a = s as Assign;
        val = validate_load_expr(a.value, in_function);
        if val.diag is not None {
            return val;
        }
        ti = 0;
        while ti < len(a.targets) {
            tgt = validate_store_target(a.targets[ti], in_function);
            if tgt.diag is not None {
                return tgt;
            }
            ti = ti + 1;
        }
        return validation_ok();
    }
    if isinstance(s, AugAssign) {
        aa = s as AugAssign;
        tgt = validate_store_target(aa.target, in_function);
        if tgt.diag is not None {
            return tgt;
        }
        return validate_load_expr(aa.value, in_function);
    }
    if isinstance(s, AnnAssign) {
        an = s as AnnAssign;
        tgt = validate_store_target(an.target, in_function);
        if tgt.diag is not None {
            return tgt;
        }
        if an.value is not None {
            return validate_load_expr(an.value, in_function);
        }
        return validation_ok();
    }
    if isinstance(s, Delete) {
        d = s as Delete;
        ti = 0;
        while ti < len(d.targets) {
            tgt = validate_delete_target(d.targets[ti], in_function);
            if tgt.diag is not None {
                return tgt;
            }
            ti = ti + 1;
        }
        return validation_ok();
    }
    if isinstance(s, Expr) {
        return validate_load_expr((s as Expr).value, in_function);
    }
    if isinstance(s, (Pass, Global, Nonlocal)) {
        # Repeated names within one global/nonlocal declaration are legal.
        # Scope conflicts and ordering are checked by the symbol-table pass.
        return validation_ok();
    }
    if isinstance(s, For) {
        fo = s as For;
        tgt = validate_store_target(fo.target, in_function);
        if tgt.diag is not None {
            return tgt;
        }
        it = validate_load_expr(fo.iter, in_function);
        if it.diag is not None {
            return it;
        }
        body = validate_stmt_list(fo.body, in_function, True, in_async);
        if body.diag is not None {
            return body;
        }
        return validate_stmt_list(fo.orelse, in_function, in_loop, in_async);
    }
    if isinstance(s, AsyncFor) {
        if not in_async {
            af = s as AsyncFor;
            return validation_error(
                "SyntaxError",
                "'async for' outside async function",
                af.lineno,
                af.col_offset
            );
        }
        afo = s as AsyncFor;
        tgt = validate_store_target(afo.target, in_function);
        if tgt.diag is not None {
            return tgt;
        }
        it = validate_load_expr(afo.iter, in_function);
        if it.diag is not None {
            return it;
        }
        body = validate_stmt_list(afo.body, in_function, True, True);
        if body.diag is not None {
            return body;
        }
        return validate_stmt_list(afo.orelse, in_function, in_loop, True);
    }
    if isinstance(s, While) {
        wh = s as While;
        te = validate_load_expr(wh.`test, in_function);
        if te.diag is not None {
            return te;
        }
        body = validate_stmt_list(wh.body, in_function, True, in_async);
        if body.diag is not None {
            return body;
        }
        return validate_stmt_list(wh.orelse, in_function, in_loop, in_async);
    }
    if isinstance(s, If) {
        iff = s as If;
        te = validate_load_expr(iff.`test, in_function);
        if te.diag is not None {
            return te;
        }
        body = validate_stmt_list(iff.body, in_function, in_loop, in_async);
        if body.diag is not None {
            return body;
        }
        return validate_stmt_list(iff.orelse, in_function, in_loop, in_async);
    }
    if isinstance(s, (Try, TryStar)) {
        tr = s;
        body = validate_stmt_list(tr.body, in_function, in_loop, in_async);
        if body.diag is not None {
            return body;
        }
        if tr.orelse is not None {
            body = validate_stmt_list(tr.orelse, in_function, in_loop, in_async);
            if body.diag is not None {
                return body;
            }
        }
        if tr.handlers is not None {
            hi = 0;
            while hi < len(tr.handlers) {
                h = tr.handlers[hi];
                if h.type is not None {
                    te = validate_load_expr(h.type, in_function);
                    if te.diag is not None {
                        return te;
                    }
                }
                body = validate_stmt_list(h.body, in_function, in_loop, in_async);
                if body.diag is not None {
                    return body;
                }
                hi = hi + 1;
            }
        }
        if tr.finalbody is not None {
            return validate_stmt_list(tr.finalbody, in_function, in_loop, in_async);
        }
        return validation_ok();
    }
    if isinstance(s, With) {
        wi = s as With;
        ii = 0;
        while ii < len(wi.items) {
            item = wi.items[ii];
            ce = validate_load_expr(item.context_expr, in_function);
            if ce.diag is not None {
                return ce;
            }
            if item.optional_vars is not None {
                ov = validate_store_target(item.optional_vars, in_function);
                if ov.diag is not None {
                    return ov;
                }
            }
            ii = ii + 1;
        }
        return validate_stmt_list(wi.body, in_function, in_loop, in_async);
    }
    if isinstance(s, AsyncWith) {
        if not in_async {
            aw = s as AsyncWith;
            return validation_error(
                "SyntaxError",
                "'async with' outside async function",
                aw.lineno,
                aw.col_offset
            );
        }
        awi = s as AsyncWith;
        ii = 0;
        while ii < len(awi.items) {
            item = awi.items[ii];
            ce = validate_load_expr(item.context_expr, in_function);
            if ce.diag is not None {
                return ce;
            }
            if item.optional_vars is not None {
                ov = validate_store_target(item.optional_vars, in_function);
                if ov.diag is not None {
                    return ov;
                }
            }
            ii = ii + 1;
        }
        return validate_stmt_list(awi.body, in_function, in_loop, True);
    }
    if isinstance(s, FunctionDef) {
        fd = s as FunctionDef;
        return validate_stmt_list(fd.body, True, False, False);
    }
    if isinstance(s, AsyncFunctionDef) {
        afd = s as AsyncFunctionDef;
        return validate_stmt_list(afd.body, True, False, True);
    }
    if isinstance(s, ClassDef) {
        cd = s as ClassDef;
        return validate_stmt_list(cd.body, False, False, in_async);
    }
    if isinstance(s, TypeAlias) {
        # The alias value is an ordinary load expression compiled inside a
        # nested scope; only expression-level rules apply to it.
        ta = s as TypeAlias;
        if not isinstance(ta.name, Name) {
            return validation_error("SyntaxError", "invalid type alias target");
        }
        return validate_load_expr(ta.value, in_function);
    }
    return validation_ok();
}

def validate_except_star_exits(body: list[stmt]) -> validation_result {
    pending: list[tuple[ast_node, bool, bool]] = [
        (item, False, False) for item in reversed(body)
    ];
    while pending {
        (item, return_forbidden, loop_exit_forbidden) = pending.pop();
        if (isinstance(item, Return) and return_forbidden)
            or (isinstance(item, (Break, Continue)) and loop_exit_forbidden) {
            return validation_error(
                "SyntaxError",
                "'break', 'continue' and 'return' cannot appear in an except* block",
                item.lineno,
                item.col_offset
            );
        }
        children: list[tuple[ast_node, bool, bool]] = [];
        for (key, value) in vars(item).items() {
            no_return = return_forbidden;
            no_loop_exit = loop_exit_forbidden;
            if isinstance(item, (FunctionDef, AsyncFunctionDef, ClassDef)) {
                no_return = False;
                no_loop_exit = False;
            } elif isinstance(item, TryStar) and key == "handlers" {
                no_return = True;
                no_loop_exit = True;
            } elif isinstance(item, (For, AsyncFor, While)) and key == "body" {
                no_loop_exit = False;
            }
            if isinstance(value, ast_node) {
                children.append((value, no_return, no_loop_exit));
            } elif isinstance(value, list) {
                children.extend(
                    (child, no_return, no_loop_exit)
                    for child in value
                    if isinstance(child, ast_node)
                );
            }
        }
        pending.extend(reversed(children));
    }
    return validation_ok();
}

# Suspension legality follows lexical scopes, including expression fields
# such as defaults, decorators, annotations and comprehension filters.
def validate_suspensions(
    roots: list[ast_node], allow_top_await: bool = False
) -> validation_result {
    pending: list[tuple[ast_node, bool, bool, bool, bool]] = [
        (item, False, allow_top_await, False, False) for item in reversed(roots)
    ];
    while pending {
        (item, in_function, in_async, in_comp, in_annotation) = pending.pop();
        message: str | None = None;
        if isinstance(item, NamedExpr) and in_annotation {
            message = "named expression cannot be used within an annotation";
        } elif isinstance(item, Await) {
            if in_annotation {
                message = "await expression cannot be used within an annotation";
            } elif not in_async {
                message = "'await' outside async function"
                    if in_function
                    else "'await' outside function";
            }
        } elif isinstance(item, (Yield, YieldFrom)) {
            if in_annotation {
                message = "yield expression cannot be used within an annotation";
            } elif in_comp {
                message = "'yield' inside comprehension";
            } elif not in_function {
                message = "'yield' outside function";
            } elif in_async and isinstance(item, YieldFrom) {
                message = "'yield from' inside async function";
            }
        }
        if message is not None {
            located = item as expr;
            return validation_error(
                "SyntaxError", message, located.lineno, located.col_offset
            );
        }
        if isinstance(item, (ListComp, SetComp, DictComp, GeneratorExp)) {
            is_gen = isinstance(item, GeneratorExp);
            if not is_gen
                and not in_async
                and any(gen.is_async for gen in item.generators) {
                return validation_error(
                    "SyntaxError",
                    "asynchronous comprehension outside of an asynchronous function",
                    item.lineno,
                    item.col_offset
                );
            }
            comp_async = in_async or is_gen;
            for (index, gen) in enumerate(item.generators) {
                pending.append(
                    (
                        gen.iter,
                        in_function if index == 0 else True,
                        in_async if index == 0 else comp_async,
                        in_comp if index == 0 else True,
                        in_annotation if index == 0 else False
                    )
                );
                pending.append((gen.target, True, comp_async, True, False));
                pending.extend(
                    (condition, True, comp_async, True, False) for condition in gen.ifs
                );
            }
            if isinstance(item, DictComp) {
                pending.append((item.key, True, comp_async, True, False));
                pending.append((item.value, True, comp_async, True, False));
            } else {
                pending.append((item.elt, True, comp_async, True, False));
            }
            continue;
        }
        children: list[tuple[ast_node, bool, bool, bool, bool]] = [];
        for (field, value) in vars(item).items() {
            fn = in_function;
            asynchronous = in_async;
            comp = in_comp;
            annotation = in_annotation or field in ("annotation", "returns");
            if field in ("annotation", "returns") {
                asynchronous = False;
                comp = False;
            }
            if isinstance(item, (FunctionDef, AsyncFunctionDef, Lambda, ClassDef))
                and field == "body" {
                fn = not isinstance(item, ClassDef);
                asynchronous = isinstance(item, AsyncFunctionDef);
                comp = False;
                annotation = False;
            }
            if isinstance(value, ast_node) {
                children.append((value, fn, asynchronous, comp, annotation));
            } elif isinstance(value, list) {
                children.extend(
                    (child, fn, asynchronous, comp, annotation)
                    for child in value
                    if isinstance(child, ast_node)
                );
            }
        }
        pending.extend(reversed(children));
    }
    return validation_ok();
}

def validate_module_body(
    body: list[stmt], allow_top_await: bool = False
) -> validation_result {
    result = validate_suspensions([item for item in body], allow_top_await);
    if result.diag is not None {
        return result;
    }
    result = validate_except_star_exits(body);
    if result.diag is not None {
        return result;
    }
    return validate_stmt_list(
        body, in_function=False, in_loop=False, in_async=allow_top_await
    );
}

def validate_eval_expr(e: expr, allow_top_await: bool = False) -> validation_result {
    result = validate_suspensions([e], allow_top_await);
    if result.diag is not None {
        return result;
    }
    return validate_load_expr(e, False);
}

# Resolve future directives before scopes are built. Only a leading docstring
# and other future directives may precede them, including on the same line.
def future_features(
    body: list[stmt], check_placement: bool = True
) -> tuple[int, validation_result] {
    allowed: set[int] = set();
    flags = 0;
    obsolete = (
        "nested_scopes",
        "generators",
        "division",
        "absolute_import",
        "with_statement",
        "print_function",
        "unicode_literals",
        "generator_stop"
    );
    for (index, item) in enumerate(body) {
        if index == 0
            and isinstance(item, Expr)
            and isinstance(item.value, Constant)
            and item.value.value.t == "str" {
            continue;
        }
        if not isinstance(item, ImportFrom)
            or item.module != "__future__"
            or item.level {
            break;
        }
        allowed.add(id(item));
        for feature in item.names {
            if feature.name in obsolete {
                continue;
            }
            if feature.name == "barry_as_FLUFL" {
                flags |= 0x400000;
            } elif feature.name == "annotations" {
                flags |= 0x1000000;
            } else {
                message = "not a chance"
                    if feature.name == "braces"
                    else "future feature " + feature.name[:100] + " is not defined";
                return (
                    flags,
                    validation_error(
                        "SyntaxError", message, feature.lineno, feature.col_offset
                    )
                );
            }
        }
    }
    if not check_placement {
        return (flags, validation_ok());
    }
    pending: list[ast_node] = [item for item in reversed(body)];
    while pending {
        item = pending.pop();
        if isinstance(item, ImportFrom)
            and item.module == "__future__"
            and not item.level
            and id(item) not in allowed {
            return (
                flags,
                validation_error(
                    "SyntaxError",
                    "from __future__ imports must occur at the beginning of the file",
                    item.lineno,
                    item.col_offset
                )
            );
        }
        children: list[ast_node] = [];
        for value in vars(item).values() {
            if isinstance(value, ast_node) {
                children.append(value);
            } elif isinstance(value, list) {
                children.extend(
                    child
                    for child in value
                    if isinstance(child, ast_node)
                );
            }
        }
        pending.extend(reversed(children));
    }
    return (flags, validation_ok());
}
