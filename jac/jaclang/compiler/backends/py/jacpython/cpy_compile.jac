# Compiler state for the JacPython compiler: a port of the compiler unit
# stack, scopes, constant and name tables, frame blocks and the code unit
# assembly step of CPython 3.14's Python/compile.c and Python/future.c.

glob COMPILE_SCOPE_MODULE: int = 0,
     COMPILE_SCOPE_CLASS: int = 1,
     COMPILE_SCOPE_FUNCTION: int = 2,
     COMPILE_SCOPE_ASYNC_FUNCTION: int = 3,
     COMPILE_SCOPE_LAMBDA: int = 4,
     COMPILE_SCOPE_COMPREHENSION: int = 5,
     COMPILE_SCOPE_ANNOTATIONS: int = 6;

glob COMPILE_FBLOCK_WHILE_LOOP: int = 0,
     COMPILE_FBLOCK_FOR_LOOP: int = 1,
     COMPILE_FBLOCK_TRY_EXCEPT: int = 2,
     COMPILE_FBLOCK_FINALLY_TRY: int = 3,
     COMPILE_FBLOCK_FINALLY_END: int = 4,
     COMPILE_FBLOCK_WITH: int = 5,
     COMPILE_FBLOCK_ASYNC_WITH: int = 6,
     COMPILE_FBLOCK_HANDLER_CLEANUP: int = 7,
     COMPILE_FBLOCK_POP_VALUE: int = 8,
     COMPILE_FBLOCK_EXCEPTION_HANDLER: int = 9,
     COMPILE_FBLOCK_EXCEPTION_GROUP_HANDLER: int = 10,
     COMPILE_FBLOCK_ASYNC_COMPREHENSION_GENERATOR: int = 11,
     COMPILE_FBLOCK_STOP_ITERATION: int = 12;

glob COMPILE_OP_FAST: int = 0,
     COMPILE_OP_GLOBAL: int = 1,
     COMPILE_OP_DEREF: int = 2,
     COMPILE_OP_NAME: int = 3;

glob CO_MAXBLOCKS: int = 21,
     PyCF_MASK: int = 0x1FE0000,
     NO_LABEL: int = -1;

obj cpy_fblock {
    has fb_type: int,
        fb_block: int,
        fb_loc: srcloc,
        fb_exit: int,
        fb_body: list[stmt] | None = None,
        fb_name: str | None = None;
}

obj cpy_inline_state {
    has pushed_locals: list[str] | None = None,
        temp_symbols: dict[str, int] | None = None,
        temp_order: list[str] = [],
        fast_hidden: list[str] | None = None,
        cleanup: int = -1;
}

obj cpy_unit {
    has ste: cpy_ste,
        scope_type: int,
        seq: instr_seq,
        md: code_unit_metadata,
        private: str | None = None,
        static_attributes: set[str] | None = None,
        deferred_annotations: list[AnnAssign] | None = None,
        conditional_annotation_indices: list[int] | None = None,
        next_conditional_annotation_index: int = 0,
        stashed_seq: instr_seq | None = None,
        fblocks: list[cpy_fblock] = [],
        in_inlined_comp: int = 0,
        in_conditional_block: int = 0;
}

obj cpy_compiler {
    has filename: str,
        st: cpy_symtable,
        future_features: int,
        flags: int,
        optimize: int,
        interactive: bool = False,
        u: cpy_unit | None = None,
        stack: list[cpy_unit] = [],
        disable_warning: int = 0;

    def unit -> cpy_unit {
        u = self.u;
        if u is None {
            raise RuntimeError("compiler has no current unit");
        }
        return u;
    }
}

def cpy_future_from_ast(m: mod, filename: str) -> int {
    if not isinstance(m, (Module, Interactive)) {
        return 0;
    }
    body = m.body;
    n = len(body);
    features = 0;
    i = 0;
    if n > 0 and cpy_get_docstring(body) is not None {
        i = 1;
    }
    while i < n {
        s = body[i];
        if not isinstance(s, ImportFrom)
            or (s.level if s.level is not None else 0) != 0 {
            return features;
        }
        modname = s.module;
        if modname is None or modname != "__future__" {
            return features;
        }
        for name in s.names {
            feature = name.name;
            if feature == "barry_as_FLUFL" {
                features |= 0x400000;
            } elif feature == "annotations" {
                features |= 0x1000000;
            } elif feature == "braces" {
                raise cpy_future_error("not a chance", filename, name);
            } elif feature
                not in (
                    "nested_scopes",
                    "generators",
                    "division",
                    "absolute_import",
                    "with_statement",
                    "print_function",
                    "unicode_literals",
                    "generator_stop"
                ) {
                raise cpy_future_error(
                    "future feature " + feature[:100] + " is not defined",
                    filename,
                    name
                );
            }
        }
        i += 1;
    }
    return features;
}

def cpy_future_error(msg: str, filename: str, name: alias) -> syntax_failure {
    end_lineno = name.end_lineno if name.end_lineno is not None else name.lineno;
    end_col = name.end_col_offset
        if name.end_col_offset is not None
        else name.col_offset;
    return syntax_failure(
        msg,
        filename=filename,
        lineno=name.lineno,
        offset=name.col_offset + 1,
        end_lineno=end_lineno,
        end_offset=end_col + 1
    );
}

def cpy_get_docstring(body: list[stmt]) -> str | None {
    if len(body) == 0 {
        return None;
    }
    first = body[0];
    if not isinstance(first, Expr) {
        return None;
    }
    value = first.value;
    if isinstance(value, Constant) and isinstance(value.value, PyStr) {
        return value.value.val;
    }
    return None;
}

def cpy_compile_maybe_add_static_attribute(c: cpy_compiler, e: Attribute) {
    attr_value = e.value;
    if not isinstance(attr_value, Name)
        or not isinstance(e.ctx, Store)
        or attr_value.id != "self" {
        return;
    }
    i = len(c.stack) - 1;
    while i >= 0 {
        u = c.stack[i];
        if u.scope_type == COMPILE_SCOPE_CLASS {
            attrs = u.static_attributes;
            if attrs is not None {
                attrs.add(e.attr);
            }
            break;
        }
        i -= 1;
    }
}

def cpy_compile_set_qualname(c: cpy_compiler) {
    u = c.unit();
    base: str | None = None;
    stack_size = len(c.stack);
    if stack_size > 1 {
        force_global = False;
        parent = c.stack[stack_size - 1];
        if parent.scope_type == COMPILE_SCOPE_ANNOTATIONS {
            if stack_size == 2 {
                u.md.qualname = u.md.name;
                return;
            }
            parent = c.stack[stack_size - 2];
        }
        if u.scope_type == COMPILE_SCOPE_FUNCTION
            or u.scope_type == COMPILE_SCOPE_ASYNC_FUNCTION
            or u.scope_type == COMPILE_SCOPE_CLASS {
            mangled = cpy_mangle(parent.private, u.md.name);
            scope = cpy_st_get_scope(parent.ste, mangled);
            if scope == ST_GLOBAL_EXPLICIT {
                force_global = True;
            }
        }
        if not force_global {
            if parent.scope_type == COMPILE_SCOPE_FUNCTION
                or parent.scope_type == COMPILE_SCOPE_ASYNC_FUNCTION
                or parent.scope_type == COMPILE_SCOPE_LAMBDA {
                base = parent.md.qualname + ".<locals>";
            } else {
                base = parent.md.qualname;
            }
        }
    }
    if base is not None {
        u.md.qualname = base + "." + u.md.name;
    } else {
        u.md.qualname = u.md.name;
    }
}

def cpy_dict_add(keys: list[str], index: dict[str, int], name: str) -> int {
    if name in index {
        return index[name];
    }
    arg = len(keys);
    keys.append(name);
    index[name] = arg;
    return arg;
}

def cpy_key_join(parts: list[str]) -> str {
    return "".join([str(len(part)) + ":" + part for part in parts]);
}

def cpy_const_key(o: PyObj) -> str {
    if isinstance(o, PyCode) {
        return "code:"
            + cpy_key_join(
                [
                    o.name,
                    str(o.argcount),
                    str(o.posonlyargcount),
                    str(o.kwonlyargcount),
                    str(o.flags),
                    str(o.firstlineno),
                    cpy_key_join([str(b) for b in o.co_code]),
                    cpy_key_join([cpy_const_key(k) for k in o.consts]),
                    cpy_key_join(o.names),
                    cpy_key_join(o.localsplusnames),
                    cpy_key_join([str(b) for b in o.linetable]),
                    cpy_key_join([str(b) for b in o.exceptiontable])
                ]
            );
    }
    return constant_key(o);
}

def cpy_compile_add_const(c: cpy_compiler, o: PyObj) -> int {
    md = c.unit().md;
    key = cpy_const_key(o);
    if key in md.const_index {
        return md.const_index[key];
    }
    arg = len(md.consts);
    md.consts.append(o);
    md.const_index[key] = arg;
    return arg;
}

def cpy_dictbytype(
    ste: cpy_ste,
    scope_type: int,
    flag: int,
    offset: int,
    keys: list[str],
    index: dict[str, int]
) {
    i = offset;
    for k in sorted(ste.symbol_order) {
        vi = ste.symbols[k];
        if ((vi >> ST_SCOPE_OFFSET) & ST_SCOPE_MASK) == scope_type or vi & flag {
            keys.append(k);
            index[k] = i;
            i += 1;
        }
    }
}

def cpy_compile_enter_scope(
    c: cpy_compiler,
    name: str,
    scope_type: int,
    key: int,
    lineno: int,
    private: str | None,
    argcount: int,
    posonlyargcount: int,
    kwonlyargcount: int
) {
    ste = cpy_symtable_lookup(c.st, key);
    md = code_unit_metadata(
        name=name,
        qualname="",
        consts=[],
        const_index={},
        names=[],
        name_index={},
        varnames=[],
        varname_index={},
        cellvars=[],
        cellvar_index={},
        freevars=[],
        freevar_index={},
        fasthidden={},
        argcount=argcount,
        posonlyargcount=posonlyargcount,
        kwonlyargcount=kwonlyargcount,
        firstlineno=lineno
    );
    for vname in ste.varnames {
        cpy_dict_add(md.varnames, md.varname_index, vname);
    }
    cpy_dictbytype(ste, ST_CELL, ST_DEF_COMP_CELL, 0, md.cellvars, md.cellvar_index);
    if ste.needs_class_closure {
        cpy_dict_add(md.cellvars, md.cellvar_index, "__class__");
    }
    if ste.needs_classdict {
        cpy_dict_add(md.cellvars, md.cellvar_index, "__classdict__");
    }
    if ste.has_conditional_annotations {
        cpy_dict_add(md.cellvars, md.cellvar_index, "__conditional_annotations__");
    }
    cpy_dictbytype(
        ste, ST_FREE, ST_DEF_FREE_CLASS, len(md.cellvars), md.freevars, md.freevar_index
    );
    u = cpy_unit(
        ste=ste,
        scope_type=scope_type,
        seq=instr_seq(instrs=[], labelmap=[], nested=[]),
        md=md,
        fblocks=[]
    );
    if scope_type == COMPILE_SCOPE_CLASS {
        u.static_attributes = set();
    }
    cur = c.u;
    if cur is not None {
        c.stack.append(cur);
        if private is None {
            private = cur.private;
        }
    }
    u.private = private;
    c.u = u;
    if scope_type != COMPILE_SCOPE_MODULE {
        cpy_compile_set_qualname(c);
    }
}

def cpy_compile_exit_scope(c: cpy_compiler) {
    n = len(c.stack) - 1;
    if n >= 0 {
        c.u = c.stack.pop();
    } else {
        c.u = None;
    }
}

def cpy_compile_push_fblock(
    c: cpy_compiler,
    loc: srcloc,
    t: int,
    block_label: int,
    exit_label: int,
    body: list[stmt] | None = None,
    name: str | None = None
) {
    u = c.unit();
    if len(u.fblocks) >= CO_MAXBLOCKS {
        cpy_compile_error(c, loc, "too many statically nested blocks");
    }
    u.fblocks.append(
        cpy_fblock(
            fb_type=t,
            fb_block=block_label,
            fb_loc=loc,
            fb_exit=exit_label,
            fb_body=body,
            fb_name=name
        )
    );
    if t == COMPILE_FBLOCK_FINALLY_END {
        c.disable_warning += 1;
    }
}

def cpy_compile_pop_fblock(c: cpy_compiler, t: int, block_label: int) {
    u = c.unit();
    u.fblocks.pop();
    if t == COMPILE_FBLOCK_FINALLY_END {
        c.disable_warning -= 1;
    }
}

def cpy_compile_top_fblock(c: cpy_compiler) -> cpy_fblock | None {
    u = c.unit();
    if len(u.fblocks) == 0 {
        return None;
    }
    return u.fblocks[len(u.fblocks) - 1];
}

def cpy_compile_get_ref_type(c: cpy_compiler, name: str) -> int {
    u = c.unit();
    if u.scope_type == COMPILE_SCOPE_CLASS
        and (
            name == "__class__"
            or name == "__classdict__"
            or name == "__conditional_annotations__"
        ) {
        return ST_CELL;
    }
    scope = cpy_st_get_scope(u.ste, name);
    if scope == 0 {
        raise SystemError(
            "_PyST_GetScope(name='"
                + name
                + "') failed: unknown scope in unit "
                + u.md.name
        );
    }
    return scope;
}

def cpy_compile_lookup_cellvar(c: cpy_compiler, name: str) -> int {
    md = c.unit().md;
    if name not in md.cellvar_index {
        raise SystemError("unknown cell variable " + name);
    }
    return md.cellvar_index[name];
}

def cpy_compile_lookup_arg(c: cpy_compiler, co: PyCode, name: str) -> int {
    reftype = cpy_compile_get_ref_type(c, name);
    md = c.unit().md;
    if reftype == ST_CELL {
        if name in md.cellvar_index {
            return md.cellvar_index[name];
        }
    } elif name in md.freevar_index {
        return md.freevar_index[name];
    }
    raise SystemError(
        "compiler_lookup_arg(name='"
            + name
            + "') with reftype="
            + str(reftype)
            + " failed in "
            + md.name
            + "; freevars of code "
            + co.name
    );
}

def cpy_compile_static_attributes(c: cpy_compiler) -> PyObj {
    attrs = c.unit().static_attributes;
    items: list[PyObj] = [];
    if attrs is not None {
        for name in sorted(attrs) {
            items.append(PyStr(t="str", val=name));
        }
    }
    return PyTuple(t="tuple", items=items);
}

def cpy_compile_resolve_nameop(
    c: cpy_compiler, mangled: str, scope: int
) -> tuple[int, int] {
    u = c.unit();
    md = u.md;
    optype = COMPILE_OP_NAME;
    which = 0;
    if scope == ST_FREE {
        which = 2;
        optype = COMPILE_OP_DEREF;
    } elif scope == ST_CELL {
        which = 1;
        optype = COMPILE_OP_DEREF;
    } elif scope == ST_LOCAL {
        if cpy_st_is_function_like(u.ste) {
            optype = COMPILE_OP_FAST;
        } elif mangled in md.fasthidden and md.fasthidden[mangled] {
            optype = COMPILE_OP_FAST;
        }
    } elif scope == ST_GLOBAL_IMPLICIT {
        if cpy_st_is_function_like(u.ste) {
            optype = COMPILE_OP_GLOBAL;
        }
    } elif scope == ST_GLOBAL_EXPLICIT {
        optype = COMPILE_OP_GLOBAL;
    }
    arg = 0;
    if optype != COMPILE_OP_FAST {
        if which == 2 {
            arg = cpy_dict_add(md.freevars, md.freevar_index, mangled);
        } elif which == 1 {
            arg = cpy_dict_add(md.cellvars, md.cellvar_index, mangled);
        } else {
            arg = cpy_dict_add(md.names, md.name_index, mangled);
        }
    }
    return (optype, arg);
}

def cpy_compile_tweak_inlined_comprehension_scopes(
    c: cpy_compiler, loc: srcloc, comp: cpy_ste, state: cpy_inline_state
) {
    u = c.unit();
    in_class_block = u.ste.ste_type == ClassBlock and not u.in_inlined_comp;
    u.in_inlined_comp += 1;
    for k in list(comp.symbol_order) {
        symbol = comp.symbols[k];
        scope = (symbol >> ST_SCOPE_OFFSET) & ST_SCOPE_MASK;
        outsymbol = cpy_st_get_symbol(u.ste, k);
        outsc = (outsymbol >> ST_SCOPE_OFFSET) & ST_SCOPE_MASK;
        if (
            scope != outsc
            and scope != ST_FREE
            and not (scope == ST_CELL and outsc == ST_FREE)
        )
            or in_class_block {
            temp = state.temp_symbols;
            if temp is None {
                temp = {};
                state.temp_symbols = temp;
                state.temp_order = [];
            }
            ste_set_symbol(u.ste, k, symbol);
            if k not in temp {
                state.temp_order.append(k);
            }
            temp[k] = outsymbol;
        }
        if ((symbol & ST_DEF_LOCAL) and not (symbol & ST_DEF_NONLOCAL))
            or in_class_block {
            if not cpy_st_is_function_like(u.ste) {
                hidden = u.md.fasthidden;
                orig_true = k in hidden and hidden[k];
                if not orig_true {
                    hidden[k] = True;
                    fh = state.fast_hidden;
                    if fh is None {
                        fh = [];
                        state.fast_hidden = fh;
                    }
                    if k not in fh {
                        fh.append(k);
                    }
                }
            }
        }
    }
}

def cpy_compile_revert_inlined_comprehension_scopes(
    c: cpy_compiler, loc: srcloc, state: cpy_inline_state
) {
    u = c.unit();
    u.in_inlined_comp -= 1;
    temp = state.temp_symbols;
    if temp is not None {
        for k in state.temp_order {
            ste_set_symbol(u.ste, k, temp[k]);
        }
        state.temp_symbols = None;
        state.temp_order = [];
    }
    fh = state.fast_hidden;
    if fh is not None {
        for k in fh {
            u.md.fasthidden[k] = False;
        }
        state.fast_hidden = None;
    }
}

def cpy_compile_add_deferred_annotation(c: cpy_compiler, s: AnnAssign) -> int {
    u = c.unit();
    deferred = u.deferred_annotations;
    if deferred is None {
        deferred = [];
        u.deferred_annotations = deferred;
    }
    indices = u.conditional_annotation_indices;
    if indices is None {
        indices = [];
        u.conditional_annotation_indices = indices;
    }
    deferred.append(s);
    result = -1;
    if u.scope_type == COMPILE_SCOPE_MODULE or u.in_conditional_block {
        result = u.next_conditional_annotation_index;
        u.next_conditional_annotation_index += 1;
    }
    indices.append(result);
    return result;
}

def cpy_compile_error(c: cpy_compiler, loc: srcloc, msg: str) {
    raise syntax_failure(
        msg,
        filename=c.filename,
        lineno=loc.lineno,
        offset=loc.col_offset + 1,
        end_lineno=loc.end_lineno,
        end_offset=loc.end_col_offset + 1
    );
}

def cpy_compile_warn(c: cpy_compiler, loc: srcloc, msg: str) {
    if c.disable_warning {
        return;
    }
    try {
        warn(msg, c.filename, loc.lineno, loc.col_offset);
    } except syntax_failure {
        cpy_compile_error(c, loc, msg);
    }
}

def cpy_compile_mangle(c: cpy_compiler, name: str) -> str {
    return cpy_mangle(c.unit().private, name);
}

def cpy_compile_maybe_mangle(c: cpy_compiler, name: str) -> str {
    u = c.unit();
    return cpy_maybe_mangle(u.private, u.ste, name);
}

def cpy_compile_start_annotation_setup(c: cpy_compiler) {
    u = c.unit();
    u.stashed_seq = u.seq;
    u.seq = instr_seq(instrs=[], labelmap=[], nested=[]);
}

def cpy_compile_end_annotation_setup(c: cpy_compiler) {
    u = c.unit();
    parent_seq = u.stashed_seq;
    if parent_seq is None {
        raise SystemError("no stashed instruction sequence");
    }
    anno_seq = u.seq;
    u.stashed_seq = None;
    u.seq = parent_seq;
    parent_seq.set_annotations_code(anno_seq);
}

def cpy_compile_is_interactive_top_level(c: cpy_compiler) -> bool {
    return c.interactive and len(c.stack) == 0;
}

def cpy_compute_code_flags(c: cpy_compiler) -> int {
    ste = c.unit().ste;
    flags = 0;
    if cpy_st_is_function_like(ste) {
        flags |= CO_NEWLOCALS | CO_OPTIMIZED;
        if ste.nested {
            flags |= CO_NESTED;
        }
        if ste.generator and not ste.coroutine {
            flags |= CO_GENERATOR;
        }
        if ste.generator and ste.coroutine {
            flags |= CO_ASYNC_GENERATOR;
        }
        if ste.varargs {
            flags |= CO_VARARGS;
        }
        if ste.varkeywords {
            flags |= CO_VARKEYWORDS;
        }
        if ste.has_docstring {
            flags |= CO_HAS_DOCSTRING;
        }
        if ste.method {
            flags |= CO_METHOD;
        }
    }
    if ste.coroutine and not ste.generator {
        flags |= CO_COROUTINE;
    }
    flags |= c.flags & PyCF_MASK;
    return flags;
}

def cpy_compile_optimize_and_assemble(c: cpy_compiler, add_none: bool) -> PyCode {
    code_flags = cpy_compute_code_flags(c);
    u = c.unit();
    if add_none {
        u.seq.addop(OP_LOAD_CONST, cpy_compile_add_const(c, py_none()), no_location());
    }
    u.seq.addop(OP_RETURN_VALUE, 0, no_location());
    return cpy_optimize_and_assemble(
        u.seq, u.md, code_flags, len(u.ste.varnames), c.filename
    );
}

def cpy_clean_doc(text: str) -> str {
    doc = cpy_expandtabs(text);
    n = len(doc);
    p = 0;
    while p < n {
        ch = doc[p];
        p += 1;
        if ch == "\n" {
            break;
        }
    }
    margin = -1;
    while p < n {
        s = p;
        while p < n and doc[p] == " " {
            p += 1;
        }
        if p < n and doc[p] != "\n" {
            if margin < 0 or p - s < margin {
                margin = p - s;
            }
        }
        while p < n {
            ch = doc[p];
            p += 1;
            if ch == "\n" {
                break;
            }
        }
    }
    if margin < 0 {
        margin = 0;
    }
    p = 0;
    while p < n and doc[p] == " " {
        p += 1;
    }
    if p == 0 and margin == 0 {
        return doc;
    }
    out: list[str] = [];
    while p < n {
        ch = doc[p];
        out.append(ch);
        p += 1;
        if ch == "\n" {
            break;
        }
    }
    while p < n {
        i = 0;
        while i < margin and p < n {
            if doc[p] != " " {
                break;
            }
            i += 1;
            p += 1;
        }
        while p < n {
            ch = doc[p];
            out.append(ch);
            p += 1;
            if ch == "\n" {
                break;
            }
        }
    }
    return "".join(out);
}

def cpy_expandtabs(text: str) -> str {
    if "\t" not in text {
        return text;
    }
    out: list[str] = [];
    column = 0;
    for ch in text {
        if ch == "\t" {
            spaces = 8 - column % 8;
            out.append(" " * spaces);
            column += spaces;
        } else {
            out.append(ch);
            if ch == "\n" or ch == "\r" {
                column = 0;
            } else {
                column += 1;
            }
        }
    }
    return "".join(out);
}

obj cpy_cf_context {
    has in_finally: bool,
        in_funcdef: bool,
        in_loop: bool;
}

def cpy_control_flow_warnings(filename: str, body: list[stmt]) {
    stack: list[cpy_cf_context] = [];
    cpy_cf_visit_body(filename, body, stack);
}

def cpy_cf_visit_body(filename: str, body: list[stmt], stack: list[cpy_cf_context]) {
    for s in body {
        cpy_cf_visit_stmt(filename, s, stack);
    }
}

def cpy_cf_warn(filename: str, kw: str, s: stmt) {
    msg = "'" + kw + "' in a 'finally' block";
    try {
        warn(msg, filename, s.lineno, s.col_offset);
    } except syntax_failure {
        loc = stmt_loc(s);
        raise syntax_failure(
            msg,
            filename=filename,
            lineno=loc.lineno,
            offset=loc.col_offset + 1,
            end_lineno=loc.end_lineno,
            end_offset=loc.end_col_offset + 1
        );
    }
}

def cpy_cf_visit_scoped(
    filename: str,
    body: list[stmt],
    stack: list[cpy_cf_context],
    in_finally: bool,
    in_funcdef: bool,
    in_loop: bool
) {
    stack.append(
        cpy_cf_context(in_finally=in_finally, in_funcdef=in_funcdef, in_loop=in_loop)
    );
    cpy_cf_visit_body(filename, body, stack);
    stack.pop();
}

def cpy_cf_visit_stmt(filename: str, s: stmt, stack: list[cpy_cf_context]) {
    if isinstance(s, FunctionDef) {
        cpy_cf_visit_scoped(filename, s.body, stack, False, True, False);
    } elif isinstance(s, AsyncFunctionDef) {
        cpy_cf_visit_scoped(filename, s.body, stack, False, True, False);
    } elif isinstance(s, ClassDef) {
        cpy_cf_visit_body(filename, s.body, stack);
    } elif isinstance(s, Return) {
        if len(stack) > 0 {
            top = stack[len(stack) - 1];
            if top.in_finally and not top.in_funcdef {
                cpy_cf_warn(filename, "return", s);
            }
        }
    } elif isinstance(s, For) {
        cpy_cf_visit_scoped(filename, s.body, stack, False, False, True);
        cpy_cf_visit_body(filename, s.orelse, stack);
    } elif isinstance(s, AsyncFor) {
        cpy_cf_visit_scoped(filename, s.body, stack, False, False, True);
        cpy_cf_visit_body(filename, s.orelse, stack);
    } elif isinstance(s, While) {
        cpy_cf_visit_scoped(filename, s.body, stack, False, False, True);
        cpy_cf_visit_body(filename, s.orelse, stack);
    } elif isinstance(s, If) {
        cpy_cf_visit_body(filename, s.body, stack);
        cpy_cf_visit_body(filename, s.orelse, stack);
    } elif isinstance(s, With) {
        cpy_cf_visit_body(filename, s.body, stack);
    } elif isinstance(s, AsyncWith) {
        cpy_cf_visit_body(filename, s.body, stack);
    } elif isinstance(s, Try) {
        cpy_cf_visit_body(filename, s.body, stack);
        for h in s.handlers {
            cpy_cf_visit_body(filename, h.body, stack);
        }
        cpy_cf_visit_body(filename, s.orelse, stack);
        cpy_cf_visit_scoped(filename, s.finalbody, stack, True, False, False);
    } elif isinstance(s, TryStar) {
        cpy_cf_visit_body(filename, s.body, stack);
        for h in s.handlers {
            cpy_cf_visit_body(filename, h.body, stack);
        }
        cpy_cf_visit_body(filename, s.orelse, stack);
        cpy_cf_visit_scoped(filename, s.finalbody, stack, True, False, False);
    } elif isinstance(s, Match) {
        for mc in s.cases {
            cpy_cf_visit_body(filename, mc.body, stack);
        }
    } elif isinstance(s, Break) or isinstance(s, Continue) {
        if len(stack) > 0 {
            top = stack[len(stack) - 1];
            if top.in_finally and not top.in_loop {
                cpy_cf_warn(
                    filename, "break" if isinstance(s, Break) else "continue", s
                );
            }
        }
    }
}
