# Pure leaf helpers extracted from compiler_codegen.jac (no cfg_builder,
# no visit_*/emit_* calls) so the recursive codegen core is smaller to read.
# Imports mirror the header of compiler_codegen.jac (foundational modules only).

import from objects { PyObj, PyInt, PyStr, py_none, PySlice, PyCode, PyTuple }
import from opcode_meta {
    OP_RESUME,
    OP_RETURN_GENERATOR,
    OP_RETURN_VALUE,
    OP_YIELD_VALUE,
    OP_GET_YIELD_FROM_ITER,
    OP_GET_AWAITABLE,
    OP_GET_AITER,
    OP_GET_ANEXT,
    OP_END_ASYNC_FOR,
    OP_SEND,
    OP_END_SEND,
    OP_CLEANUP_THROW,
    OP_JUMP_BACKWARD_NO_INTERRUPT,
    OP_CALL_INTRINSIC_1,
    OP_LOAD_CONST,
    OP_LOAD_SMALL_INT,
    OP_LOAD_NAME,
    OP_LOAD_GLOBAL,
    OP_LOAD_BUILD_CLASS,
    OP_MAKE_FUNCTION,
    OP_MAKE_CELL,
    OP_COPY_FREE_VARS,
    OP_LOAD_DEREF,
    OP_STORE_DEREF,
    OP_BUILD_TUPLE,
    OP_SET_FUNCTION_ATTRIBUTE,
    OP_BINARY_OP,
    CO_OPTIMIZED,
    CO_NEWLOCALS,
    CO_NESTED,
    CO_GENERATOR,
    CO_COROUTINE,
    CO_ASYNC_GENERATOR,
    CO_VARARGS,
    CO_VARKEYWORDS,
    OP_UNARY_NEGATIVE,
    OP_UNARY_INVERT,
    OP_UNARY_NOT,
    OP_PUSH_NULL,
    OP_CALL,
    OP_CALL_KW,
    OP_LOAD_LOCALS,
    OP_COMPARE_OP,
    OP_IS_OP,
    OP_POP_TOP,
    OP_IMPORT_NAME,
    OP_IMPORT_FROM,
    OP_STORE_NAME,
    OP_STORE_ATTR,
    OP_STORE_SUBSCR,
    OP_LOAD_ATTR,
    OP_DELETE_NAME,
    OP_DELETE_ATTR,
    OP_DELETE_SUBSCR,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_TRUE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_POP_JUMP_IF_NONE,
    OP_JUMP_FORWARD,
    OP_JUMP_BACKWARD,
    OP_COPY,
    OP_SWAP,
    OP_GET_LEN,
    OP_MATCH_SEQUENCE,
    OP_MATCH_MAPPING,
    OP_MATCH_KEYS,
    OP_MATCH_CLASS,
    OP_DICT_UPDATE,
    OP_TO_BOOL,
    OP_NOP,
    OP_NOT_TAKEN,
    OP_GET_ITER,
    OP_FOR_ITER,
    OP_END_FOR,
    OP_POP_ITER,
    OP_BUILD_LIST,
    OP_LIST_APPEND,
    OP_LIST_EXTEND,
    OP_BUILD_SET,
    OP_SET_ADD,
    OP_SET_UPDATE,
    OP_BUILD_MAP,
    OP_MAP_ADD,
    OP_LOAD_FAST,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_FAST_CHECK,
    OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
    OP_LOAD_FAST_AND_CLEAR,
    OP_STORE_FAST,
    OP_DELETE_FAST,
    OP_STORE_FAST_STORE_FAST,
    OP_STORE_FAST_LOAD_FAST,
    OP_UNPACK_SEQUENCE,
    OP_UNPACK_EX,
    OP_PUSH_EXC_INFO,
    OP_POP_EXCEPT,
    OP_CHECK_EXC_MATCH,
    OP_RERAISE,
    OP_RAISE_VARARGS,
    OP_LOAD_SPECIAL,
    OP_WITH_EXCEPT_START,
    OP_LOAD_COMMON_CONSTANT,
    NB_ADD,
    NB_SUBTRACT,
    NB_MULTIPLY,
    NB_TRUE_DIVIDE,
    NB_FLOOR_DIVIDE,
    NB_REMAINDER,
    NB_POWER,
    NB_LSHIFT,
    NB_RSHIFT,
    NB_OR,
    NB_XOR,
    NB_AND,
    NB_MATRIX_MULTIPLY,
    NB_SUBSCR,
    NB_INPLACE_ADD,
    NB_INPLACE_SUBTRACT,
    NB_INPLACE_MULTIPLY,
    NB_INPLACE_TRUE_DIVIDE,
    NB_INPLACE_FLOOR_DIVIDE,
    NB_INPLACE_REMAINDER,
    NB_INPLACE_POWER,
    NB_INPLACE_LSHIFT,
    NB_INPLACE_RSHIFT,
    NB_INPLACE_OR,
    NB_INPLACE_XOR,
    NB_INPLACE_AND,
    NB_INPLACE_MATRIX_MULTIPLY,
    CMP_LT,
    CMP_LE,
    CMP_EQ,
    CMP_NE,
    CMP_GT,
    CMP_GE,
    compare_oparg,
    compare_filter_oparg,
}
import from ast_nodes {
    ast_node,
    expr,
    stmt,
    Constant,
    Name,
    BinOp,
    UnaryOp,
    Call,
    Compare,
    Assign,
    Expr,
    Pass,
    Return,
    AugAssign,
    AnnAssign,
    Delete,
    Attribute,
    Subscript,
    Slice,
    Load,
    Store,
    Lt,
    Gt,
    Eq,
    NotEq,
    LtE,
    GtE,
    Add,
    Sub,
    Mult,
    Div,
    Mod,
    Pow,
    LShift,
    RShift,
    BitOr,
    BitXor,
    BitAnd,
    FloorDiv,
    MatMult,
    USub,
    UAdd,
    Invert,
    Not,
    BoolOp,
    And,
    Or,
    NamedExpr,
    Lambda,
    IfExp,
    Dict,
    Set,
    ListComp,
    SetComp,
    DictComp,
    GeneratorExp,
    comprehension,
    Await,
    Yield,
    YieldFrom,
    FormattedValue,
    JoinedStr,
    Interpolation,
    TemplateStr,
    Starred,
    List,
    Tuple,
    FunctionDef,
    AsyncFunctionDef,
    keyword,
    arguments,
    ClassDef,
    TypeAlias,
    For,
    AsyncFor,
    While,
    If,
    With,
    AsyncWith,
    Match,
    match_case,
    pattern,
    MatchValue,
    MatchSingleton,
    MatchAs,
    MatchOr,
    MatchSequence,
    MatchMapping,
    MatchClass,
    MatchStar,
    Raise,
    Try,
    TryStar,
    ExceptHandler,
    Assert,
    Import,
    ImportFrom,
    alias,
    Global,
    Nonlocal,
    Break,
    Continue,
}
import from compiler_ir {
    cloc,
    unverified_cfg,
    basicblock,
    cinstr,
    loc,
    no_loc,
    mk_instr,
    mk_jump,
    cfg_builder,
    stmt_cont,
    new_cfg_builder,
    loop_frame,
    except_region,
    comp_handler,
}

# Fold default expressions when every value is a Constant (CPython LOAD_CONST tuple).
def fold_default_values(defaults: list[expr]) -> list[PyObj] | None {
    items: list[PyObj] = [];
    di = 0;
    while di < len(defaults) {
        d = defaults[di];
        if not isinstance(d, Constant) {
            return None;
        }
        items.append((d as Constant).value);
        di = di + 1;
    }
    return items;
}

def args_have_kw_defaults(args: arguments) -> bool {
    ki = 0;
    while ki < len(args.kw_defaults) {
        if args.kw_defaults[ki] is not None {
            return True;
        }
        ki = ki + 1;
    }
    return False;
}

def function_argcounts(args: arguments) -> tuple[int, int, int] {
    posonly = len(args.posonlyargs);
    regular = len(args.args);
    kwonly = len(args.kwonlyargs);
    return (posonly + regular, posonly, kwonly);
}

def function_code_flags(args: arguments) -> int {
    flags = CO_OPTIMIZED | CO_NEWLOCALS;
    if args.vararg is not None {
        flags = flags | CO_VARARGS;
    }
    if args.kwarg is not None {
        flags = flags | CO_VARKEYWORDS;
    }
    return flags;
}

# AST class name for unsupported-node diagnostics (ordered isinstance chain).
def ast_node_name(n: ast_node) -> str {
    if isinstance(n, BoolOp) {
        return "BoolOp";
    }
    if isinstance(n, NamedExpr) {
        return "NamedExpr";
    }
    if isinstance(n, BinOp) {
        return "BinOp";
    }
    if isinstance(n, UnaryOp) {
        return "UnaryOp";
    }
    if isinstance(n, Lambda) {
        return "Lambda";
    }
    if isinstance(n, IfExp) {
        return "IfExp";
    }
    if isinstance(n, Dict) {
        return "Dict";
    }
    if isinstance(n, Set) {
        return "Set";
    }
    if isinstance(n, ListComp) {
        return "ListComp";
    }
    if isinstance(n, SetComp) {
        return "SetComp";
    }
    if isinstance(n, DictComp) {
        return "DictComp";
    }
    if isinstance(n, GeneratorExp) {
        return "GeneratorExp";
    }
    if isinstance(n, Await) {
        return "Await";
    }
    if isinstance(n, Yield) {
        return "Yield";
    }
    if isinstance(n, YieldFrom) {
        return "YieldFrom";
    }
    if isinstance(n, Compare) {
        return "Compare";
    }
    if isinstance(n, Call) {
        return "Call";
    }
    if isinstance(n, FormattedValue) {
        return "FormattedValue";
    }
    if isinstance(n, JoinedStr) {
        return "JoinedStr";
    }
    if isinstance(n, Interpolation) {
        return "Interpolation";
    }
    if isinstance(n, TemplateStr) {
        return "TemplateStr";
    }
    if isinstance(n, Constant) {
        return "Constant";
    }
    if isinstance(n, Attribute) {
        return "Attribute";
    }
    if isinstance(n, Subscript) {
        return "Subscript";
    }
    if isinstance(n, Starred) {
        return "Starred";
    }
    if isinstance(n, Name) {
        return "Name";
    }
    if isinstance(n, List) {
        return "List";
    }
    if isinstance(n, Tuple) {
        return "Tuple";
    }
    if isinstance(n, Slice) {
        return "Slice";
    }
    if isinstance(n, FunctionDef) {
        return "FunctionDef";
    }
    if isinstance(n, AsyncFunctionDef) {
        return "AsyncFunctionDef";
    }
    if isinstance(n, ClassDef) {
        return "ClassDef";
    }
    if isinstance(n, Return) {
        return "Return";
    }
    if isinstance(n, Delete) {
        return "Delete";
    }
    if isinstance(n, Assign) {
        return "Assign";
    }
    if isinstance(n, TypeAlias) {
        return "TypeAlias";
    }
    if isinstance(n, AugAssign) {
        return "AugAssign";
    }
    if isinstance(n, AnnAssign) {
        return "AnnAssign";
    }
    if isinstance(n, For) {
        return "For";
    }
    if isinstance(n, AsyncFor) {
        return "AsyncFor";
    }
    if isinstance(n, While) {
        return "While";
    }
    if isinstance(n, If) {
        return "If";
    }
    if isinstance(n, With) {
        return "With";
    }
    if isinstance(n, AsyncWith) {
        return "AsyncWith";
    }
    if isinstance(n, Match) {
        return "Match";
    }
    if isinstance(n, Raise) {
        return "Raise";
    }
    if isinstance(n, Try) {
        return "Try";
    }
    if isinstance(n, TryStar) {
        return "TryStar";
    }
    if isinstance(n, Assert) {
        return "Assert";
    }
    if isinstance(n, Import) {
        return "Import";
    }
    if isinstance(n, ImportFrom) {
        return "ImportFrom";
    }
    if isinstance(n, Global) {
        return "Global";
    }
    if isinstance(n, Nonlocal) {
        return "Nonlocal";
    }
    if isinstance(n, Expr) {
        return "Expr";
    }
    if isinstance(n, Pass) {
        return "Pass";
    }
    if isinstance(n, Break) {
        return "Break";
    }
    if isinstance(n, Continue) {
        return "Continue";
    }
    return "ast_node";
}

# Normalize an AST node's location: end_lineno is int|None; None means "same as
# lineno" (CPython's convention for single-line nodes).
def nloc(lineno: int, end_ln: int | None, col: int, end_col: int | None) -> cloc {
    el = lineno;
    if end_ln is not None {
        el = end_ln as int;
    }
    ec = -1;
    if end_col is not None {
        ec = end_col as int;
    }
    return loc(lineno, el, col, ec);
}

# CPython spans for `def`/`async def` run through the last body statement. The
# generated parser's end_tok can point past the block (wrong end_lineno/col).
def function_def_loc(fd: FunctionDef) -> cloc {
    last = fd.body[len(fd.body) - 1];
    end_ln = last.lineno;
    end_col = last.col_offset;
    if last.end_lineno is not None {
        end_ln = last.end_lineno;
    }
    if last.end_col_offset is not None {
        end_col = last.end_col_offset;
    }
    return nloc(fd.lineno, end_ln, fd.col_offset, end_col);
}

def async_function_def_loc(afd: AsyncFunctionDef) -> cloc {
    last = afd.body[len(afd.body) - 1];
    end_ln = last.lineno;
    end_col = last.col_offset;
    if last.end_lineno is not None {
        end_ln = last.end_lineno;
    }
    if last.end_col_offset is not None {
        end_col = last.end_col_offset;
    }
    return nloc(afd.lineno, end_ln, afd.col_offset, end_col);
}

# Operator AST node -> NB_* binary-op id (opcode.h).
def binop_id(op: PyObj) -> int {
    if isinstance(op, Add) {
        return NB_ADD;
    }
    if isinstance(op, Sub) {
        return NB_SUBTRACT;
    }
    if isinstance(op, Mult) {
        return NB_MULTIPLY;
    }
    if isinstance(op, Div) {
        return NB_TRUE_DIVIDE;
    }
    if isinstance(op, FloorDiv) {
        return NB_FLOOR_DIVIDE;
    }
    if isinstance(op, Mod) {
        return NB_REMAINDER;
    }
    if isinstance(op, Pow) {
        return NB_POWER;
    }
    if isinstance(op, LShift) {
        return NB_LSHIFT;
    }
    if isinstance(op, RShift) {
        return NB_RSHIFT;
    }
    if isinstance(op, BitOr) {
        return NB_OR;
    }
    if isinstance(op, BitXor) {
        return NB_XOR;
    }
    if isinstance(op, BitAnd) {
        return NB_AND;
    }
    if isinstance(op, MatMult) {
        return NB_MATRIX_MULTIPLY;
    }
    return -1;
}

# AugAssign operator -> NB_INPLACE_* id (opcode.h).
def inplace_binop_id(op: PyObj) -> int {
    if isinstance(op, Add) {
        return NB_INPLACE_ADD;
    }
    if isinstance(op, Sub) {
        return NB_INPLACE_SUBTRACT;
    }
    if isinstance(op, Mult) {
        return NB_INPLACE_MULTIPLY;
    }
    if isinstance(op, Div) {
        return NB_INPLACE_TRUE_DIVIDE;
    }
    if isinstance(op, FloorDiv) {
        return NB_INPLACE_FLOOR_DIVIDE;
    }
    if isinstance(op, Mod) {
        return NB_INPLACE_REMAINDER;
    }
    if isinstance(op, Pow) {
        return NB_INPLACE_POWER;
    }
    if isinstance(op, LShift) {
        return NB_INPLACE_LSHIFT;
    }
    if isinstance(op, RShift) {
        return NB_INPLACE_RSHIFT;
    }
    if isinstance(op, BitOr) {
        return NB_INPLACE_OR;
    }
    if isinstance(op, BitXor) {
        return NB_INPLACE_XOR;
    }
    if isinstance(op, BitAnd) {
        return NB_INPLACE_AND;
    }
    if isinstance(op, MatMult) {
        return NB_INPLACE_MATRIX_MULTIPLY;
    }
    return -1;
}

# Source span for an expression node (store/load/delete targets and calls).
def expr_loc(e: expr) -> cloc {
    if isinstance(e, Name) {
        n = e as Name;
        return nloc(n.lineno, n.end_lineno, n.col_offset, n.end_col_offset);
    }
    if isinstance(e, Attribute) {
        a = e as Attribute;
        return nloc(a.lineno, a.end_lineno, a.col_offset, a.end_col_offset);
    }
    if isinstance(e, Subscript) {
        s = e as Subscript;
        return nloc(s.lineno, s.end_lineno, s.col_offset, s.end_col_offset);
    }
    if isinstance(e, Constant) {
        c = e as Constant;
        return nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
    }
    if isinstance(e, BinOp) {
        b = e as BinOp;
        return nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
    }
    if isinstance(e, UnaryOp) {
        un = e as UnaryOp;
        return nloc(un.lineno, un.end_lineno, un.col_offset, un.end_col_offset);
    }
    if isinstance(e, Call) {
        ca = e as Call;
        return nloc(ca.lineno, ca.end_lineno, ca.col_offset, ca.end_col_offset);
    }
    if isinstance(e, Compare) {
        c = e as Compare;
        return nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
    }
    if isinstance(e, ListComp) {
        lc = e as ListComp;
        return nloc(lc.lineno, lc.end_lineno, lc.col_offset, lc.end_col_offset);
    }
    if isinstance(e, SetComp) {
        sc = e as SetComp;
        return nloc(sc.lineno, sc.end_lineno, sc.col_offset, sc.end_col_offset);
    }
    if isinstance(e, DictComp) {
        dc = e as DictComp;
        return nloc(dc.lineno, dc.end_lineno, dc.col_offset, dc.end_col_offset);
    }
    if isinstance(e, Tuple) {
        t = e as Tuple;
        return nloc(t.lineno, t.end_lineno, t.col_offset, t.end_col_offset);
    }
    if isinstance(e, List) {
        l = e as List;
        return nloc(l.lineno, l.end_lineno, l.col_offset, l.end_col_offset);
    }
    return loc(1, 1, 0, 0);
}

# Fold a constant Slice AST node into a PySlice const, or None if non-constant.
def fold_slice_const(sl: Slice) -> PyObj | None {
    lo: PyObj = py_none();
    if sl.lower is not None {
        if not isinstance(sl.lower, Constant) {
            return None;
        }
        lo = (sl.lower as Constant).value;
    }
    up: PyObj = py_none();
    if sl.upper is not None {
        if not isinstance(sl.upper, Constant) {
            return None;
        }
        up = (sl.upper as Constant).value;
    }
    st: PyObj = py_none();
    if sl.step is not None {
        if not isinstance(sl.step, Constant) {
            return None;
        }
        st = (sl.step as Constant).value;
    }
    return PySlice(t="slice", start=lo, stop=up, step=st);
}

# UnaryOp AST node -> opcode (None if the operator maps to no instruction in
# this slice; the caller reports it loudly).
def unary_opcode(op: PyObj) -> int {
    if isinstance(op, USub) {
        return OP_UNARY_NEGATIVE;
    }
    if isinstance(op, Invert) {
        return OP_UNARY_INVERT;
    }
    if isinstance(op, Not) {
        return OP_UNARY_NOT;
    }
    return -1;
}

# cmpop AST node -> CMP_* rich-compare kind (cmp_op tuple order).
def ast_cmp_kind(op: PyObj) -> int {
    if isinstance(op, Lt) {
        return CMP_LT;
    }
    if isinstance(op, LtE) {
        return CMP_LE;
    }
    if isinstance(op, Eq) {
        return CMP_EQ;
    }
    if isinstance(op, NotEq) {
        return CMP_NE;
    }
    if isinstance(op, Gt) {
        return CMP_GT;
    }
    if isinstance(op, GtE) {
        return CMP_GE;
    }
    return -1;
}

# cmpop -> CPython 3.14 COMPARE_OP oparg (low bits carry cache metadata).
def cmpop_oparg(op: PyObj) -> int {
    kind = ast_cmp_kind(op);
    if kind < 0 {
        return -1;
    }
    return compare_oparg(kind);
}

# Comprehension filters use bool-context compare opargs (base | 16).
def cmpop_filter_oparg(op: PyObj) -> int {
    kind = ast_cmp_kind(op);
    if kind < 0 {
        return -1;
    }
    return compare_filter_oparg(kind);
}

# Constant-fold a BinOp when both operands are literal ints (CPython peephole).
def try_fold_binop(left: expr, op: PyObj, right: expr) -> PyObj | None {
    if not isinstance(left, Constant) {
        return None;
    }
    if not isinstance(right, Constant) {
        return None;
    }
    lc = left as Constant;
    rc = right as Constant;
    if not isinstance(lc.value, PyInt) {
        return None;
    }
    if not isinstance(rc.value, PyInt) {
        return None;
    }
    lv = (lc.value as PyInt).val;
    rv = (rc.value as PyInt).val;
    if isinstance(op, Add) {
        return PyInt(t="int", val=lv + rv);
    }
    return None;
}

# The callable's location, used for PUSH_NULL. For the slice the callable is a
# Name; this stays general for future Attribute/method lowering.
def call_func_loc(f: expr) -> cloc {
    return expr_loc(f);
}

def call_effective_args(ca: Call) -> list[expr] {
    args = ca.args;
    if args is None {
        args = [];
    }
    return args;
}

def call_effective_keywords(ca: Call) -> list[keyword] {
    kws = ca.keywords;
    if kws is None {
        kws = [];
    }
    return kws;
}

# The top-level expression's location, assigned to the trailing RETURN_VALUE in
# eval mode (matches CPython's observed co_positions).
def top_loc(e: expr) -> cloc {
    return expr_loc(e);
}

def stmt_loc(s: stmt) -> cloc {
    if isinstance(s, Assign) {
        a = s as Assign;
        # CPython attributes STORE_NAME to the assignment target's span, not the
        # whole Assign. For band 2 the target is a single Name.
        if len(a.targets) > 0 {
            return expr_loc(a.targets[0]);
        }
        return nloc(a.lineno, a.end_lineno, a.col_offset, a.end_col_offset);
    }
    if isinstance(s, AugAssign) {
        aa = s as AugAssign;
        return expr_loc(aa.target);
    }
    if isinstance(s, Delete) {
        d = s as Delete;
        return nloc(d.lineno, d.end_lineno, d.col_offset, d.end_col_offset);
    }
    if isinstance(s, Return) {
        r = s as Return;
        return nloc(r.lineno, r.end_lineno, r.col_offset, r.end_col_offset);
    }
    if isinstance(s, Expr) {
        x = s as Expr;
        return nloc(x.lineno, x.end_lineno, x.col_offset, x.end_col_offset);
    }
    if isinstance(s, Pass) {
        p = s as Pass;
        return nloc(p.lineno, p.end_lineno, p.col_offset, p.end_col_offset);
    }
    if isinstance(s, If) {
        i = s as If;
        return nloc(i.lineno, i.end_lineno, i.col_offset, i.end_col_offset);
    }
    if isinstance(s, While) {
        w = s as While;
        return nloc(w.lineno, w.end_lineno, w.col_offset, w.end_col_offset);
    }
    if isinstance(s, For) {
        f = s as For;
        return nloc(f.lineno, f.end_lineno, f.col_offset, f.end_col_offset);
    }
    if isinstance(s, Break) {
        b = s as Break;
        return nloc(b.lineno, b.end_lineno, b.col_offset, b.end_col_offset);
    }
    if isinstance(s, Continue) {
        c = s as Continue;
        return nloc(c.lineno, c.end_lineno, c.col_offset, c.end_col_offset);
    }
    if isinstance(s, Try) {
        tr = s as Try;
        return nloc(tr.lineno, tr.end_lineno, tr.col_offset, tr.end_col_offset);
    }
    return loc(1, 1, 0, 0);
}

# Elements of a Tuple or List target/value node.
def seq_target_elts(e: expr) -> list[expr] {
    if isinstance(e, Tuple) {
        return (e as Tuple).elts;
    }
    return (e as List).elts;
}

def is_seq_literal(e: expr) -> bool {
    return isinstance(e, Tuple) or isinstance(e, List);
}

# Whether any display element is a Starred unpack.
def display_has_starred(elts: list[expr]) -> bool {
    i = 0;
    while i < len(elts) {
        if isinstance(elts[i], Starred) {
            return True;
        }
        i = i + 1;
    }
    return False;
}

# Whether every display element is a compile-time Constant (empty => True).
def display_all_constant(elts: list[expr]) -> bool {
    i = 0;
    while i < len(elts) {
        if not isinstance(elts[i], Constant) {
            return False;
        }
        i = i + 1;
    }
    return True;
}

# Extract the constant PyObj values from an all-constant display.
def display_const_items(elts: list[expr]) -> list[PyObj] {
    items: list[PyObj] = [];
    i = 0;
    while i < len(elts) {
        items.append((elts[i] as Constant).value);
        i = i + 1;
    }
    return items;
}

# Index of the first Starred element in a target list, or -1 if none.
def starred_target_index(elts: list[expr]) -> int {
    i = 0;
    while i < len(elts) {
        if isinstance(elts[i], Starred) {
            return i;
        }
        i = i + 1;
    }
    return -1;
}

# True when any statement from from_idx onward emits bytecode (Pass alone does not).
def exec_tail_emits_code(body: list[stmt], from_idx: int) -> bool {
    si = from_idx;
    while si < len(body) {
        if not isinstance(body[si], Pass) {
            return True;
        }
        si = si + 1;
    }
    return False;
}

def comp_name_bound(name: str, bound_names: list[str]) -> bool {
    bi = 0;
    while bi < len(bound_names) {
        if bound_names[bi] == name {
            return True;
        }
        bi = bi + 1;
    }
    return False;
}

def comp_bound_names_from_target(target: expr) -> list[str] | None {
    if isinstance(target, Name) {
        return [(target as Name).id];
    }
    if isinstance(target, Tuple) {
        elts = (target as Tuple).elts;
        if len(elts) != 2 {
            return None;
        }
        if not isinstance(elts[0], Name) or not isinstance(elts[1], Name) {
            return None;
        }
        return [(elts[0] as Name).id, (elts[1] as Name).id];
    }
    return None;
}

# Leftmost sub-expression in CPython evaluation order (the first leaf pushed).
def comp_leftmost_leaf(e: expr) -> expr {
    cur = e;
    while True {
        if isinstance(cur, BinOp) {
            cur = (cur as BinOp).left;
        } elif isinstance(cur, Compare) {
            cur = (cur as Compare).left;
        } elif isinstance(cur, UnaryOp) {
            cur = (cur as UnaryOp).operand;
        } elif isinstance(cur, BoolOp) {
            vals = (cur as BoolOp).values;
            if len(vals) == 0 {
                return cur;
            }
            cur = vals[0];
        } elif isinstance(cur, Call) {
            cur = (cur as Call).func;
        } elif isinstance(cur, Attribute) {
            cur = (cur as Attribute).value;
        } elif isinstance(cur, Subscript) {
            cur = (cur as Subscript).value;
        } elif isinstance(cur, Tuple) {
            elts = (cur as Tuple).elts;
            if len(elts) == 0 {
                return cur;
            }
            cur = elts[0];
        } elif isinstance(cur, List) {
            elts2 = (cur as List).elts;
            if len(elts2) == 0 {
                return cur;
            }
            cur = elts2[0];
        } else {
            return cur;
        }
    }
    return cur;
}

def comp_dict_map_loc(dc: DictComp) -> cloc {
    return nloc(
        dc.key.lineno, dc.value.end_lineno, dc.key.col_offset, dc.value.end_col_offset
    );
}

def try_handler_span(h: ExceptHandler) -> cloc {
    el = h.end_lineno;
    if el is None {
        el = h.lineno;
    }
    ec = h.end_col_offset;
    if ec is None {
        ec = h.col_offset;
    }
    return nloc(h.lineno, el, h.col_offset, ec);
}

# True when `body` is a single try/finally-only statement (no except on inner).
def body_is_try_finally_only(body: list[stmt]) -> bool {
    if len(body) != 1 {
        return False;
    }
    if not isinstance(body[0], Try) {
        return False;
    }
    inner = body[0] as Try;
    if inner.finalbody is None or len(inner.finalbody) == 0 {
        return False;
    }
    if inner.handlers is not None and len(inner.handlers) > 0 {
        return False;
    }
    return True;
}

# Single try/except statement (no finally) as the whole body of an outer try.
# The nested try publishes its last block so the outer body span starts after
# the inner regions instead of overlapping them.
def body_is_try_except_only(body: list[stmt]) -> bool {
    if len(body) != 1 {
        return False;
    }
    if not isinstance(body[0], Try) {
        return False;
    }
    inner = body[0] as Try;
    if inner.handlers is None or len(inner.handlers) == 0 {
        return False;
    }
    if inner.finalbody is not None and len(inner.finalbody) > 0 {
        return False;
    }
    return True;
}

def match_pattern_loc(p: pattern) -> cloc {
    return nloc(p.lineno, p.end_lineno, p.col_offset, p.end_col_offset);
}

def match_pattern_unwrap_or(p: pattern) -> pattern {
    if isinstance(p, MatchOr) {
        mo = p as MatchOr;
        if len(mo.patterns) == 1 {
            return mo.patterns[0];
        }
    }
    return p;
}

def match_pattern_wildcard(p: pattern) -> bool {
    p = match_pattern_unwrap_or(p);
    if not isinstance(p, MatchAs) {
        return False;
    }
    ma = p as MatchAs;
    return ma.pattern is None and ma.name is None;
}

def loop_body_has_break(stmts: list[stmt]) -> bool {
    si = 0;
    while si < len(stmts) {
        s = stmts[si];
        if isinstance(s, Break) {
            return True;
        }
        if isinstance(s, If) {
            iff = s as If;
            if loop_body_has_break(iff.body) {
                return True;
            }
            if loop_body_has_break(iff.orelse) {
                return True;
            }
        }
        si = si + 1;
    }
    return False;
}

# Module-local name bound by `import` / `from ... import`.
def import_bind_name(a: alias) -> str {
    if a.asname is not None {
        return a.asname;
    }
    parts = a.name.split(".");
    return parts[0];
}

def class_effective_bases(cd: ClassDef) -> list[expr] {
    bases = cd.bases;
    if bases is None {
        bases = [];
    }
    return bases;
}

def class_effective_keywords(cd: ClassDef) -> list[keyword] {
    kws = cd.keywords;
    if kws is None {
        kws = [];
    }
    return kws;
}
