# Symbol table for the P4 front track (INTEGRATION_PLAN Phase 5).
#
# Two-pass scope analysis over validated AST: raw def/use collection, then
# LOCAL/GLOBAL/FREE/CELL classification matching CPython 3.14 symtable.c.
# Codegen consumes sym_facts; product_compile runs this after validation.

import from ast_nodes {
    Module,
    expr,
    stmt,
    Name,
    Attribute,
    Subscript,
    Slice,
    Tuple,
    List,
    Starred,
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
    Delete,
    Raise,
    Assert,
    Global,
    Nonlocal,
    For,
    While,
    If,
    Try,
    With,
    FunctionDef,
    ClassDef,
    AsyncFunctionDef,
    AsyncFor,
    AsyncWith,
    Set,
    Dict,
    ListComp,
    SetComp,
    DictComp,
    GeneratorExp,
    Lambda,
    comprehension,
    Yield,
    YieldFrom,
    Await,
    Import,
    ImportFrom,
    alias,
    Load,
    Store,
    Del,
    arg,
    arguments,
    Match,
    match_case,
    pattern,
    MatchValue,
    MatchSingleton,
    MatchAs,
    MatchOr,
    MatchSequence,
    MatchStar,
    MatchMapping,
    MatchClass,
}
import from compiler_diagnostics {
    symbol_diagnostic,
    compiler_diagnostic,
    compiler_diag_kind,
    compiler_diag_message
}

# CPython symtable flag bits (Include/internal/pycore_symtable.h).
glob DEF_GLOBAL: int = 1,
     DEF_LOCAL: int = 2,
     DEF_PARAM: int = 4,
     DEF_NONLOCAL: int = 8,
     SYM_USE: int = 16,
     DEF_BOUND: int = 70,
     DEF_COMP_ITER: int = 512,
     SCOPE_OFFSET: int = 12,
     SCOPE_LOCAL: int = 1,
     SCOPE_GLOBAL_EXPLICIT: int = 2,
     SCOPE_GLOBAL_IMPLICIT: int = 3,
     SCOPE_FREE: int = 4,
     SCOPE_CELL: int = 5;

obj sym_block {
    has block_type: str,
        name: str,
        lineno: int,
        col_offset: int = -1,
        nested: bool = False,
        generator: bool = False,
        coroutine: bool = False,
        can_see_class_scope: bool = False,
        comprehension: str | None = None,
        symbols: dict[str, int] = {},
        varnames: list[str] = [],
        local_varnames: list[str] = [],
        directive_lineno: dict[str, int] = {},
        directive_col: dict[str, int] = {},
        children: list[sym_block] = [];
}

obj symtable_result {
    has top: sym_block | None = None,
        diag: compiler_diagnostic | None = None;
}

def symtable_ok(top: sym_block) -> symtable_result {
    return symtable_result(top=top);
}

def symtable_error(
    kind: str, message: str, lineno: int = -1, col_offset: int = -1
) -> symtable_result {
    return symtable_result(
        diag=symbol_diagnostic(
            kind=kind, message=message, lineno=lineno, col_offset=col_offset
        )
    );
}

def sym_flag_set(flags: int, bit: int) -> bool {
    return (flags & bit) != 0;
}

def sym_flag_add(flags: int, bit: int) -> int {
    return flags | bit;
}

def sym_scope_of(flags: int) -> int {
    return (flags >> SCOPE_OFFSET) & 31;
}

def sym_set_scope(flags: int, scope: int) -> int {
    cleared = flags & ((1 << SCOPE_OFFSET) - 1);
    return cleared | (scope << SCOPE_OFFSET);
}

def sym_dict_get(d: dict[str, int], key: str, fallback: int = 0) -> int {
    if key in d {
        return d[key];
    }
    return fallback;
}

def sym_set_add(s: dict[str, int], name: str) {
    s[name] = 1;
}

def sym_set_contains(s: dict[str, int], name: str) -> bool {
    return name in s;
}

def sym_set_keys(s: dict[str, int]) -> list[str] {
    return list(s.keys());
}

def sym_set_union(a: dict[str, int], b: dict[str, int]) -> dict[str, int] {
    out: dict[str, int] = {};
    for k in a.keys() {
        out[k] = 1;
    }
    for k in b.keys() {
        out[k] = 1;
    }
    return out;
}

def sym_set_discard(s: dict[str, int], name: str) {
    if name in s {
        del s[name];
    }
}

def sym_sorted_names(d: dict[str, int]) -> list[str] {
    return sorted(list(d.keys()));
}

def mangle_name(private: str | None, name: str) -> str {
    if private is None {
        return name;
    }
    if len(name) < 2 {
        return name;
    }
    if name[0] != "_" or name[1] != "_" {
        return name;
    }
    if len(name) > 2 and name[2] == "_" {
        return name;
    }
    return "_" + private + name;
}

obj sym_builder {
    has cur: sym_block,
        stack: list[sym_block],
        module_global: dict[str, int] = {},
        private: str | None = None,
        diag: compiler_diagnostic | None = None;

    def fail(kind: str, message: str, lineno: int = -1, col_offset: int = -1) -> bool {
        if self.diag is None {
            self.diag = symbol_diagnostic(
                kind=kind, message=message, lineno=lineno, col_offset=col_offset
            );
        }
        return False;
    }

    def lookup(name: str) -> int {
        return sym_dict_get(self.cur.symbols, name, 0);
    }

    def add_def(name: str, flags: int, lineno: int, col_offset: int) -> bool {
        mangled = mangle_name(self.private, name);
        cur_flags = self.lookup(mangled);
        if sym_flag_set(cur_flags, DEF_PARAM) and sym_flag_set(flags, DEF_GLOBAL) {
            return self.fail(
                "SyntaxError",
                "name '" + name + "' is parameter and global",
                lineno,
                col_offset
            );
        }
        if sym_flag_set(cur_flags, DEF_PARAM) and sym_flag_set(flags, DEF_NONLOCAL) {
            return self.fail(
                "SyntaxError",
                "name '" + name + "' is parameter and nonlocal",
                lineno,
                col_offset
            );
        }
        self.cur.symbols[mangled] = sym_flag_add(cur_flags, flags);
        if sym_flag_set(flags, DEF_GLOBAL) or sym_flag_set(flags, DEF_NONLOCAL) {
            self.cur.directive_lineno[mangled] = lineno;
            self.cur.directive_col[mangled] = col_offset;
        }
        if self.cur.block_type == "module" {
            self.module_global[mangled] = self.cur.symbols[mangled];
        }
        if sym_flag_set(flags, DEF_PARAM) {
            self.cur.varnames.append(mangled);
        } elif self.cur.block_type == "function" and sym_flag_set(flags, DEF_LOCAL) {
            if not sym_flag_set(cur_flags, DEF_LOCAL)
                and not sym_flag_set(cur_flags, DEF_PARAM) {
                self.cur.local_varnames.append(mangled);
            }
        }
        return True;
    }

    def add_use(name: str) -> bool {
        mangled = mangle_name(self.private, name);
        cur_flags = self.lookup(mangled);
        self.cur.symbols[mangled] = sym_flag_add(cur_flags, SYM_USE);
        return True;
    }

    def push_block(
        block_type: str,
        name: str,
        lineno: int,
        nested: bool,
        can_see_class_scope: bool = False,
        col_offset: int = -1
    ) -> bool {
        child = sym_block(
            block_type=block_type,
            name=name,
            lineno=lineno,
            col_offset=col_offset,
            nested=nested,
            can_see_class_scope=can_see_class_scope
        );
        self.cur.children.append(child);
        self.stack.append(self.cur);
        self.cur = child;
        return True;
    }

    def pop_block -> bool {
        if len(self.stack) == 0 {
            return False;
        }
        self.cur = self.stack.pop();
        return True;
    }
}

def sym_visit_comprehension_generators(
    b: sym_builder, generators: list[comprehension]
) -> bool {
    if len(generators) == 0 {
        return True;
    }
    outer = generators[0];
    if not sym_visit_load_expr(b, outer.iter) {
        return False;
    }
    gi = 0;
    while gi < len(generators) {
        g = generators[gi];
        if gi > 0 {
            if not sym_visit_load_expr(b, g.iter) {
                return False;
            }
        }
        if not sym_visit_comp_store_target(b, g.target) {
            return False;
        }
        fi = 0;
        while fi < len(g.ifs) {
            if not sym_visit_load_expr(b, g.ifs[fi]) {
                return False;
            }
            fi = fi + 1;
        }
        gi = gi + 1;
    }
    return True;
}

def sym_visit_inline_comprehension(
    b: sym_builder, generators: list[comprehension], elt: expr, value: expr | None
) -> bool {
    if not sym_visit_comprehension_generators(b, generators) {
        return False;
    }
    if value is not None and not sym_visit_load_expr(b, value) {
        return False;
    }
    return sym_visit_load_expr(b, elt);
}

def sym_visit_genexp(b: sym_builder, e: GeneratorExp) -> bool {
    if len(e.generators) == 0 {
        return True;
    }
    outer = e.generators[0];
    if not sym_visit_load_expr(b, outer.iter) {
        return False;
    }
    nested = sym_compute_nested(b);
    in_class = b.cur.block_type == "class" or b.cur.can_see_class_scope;
    if not b.push_block("function", "genexpr", e.lineno, nested, in_class) {
        return False;
    }
    b.cur.comprehension = "gen";
    dot0 = arg(
        arg=".0",
        annotation=None,
        type_comment=None,
        lineno=e.lineno,
        col_offset=e.col_offset,
        end_lineno=e.end_lineno,
        end_col_offset=e.end_col_offset
    );
    if not b.add_def(".0", DEF_PARAM, dot0.lineno, dot0.col_offset) {
        return False;
    }
    if not sym_visit_store_target(b, outer.target) {
        return False;
    }
    fi = 0;
    while fi < len(outer.ifs) {
        if not sym_visit_load_expr(b, outer.ifs[fi]) {
            return False;
        }
        fi = fi + 1;
    }
    gi = 1;
    while gi < len(e.generators) {
        g = e.generators[gi];
        if not sym_visit_load_expr(b, g.iter) {
            return False;
        }
        if not sym_visit_store_target(b, g.target) {
            return False;
        }
        fj = 0;
        while fj < len(g.ifs) {
            if not sym_visit_load_expr(b, g.ifs[fj]) {
                return False;
            }
            fj = fj + 1;
        }
        gi = gi + 1;
    }
    if not sym_visit_load_expr(b, e.elt) {
        return False;
    }
    b.cur.generator = True;
    return b.pop_block();
}

def sym_visit_load_expr(b: sym_builder, e: expr) -> bool {
    if b.diag is not None {
        return False;
    }
    if isinstance(e, Name) {
        return b.add_use((e as Name).id);
    }
    if isinstance(e, Attribute) {
        return sym_visit_load_expr(b, (e as Attribute).value);
    }
    if isinstance(e, Subscript) {
        s = e as Subscript;
        if not sym_visit_load_expr(b, s.value) {
            return False;
        }
        return sym_visit_load_expr(b, s.slice);
    }
    if isinstance(e, Slice) {
        sl = e as Slice;
        if sl.lower is not None and not sym_visit_load_expr(b, sl.lower) {
            return False;
        }
        if sl.upper is not None and not sym_visit_load_expr(b, sl.upper) {
            return False;
        }
        if sl.step is not None and not sym_visit_load_expr(b, sl.step) {
            return False;
        }
        return True;
    }
    if isinstance(e, BinOp) {
        bo = e as BinOp;
        if not sym_visit_load_expr(b, bo.left) {
            return False;
        }
        return sym_visit_load_expr(b, bo.right);
    }
    if isinstance(e, UnaryOp) {
        return sym_visit_load_expr(b, (e as UnaryOp).operand);
    }
    if isinstance(e, Compare) {
        c = e as Compare;
        if not sym_visit_load_expr(b, c.left) {
            return False;
        }
        ci = 0;
        while ci < len(c.comparators) {
            if not sym_visit_load_expr(b, c.comparators[ci]) {
                return False;
            }
            ci = ci + 1;
        }
        return True;
    }
    if isinstance(e, Call) {
        ca = e as Call;
        if not sym_visit_load_expr(b, ca.func) {
            return False;
        }
        call_args = ca.args;
        if call_args is None {
            call_args = [];
        }
        ai = 0;
        while ai < len(call_args) {
            if not sym_visit_load_expr(b, call_args[ai]) {
                return False;
            }
            ai = ai + 1;
        }
        return True;
    }
    if isinstance(e, BoolOp) {
        bop = e as BoolOp;
        vi = 0;
        while vi < len(bop.values) {
            if not sym_visit_load_expr(b, bop.values[vi]) {
                return False;
            }
            vi = vi + 1;
        }
        return True;
    }
    if isinstance(e, Tuple) or isinstance(e, List) {
        elts: list[expr];
        if isinstance(e, Tuple) {
            elts = (e as Tuple).elts;
        } else {
            le = (e as List).elts;
            elts = le if le is not None else [];
        }
        ei = 0;
        while ei < len(elts) {
            if not sym_visit_load_expr(b, elts[ei]) {
                return False;
            }
            ei = ei + 1;
        }
        return True;
    }
    if isinstance(e, Starred) {
        return sym_visit_load_expr(b, (e as Starred).value);
    }
    if isinstance(e, Set) {
        selts = (e as Set).elts;
        si = 0;
        while si < len(selts) {
            if not sym_visit_load_expr(b, selts[si]) {
                return False;
            }
            si = si + 1;
        }
        return True;
    }
    if isinstance(e, Dict) {
        d = e as Dict;
        di = 0;
        while di < len(d.keys) {
            k = d.keys[di];
            if k is not None {
                if not sym_visit_load_expr(b, k) {
                    return False;
                }
            }
            if not sym_visit_load_expr(b, d.values[di]) {
                return False;
            }
            di = di + 1;
        }
        return True;
    }
    if isinstance(e, ListComp) {
        lc = e as ListComp;
        return sym_visit_inline_comprehension(b, lc.generators, lc.elt, None);
    }
    if isinstance(e, SetComp) {
        sc = e as SetComp;
        return sym_visit_inline_comprehension(b, sc.generators, sc.elt, None);
    }
    if isinstance(e, DictComp) {
        dc = e as DictComp;
        if not sym_visit_inline_comprehension(b, dc.generators, dc.key, dc.value) {
            return False;
        }
        return True;
    }
    if isinstance(e, GeneratorExp) {
        return sym_visit_genexp(b, e as GeneratorExp);
    }
    if isinstance(e, Lambda) {
        lam = e as Lambda;
        if not sym_visit_arg_defaults(b, lam.args) {
            return False;
        }
        nested = sym_compute_nested(b);
        in_class = b.cur.block_type == "class" or b.cur.can_see_class_scope;
        if not b.push_block(
            "function", "lambda", lam.lineno, nested, in_class, lam.col_offset
        ) {
            return False;
        }
        if not sym_visit_params(b, lam.args) {
            return False;
        }
        if not sym_visit_load_expr(b, lam.body) {
            return False;
        }
        return b.pop_block();
    }
    if isinstance(e, Yield) {
        b.cur.generator = True;
        y = e as Yield;
        if y.value is not None {
            return sym_visit_load_expr(b, y.value);
        }
        return True;
    }
    if isinstance(e, YieldFrom) {
        b.cur.generator = True;
        return sym_visit_load_expr(b, (e as YieldFrom).value);
    }
    if isinstance(e, Await) {
        return sym_visit_load_expr(b, (e as Await).value);
    }
    return True;
}

def sym_visit_store_target(b: sym_builder, t: expr) -> bool {
    if b.diag is not None {
        return False;
    }
    if isinstance(t, Name) {
        n = t as Name;
        return b.add_def(n.id, DEF_LOCAL, n.lineno, n.col_offset);
    }
    if isinstance(t, Attribute) {
        return sym_visit_load_expr(b, (t as Attribute).value);
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        if not sym_visit_load_expr(b, s.value) {
            return False;
        }
        return sym_visit_load_expr(b, s.slice);
    }
    if isinstance(t, Tuple) or isinstance(t, List) {
        elts: list[expr];
        if isinstance(t, Tuple) {
            elts = (t as Tuple).elts;
        } else {
            le = (t as List).elts;
            elts = le if le is not None else [];
        }
        ei = 0;
        while ei < len(elts) {
            if not sym_visit_store_target(b, elts[ei]) {
                return False;
            }
            ei = ei + 1;
        }
        return True;
    }
    if isinstance(t, Starred) {
        return sym_visit_store_target(b, (t as Starred).value);
    }
    return True;
}

def sym_visit_comp_store_target(b: sym_builder, t: expr) -> bool {
    if b.diag is not None {
        return False;
    }
    if isinstance(t, Tuple) {
        elts = (t as Tuple).elts;
        ei = 0;
        while ei < len(elts) {
            if not sym_visit_comp_store_target(b, elts[ei]) {
                return False;
            }
            ei = ei + 1;
        }
        return True;
    }
    if isinstance(t, Name) {
        n = t as Name;
        flags = DEF_LOCAL;
        if b.cur.block_type == "module" {
            flags = DEF_LOCAL | DEF_COMP_ITER;
        }
        return b.add_def(n.id, flags, n.lineno, n.col_offset);
    }
    return sym_visit_store_target(b, t);
}

def sym_visit_delete_target(b: sym_builder, t: expr) -> bool {
    if b.diag is not None {
        return False;
    }
    if isinstance(t, Name) {
        return b.add_use((t as Name).id);
    }
    if isinstance(t, Attribute) {
        return sym_visit_load_expr(b, (t as Attribute).value);
    }
    if isinstance(t, Subscript) {
        s = t as Subscript;
        if not sym_visit_load_expr(b, s.value) {
            return False;
        }
        return sym_visit_load_expr(b, s.slice);
    }
    return True;
}

# Default expressions are evaluated in the enclosing scope at definition time.
def sym_visit_arg_defaults(b: sym_builder, args: arguments) -> bool {
    di = 0;
    while di < len(args.defaults) {
        if not sym_visit_load_expr(b, args.defaults[di]) {
            return False;
        }
        di = di + 1;
    }
    ki = 0;
    while ki < len(args.kw_defaults) {
        kd = args.kw_defaults[ki];
        if kd is not None {
            if not sym_visit_load_expr(b, kd) {
                return False;
            }
        }
        ki = ki + 1;
    }
    return True;
}

def sym_visit_params(b: sym_builder, args: arguments) -> bool {
    pi = 0;
    while pi < len(args.posonlyargs) {
        a = args.posonlyargs[pi];
        if not b.add_def(a.arg, DEF_PARAM, a.lineno, a.col_offset) {
            return False;
        }
        pi = pi + 1;
    }
    pi = 0;
    while pi < len(args.args) {
        a = args.args[pi];
        if not b.add_def(a.arg, DEF_PARAM, a.lineno, a.col_offset) {
            return False;
        }
        pi = pi + 1;
    }
    pi = 0;
    while pi < len(args.kwonlyargs) {
        a = args.kwonlyargs[pi];
        if not b.add_def(a.arg, DEF_PARAM, a.lineno, a.col_offset) {
            return False;
        }
        pi = pi + 1;
    }
    if args.vararg is not None {
        va = args.vararg as arg;
        if not b.add_def(va.arg, DEF_PARAM, va.lineno, va.col_offset) {
            return False;
        }
    }
    if args.kwarg is not None {
        ka = args.kwarg as arg;
        if not b.add_def(ka.arg, DEF_PARAM, ka.lineno, ka.col_offset) {
            return False;
        }
    }
    return True;
}

def sym_is_function_like(block: sym_block) -> bool {
    return block.block_type == "function";
}

def sym_compute_nested(b: sym_builder) -> bool {
    if b.cur.block_type == "module" {
        return False;
    }
    if sym_is_function_like(b.cur) {
        return True;
    }
    if b.cur.nested {
        return True;
    }
    return False;
}

def sym_import_bind_name(a: alias) -> str {
    if a.asname is not None {
        return a.asname;
    }
    parts = a.name.split(".");
    return parts[0];
}

def sym_visit_pattern(b: sym_builder, p: pattern) -> bool {
    if b.diag is not None {
        return False;
    }
    p = sym_match_pattern_unwrap_or(p);
    if isinstance(p, MatchValue) {
        return sym_visit_load_expr(b, (p as MatchValue).value);
    }
    if isinstance(p, MatchSingleton) {
        return True;
    }
    if isinstance(p, MatchSequence) {
        ms = p as MatchSequence;
        pi = 0;
        while pi < len(ms.patterns) {
            if not sym_visit_pattern(b, ms.patterns[pi]) {
                return False;
            }
            pi = pi + 1;
        }
        return True;
    }
    if isinstance(p, MatchStar) {
        mst = p as MatchStar;
        if mst.name is not None and mst.name != "_" {
            if not b.add_def(mst.name, DEF_LOCAL, mst.lineno, mst.col_offset) {
                return False;
            }
        }
        return True;
    }
    if isinstance(p, MatchOr) {
        mo = p as MatchOr;
        pi = 0;
        while pi < len(mo.patterns) {
            if not sym_visit_pattern(b, mo.patterns[pi]) {
                return False;
            }
            pi = pi + 1;
        }
        return True;
    }
    if isinstance(p, MatchAs) {
        ma = p as MatchAs;
        if ma.pattern is not None {
            if not sym_visit_pattern(b, ma.pattern) {
                return False;
            }
        }
        if ma.name is not None and ma.name != "_" {
            if not b.add_def(ma.name, DEF_LOCAL, ma.lineno, ma.col_offset) {
                return False;
            }
        }
        return True;
    }
    if isinstance(p, MatchMapping) {
        mm = p as MatchMapping;
        if mm.keys is not None {
            ki = 0;
            while ki < len(mm.keys) {
                if not sym_visit_load_expr(b, mm.keys[ki]) {
                    return False;
                }
                ki = ki + 1;
            }
        }
        if mm.patterns is not None {
            pi = 0;
            while pi < len(mm.patterns) {
                if not sym_visit_pattern(b, mm.patterns[pi]) {
                    return False;
                }
                pi = pi + 1;
            }
        }
        if mm.rest is not None and mm.rest != "_" {
            if not b.add_def(mm.rest, DEF_LOCAL, mm.lineno, mm.col_offset) {
                return False;
            }
        }
        return True;
    }
    if isinstance(p, MatchClass) {
        mc = p as MatchClass;
        if not sym_visit_load_expr(b, mc.cls) {
            return False;
        }
        if mc.patterns is not None {
            pi = 0;
            while pi < len(mc.patterns) {
                if not sym_visit_pattern(b, mc.patterns[pi]) {
                    return False;
                }
                pi = pi + 1;
            }
        }
        if mc.kwd_patterns is not None {
            ki = 0;
            while ki < len(mc.kwd_patterns) {
                if not sym_visit_pattern(b, mc.kwd_patterns[ki]) {
                    return False;
                }
                ki = ki + 1;
            }
        }
        return True;
    }
    return b.fail(
        "NotImplementedError", "unsupported match pattern", p.lineno, p.col_offset
    );
}

def sym_match_pattern_unwrap_or(p: pattern) -> pattern {
    if isinstance(p, MatchOr) {
        mo = p as MatchOr;
        if len(mo.patterns) == 1 {
            return mo.patterns[0];
        }
    }
    return p;
}

def sym_visit_stmt(b: sym_builder, s: stmt) -> bool {
    if b.diag is not None {
        return False;
    }
    if isinstance(s, Assign) {
        a = s as Assign;
        ti = 0;
        while ti < len(a.targets) {
            if not sym_visit_store_target(b, a.targets[ti]) {
                return False;
            }
            ti = ti + 1;
        }
        return sym_visit_load_expr(b, a.value);
    }
    if isinstance(s, AugAssign) {
        aa = s as AugAssign;
        if not sym_visit_store_target(b, aa.target) {
            return False;
        }
        return sym_visit_load_expr(b, aa.value);
    }
    if isinstance(s, AnnAssign) {
        an = s as AnnAssign;
        if isinstance(an.target, Name) {
            tn = (an.target as Name).id;
            if not b.add_def(tn, DEF_LOCAL, an.lineno, an.col_offset) {
                return False;
            }
        } else {
            if not sym_visit_store_target(b, an.target) {
                return False;
            }
        }
        if an.value is not None {
            return sym_visit_load_expr(b, an.value);
        }
        return True;
    }
    if isinstance(s, Expr) {
        return sym_visit_load_expr(b, (s as Expr).value);
    }
    if isinstance(s, Pass) {
        return True;
    }
    if isinstance(s, Return) {
        r = s as Return;
        if r.value is not None {
            return sym_visit_load_expr(b, r.value);
        }
        return True;
    }
    if isinstance(s, Yield) {
        b.cur.generator = True;
        y = s as Yield;
        if y.value is not None {
            return sym_visit_load_expr(b, y.value);
        }
        return True;
    }
    if isinstance(s, YieldFrom) {
        b.cur.generator = True;
        return sym_visit_load_expr(b, (s as YieldFrom).value);
    }
    if isinstance(s, Delete) {
        d = s as Delete;
        ti = 0;
        while ti < len(d.targets) {
            if not sym_visit_delete_target(b, d.targets[ti]) {
                return False;
            }
            ti = ti + 1;
        }
        return True;
    }
    if isinstance(s, Raise) {
        r = s as Raise;
        if r.exc is not None {
            if not sym_visit_load_expr(b, r.exc) {
                return False;
            }
        }
        if r.cause is not None {
            if not sym_visit_load_expr(b, r.cause) {
                return False;
            }
        }
        return True;
    }
    if isinstance(s, Assert) {
        a = s as Assert;
        if not sym_visit_load_expr(b, a.`test) {
            return False;
        }
        if a.msg is not None {
            if not sym_visit_load_expr(b, a.msg) {
                return False;
            }
        }
        return True;
    }
    if isinstance(s, Global) {
        g = s as Global;
        ni = 0;
        while ni < len(g.names) {
            if not b.add_def(g.names[ni], DEF_GLOBAL, g.lineno, g.col_offset) {
                return False;
            }
            ni = ni + 1;
        }
        return True;
    }
    if isinstance(s, Nonlocal) {
        nl = s as Nonlocal;
        if b.cur.block_type == "module" {
            return b.fail(
                "SyntaxError",
                "nonlocal declaration not allowed at module level",
                nl.lineno,
                nl.col_offset
            );
        }
        ni = 0;
        while ni < len(nl.names) {
            if not b.add_def(nl.names[ni], DEF_NONLOCAL, nl.lineno, nl.col_offset) {
                return False;
            }
            ni = ni + 1;
        }
        return True;
    }
    if isinstance(s, For)
        or isinstance(s, AsyncFor)
        or isinstance(s, While)
        or isinstance(s, If)
        or isinstance(s, Try) {
        body: list[stmt];
        orelse: list[stmt] = [];
        if isinstance(s, For) {
            fo = s as For;
            if not sym_visit_store_target(b, fo.target) {
                return False;
            }
            if not sym_visit_load_expr(b, fo.iter) {
                return False;
            }
            body = fo.body;
            orelse = fo.orelse;
        } elif isinstance(s, AsyncFor) {
            afo = s as AsyncFor;
            if not sym_visit_store_target(b, afo.target) {
                return False;
            }
            if not sym_visit_load_expr(b, afo.iter) {
                return False;
            }
            body = afo.body;
            orelse = afo.orelse;
        } elif isinstance(s, While) {
            wh = s as While;
            if not sym_visit_load_expr(b, wh.`test) {
                return False;
            }
            body = wh.body;
            orelse = wh.orelse;
        } elif isinstance(s, If) {
            iff = s as If;
            if not sym_visit_load_expr(b, iff.`test) {
                return False;
            }
            body = iff.body;
            orelse = iff.orelse;
        } else {
            tr = s as Try;
            body = tr.body;
            orelse = tr.orelse;
            if tr.handlers is not None {
                hi = 0;
                while hi < len(tr.handlers) {
                    h = tr.handlers[hi];
                    if h.type is not None {
                        if not sym_visit_load_expr(b, h.type) {
                            return False;
                        }
                    }
                    if h.name is not None {
                        if not b.add_def(h.name, DEF_LOCAL, h.lineno, h.col_offset) {
                            return False;
                        }
                    }
                    bi = 0;
                    while bi < len(h.body) {
                        if not sym_visit_stmt(b, h.body[bi]) {
                            return False;
                        }
                        bi = bi + 1;
                    }
                    hi = hi + 1;
                }
            }
            fi = 0;
            if tr.finalbody is not None {
                while fi < len(tr.finalbody) {
                    if not sym_visit_stmt(b, tr.finalbody[fi]) {
                        return False;
                    }
                    fi = fi + 1;
                }
            }
        }
        bi = 0;
        while bi < len(body) {
            if not sym_visit_stmt(b, body[bi]) {
                return False;
            }
            bi = bi + 1;
        }
        oi = 0;
        if orelse is not None {
            while oi < len(orelse) {
                if not sym_visit_stmt(b, orelse[oi]) {
                    return False;
                }
                oi = oi + 1;
            }
        }
        return True;
    }
    if isinstance(s, With) {
        wi = s as With;
        ii = 0;
        while ii < len(wi.items) {
            item = wi.items[ii];
            if not sym_visit_load_expr(b, item.context_expr) {
                return False;
            }
            if item.optional_vars is not None {
                if not sym_visit_store_target(b, item.optional_vars) {
                    return False;
                }
            }
            ii = ii + 1;
        }
        bi = 0;
        while bi < len(wi.body) {
            if not sym_visit_stmt(b, wi.body[bi]) {
                return False;
            }
            bi = bi + 1;
        }
        return True;
    }
    if isinstance(s, AsyncWith) {
        wi = s as AsyncWith;
        ii = 0;
        while ii < len(wi.items) {
            item = wi.items[ii];
            if not sym_visit_load_expr(b, item.context_expr) {
                return False;
            }
            if item.optional_vars is not None {
                if not sym_visit_store_target(b, item.optional_vars) {
                    return False;
                }
            }
            ii = ii + 1;
        }
        bi = 0;
        while bi < len(wi.body) {
            if not sym_visit_stmt(b, wi.body[bi]) {
                return False;
            }
            bi = bi + 1;
        }
        return True;
    }
    if isinstance(s, FunctionDef) {
        fd = s as FunctionDef;
        if not b.add_def(fd.name, DEF_LOCAL, fd.lineno, fd.col_offset) {
            return False;
        }
        decs = fd.decorator_list;
        if decs is None {
            decs = [];
        }
        di = 0;
        while di < len(decs) {
            if not sym_visit_load_expr(b, decs[di]) {
                return False;
            }
            di = di + 1;
        }
        if not sym_visit_arg_defaults(b, fd.args) {
            return False;
        }
        nested = sym_compute_nested(b);
        in_class = b.cur.block_type == "class" or b.cur.can_see_class_scope;
        if not b.push_block("function", fd.name, fd.lineno, nested, in_class) {
            return False;
        }
        if not sym_visit_params(b, fd.args) {
            return False;
        }
        bi = 0;
        while bi < len(fd.body) {
            if not sym_visit_stmt(b, fd.body[bi]) {
                return False;
            }
            bi = bi + 1;
        }
        return b.pop_block();
    }
    if isinstance(s, AsyncFunctionDef) {
        afd = s as AsyncFunctionDef;
        if not b.add_def(afd.name, DEF_LOCAL, afd.lineno, afd.col_offset) {
            return False;
        }
        decs = afd.decorator_list;
        if decs is None {
            decs = [];
        }
        di = 0;
        while di < len(decs) {
            if not sym_visit_load_expr(b, decs[di]) {
                return False;
            }
            di = di + 1;
        }
        if not sym_visit_arg_defaults(b, afd.args) {
            return False;
        }
        nested = sym_compute_nested(b);
        in_class = b.cur.block_type == "class" or b.cur.can_see_class_scope;
        if not b.push_block("function", afd.name, afd.lineno, nested, in_class) {
            return False;
        }
        b.cur.coroutine = True;
        if not sym_visit_params(b, afd.args) {
            return False;
        }
        bi = 0;
        while bi < len(afd.body) {
            if not sym_visit_stmt(b, afd.body[bi]) {
                return False;
            }
            bi = bi + 1;
        }
        return b.pop_block();
    }
    if isinstance(s, ClassDef) {
        cd = s as ClassDef;
        if not b.add_def(cd.name, DEF_LOCAL, cd.lineno, cd.col_offset) {
            return False;
        }
        saved_private = b.private;
        nested = b.cur.block_type != "module";
        if not b.push_block("class", cd.name, cd.lineno, nested) {
            return False;
        }
        b.private = cd.name;
        bi = 0;
        while bi < len(cd.body) {
            if not sym_visit_stmt(b, cd.body[bi]) {
                b.private = saved_private;
                return False;
            }
            bi = bi + 1;
        }
        b.private = saved_private;
        return b.pop_block();
    }
    if isinstance(s, Import) {
        imp = s as Import;
        ni = 0;
        while ni < len(imp.names) {
            bind = sym_import_bind_name(imp.names[ni]);
            if not b.add_def(bind, DEF_LOCAL, imp.lineno, imp.col_offset) {
                return False;
            }
            ni = ni + 1;
        }
        return True;
    }
    if isinstance(s, ImportFrom) {
        imp = s as ImportFrom;
        ni = 0;
        while ni < len(imp.names) {
            bind = sym_import_bind_name(imp.names[ni]);
            if not b.add_def(bind, DEF_LOCAL, imp.lineno, imp.col_offset) {
                return False;
            }
            ni = ni + 1;
        }
        return True;
    }
    if isinstance(s, Match) {
        m = s as Match;
        if not sym_visit_load_expr(b, m.subject) {
            return False;
        }
        ci = 0;
        while ci < len(m.cases) {
            mc = m.cases[ci];
            if mc.guard is not None {
                if not sym_visit_load_expr(b, mc.guard) {
                    return False;
                }
            }
            if not sym_visit_pattern(b, mc.pattern) {
                return False;
            }
            bi = 0;
            while bi < len(mc.body) {
                if not sym_visit_stmt(b, mc.body[bi]) {
                    return False;
                }
                bi = bi + 1;
            }
            ci = ci + 1;
        }
        return True;
    }
    return True;
}

def sym_directive_loc(block: sym_block, name: str) -> tuple[int, int] {
    if name in block.directive_lineno {
        col = 0;
        if name in block.directive_col {
            col = block.directive_col[name];
        }
        return (block.directive_lineno[name], col);
    }
    return (block.lineno, 0);
}

def sym_analyze_name(
    block: sym_block,
    name: str,
    flags: int,
    bound: dict[str, int] | None,
    local: dict[str, int],
    free: dict[str, int],
    global_set: dict[str, int],
    scopes: dict[str, int],
    class_entry: sym_block | None
) -> compiler_diagnostic | None {
    if sym_flag_set(flags, DEF_GLOBAL) {
        if sym_flag_set(flags, DEF_NONLOCAL) {
            loc = sym_directive_loc(block, name);
            return symbol_diagnostic(
                kind="SyntaxError",
                message="name '" + name + "' is nonlocal and global",
                lineno=loc[0],
                col_offset=loc[1]
            );
        }
        scopes[name] = SCOPE_GLOBAL_EXPLICIT;
        sym_set_add(global_set, name);
        if bound is not None {
            sym_set_discard(bound, name);
        }
        return None;
    }
    if sym_flag_set(flags, DEF_NONLOCAL) {
        if bound is None {
            loc = sym_directive_loc(block, name);
            return symbol_diagnostic(
                kind="SyntaxError",
                message="nonlocal declaration not allowed at module level",
                lineno=loc[0],
                col_offset=loc[1]
            );
        }
        if not sym_set_contains(bound, name) {
            loc = sym_directive_loc(block, name);
            return symbol_diagnostic(
                kind="SyntaxError",
                message="no binding for nonlocal '" + name + "' found",
                lineno=loc[0],
                col_offset=loc[1]
            );
        }
        scopes[name] = SCOPE_FREE;
        sym_set_add(free, name);
        return None;
    }
    if sym_flag_set(flags, DEF_LOCAL) or sym_flag_set(flags, DEF_PARAM) {
        scopes[name] = SCOPE_LOCAL;
        sym_set_add(local, name);
        sym_set_discard(global_set, name);
        return None;
    }
    if class_entry is not None {
        class_flags = sym_dict_get(class_entry.symbols, name, 0);
        if sym_flag_set(class_flags, DEF_GLOBAL) {
            scopes[name] = SCOPE_GLOBAL_EXPLICIT;
            return None;
        }
        if sym_flag_set(class_flags, DEF_BOUND)
            and not sym_flag_set(class_flags, DEF_NONLOCAL) {
            scopes[name] = SCOPE_GLOBAL_IMPLICIT;
            return None;
        }
    }
    if bound is not None and sym_set_contains(bound, name) {
        scopes[name] = SCOPE_FREE;
        sym_set_add(free, name);
        return None;
    }
    if sym_set_contains(global_set, name) {
        scopes[name] = SCOPE_GLOBAL_IMPLICIT;
        return None;
    }
    if block.block_type == "module" {
        scopes[name] = SCOPE_GLOBAL_IMPLICIT;
        return None;
    }
    scopes[name] = SCOPE_GLOBAL_IMPLICIT;
    return None;
}

def sym_analyze_block(
    block: sym_block,
    bound: dict[str, int] | None,
    inherited_global: dict[str, int],
    class_entry: sym_block | None
) -> tuple[dict[str, int], compiler_diagnostic | None] {
    local: dict[str, int] = {};
    free: dict[str, int] = {};
    global_set: dict[str, int] = sym_set_union({}, inherited_global);
    scopes: dict[str, int] = {};
    names = sym_sorted_names(block.symbols);
    ni = 0;
    while ni < len(names) {
        name = names[ni];
        raw = block.symbols[name];
        ad = sym_analyze_name(
            block, name, raw, bound, local, free, global_set, scopes, class_entry
        );
        if ad is not None {
            return ({}, ad);
        }
        ni = ni + 1;
    }
    # Match CPython symtable.c analyze_block: only function-like blocks add their
    # locals to newbound; module/class locals are not closure parents for
    # top-level functions (self-recursion uses LOAD_GLOBAL, not LOAD_DEREF).
    newbound: dict[str, int] = {};
    if sym_is_function_like(block) {
        newbound = sym_set_union(newbound, local);
    }
    if bound is not None {
        newbound = sym_set_union(newbound, bound);
    }
    child_free: dict[str, int] = {};
    ci = 0;
    while ci < len(block.children) {
        child = block.children[ci];
        child_class: sym_block | None = class_entry;
        if child.can_see_class_scope {
            if block.block_type == "class" {
                child_class = block;
            }
        }
        cf_result = sym_analyze_block(child, newbound, global_set, child_class);
        if cf_result[1] is not None {
            return ({}, cf_result[1]);
        }
        cf = cf_result[0];
        child_free = sym_set_union(child_free, cf);
        ci = ci + 1;
    }
    child_free = sym_set_union(child_free, free);
    fk_names = sym_set_keys(child_free);
    fi = 0;
    while fi < len(fk_names) {
        fname = fk_names[fi];
        if sym_set_contains(local, fname) {
            scopes[fname] = SCOPE_CELL;
            sym_set_discard(child_free, fname);
        } elif not sym_set_contains(local, fname)
            and sym_set_contains(newbound, fname) {
            if fname in scopes {
                scopes[fname] = SCOPE_FREE;
            } else {
                block.symbols[fname] = sym_set_scope(
                    sym_flag_add(sym_dict_get(block.symbols, fname, 0), SYM_USE),
                    SCOPE_FREE
                );
            }
        }
        fi = fi + 1;
    }
    for name in scopes.keys() {
        scope = scopes[name];
        raw = sym_dict_get(block.symbols, name, 0);
        block.symbols[name] = sym_set_scope(raw, scope);
    }
    return (child_free, None);
}

def sym_propagate_module_globals(top: sym_block) {
    ci = 0;
    while ci < len(top.children) {
        child = top.children[ci];
        if child.block_type == "function" {
            for name in child.symbols.keys() {
                flags = child.symbols[name];
                if sym_flag_set(flags, DEF_GLOBAL) {
                    cur = sym_dict_get(top.symbols, name, 0);
                    top.symbols[name] = sym_flag_add(cur, DEF_GLOBAL);
                }
            }
        }
        ci = ci + 1;
    }
}

def build_module_symtable(body: list[stmt]) -> symtable_result {
    top = sym_block(block_type="module", name="top", lineno=0, nested=False);
    b = sym_builder(cur=top, stack=[], module_global={}, private=None, diag=None);
    si = 0;
    while si < len(body) {
        if not sym_visit_stmt(b, body[si]) {
            if b.diag is not None {
                return symtable_result(diag=b.diag);
            }
            return symtable_error("SystemError", "symtable visit failed");
        }
        si = si + 1;
    }
    sym_result = sym_analyze_block(top, None, {}, None);
    if sym_result[1] is not None {
        return symtable_result(diag=sym_result[1]);
    }
    sym_propagate_module_globals(top);
    return symtable_ok(top);
}

# Normalized facts for oracle comparison (matches Lib/symtable.py queries).
def sym_symbol_facts(flags: int, module_scope: bool = False) -> dict[str, bool] {
    scope = sym_scope_of(flags);
    local = scope == SCOPE_LOCAL or scope == SCOPE_CELL;
    global_flag = scope == SCOPE_GLOBAL_EXPLICIT or scope == SCOPE_GLOBAL_IMPLICIT;
    if module_scope and sym_flag_set(flags, DEF_BOUND) {
        local = True;
        global_flag = True;
    }
    return {
        "local": local,
        "global": global_flag,
        "free": scope == SCOPE_FREE,
        "parameter": sym_flag_set(flags, DEF_PARAM),
        "nonlocal": sym_flag_set(flags, DEF_NONLOCAL),
        "declared_global": sym_flag_set(flags, DEF_GLOBAL),
        "referenced": sym_flag_set(flags, SYM_USE),
        "assigned": sym_flag_set(flags, DEF_LOCAL),

    };
}

def sym_block_tuple_names(d: dict[str, int], pred_scope: int) -> list[str] {
    out: list[str] = [];
    for name in sym_sorted_names(d) {
        if sym_scope_of(d[name]) == pred_scope {
            out.append(name);
        }
    }
    return out;
}

def sym_block_function_groups(block: sym_block) -> dict[str, list[str]] {
    params: list[str] = block.varnames;
    locals_list: list[str] = [];
    globals_list: list[str] = [];
    nonlocals_list: list[str] = [];
    frees_list: list[str] = [];
    for name in block.symbols.keys() {
        flags = block.symbols[name];
        facts = sym_symbol_facts(flags, module_scope=False);
        if facts["local"] and not facts["free"] {
            locals_list.append(name);
        }
        if facts["global"] and not facts["parameter"] {
            globals_list.append(name);
        }
        if facts["nonlocal"] {
            nonlocals_list.append(name);
        }
        if facts["free"] {
            frees_list.append(name);
        }
    }
    return {
        "parameters": params,
        "locals": locals_list,
        "globals": globals_list,
        "nonlocals": nonlocals_list,
        "frees": frees_list,

    };
}

def sym_normalize_block(block: sym_block) -> dict[str, any] {
    module_scope = block.block_type == "module";
    symbols: dict[str, any] = {};
    for name in sym_sorted_names(block.symbols) {
        symbols[name] = sym_symbol_facts(block.symbols[name], module_scope);
    }
    children: list[dict[str, any]] = [];
    ci = 0;
    while ci < len(block.children) {
        children.append(sym_normalize_block(block.children[ci]));
        ci = ci + 1;
    }
    out: dict[str, any] = {
        "name": block.name,
        "type": block.block_type,
        "lineno": block.lineno,
        "nested": block.nested,
        "symbols": symbols,
        "children": children,

    };
    if block.block_type == "function" {
        groups = sym_block_function_groups(block);
        out["parameters"] = groups["parameters"];
        out["locals"] = groups["locals"];
        out["globals"] = groups["globals"];
        out["nonlocals"] = groups["nonlocals"];
        out["frees"] = groups["frees"];
    }
    return out;
}

def sym_normalize(top: sym_block) -> dict[str, any] {
    return sym_normalize_block(top);
}

# ---------------- tests ----------------

import from compiler_diagnostics { compiler_diag_message }
import from objects { PyInt }
import from ast_nodes { Constant, Assign, USub }

::py::
import symtable as _symtable_mod


def _host_sym_normalize(source, mode="exec"):
    st = _symtable_mod.symtable(source, "<t>", mode)

    def block_info(st):
        d = {
            "name": st.get_name(),
            "type": st.get_type().value,
            "lineno": st.get_lineno(),
            "nested": st.is_nested(),
            "symbols": {},
            "children": [],
        }
        if hasattr(st, "get_parameters"):
            d["parameters"] = list(st.get_parameters())
            d["locals"] = list(st.get_locals())
            d["globals"] = list(st.get_globals())
            d["nonlocals"] = list(st.get_nonlocals())
            d["frees"] = list(st.get_frees())
        for name in sorted(st.get_identifiers()):
            sym = st.lookup(name)
            d["symbols"][name] = {
                "local": sym.is_local(),
                "global": sym.is_global(),
                "free": sym.is_free(),
                "parameter": sym.is_parameter(),
                "nonlocal": sym.is_nonlocal(),
                "declared_global": sym.is_declared_global(),
                "referenced": sym.is_referenced(),
                "assigned": sym.is_assigned(),
            }
        for ch in st.get_children():
            if ch.get_type().value == "annotation":
                continue
            d["children"].append(block_info(ch))
        return d

    return block_info(st)
::py::



def _sym_oracle_equal_py(native: any, expected: any) -> bool {
    return _sym_oracle_equal(native, expected) as bool;
}

::py::
import json


def _sym_oracle_equal(native, expected):
    nj = json.dumps(native, sort_keys=True, default=str)
    ej = json.dumps(expected, sort_keys=True, default=str)
    return nj == ej
::py::



def host_sym_normalize(source: str, mode: str = "exec") -> dict[str, any] {
    return _host_sym_normalize(source, mode) as dict[str, any];
}

def sym_dicts_equal(a: dict[str, any], b: dict[str, any]) -> bool {
    akeys = sorted(list(a.keys()));
    bkeys = sorted(list(b.keys()));
    if akeys != bkeys {
        return False;
    }
    ki = 0;
    while ki < len(akeys) {
        k = akeys[ki];
        av = a[k];
        bv = b[k];
        if isinstance(av, dict) and isinstance(bv, dict) {
            if not sym_dicts_equal(av as dict[str, any], bv as dict[str, any]) {
                return False;
            }
        } elif isinstance(av, list) and isinstance(bv, list) {
            la = av as list;
            lb = bv as list;
            if len(la) != len(lb) {
                return False;
            }
            ii = 0;
            while ii < len(la) {
                if la[ii] != lb[ii] {
                    return False;
                }
                ii = ii + 1;
            }
        } elif av != bv {
            return False;
        }
        ki = ki + 1;
    }
    return True;
}

def assert_sym_matches_oracle(source: str, body: list[stmt]) {
    sr = build_module_symtable(body);
    assert sr.diag is None;
    assert sr.top is not None;
    native = sym_normalize(sr.top);
    expected = host_sym_normalize(source, "exec");
    assert _sym_oracle_equal_py(native, expected);
}

import from ast_nodes {
    Module,
    FunctionDef,
    ClassDef,
    arguments,
    Load,
    Store,
    Return,
    arg
}

def ast_module_assign -> list[stmt] {
    x = Name(
        id="x", ctx=Store(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    y = Name(
        id="y", ctx=Store(), lineno=2, col_offset=0, end_lineno=2, end_col_offset=1
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=5
    );
    xload = Name(
        id="x", ctx=Load(), lineno=2, col_offset=4, end_lineno=2, end_col_offset=5
    );
    return [
        Assign(
            targets=[x],
            value=one,
            type_comment=None,
            lineno=1,
            col_offset=0,
            end_lineno=1,
            end_col_offset=5
        ),
        Assign(
            targets=[y],
            value=xload,
            type_comment=None,
            lineno=2,
            col_offset=0,
            end_lineno=2,
            end_col_offset=5
        ),

    ];
}

def ast_global_in_function -> list[stmt] {
    gx = Name(
        id="x", ctx=Store(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    gload = Name(
        id="x", ctx=Load(), lineno=1, col_offset=4, end_lineno=1, end_col_offset=5
    );
    gstore = Name(
        id="x", ctx=Store(), lineno=3, col_offset=1, end_lineno=3, end_col_offset=2
    );
    two = Constant(
        value=PyInt(t="int", val=2),
        kind=None,
        lineno=3,
        col_offset=5,
        end_lineno=3,
        end_col_offset=6
    );
    fbody = [
        Global(names=["x"], lineno=2, col_offset=1, end_lineno=2, end_col_offset=10),
        Assign(
            targets=[gstore],
            value=two,
            type_comment=None,
            lineno=3,
            col_offset=1,
            end_lineno=3,
            end_col_offset=6
        ),

    ];
    return [
        Assign(
            targets=[gx],
            value=Constant(
                value=PyInt(t="int", val=1),
                kind=None,
                lineno=1,
                col_offset=4,
                end_lineno=1,
                end_col_offset=5
            ),
            type_comment=None,
            lineno=1,
            col_offset=0,
            end_lineno=1,
            end_col_offset=5
        ),
        FunctionDef(
            name="f",
            args=arguments(
                posonlyargs=[],
                args=[],
                vararg=None,
                kwonlyargs=[],
                kw_defaults=[],
                kwarg=None,
                defaults=[]
            ),
            body=fbody,
            decorator_list=[],
            returns=None,
            type_comment=None,
            type_params=[],
            lineno=2,
            col_offset=0,
            end_lineno=3,
            end_col_offset=6
        ),

    ];
}

def empty_args -> arguments {
    return arguments(
        posonlyargs=[],
        args=[],
        vararg=None,
        kwonlyargs=[],
        kw_defaults=[],
        kwarg=None,
        defaults=[]
    );
}

def ast_nonlocal_nested -> list[stmt] {
    xstore = Name(
        id="x", ctx=Store(), lineno=2, col_offset=1, end_lineno=2, end_col_offset=2
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=2,
        col_offset=5,
        end_lineno=2,
        end_col_offset=6
    );
    inner_xstore = Name(
        id="x", ctx=Store(), lineno=4, col_offset=2, end_lineno=4, end_col_offset=3
    );
    two = Constant(
        value=PyInt(t="int", val=2),
        kind=None,
        lineno=4,
        col_offset=6,
        end_lineno=4,
        end_col_offset=7
    );
    inner_body = [
        Nonlocal(names=["x"], lineno=3, col_offset=2, end_lineno=3, end_col_offset=13),
        Assign(
            targets=[inner_xstore],
            value=two,
            type_comment=None,
            lineno=4,
            col_offset=2,
            end_lineno=4,
            end_col_offset=7
        ),

    ];
    inner = FunctionDef(
        name="inner",
        args=empty_args(),
        body=inner_body,
        decorator_list=[],
        returns=None,
        type_comment=None,
        type_params=[],
        lineno=3,
        col_offset=1,
        end_lineno=4,
        end_col_offset=7
    );
    innerref = Name(
        id="inner", ctx=Load(), lineno=5, col_offset=8, end_lineno=5, end_col_offset=13
    );
    outer_body = [
        Assign(
            targets=[xstore],
            value=one,
            type_comment=None,
            lineno=2,
            col_offset=1,
            end_lineno=2,
            end_col_offset=6
        ),
        inner,
        Return(value=innerref, lineno=5, col_offset=1, end_lineno=5, end_col_offset=13),

    ];
    outer = FunctionDef(
        name="outer",
        args=empty_args(),
        body=outer_body,
        decorator_list=[],
        returns=None,
        type_comment=None,
        type_params=[],
        lineno=1,
        col_offset=0,
        end_lineno=5,
        end_col_offset=13
    );
    return [outer];
}

def ast_closure -> list[stmt] {
    xparam = arg(
        arg="x",
        annotation=None,
        type_comment=None,
        lineno=1,
        col_offset=10,
        end_lineno=1,
        end_col_offset=11
    );
    xload = Name(
        id="x", ctx=Load(), lineno=3, col_offset=9, end_lineno=3, end_col_offset=10
    );
    inner_body = [
        Return(value=xload, lineno=3, col_offset=2, end_lineno=3, end_col_offset=10),

    ];
    inner = FunctionDef(
        name="inner",
        args=empty_args(),
        body=inner_body,
        decorator_list=[],
        returns=None,
        type_comment=None,
        type_params=[],
        lineno=2,
        col_offset=1,
        end_lineno=3,
        end_col_offset=10
    );
    innerref = Name(
        id="inner", ctx=Load(), lineno=4, col_offset=8, end_lineno=4, end_col_offset=13
    );
    outer_args = arguments(
        posonlyargs=[],
        args=[xparam],
        vararg=None,
        kwonlyargs=[],
        kw_defaults=[],
        kwarg=None,
        defaults=[]
    );
    outer_body = [
        inner,
        Return(value=innerref, lineno=4, col_offset=1, end_lineno=4, end_col_offset=13)
    ];
    outer = FunctionDef(
        name="outer",
        args=outer_args,
        body=outer_body,
        decorator_list=[],
        returns=None,
        type_comment=None,
        type_params=[],
        lineno=1,
        col_offset=0,
        end_lineno=4,
        end_col_offset=13
    );
    return [outer];
}

def ast_class_method -> list[stmt] {
    selfparam = arg(
        arg="self",
        annotation=None,
        type_comment=None,
        lineno=2,
        col_offset=8,
        end_lineno=2,
        end_col_offset=12
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=2,
        col_offset=15,
        end_lineno=2,
        end_col_offset=16
    );
    mbody = [
        Return(value=one, lineno=2, col_offset=5, end_lineno=2, end_col_offset=16),

    ];
    margs = arguments(
        posonlyargs=[],
        args=[selfparam],
        vararg=None,
        kwonlyargs=[],
        kw_defaults=[],
        kwarg=None,
        defaults=[]
    );
    m = FunctionDef(
        name="m",
        args=margs,
        body=mbody,
        decorator_list=[],
        returns=None,
        type_comment=None,
        type_params=[],
        lineno=2,
        col_offset=1,
        end_lineno=2,
        end_col_offset=16
    );
    c = ClassDef(
        name="C",
        bases=[],
        keywords=[],
        body=[m],
        decorator_list=[],
        type_params=[],
        lineno=1,
        col_offset=0,
        end_lineno=2,
        end_col_offset=16
    );
    return [c];
}

import from parser { parse_file }

test "compiler_symtable: parsed x=1 symtable accepted" {
    m = parse_file("x = 1\n", "<t>");
    assert m is not None;
    sr = build_module_symtable((m as Module).body);
    assert sr.diag is None;
}

test "compiler_symtable: module assignment matches oracle" {
    assert_sym_matches_oracle("x = 1\ny = x\n", ast_module_assign());
}

test "compiler_symtable: global in function matches oracle" {
    assert_sym_matches_oracle(
        "x = 1\ndef f():\n global x\n x = 2\n", ast_global_in_function()
    );
}

test "compiler_symtable: nonlocal matches oracle" {
    assert_sym_matches_oracle(
        "def outer():\n x = 1\n def inner():\n  nonlocal x\n  x = 2\n return inner\n",
        ast_nonlocal_nested()
    );
}

test "compiler_symtable: closure free var matches oracle" {
    assert_sym_matches_oracle(
        "def outer(x):\n def inner():\n  return x\n return inner\n", ast_closure()
    );
}

test "compiler_symtable: recursive function self-call matches oracle" {
    src = (
        "def fact(n):\n"
        + " if n <= 1:\n"
        + "  return 1\n"
        + " return n * fact(n - 1)\n\n"
        + "result = fact(5)\n"
    );
    m = parse_file(src, "<t>");
    assert m is not None;
    sr = build_module_symtable((m as Module).body);
    assert sr.diag is None;
    native = sym_normalize(sr.top);
    expected = host_sym_normalize(src, "exec");
    assert _sym_oracle_equal_py(native, expected);
}

test "compiler_symtable: lambda assign matches oracle" {
    src = "f = lambda x: x + 1\nresult = f(2)\n";
    m = parse_file(src, "<t>");
    assert m is not None;
    sr = build_module_symtable((m as Module).body);
    assert sr.diag is None;
    native = sym_normalize(sr.top);
    expected = host_sym_normalize(src, "exec");
    assert _sym_oracle_equal_py(native, expected);
}

test "compiler_symtable: closure capture parsed matches oracle" {
    src = (
        "def outer(x):\n"
        + "    def inner():\n"
        + "        return x\n"
        + "    return inner()\n\n"
        + "result = outer(42)\n"
    );
    m = parse_file(src, "<t>");
    assert m is not None;
    sr = build_module_symtable((m as Module).body);
    assert sr.diag is None;
    native = sym_normalize(sr.top);
    expected = host_sym_normalize(src, "exec");
    assert _sym_oracle_equal_py(native, expected);
}

test "compiler_symtable: decorator parsed matches oracle" {
    src = (
        "def deco(fn):\n"
        + "    return fn\n\n"
        + "@deco\n"
        + "def f(x):\n"
        + "    return x + 1\n\n"
        + "result = f(2)\n"
    );
    m = parse_file(src, "<t>");
    assert m is not None;
    sr = build_module_symtable((m as Module).body);
    assert sr.diag is None;
    native = sym_normalize(sr.top);
    expected = host_sym_normalize(src, "exec");
    assert _sym_oracle_equal_py(native, expected);
}

def ast_class_mangle -> list[stmt] {
    priv_x = Name(
        id="__x", ctx=Store(), lineno=2, col_offset=1, end_lineno=2, end_col_offset=4
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=2,
        col_offset=7,
        end_lineno=2,
        end_col_offset=8
    );
    selfparam = arg(
        arg="self",
        annotation=None,
        type_comment=None,
        lineno=3,
        col_offset=8,
        end_lineno=3,
        end_col_offset=12
    );
    xload = Name(
        id="__x", ctx=Load(), lineno=4, col_offset=9, end_lineno=4, end_col_offset=12
    );
    mbody = [
        Return(value=xload, lineno=4, col_offset=2, end_lineno=4, end_col_offset=12),

    ];
    margs = arguments(
        posonlyargs=[],
        args=[selfparam],
        vararg=None,
        kwonlyargs=[],
        kw_defaults=[],
        kwarg=None,
        defaults=[]
    );
    m = FunctionDef(
        name="m",
        args=margs,
        body=mbody,
        decorator_list=[],
        returns=None,
        type_comment=None,
        type_params=[],
        lineno=3,
        col_offset=1,
        end_lineno=4,
        end_col_offset=12
    );
    c = ClassDef(
        name="C",
        bases=[],
        keywords=[],
        body=[
            Assign(
                targets=[priv_x],
                value=one,
                type_comment=None,
                lineno=2,
                col_offset=1,
                end_lineno=2,
                end_col_offset=8
            ),
            m,

        ],
        decorator_list=[],
        type_params=[],
        lineno=1,
        col_offset=0,
        end_lineno=4,
        end_col_offset=12
    );
    return [c];
}

test "compiler_symtable: class method matches oracle" {
    assert_sym_matches_oracle(
        "class C:\n def m(self):\n  return 1\n", ast_class_method()
    );
}

test "compiler_symtable: class name mangling matches oracle" {
    assert_sym_matches_oracle(
        "class C:\n __x = 1\n def m(self):\n  return __x\n", ast_class_mangle()
    );
}

test "compiler_symtable: genexpr matches oracle" {
    m = parse_file("x = (y for y in range(3))\n", "<t>");
    assert m is not None;
    sr = build_module_symtable((m as Module).body);
    assert sr.diag is None;
    native = sym_normalize(sr.top);
    expected = host_sym_normalize("x = (y for y in range(3))\n", "exec");
    assert _sym_oracle_equal_py(native, expected);
}

test "compiler_symtable: listcomp inlined at module matches oracle" {
    m = parse_file("x = [y for y in range(3)]\n", "<t>");
    assert m is not None;
    sr = build_module_symtable((m as Module).body);
    assert sr.diag is None;
    native = sym_normalize(sr.top);
    expected = host_sym_normalize("x = [y for y in range(3)]\n", "exec");
    assert _sym_oracle_equal_py(native, expected);
}

test "compiler_symtable: setcomp inlined at module matches oracle" {
    m = parse_file("x = {y for y in range(3)}\n", "<t>");
    assert m is not None;
    sr = build_module_symtable((m as Module).body);
    assert sr.diag is None;
    native = sym_normalize(sr.top);
    expected = host_sym_normalize("x = {y for y in range(3)}\n", "exec");
    assert _sym_oracle_equal_py(native, expected);
}

test "compiler_symtable: dictcomp inlined at module matches oracle" {
    kload = Name(
        id="k", ctx=Load(), lineno=1, col_offset=5, end_lineno=1, end_col_offset=6
    );
    vload = Name(
        id="v", ctx=Load(), lineno=1, col_offset=8, end_lineno=1, end_col_offset=9
    );
    kstore = Name(
        id="k", ctx=Store(), lineno=1, col_offset=16, end_lineno=1, end_col_offset=17
    );
    vstore = Name(
        id="v", ctx=Store(), lineno=1, col_offset=19, end_lineno=1, end_col_offset=20
    );
    pair = Tuple(
        elts=[
            Constant(
                value=PyInt(t="int", val=1),
                kind=None,
                lineno=1,
                col_offset=25,
                end_lineno=1,
                end_col_offset=26
            ),
            Constant(
                value=PyInt(t="int", val=2),
                kind=None,
                lineno=1,
                col_offset=28,
                end_lineno=1,
                end_col_offset=29
            ),

        ],
        ctx=Load(),
        lineno=1,
        col_offset=24,
        end_lineno=1,
        end_col_offset=30
    );
    pairs = List(
        elts=[pair],
        ctx=Load(),
        lineno=1,
        col_offset=23,
        end_lineno=1,
        end_col_offset=31
    );
    target = Tuple(
        elts=[kstore, vstore],
        ctx=Store(),
        lineno=1,
        col_offset=16,
        end_lineno=1,
        end_col_offset=20
    );
    gen = comprehension(target=target, iter=pairs, ifs=[], is_async=0);
    dc = DictComp(
        key=kload,
        value=vload,
        generators=[gen],
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=32
    );
    x = Name(
        id="x", ctx=Store(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    body = [
        Assign(
            targets=[x],
            value=dc,
            type_comment=None,
            lineno=1,
            col_offset=0,
            end_lineno=1,
            end_col_offset=32
        ),

    ];
    assert_sym_matches_oracle("x = {k: v for k, v in [(1, 2)]}\n", body);
}

def sym_first_function(top: sym_block) -> sym_block | None {
    ci = 0;
    while ci < len(top.children) {
        ch = top.children[ci];
        if ch.block_type == "function" {
            return ch;
        }
        ci = ci + 1;
    }
    return None;
}

test "compiler_symtable: yield marks generator flag" {
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=2,
        col_offset=7,
        end_lineno=2,
        end_col_offset=8
    );
    fbody = [
        Expr(
            value=Yield(
                value=one, lineno=2, col_offset=1, end_lineno=2, end_col_offset=8
            ),
            lineno=2,
            col_offset=1,
            end_lineno=2,
            end_col_offset=8
        ),

    ];
    f = FunctionDef(
        name="f",
        args=empty_args(),
        body=fbody,
        decorator_list=[],
        returns=None,
        type_comment=None,
        type_params=[],
        lineno=1,
        col_offset=0,
        end_lineno=2,
        end_col_offset=8
    );
    sr = build_module_symtable([f]);
    assert sr.diag is None;
    assert sr.top is not None;
    fn = sym_first_function(sr.top);
    assert fn is not None;
    assert fn.generator;
    assert not fn.coroutine;
}

test "compiler_symtable: async def marks coroutine flag" {
    afd = AsyncFunctionDef(
        name="f",
        args=empty_args(),
        body=[Pass(lineno=2, col_offset=1, end_lineno=2, end_col_offset=5)],
        decorator_list=[],
        returns=None,
        type_comment=None,
        type_params=[],
        lineno=1,
        col_offset=0,
        end_lineno=2,
        end_col_offset=5
    );
    sr = build_module_symtable([afd]);
    assert sr.diag is None;
    assert sr.top is not None;
    fn = sym_first_function(sr.top);
    assert fn is not None;
    assert fn.coroutine;
}

test "compiler_symtable: genexpr child marks generator flag" {
    m = parse_file("x = (y for y in range(3))\n", "<t>");
    assert m is not None;
    sr = build_module_symtable((m as Module).body);
    assert sr.diag is None;
    assert sr.top is not None;
    g = sym_first_function(sr.top);
    assert g is not None;
    assert g.name == "genexpr";
    assert g.generator;
}

def ast_invalid_nonlocal -> list[stmt] {
    fbody = [
        Nonlocal(names=["x"], lineno=2, col_offset=1, end_lineno=2, end_col_offset=13),

    ];
    f = FunctionDef(
        name="f",
        args=empty_args(),
        body=fbody,
        decorator_list=[],
        returns=None,
        type_comment=None,
        type_params=[],
        lineno=1,
        col_offset=0,
        end_lineno=2,
        end_col_offset=13
    );
    return [f];
}

def ast_global_nonlocal_conflict -> list[stmt] {
    fbody = [
        Global(names=["x"], lineno=2, col_offset=1, end_lineno=2, end_col_offset=10),
        Nonlocal(names=["x"], lineno=3, col_offset=1, end_lineno=3, end_col_offset=13),

    ];
    f = FunctionDef(
        name="f",
        args=empty_args(),
        body=fbody,
        decorator_list=[],
        returns=None,
        type_comment=None,
        type_params=[],
        lineno=1,
        col_offset=0,
        end_lineno=3,
        end_col_offset=13
    );
    return [f];
}

test "compiler_symtable: invalid nonlocal is SyntaxError" {
    sr = build_module_symtable(ast_invalid_nonlocal());
    assert sr.diag is not None;
    assert compiler_diag_kind(sr.diag) == "SyntaxError";
    assert compiler_diag_message(sr.diag) == "no binding for nonlocal 'x' found";
}

test "compiler_symtable: global and nonlocal conflict is SyntaxError" {
    sr = build_module_symtable(ast_global_nonlocal_conflict());
    assert sr.diag is not None;
    assert compiler_diag_message(sr.diag) == "name 'x' is nonlocal and global";
}

test "compiler_symtable: nonlocal at module is SyntaxError" {
    sr = build_module_symtable(
        [Nonlocal(names=["x"], lineno=1, col_offset=0, end_lineno=1, end_col_offset=13)]
    );
    assert sr.diag is not None;
    assert compiler_diag_message(sr.diag)
        == "nonlocal declaration not allowed at module level";
}
