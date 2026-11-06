# Symbol tables for the JacPython compiler: a port of CPython 3.14's
# Python/symtable.c and Include/internal/pycore_symtable.h, with the future
# statement location record of Python/future.c. Entries are keyed as CPython
# keys st_blocks by AST node address (cpy_st_key).

glob ST_DEF_GLOBAL: int = 1,
     ST_DEF_LOCAL: int = 2,
     ST_DEF_PARAM: int = 4,
     ST_DEF_NONLOCAL: int = 8,
     ST_USE: int = 16,
     ST_DEF_FREE_CLASS: int = 64,
     ST_DEF_IMPORT: int = 128,
     ST_DEF_ANNOT: int = 256,
     ST_DEF_COMP_ITER: int = 512,
     ST_DEF_TYPE_PARAM: int = 1024,
     ST_DEF_COMP_CELL: int = 2048,
     ST_DEF_BOUND: int = 134,
     ST_SCOPE_OFFSET: int = 12,
     ST_SCOPE_MASK: int = 15,
     ST_LOCAL: int = 1,
     ST_GLOBAL_EXPLICIT: int = 2,
     ST_GLOBAL_IMPLICIT: int = 3,
     ST_FREE: int = 4,
     ST_CELL: int = 5;

glob FunctionBlock: int = 0,
     ClassBlock: int = 1,
     ModuleBlock: int = 2,
     AnnotationBlock: int = 3,
     TypeAliasBlock: int = 4,
     TypeParametersBlock: int = 5,
     TypeVariableBlock: int = 6;

glob NoComprehension: int = 0,
     ListComprehension: int = 1,
     DictComprehension: int = 2,
     SetComprehension: int = 3,
     GeneratorExpression: int = 4;

glob ST_CTX_LOAD: int = 1,
     ST_CTX_STORE: int = 2,
     ST_CTX_DEL: int = 3;

glob ST_CO_FUTURE_ANNOTATIONS: int = 0x1000000,
     ST_PyCF_ALLOW_TOP_LEVEL_AWAIT: int = 0x2000,
     ST_RECURSION_LIMIT: int = 3000;

obj cpy_directive {
    has name: str,
        loc: srcloc;
}

obj cpy_ste {
    has id: int,
        name: str,
        ste_type: int,
        loc: srcloc,
        symbols: dict[str, int] = {},
        symbol_order: list[str] = [],
        varnames: list[str] = [],
        children: list[cpy_ste] = [],
        directives: list[cpy_directive] | None = None,
        mangled_names: set[str] | None = None,
        scope_info: str = "",
        nested: int = 0,
        generator: int = 0,
        coroutine: int = 0,
        annotations_used: int = 0,
        comprehension: int = 0,
        varargs: int = 0,
        varkeywords: int = 0,
        returns_value: int = 0,
        needs_class_closure: int = 0,
        needs_classdict: int = 0,
        comp_inlined: int = 0,
        comp_iter_target: int = 0,
        can_see_class_scope: int = 0,
        has_docstring: int = 0,
        method: int = 0,
        has_conditional_annotations: int = 0,
        in_conditional_block: int = 0,
        in_unevaluated_annotation: int = 0,
        comp_iter_expr: int = 0,
        annotation_block: cpy_ste | None = None;
}

obj cpy_symtable {
    has filename: str,
        future_features: int,
        future_location: srcloc,
        top: cpy_ste | None = None,
        cur: cpy_ste | None = None,
        global_ste: cpy_ste | None = None,
        blocks: dict[int, cpy_ste] = {},
        block_order: list[cpy_ste] = [],
        stack: list[cpy_ste] = [],
        private: str | None = None,
        depth: int = 0;

    def current -> cpy_ste {
        ste = self.cur;
        if ste is None {
            raise RuntimeError("symbol table has no current block");
        }
        return ste;
    }

    def module_entry -> cpy_ste {
        ste = self.global_ste;
        if ste is None {
            raise RuntimeError("symbol table has no module block");
        }
        return ste;
    }
}

def cpy_st_key(key_node: any, plus: int = 0) -> int {
    return id(key_node) * 4 + plus;
}

def st_location(
    lineno: int, col_offset: int, end_lineno: int | None, end_col_offset: int | None
) -> srcloc {
    return mkloc(
        lineno,
        end_lineno if end_lineno is not None else lineno,
        col_offset,
        end_col_offset if end_col_offset is not None else col_offset
    );
}

def stmt_loc(s: stmt) -> srcloc {
    return st_location(s.lineno, s.col_offset, s.end_lineno, s.end_col_offset);
}

def expr_loc(e: expr) -> srcloc {
    return st_location(e.lineno, e.col_offset, e.end_lineno, e.end_col_offset);
}

def pattern_loc(p: pattern) -> srcloc {
    return st_location(p.lineno, p.col_offset, p.end_lineno, p.end_col_offset);
}

def type_param_loc(tp: type_param) -> srcloc {
    return st_location(tp.lineno, tp.col_offset, tp.end_lineno, tp.end_col_offset);
}

def arg_loc(a: arg) -> srcloc {
    return st_location(a.lineno, a.col_offset, a.end_lineno, a.end_col_offset);
}

def keyword_loc(k: keyword) -> srcloc {
    return st_location(k.lineno, k.col_offset, k.end_lineno, k.end_col_offset);
}

def alias_loc(a: alias) -> srcloc {
    return st_location(a.lineno, a.col_offset, a.end_lineno, a.end_col_offset);
}

def handler_loc(h: excepthandler) -> srcloc {
    return st_location(h.lineno, h.col_offset, h.end_lineno, h.end_col_offset);
}

def st_syntax_error(st: cpy_symtable, msg: str, loc: srcloc) -> syntax_failure {
    return syntax_failure(
        msg,
        filename=st.filename,
        lineno=loc.lineno,
        offset=loc.col_offset + 1,
        end_lineno=loc.end_lineno,
        end_offset=loc.end_col_offset + 1
    );
}

def ast_docstring(body: list[stmt]) -> bool {
    if len(body) == 0 {
        return False;
    }
    first = body[0];
    if not isinstance(first, Expr) {
        return False;
    }
    value = first.value;
    return isinstance(value, Constant) and isinstance(value.value, PyStr);
}

def st_ctx(ctx: expr_context) -> int {
    if isinstance(ctx, Store) {
        return ST_CTX_STORE;
    }
    if isinstance(ctx, Del) {
        return ST_CTX_DEL;
    }
    return ST_CTX_LOAD;
}

def ste_set_symbol(ste: cpy_ste, name: str, flags: int) {
    if name not in ste.symbols {
        ste.symbol_order.append(name);
    }
    ste.symbols[name] = flags;
}

def ste_del_symbol(ste: cpy_ste, name: str) {
    if name not in ste.symbols {
        raise KeyError(name);
    }
    del ste.symbols[name];
    ste.symbol_order.remove(name);
}

def ste_new(st: cpy_symtable, name: str, block: int, key: int, loc: srcloc) -> cpy_ste {
    ste = cpy_ste(id=key, name=name, ste_type=block, loc=loc);
    cur = st.cur;
    if cur is not None and (cur.nested or cpy_st_is_function_like(cur)) {
        ste.nested = 1;
    }
    if cur is not None and cur.ste_type == ClassBlock and block == FunctionBlock {
        ste.method = 1;
    }
    st.blocks[key] = ste;
    st.block_order.append(ste);
    return ste;
}

def cpy_symtable_build(
    m: mod, filename: str, future_features: int, future_location: srcloc | None = None
) -> cpy_symtable {
    location = future_location
        if future_location is not None
        else cpy_future_location(m);
    st = cpy_symtable(
        filename=filename, future_features=future_features, future_location=location
    );
    symtable_enter_block(st, "top", ModuleBlock, cpy_st_key(m), mkloc(0, 0, 0, 0));
    top = st.current();
    st.top = top;
    if isinstance(m, Module) {
        if ast_docstring(m.body) {
            top.has_docstring = 1;
        }
        for s in m.body {
            symtable_visit_stmt(st, s);
        }
    } elif isinstance(m, Expression) {
        symtable_visit_expr(st, m.body);
    } elif isinstance(m, Interactive) {
        for s in m.body {
            symtable_visit_stmt(st, s);
        }
    } elif isinstance(m, FunctionType) {
        raise RuntimeError("this compiler does not handle FunctionTypes");
    }
    symtable_exit_block(st);
    symtable_analyze(st);
    return st;
}

def cpy_future_location(m: mod) -> srcloc {
    location = mkloc(-1, -1, -1, -1);
    body: list[stmt] = [];
    if isinstance(m, Module) {
        body = m.body;
    } elif isinstance(m, Interactive) {
        body = m.body;
    } else {
        return location;
    }
    n = len(body);
    if n == 0 {
        return location;
    }
    i = 0;
    if ast_docstring(body) {
        i += 1;
    }
    while i < n {
        s = body[i];
        if isinstance(s, ImportFrom)
            and (s.level if s.level is not None else 0) == 0
            and s.module is not None
            and s.module == "__future__" {
            location = stmt_loc(s);
        } else {
            return location;
        }
        i += 1;
    }
    return location;
}

def cpy_symtable_lookup(st: cpy_symtable, key: int) -> cpy_ste {
    if key not in st.blocks {
        raise KeyError("unknown symbol table entry");
    }
    return st.blocks[key];
}

def cpy_symtable_lookup_optional(st: cpy_symtable, key: int) -> cpy_ste | None {
    if key not in st.blocks {
        return None;
    }
    return st.blocks[key];
}

def cpy_st_get_symbol(ste: cpy_ste, name: str) -> int {
    if name not in ste.symbols {
        return 0;
    }
    return ste.symbols[name];
}

def cpy_st_get_scope(ste: cpy_ste, name: str) -> int {
    return (cpy_st_get_symbol(ste, name) >> ST_SCOPE_OFFSET) & ST_SCOPE_MASK;
}

def cpy_st_is_function_like(ste: cpy_ste) -> bool {
    return ste.ste_type == FunctionBlock
        or ste.ste_type == AnnotationBlock
        or ste.ste_type == TypeVariableBlock
        or ste.ste_type == TypeAliasBlock
        or ste.ste_type == TypeParametersBlock;
}

def error_at_directive(st: cpy_symtable, ste: cpy_ste, name: str, msg: str) {
    directives = ste.directives;
    if directives is not None {
        for data in directives {
            if data.name == name {
                raise st_syntax_error(st, msg, data.loc);
            }
        }
    }
    raise RuntimeError("BUG: internal directive bookkeeping broken");
}

def analyze_name(
    st: cpy_symtable,
    ste: cpy_ste,
    scopes: dict[str, int],
    name: str,
    flags: int,
    bound: set[str] | None,
    local: set[str],
    free: set[str],
    global_names: set[str],
    type_params: set[str],
    class_entry: cpy_ste | None
) {
    if flags & ST_DEF_GLOBAL {
        if flags & ST_DEF_NONLOCAL {
            error_at_directive(st, ste, name, f"name '{name}' is nonlocal and global");
        }
        scopes[name] = ST_GLOBAL_EXPLICIT;
        global_names.add(name);
        if bound is not None {
            bound.discard(name);
        }
        return;
    }
    if flags & ST_DEF_NONLOCAL {
        if bound is None {
            error_at_directive(
                st, ste, name, "nonlocal declaration not allowed at module level"
            );
            return;
        }
        if name not in bound {
            error_at_directive(
                st, ste, name, f"no binding for nonlocal '{name}' found"
            );
        }
        if name in type_params {
            error_at_directive(
                st,
                ste,
                name,
                f"nonlocal binding not allowed for type parameter '{name}'"
            );
        }
        scopes[name] = ST_FREE;
        free.add(name);
        return;
    }
    if flags & ST_DEF_BOUND {
        scopes[name] = ST_LOCAL;
        local.add(name);
        global_names.discard(name);
        if flags & ST_DEF_TYPE_PARAM {
            type_params.add(name);
        } else {
            type_params.discard(name);
        }
        return;
    }
    if class_entry is not None {
        class_flags = cpy_st_get_symbol(class_entry, name);
        if class_flags & ST_DEF_GLOBAL {
            scopes[name] = ST_GLOBAL_EXPLICIT;
            return;
        } elif (class_flags & ST_DEF_BOUND) and not (class_flags & ST_DEF_NONLOCAL) {
            scopes[name] = ST_GLOBAL_IMPLICIT;
            return;
        }
    }
    if bound is not None and name in bound {
        scopes[name] = ST_FREE;
        free.add(name);
        return;
    }
    if name in global_names {
        scopes[name] = ST_GLOBAL_IMPLICIT;
        return;
    }
    scopes[name] = ST_GLOBAL_IMPLICIT;
}

def is_free_in_any_child(comp: cpy_ste, key: str) -> bool {
    for child_ste in comp.children {
        if cpy_st_get_scope(child_ste, key) == ST_FREE {
            return True;
        }
    }
    return False;
}

def inline_comprehension(
    ste: cpy_ste,
    comp: cpy_ste,
    scopes: dict[str, int],
    comp_free: set[str],
    inlined_cells: set[str]
) {
    remove_dunder_class = False;
    remove_dunder_classdict = False;
    remove_dunder_cond_annotations = False;
    for k in list(comp.symbol_order) {
        comp_flags = comp.symbols[k];
        if comp_flags & ST_DEF_PARAM {
            continue;
        }
        scope = (comp_flags >> ST_SCOPE_OFFSET) & ST_SCOPE_MASK;
        only_flags = comp_flags & ((1 << ST_SCOPE_OFFSET) - 1);
        if scope == ST_CELL or only_flags & ST_DEF_COMP_CELL {
            inlined_cells.add(k);
        }
        existing = k in ste.symbols;
        if scope == ST_FREE
            and ste.ste_type == ClassBlock
            and (
                k == "__class__"
                or k == "__classdict__"
                or k == "__conditional_annotations__"
            ) {
            scope = ST_GLOBAL_IMPLICIT;
            if not is_free_in_any_child(comp, k) {
                comp_free.discard(k);
            }
            if k == "__class__" {
                remove_dunder_class = True;
            } elif k == "__conditional_annotations__" {
                remove_dunder_cond_annotations = True;
            } else {
                remove_dunder_classdict = True;
            }
        }
        if not existing {
            ste_set_symbol(ste, k, only_flags);
            scopes[k] = scope;
        } else {
            flags = ste.symbols[k];
            if (flags & ST_DEF_BOUND) and ste.ste_type != ClassBlock {
                if not is_free_in_any_child(comp, k) {
                    comp_free.discard(k);
                }
            }
        }
    }
    if remove_dunder_class {
        ste_del_symbol(comp, "__class__");
    }
    if remove_dunder_classdict {
        ste_del_symbol(comp, "__classdict__");
    }
    if remove_dunder_cond_annotations {
        ste_del_symbol(comp, "__conditional_annotations__");
    }
}

def analyze_cells(scopes: dict[str, int], free: set[str], inlined_cells: set[str]) {
    for name in list(scopes.keys()) {
        if scopes[name] != ST_LOCAL {
            continue;
        }
        if name not in free and name not in inlined_cells {
            continue;
        }
        scopes[name] = ST_CELL;
        free.discard(name);
    }
}

def drop_class_free(ste: cpy_ste, free: set[str]) {
    if "__class__" in free {
        free.discard("__class__");
        ste.needs_class_closure = 1;
    }
    if "__classdict__" in free {
        free.discard("__classdict__");
        ste.needs_classdict = 1;
    }
    if "__conditional_annotations__" in free {
        free.discard("__conditional_annotations__");
        ste.has_conditional_annotations = 1;
    }
}

def update_symbols(
    ste: cpy_ste,
    scopes: dict[str, int],
    bound: set[str] | None,
    free: set[str],
    inlined_cells: set[str],
    classflag: bool
) {
    for name in list(ste.symbol_order) {
        flags = ste.symbols[name];
        if name in inlined_cells {
            flags |= ST_DEF_COMP_CELL;
        }
        if name not in scopes {
            raise KeyError(name);
        }
        flags |= scopes[name] << ST_SCOPE_OFFSET;
        ste.symbols[name] = flags;
    }
    for name in sorted(free) {
        if name in ste.symbols {
            if classflag {
                ste.symbols[name] = ste.symbols[name] | ST_DEF_FREE_CLASS;
            }
            continue;
        }
        if bound is not None and name not in bound {
            continue;
        }
        ste_set_symbol(ste, name, ST_FREE << ST_SCOPE_OFFSET);
    }
}

def analyze_block(
    st: cpy_symtable,
    ste: cpy_ste,
    bound: set[str] | None,
    free: set[str],
    global_names: set[str],
    type_params: set[str],
    class_entry: cpy_ste | None
) {
    local: set[str] = set();
    scopes: dict[str, int] = {};
    newglobal: set[str] = set();
    newfree: set[str] = set();
    newbound: set[str] = set();
    inlined_cells: set[str] = set();
    if ste.ste_type == ClassBlock {
        newglobal.update(global_names);
        if bound is not None {
            newbound.update(bound);
        }
    }
    for name in list(ste.symbol_order) {
        analyze_name(
            st,
            ste,
            scopes,
            name,
            ste.symbols[name],
            bound,
            local,
            free,
            global_names,
            type_params,
            class_entry
        );
    }
    if ste.ste_type != ClassBlock {
        if cpy_st_is_function_like(ste) {
            newbound.update(local);
        }
        if bound is not None {
            newbound.update(bound);
        }
        newglobal.update(global_names);
    } else {
        newbound.add("__class__");
        newbound.add("__classdict__");
        newbound.add("__conditional_annotations__");
    }
    i = 0;
    while i < len(ste.children) {
        child = ste.children[i];
        new_class_entry: cpy_ste | None = None;
        if child.can_see_class_scope {
            if ste.ste_type == ClassBlock {
                new_class_entry = ste;
            } elif class_entry is not None {
                new_class_entry = class_entry;
            }
        }
        inline_comp = child.comprehension != NoComprehension
            and not child.generator
            and not ste.can_see_class_scope;
        child_free = analyze_child_block(
            st, child, newbound, newfree, newglobal, type_params, new_class_entry
        );
        if inline_comp {
            inline_comprehension(ste, child, scopes, child_free, inlined_cells);
            child.comp_inlined = 1;
        }
        newfree.update(child_free);
        i += 1;
    }
    i = len(ste.children) - 1;
    while i >= 0 {
        child = ste.children[i];
        if child.comp_inlined {
            ste.children = ste.children[:i] + child.children + ste.children[i + 1:];
        }
        i -= 1;
    }
    if cpy_st_is_function_like(ste) {
        analyze_cells(scopes, newfree, inlined_cells);
    } elif ste.ste_type == ClassBlock {
        drop_class_free(ste, newfree);
    }
    update_symbols(
        ste,
        scopes,
        bound,
        newfree,
        inlined_cells,
        ste.ste_type == ClassBlock or bool(ste.can_see_class_scope)
    );
    free.update(newfree);
}

def analyze_child_block(
    st: cpy_symtable,
    child: cpy_ste,
    bound: set[str],
    free: set[str],
    global_names: set[str],
    type_params: set[str],
    class_entry: cpy_ste | None
) -> set[str] {
    temp_bound: set[str] = set(bound);
    temp_free: set[str] = set(free);
    temp_global: set[str] = set(global_names);
    temp_type_params: set[str] = set(type_params);
    analyze_block(
        st, child, temp_bound, temp_free, temp_global, temp_type_params, class_entry
    );
    return temp_free;
}

def symtable_analyze(st: cpy_symtable) {
    top = st.top;
    if top is None {
        raise RuntimeError("symbol table has no top block");
    }
    free: set[str] = set();
    global_names: set[str] = set();
    type_params: set[str] = set();
    analyze_block(st, top, None, free, global_names, type_params, None);
}

def symtable_exit_block(st: cpy_symtable) {
    st.cur = None;
    size = len(st.stack);
    if size {
        st.stack.pop();
        size -= 1;
        if size {
            st.cur = st.stack[size - 1];
        }
    }
}

def symtable_enter_existing_block(
    st: cpy_symtable, ste: cpy_ste, add_to_children: bool
) {
    st.stack.append(ste);
    prev = st.cur;
    if prev is not None {
        ste.comp_iter_expr = prev.comp_iter_expr;
        if prev.mangled_names is not None and ste.ste_type != ClassBlock {
            ste.mangled_names = prev.mangled_names;
        }
    }
    st.cur = ste;
    if st.future_features & ST_CO_FUTURE_ANNOTATIONS
        and ste.ste_type == AnnotationBlock {
        return;
    }
    if ste.ste_type == ModuleBlock {
        st.global_ste = ste;
    }
    if add_to_children and prev is not None {
        prev.children.append(ste);
    }
}

def symtable_enter_block(
    st: cpy_symtable, name: str, block: int, key: int, loc: srcloc
) {
    ste = ste_new(st, name, block, key, loc);
    symtable_enter_existing_block(st, ste, True);
    if block == AnnotationBlock
        or block == TypeVariableBlock
        or block == TypeAliasBlock {
        symtable_add_def(st, ".format", ST_DEF_PARAM, loc);
        symtable_add_def(st, ".format", ST_USE, loc);
    }
}

def symtable_lookup_entry(st: cpy_symtable, ste: cpy_ste, name: str) -> int {
    return cpy_st_get_symbol(ste, cpy_maybe_mangle(st.private, ste, name));
}

def symtable_lookup(st: cpy_symtable, name: str) -> int {
    return symtable_lookup_entry(st, st.current(), name);
}

def symtable_add_def_helper(
    st: cpy_symtable, name: str, flag: int, ste: cpy_ste, loc: srcloc
) {
    mangled = cpy_maybe_mangle(st.private, st.current(), name);
    val = flag;
    if mangled in ste.symbols {
        val = ste.symbols[mangled];
        if (flag & ST_DEF_PARAM) and (val & ST_DEF_PARAM) {
            raise st_syntax_error(
                st, f"duplicate argument '{name}' in function definition", loc
            );
        }
        if (flag & ST_DEF_TYPE_PARAM) and (val & ST_DEF_TYPE_PARAM) {
            raise st_syntax_error(st, f"duplicate type parameter '{name}'", loc);
        }
        val |= flag;
    }
    if ste.comp_iter_target {
        if val & (ST_DEF_GLOBAL | ST_DEF_NONLOCAL) {
            raise st_syntax_error(
                st,
                f"comprehension inner loop cannot rebind assignment expression target '{name}'",
                loc
            );
        }
        val |= ST_DEF_COMP_ITER;
    }
    ste_set_symbol(ste, mangled, val);
    if flag & ST_DEF_PARAM {
        ste.varnames.append(mangled);
    } elif flag & ST_DEF_GLOBAL {
        module = st.module_entry();
        ste_set_symbol(module, mangled, cpy_st_get_symbol(module, mangled) | flag);
    }
}

def check_name(st: cpy_symtable, name: str, loc: srcloc, ctx: int) {
    if ctx == ST_CTX_STORE and name == "__debug__" {
        raise st_syntax_error(st, "cannot assign to __debug__", loc);
    }
    if ctx == ST_CTX_DEL and name == "__debug__" {
        raise st_syntax_error(st, "cannot delete __debug__", loc);
    }
}

def check_keywords(st: cpy_symtable, keywords: list[keyword]) {
    for key in keywords {
        key_arg = key.arg;
        if key_arg is not None {
            check_name(st, key_arg, keyword_loc(key), ST_CTX_STORE);
        }
    }
}

def check_kwd_patterns(st: cpy_symtable, p: MatchClass) {
    i = 0;
    while i < len(p.kwd_attrs) {
        check_name(st, p.kwd_attrs[i], pattern_loc(p.kwd_patterns[i]), ST_CTX_STORE);
        i += 1;
    }
}

def symtable_add_def_ctx(
    st: cpy_symtable, name: str, flag: int, loc: srcloc, ctx: int
) {
    write_mask = ST_DEF_PARAM | ST_DEF_LOCAL | ST_DEF_IMPORT;
    if flag & write_mask {
        check_name(st, name, loc, ctx);
    }
    cur = st.current();
    if flag & ST_DEF_TYPE_PARAM {
        mangled_names = cur.mangled_names;
        if mangled_names is not None {
            mangled_names.add(name);
        }
    }
    symtable_add_def_helper(st, name, flag, cur, loc);
}

def symtable_add_def(st: cpy_symtable, name: str, flag: int, loc: srcloc) {
    symtable_add_def_ctx(
        st, name, flag, loc, ST_CTX_LOAD if flag == ST_USE else ST_CTX_STORE
    );
}

def symtable_enter_type_param_block(
    st: cpy_symtable,
    name: str,
    key: int,
    has_defaults: bool,
    has_kwdefaults: bool,
    is_class: bool,
    loc: srcloc
) {
    current_type = st.current().ste_type;
    symtable_enter_block(st, name, TypeParametersBlock, key, loc);
    if current_type == ClassBlock {
        st.current().can_see_class_scope = 1;
        symtable_add_def(st, "__classdict__", ST_USE, loc);
    }
    if is_class {
        symtable_add_def(st, ".type_params", ST_DEF_LOCAL, loc);
        symtable_add_def(st, ".type_params", ST_USE, loc);
        symtable_add_def(st, ".generic_base", ST_DEF_LOCAL, loc);
        symtable_add_def(st, ".generic_base", ST_USE, loc);
    }
    if has_defaults {
        symtable_add_def(st, ".defaults", ST_DEF_PARAM, loc);
    }
    if has_kwdefaults {
        symtable_add_def(st, ".kwdefaults", ST_DEF_PARAM, loc);
    }
}

def symtable_enter_recursive(st: cpy_symtable) {
    st.depth += 1;
    if st.depth > ST_RECURSION_LIMIT {
        raise RecursionError("maximum recursion depth exceeded during compilation");
    }
}

def symtable_record_directive(st: cpy_symtable, name: str, loc: srcloc) {
    cur = st.current();
    directives = cur.directives;
    if directives is None {
        directives = [];
        cur.directives = directives;
    }
    mangled = cpy_maybe_mangle(st.private, cur, name);
    directives.append(cpy_directive(name=mangled, loc=loc));
}

def has_kwonlydefaults(kwonlyargs: list[arg], kw_defaults: list[expr | None]) -> bool {
    i = 0;
    while i < len(kwonlyargs) {
        if kw_defaults[i] is not None {
            return True;
        }
        i += 1;
    }
    return False;
}

def check_import_from(st: cpy_symtable, s: ImportFrom) {
    fut = st.future_location;
    level = s.level if s.level is not None else 0;
    if s.module is not None
        and level == 0
        and s.module == "__future__"
        and (
            (s.lineno > fut.lineno)
            or (s.lineno == fut.end_lineno and s.col_offset > fut.end_col_offset)
        ) {
        raise st_syntax_error(
            st,
            "from __future__ imports must occur at the beginning of the file",
            stmt_loc(s)
        );
    }
}

def allows_top_level_await(st: cpy_symtable) -> bool {
    return bool(st.future_features & ST_PyCF_ALLOW_TOP_LEVEL_AWAIT)
        and st.current().ste_type == ModuleBlock;
}

def maybe_set_ste_coroutine_for_module(st: cpy_symtable) {
    if allows_top_level_await(st) {
        st.current().coroutine = 1;
    }
}

def is_async_def(st: cpy_symtable) -> bool {
    cur = st.current();
    return cur.ste_type == FunctionBlock and bool(cur.coroutine);
}

def symtable_visit_stmts(st: cpy_symtable, body: list[stmt]) {
    for s in body {
        symtable_visit_stmt(st, s);
    }
}

def symtable_visit_exprs(st: cpy_symtable, values: list[expr]) {
    for e in values {
        symtable_visit_expr(st, e);
    }
}

def symtable_visit_optional_exprs(st: cpy_symtable, values: list[expr | None]) {
    for e in values {
        if e is not None {
            symtable_visit_expr(st, e);
        }
    }
}

def symtable_visit_patterns(st: cpy_symtable, patterns: list[pattern]) {
    for p in patterns {
        symtable_visit_pattern(st, p);
    }
}

def symtable_visit_function(
    st: cpy_symtable,
    s: stmt,
    name: str,
    args: arguments,
    body: list[stmt],
    decorator_list: list[expr],
    returns: expr | None,
    type_params: list[type_param],
    is_async: bool
) {
    loc = stmt_loc(s);
    symtable_add_def(st, name, ST_DEF_LOCAL, loc);
    symtable_visit_exprs(st, args.defaults);
    symtable_visit_optional_exprs(st, args.kw_defaults);
    symtable_visit_exprs(st, decorator_list);
    if len(type_params) > 0 {
        symtable_enter_type_param_block(
            st,
            name,
            cpy_st_key(type_params),
            True,
            has_kwonlydefaults(args.kwonlyargs, args.kw_defaults),
            False,
            loc
        );
        for tp in type_params {
            symtable_visit_type_param(st, tp);
        }
    }
    new_ste = ste_new(st, name, FunctionBlock, cpy_st_key(s), loc);
    if ast_docstring(body) {
        new_ste.has_docstring = 1;
    }
    symtable_visit_annotations(st, s, args, returns);
    symtable_enter_existing_block(st, new_ste, True);
    if is_async {
        st.current().coroutine = 1;
    }
    symtable_visit_arguments(st, args);
    symtable_visit_stmts(st, body);
    symtable_exit_block(st);
    if len(type_params) > 0 {
        symtable_exit_block(st);
    }
}

def symtable_visit_classdef(st: cpy_symtable, s: ClassDef) {
    loc = stmt_loc(s);
    symtable_add_def(st, s.name, ST_DEF_LOCAL, loc);
    symtable_visit_exprs(st, s.decorator_list);
    tmp = st.private;
    if len(s.type_params) > 0 {
        symtable_enter_type_param_block(
            st, s.name, cpy_st_key(s.type_params), False, False, True, loc
        );
        st.private = s.name;
        st.current().mangled_names = set();
        for tp in s.type_params {
            symtable_visit_type_param(st, tp);
        }
    }
    symtable_visit_exprs(st, s.bases);
    check_keywords(st, s.keywords);
    for k in s.keywords {
        symtable_visit_expr(st, k.value);
    }
    symtable_enter_block(st, s.name, ClassBlock, cpy_st_key(s), loc);
    st.private = s.name;
    if len(s.type_params) > 0 {
        symtable_add_def(st, "__type_params__", ST_DEF_LOCAL, loc);
        symtable_add_def(st, ".type_params", ST_USE, loc);
    }
    if ast_docstring(s.body) {
        st.current().has_docstring = 1;
    }
    symtable_visit_stmts(st, s.body);
    symtable_exit_block(st);
    if len(s.type_params) > 0 {
        symtable_exit_block(st);
    }
    st.private = tmp;
}

def symtable_visit_typealias(st: cpy_symtable, s: TypeAlias) {
    symtable_visit_expr(st, s.name);
    target = s.name;
    if not isinstance(target, Name) {
        raise RuntimeError("type alias name must be a Name");
    }
    name = target.id;
    is_in_class = st.current().ste_type == ClassBlock;
    is_generic = len(s.type_params) > 0;
    loc = stmt_loc(s);
    if is_generic {
        symtable_enter_type_param_block(
            st, name, cpy_st_key(s.type_params), False, False, False, loc
        );
        for tp in s.type_params {
            symtable_visit_type_param(st, tp);
        }
    }
    symtable_enter_block(st, name, TypeAliasBlock, cpy_st_key(s), loc);
    st.current().can_see_class_scope = 1 if is_in_class else 0;
    if is_in_class {
        symtable_add_def(st, "__classdict__", ST_USE, expr_loc(s.value));
    }
    symtable_visit_expr(st, s.value);
    symtable_exit_block(st);
    if is_generic {
        symtable_exit_block(st);
    }
}

def symtable_visit_annassign(st: cpy_symtable, s: AnnAssign) {
    cur = st.current();
    cur.annotations_used = 1;
    target = s.target;
    if isinstance(target, Name) {
        cur_flags = symtable_lookup(st, target.id);
        if (cur_flags & (ST_DEF_GLOBAL | ST_DEF_NONLOCAL))
            and cur is not st.global_ste
            and s.simple {
            msg = f"annotated name '{target.id}' can't be global"
                if cur_flags & ST_DEF_GLOBAL
                else f"annotated name '{target.id}' can't be nonlocal";
            raise st_syntax_error(st, msg, stmt_loc(s));
        }
        if s.simple {
            symtable_add_def(
                st, target.id, ST_DEF_ANNOT | ST_DEF_LOCAL, expr_loc(target)
            );
        }
        if s.value is not None {
            symtable_add_def(st, target.id, ST_DEF_LOCAL, expr_loc(target));
        }
    } else {
        symtable_visit_expr(st, target);
    }
    symtable_visit_annotation(st, s.annotation, cur.id + 1);
    value = s.value;
    if value is not None {
        symtable_visit_expr(st, value);
    }
}

def symtable_visit_directive(
    st: cpy_symtable, s: stmt, names: list[str], is_global: bool
) {
    loc = stmt_loc(s);
    word = "global" if is_global else "nonlocal";
    for name in names {
        cur_flags = symtable_lookup(st, name);
        if cur_flags & (ST_DEF_PARAM | ST_DEF_LOCAL | ST_USE | ST_DEF_ANNOT) {
            msg = "";
            if cur_flags & ST_DEF_PARAM {
                msg = f"name '{name}' is parameter and {word}";
            } elif cur_flags & ST_USE {
                msg = f"name '{name}' is used prior to {word} declaration";
            } elif cur_flags & ST_DEF_ANNOT {
                msg = f"annotated name '{name}' can't be {word}";
            } else {
                msg = f"name '{name}' is assigned to before {word} declaration";
            }
            raise st_syntax_error(st, msg, loc);
        }
        symtable_add_def(
            st, name, ST_DEF_GLOBAL if is_global else ST_DEF_NONLOCAL, loc
        );
        symtable_record_directive(st, name, loc);
    }
}

def symtable_visit_stmt(st: cpy_symtable, s: stmt) {
    symtable_enter_recursive(st);
    if isinstance(s, Expr) {
        symtable_visit_expr(st, s.value);
    } elif isinstance(s, Assign) {
        symtable_visit_exprs(st, s.targets);
        symtable_visit_expr(st, s.value);
    } elif isinstance(s, If) {
        symtable_visit_expr(st, s.`test);
        cur = st.current();
        in_conditional_block = cur.in_conditional_block;
        cur.in_conditional_block = 1;
        symtable_visit_stmts(st, s.body);
        symtable_visit_stmts(st, s.orelse);
        cur.in_conditional_block = in_conditional_block;
    } elif isinstance(s, Return) {
        value = s.value;
        if value is not None {
            symtable_visit_expr(st, value);
            st.current().returns_value = 1;
        }
    } elif isinstance(s, FunctionDef) {
        symtable_visit_function(
            st,
            s,
            s.name,
            s.args,
            s.body,
            s.decorator_list,
            s.returns,
            s.type_params,
            False
        );
    } elif isinstance(s, AsyncFunctionDef) {
        symtable_visit_function(
            st,
            s,
            s.name,
            s.args,
            s.body,
            s.decorator_list,
            s.returns,
            s.type_params,
            True
        );
    } elif isinstance(s, ClassDef) {
        symtable_visit_classdef(st, s);
    } elif isinstance(s, TypeAlias) {
        symtable_visit_typealias(st, s);
    } elif isinstance(s, Delete) {
        symtable_visit_exprs(st, s.targets);
    } elif isinstance(s, AnnAssign) {
        symtable_visit_annassign(st, s);
    } elif isinstance(s, AugAssign) {
        symtable_visit_expr(st, s.target);
        symtable_visit_expr(st, s.value);
    } elif isinstance(s, For) {
        symtable_visit_expr(st, s.target);
        symtable_visit_expr(st, s.iter);
        cur = st.current();
        in_conditional_block = cur.in_conditional_block;
        cur.in_conditional_block = 1;
        symtable_visit_stmts(st, s.body);
        symtable_visit_stmts(st, s.orelse);
        cur.in_conditional_block = in_conditional_block;
    } elif isinstance(s, While) {
        symtable_visit_expr(st, s.`test);
        cur = st.current();
        in_conditional_block = cur.in_conditional_block;
        cur.in_conditional_block = 1;
        symtable_visit_stmts(st, s.body);
        symtable_visit_stmts(st, s.orelse);
        cur.in_conditional_block = in_conditional_block;
    } elif isinstance(s, Match) {
        symtable_visit_expr(st, s.subject);
        cur = st.current();
        in_conditional_block = cur.in_conditional_block;
        cur.in_conditional_block = 1;
        for m in s.cases {
            symtable_visit_match_case(st, m);
        }
        cur.in_conditional_block = in_conditional_block;
    } elif isinstance(s, Raise) {
        exc = s.exc;
        if exc is not None {
            symtable_visit_expr(st, exc);
            cause = s.cause;
            if cause is not None {
                symtable_visit_expr(st, cause);
            }
        }
    } elif isinstance(s, Try) {
        cur = st.current();
        in_conditional_block = cur.in_conditional_block;
        cur.in_conditional_block = 1;
        symtable_visit_stmts(st, s.body);
        for h in s.handlers {
            symtable_visit_excepthandler(st, h);
        }
        symtable_visit_stmts(st, s.orelse);
        symtable_visit_stmts(st, s.finalbody);
        cur.in_conditional_block = in_conditional_block;
    } elif isinstance(s, TryStar) {
        cur = st.current();
        in_conditional_block = cur.in_conditional_block;
        cur.in_conditional_block = 1;
        symtable_visit_stmts(st, s.body);
        for h in s.handlers {
            symtable_visit_excepthandler(st, h);
        }
        symtable_visit_stmts(st, s.orelse);
        symtable_visit_stmts(st, s.finalbody);
        cur.in_conditional_block = in_conditional_block;
    } elif isinstance(s, Assert) {
        symtable_visit_expr(st, s.`test);
        msg = s.msg;
        if msg is not None {
            symtable_visit_expr(st, msg);
        }
    } elif isinstance(s, Import) {
        for a in s.names {
            symtable_visit_alias(st, a);
        }
    } elif isinstance(s, ImportFrom) {
        for a in s.names {
            symtable_visit_alias(st, a);
        }
        check_import_from(st, s);
    } elif isinstance(s, Global) {
        symtable_visit_directive(st, s, s.names, True);
    } elif isinstance(s, Nonlocal) {
        symtable_visit_directive(st, s, s.names, False);
    } elif isinstance(s, With) {
        cur = st.current();
        in_conditional_block = cur.in_conditional_block;
        cur.in_conditional_block = 1;
        for item in s.items {
            symtable_visit_withitem(st, item);
        }
        symtable_visit_stmts(st, s.body);
        cur.in_conditional_block = in_conditional_block;
    } elif isinstance(s, AsyncWith) {
        maybe_set_ste_coroutine_for_module(st);
        symtable_raise_if_not_coroutine(
            st, "'async with' outside async function", stmt_loc(s)
        );
        cur = st.current();
        in_conditional_block = cur.in_conditional_block;
        cur.in_conditional_block = 1;
        for item in s.items {
            symtable_visit_withitem(st, item);
        }
        symtable_visit_stmts(st, s.body);
        cur.in_conditional_block = in_conditional_block;
    } elif isinstance(s, AsyncFor) {
        maybe_set_ste_coroutine_for_module(st);
        symtable_raise_if_not_coroutine(
            st, "'async for' outside async function", stmt_loc(s)
        );
        symtable_visit_expr(st, s.target);
        symtable_visit_expr(st, s.iter);
        cur = st.current();
        in_conditional_block = cur.in_conditional_block;
        cur.in_conditional_block = 1;
        symtable_visit_stmts(st, s.body);
        symtable_visit_stmts(st, s.orelse);
        cur.in_conditional_block = in_conditional_block;
    }
    st.depth -= 1;
}

def symtable_extend_namedexpr_scope(st: cpy_symtable, e: Name) {
    target_name = e.id;
    loc = expr_loc(e);
    i = len(st.stack) - 1;
    while i >= 0 {
        ste = st.stack[i];
        if ste.comprehension {
            target_in_scope = symtable_lookup_entry(st, ste, target_name);
            if (target_in_scope & ST_DEF_COMP_ITER)
                and (target_in_scope & ST_DEF_LOCAL) {
                raise st_syntax_error(
                    st,
                    f"assignment expression cannot rebind comprehension iteration variable '{target_name}'",
                    loc
                );
            }
            i -= 1;
            continue;
        }
        if ste.ste_type == FunctionBlock {
            target_in_scope = symtable_lookup_entry(st, ste, target_name);
            if target_in_scope & ST_DEF_GLOBAL {
                symtable_add_def(st, target_name, ST_DEF_GLOBAL, loc);
            } else {
                symtable_add_def(st, target_name, ST_DEF_NONLOCAL, loc);
            }
            symtable_record_directive(st, target_name, loc);
            symtable_add_def_helper(st, target_name, ST_DEF_LOCAL, ste, loc);
            return;
        }
        if ste.ste_type == ModuleBlock {
            symtable_add_def(st, target_name, ST_DEF_GLOBAL, loc);
            symtable_record_directive(st, target_name, loc);
            symtable_add_def_helper(st, target_name, ST_DEF_GLOBAL, ste, loc);
            return;
        }
        if ste.ste_type == ClassBlock {
            raise st_syntax_error(
                st,
                "assignment expression within a comprehension cannot be used in a class body",
                loc
            );
        }
        if ste.ste_type == TypeParametersBlock {
            raise st_syntax_error(
                st,
                "assignment expression within a comprehension cannot be used within the definition of a generic",
                loc
            );
        }
        if ste.ste_type == TypeAliasBlock {
            raise st_syntax_error(
                st,
                "assignment expression within a comprehension cannot be used in a type alias",
                loc
            );
        }
        if ste.ste_type == TypeVariableBlock {
            raise st_syntax_error(
                st,
                "assignment expression within a comprehension cannot be used in a TypeVar bound",
                loc
            );
        }
        i -= 1;
    }
    raise SystemError("symtable_extend_namedexpr_scope found no target scope");
}

def symtable_handle_namedexpr(st: cpy_symtable, e: NamedExpr) {
    cur = st.current();
    if cur.comp_iter_expr > 0 {
        raise st_syntax_error(
            st,
            "assignment expression cannot be used in a comprehension iterable expression",
            expr_loc(e)
        );
    }
    if cur.comprehension {
        target = e.target;
        if not isinstance(target, Name) {
            raise RuntimeError("named expression target must be a Name");
        }
        symtable_extend_namedexpr_scope(st, target);
    }
    symtable_visit_expr(st, e.value);
    symtable_visit_expr(st, e.target);
}

def symtable_visit_expr(st: cpy_symtable, e: expr) {
    symtable_enter_recursive(st);
    if isinstance(e, Name) {
        cur = st.current();
        if not cur.in_unevaluated_annotation {
            ctx = st_ctx(e.ctx);
            symtable_add_def_ctx(
                st,
                e.id,
                ST_USE if ctx == ST_CTX_LOAD else ST_DEF_LOCAL,
                expr_loc(e),
                ctx
            );
            if ctx == ST_CTX_LOAD
                and cpy_st_is_function_like(st.current())
                and e.id == "super" {
                symtable_add_def(st, "__class__", ST_USE, expr_loc(e));
            }
        }
    } elif isinstance(e, Attribute) {
        check_name(st, e.attr, expr_loc(e), st_ctx(e.ctx));
        symtable_visit_expr(st, e.value);
    } elif isinstance(e, Call) {
        symtable_visit_expr(st, e.func);
        symtable_visit_exprs(st, e.args);
        check_keywords(st, e.keywords);
        for k in e.keywords {
            symtable_visit_expr(st, k.value);
        }
    } elif isinstance(e, Constant) {} elif isinstance(e, Tuple) {
        symtable_visit_exprs(st, e.elts);
    } elif isinstance(e, List) {
        symtable_visit_exprs(st, e.elts);
    } elif isinstance(e, Subscript) {
        symtable_visit_expr(st, e.value);
        symtable_visit_expr(st, e.slice);
    } elif isinstance(e, BinOp) {
        symtable_visit_expr(st, e.left);
        symtable_visit_expr(st, e.right);
    } elif isinstance(e, Compare) {
        symtable_visit_expr(st, e.left);
        symtable_visit_exprs(st, e.comparators);
    } elif isinstance(e, BoolOp) {
        symtable_visit_exprs(st, e.values);
    } elif isinstance(e, UnaryOp) {
        symtable_visit_expr(st, e.operand);
    } elif isinstance(e, NamedExpr) {
        symtable_raise_if_annotation_block(st, "named expression", e);
        symtable_handle_namedexpr(st, e);
    } elif isinstance(e, Lambda) {
        symtable_visit_exprs(st, e.args.defaults);
        symtable_visit_optional_exprs(st, e.args.kw_defaults);
        symtable_enter_block(st, "lambda", FunctionBlock, cpy_st_key(e), expr_loc(e));
        symtable_visit_arguments(st, e.args);
        symtable_visit_expr(st, e.body);
        symtable_exit_block(st);
    } elif isinstance(e, IfExp) {
        symtable_visit_expr(st, e.`test);
        symtable_visit_expr(st, e.body);
        symtable_visit_expr(st, e.orelse);
    } elif isinstance(e, Dict) {
        symtable_visit_optional_exprs(st, e.keys);
        symtable_visit_exprs(st, e.values);
    } elif isinstance(e, Set) {
        symtable_visit_exprs(st, e.elts);
    } elif isinstance(e, GeneratorExp) {
        symtable_handle_comprehension(
            st, e, "genexpr", GeneratorExpression, e.generators, e.elt, None
        );
    } elif isinstance(e, ListComp) {
        symtable_handle_comprehension(
            st, e, "listcomp", ListComprehension, e.generators, e.elt, None
        );
    } elif isinstance(e, SetComp) {
        symtable_handle_comprehension(
            st, e, "setcomp", SetComprehension, e.generators, e.elt, None
        );
    } elif isinstance(e, DictComp) {
        symtable_handle_comprehension(
            st, e, "dictcomp", DictComprehension, e.generators, e.key, e.value
        );
    } elif isinstance(e, Yield) {
        symtable_raise_if_annotation_block(st, "yield expression", e);
        value = e.value;
        if value is not None {
            symtable_visit_expr(st, value);
        }
        cur = st.current();
        cur.generator = 1;
        if cur.comprehension {
            symtable_raise_if_comprehension_block(st, e);
        }
    } elif isinstance(e, YieldFrom) {
        symtable_raise_if_annotation_block(st, "yield expression", e);
        symtable_visit_expr(st, e.value);
        cur = st.current();
        cur.generator = 1;
        if cur.comprehension {
            symtable_raise_if_comprehension_block(st, e);
        }
    } elif isinstance(e, Await) {
        symtable_raise_if_annotation_block(st, "await expression", e);
        if not allows_top_level_await(st) {
            if not cpy_st_is_function_like(st.current()) {
                raise st_syntax_error(st, "'await' outside function", expr_loc(e));
            }
            if not is_async_def(st) and st.current().comprehension == NoComprehension {
                raise st_syntax_error(
                    st, "'await' outside async function", expr_loc(e)
                );
            }
        }
        symtable_visit_expr(st, e.value);
        st.current().coroutine = 1;
    } elif isinstance(e, FormattedValue) {
        symtable_visit_expr(st, e.value);
        spec = e.format_spec;
        if spec is not None {
            symtable_visit_expr(st, spec);
        }
    } elif isinstance(e, Interpolation) {
        symtable_visit_expr(st, e.value);
        spec = e.format_spec;
        if spec is not None {
            symtable_visit_expr(st, spec);
        }
    } elif isinstance(e, JoinedStr) {
        symtable_visit_exprs(st, e.values);
    } elif isinstance(e, TemplateStr) {
        symtable_visit_exprs(st, e.values);
    } elif isinstance(e, Starred) {
        symtable_visit_expr(st, e.value);
    } elif isinstance(e, Slice) {
        lower = e.lower;
        if lower is not None {
            symtable_visit_expr(st, lower);
        }
        upper = e.upper;
        if upper is not None {
            symtable_visit_expr(st, upper);
        }
        step = e.step;
        if step is not None {
            symtable_visit_expr(st, step);
        }
    }
    st.depth -= 1;
}

def symtable_visit_type_param_bound_or_default(
    st: cpy_symtable,
    e: expr | None,
    name: str,
    tp: type_param,
    key: int,
    ste_scope_info: str
) {
    if name == "__classdict__" {
        raise st_syntax_error(
            st,
            f"reserved name '{name}' cannot be used for type parameter",
            type_param_loc(tp)
        );
    }
    if e is not None {
        is_in_class = st.current().can_see_class_scope;
        symtable_enter_block(st, name, TypeVariableBlock, key, expr_loc(e));
        cur = st.current();
        cur.can_see_class_scope = is_in_class;
        if is_in_class {
            symtable_add_def(st, "__classdict__", ST_USE, expr_loc(e));
        }
        cur.scope_info = ste_scope_info;
        symtable_visit_expr(st, e);
        symtable_exit_block(st);
    }
}

def symtable_visit_type_param(st: cpy_symtable, tp: type_param) {
    symtable_enter_recursive(st);
    if isinstance(tp, TypeVar) {
        symtable_add_def(
            st, tp.name, ST_DEF_TYPE_PARAM | ST_DEF_LOCAL, type_param_loc(tp)
        );
        ste_scope_info = "";
        bound = tp.bound;
        if bound is not None {
            ste_scope_info = "a TypeVar constraint"
                if isinstance(bound, Tuple)
                else "a TypeVar bound";
        }
        symtable_visit_type_param_bound_or_default(
            st, tp.bound, tp.name, tp, cpy_st_key(tp), ste_scope_info
        );
        symtable_visit_type_param_bound_or_default(
            st, tp.default_value, tp.name, tp, cpy_st_key(tp, 1), "a TypeVar default"
        );
    } elif isinstance(tp, TypeVarTuple) {
        symtable_add_def(
            st, tp.name, ST_DEF_TYPE_PARAM | ST_DEF_LOCAL, type_param_loc(tp)
        );
        symtable_visit_type_param_bound_or_default(
            st, tp.default_value, tp.name, tp, cpy_st_key(tp), "a TypeVarTuple default"
        );
    } elif isinstance(tp, ParamSpec) {
        symtable_add_def(
            st, tp.name, ST_DEF_TYPE_PARAM | ST_DEF_LOCAL, type_param_loc(tp)
        );
        symtable_visit_type_param_bound_or_default(
            st, tp.default_value, tp.name, tp, cpy_st_key(tp), "a ParamSpec default"
        );
    }
    st.depth -= 1;
}

def symtable_visit_pattern(st: cpy_symtable, p: pattern) {
    symtable_enter_recursive(st);
    if isinstance(p, MatchValue) {
        symtable_visit_expr(st, p.value);
    } elif isinstance(p, MatchSequence) {
        symtable_visit_patterns(st, p.patterns);
    } elif isinstance(p, MatchStar) {
        star_name = p.name;
        if star_name is not None {
            symtable_add_def(st, star_name, ST_DEF_LOCAL, pattern_loc(p));
        }
    } elif isinstance(p, MatchMapping) {
        symtable_visit_exprs(st, p.keys);
        symtable_visit_patterns(st, p.patterns);
        rest = p.rest;
        if rest is not None {
            symtable_add_def(st, rest, ST_DEF_LOCAL, pattern_loc(p));
        }
    } elif isinstance(p, MatchClass) {
        symtable_visit_expr(st, p.cls);
        symtable_visit_patterns(st, p.patterns);
        check_kwd_patterns(st, p);
        symtable_visit_patterns(st, p.kwd_patterns);
    } elif isinstance(p, MatchAs) {
        inner = p.pattern;
        if inner is not None {
            symtable_visit_pattern(st, inner);
        }
        as_name = p.name;
        if as_name is not None {
            symtable_add_def(st, as_name, ST_DEF_LOCAL, pattern_loc(p));
        }
    } elif isinstance(p, MatchOr) {
        symtable_visit_patterns(st, p.patterns);
    }
    st.depth -= 1;
}

def symtable_implicit_arg(st: cpy_symtable, pos: int) {
    symtable_add_def(st, "." + str(pos), ST_DEF_PARAM, st.current().loc);
}

def symtable_visit_params(st: cpy_symtable, args: list[arg]) {
    for a in args {
        symtable_add_def(st, a.arg, ST_DEF_PARAM, arg_loc(a));
    }
}

def symtable_visit_annotation(st: cpy_symtable, annotation: expr, key: int) {
    cur = st.current();
    is_unevaluated = cur.ste_type == FunctionBlock;
    if (
        (cur.ste_type == ClassBlock and cur.in_conditional_block)
        or cur.ste_type == ModuleBlock
    )
        and not cur.has_conditional_annotations {
        cur.has_conditional_annotations = 1;
        symtable_add_def(
            st, "__conditional_annotations__", ST_USE, expr_loc(annotation)
        );
    }
    parent_ste = cur;
    annotation_block = parent_ste.annotation_block;
    if annotation_block is None {
        current_type = parent_ste.ste_type;
        symtable_enter_block(
            st, "__annotate__", AnnotationBlock, key, expr_loc(annotation)
        );
        block = st.current();
        parent_ste.annotation_block = block;
        future_annotations = st.future_features & ST_CO_FUTURE_ANNOTATIONS;
        if current_type == ClassBlock and not future_annotations {
            block.can_see_class_scope = 1;
            parent_ste.needs_classdict = 1;
            symtable_add_def(st, "__classdict__", ST_USE, expr_loc(annotation));
        }
    } else {
        symtable_enter_existing_block(st, annotation_block, False);
    }
    if is_unevaluated {
        st.current().in_unevaluated_annotation = 1;
    }
    symtable_visit_expr(st, annotation);
    if is_unevaluated {
        st.current().in_unevaluated_annotation = 0;
    }
    symtable_exit_block(st);
}

def symtable_visit_argannotations(st: cpy_symtable, args: list[arg]) {
    for a in args {
        annotation = a.annotation;
        if annotation is not None {
            st.current().annotations_used = 1;
            symtable_visit_expr(st, annotation);
        }
    }
}

def symtable_visit_annotations(
    st: cpy_symtable, o: stmt, a: arguments, returns: expr | None
) {
    is_in_class = st.current().can_see_class_scope;
    current_type = st.current().ste_type;
    symtable_enter_block(
        st, "__annotate__", AnnotationBlock, cpy_st_key(a), stmt_loc(o)
    );
    if is_in_class or current_type == ClassBlock {
        st.current().can_see_class_scope = 1;
        symtable_add_def(st, "__classdict__", ST_USE, stmt_loc(o));
    }
    symtable_visit_argannotations(st, a.posonlyargs);
    symtable_visit_argannotations(st, a.args);
    vararg = a.vararg;
    if vararg is not None {
        annotation = vararg.annotation;
        if annotation is not None {
            st.current().annotations_used = 1;
            symtable_visit_expr(st, annotation);
        }
    }
    kwarg = a.kwarg;
    if kwarg is not None {
        annotation = kwarg.annotation;
        if annotation is not None {
            st.current().annotations_used = 1;
            symtable_visit_expr(st, annotation);
        }
    }
    symtable_visit_argannotations(st, a.kwonlyargs);
    if returns is not None {
        st.current().annotations_used = 1;
        symtable_visit_expr(st, returns);
    }
    symtable_exit_block(st);
}

def symtable_visit_arguments(st: cpy_symtable, a: arguments) {
    symtable_visit_params(st, a.posonlyargs);
    symtable_visit_params(st, a.args);
    symtable_visit_params(st, a.kwonlyargs);
    vararg = a.vararg;
    if vararg is not None {
        symtable_add_def(st, vararg.arg, ST_DEF_PARAM, arg_loc(vararg));
        st.current().varargs = 1;
    }
    kwarg = a.kwarg;
    if kwarg is not None {
        symtable_add_def(st, kwarg.arg, ST_DEF_PARAM, arg_loc(kwarg));
        st.current().varkeywords = 1;
    }
}

def symtable_visit_excepthandler(st: cpy_symtable, eh: excepthandler) {
    handler_type = eh.type;
    if handler_type is not None {
        symtable_visit_expr(st, handler_type);
    }
    handler_name = eh.name;
    if handler_name is not None {
        symtable_add_def(st, handler_name, ST_DEF_LOCAL, handler_loc(eh));
    }
    symtable_visit_stmts(st, eh.body);
}

def symtable_visit_withitem(st: cpy_symtable, item: withitem) {
    symtable_visit_expr(st, item.context_expr);
    optional_vars = item.optional_vars;
    if optional_vars is not None {
        symtable_visit_expr(st, optional_vars);
    }
}

def symtable_visit_match_case(st: cpy_symtable, m: match_case) {
    symtable_visit_pattern(st, m.pattern);
    guard = m.guard;
    if guard is not None {
        symtable_visit_expr(st, guard);
    }
    symtable_visit_stmts(st, m.body);
}

def symtable_visit_alias(st: cpy_symtable, a: alias) {
    asname = a.asname;
    name = a.name if asname is None else asname;
    dot = name.find(".");
    store_name = name[:dot] if dot != -1 else name;
    if name != "*" {
        symtable_add_def(st, store_name, ST_DEF_IMPORT, alias_loc(a));
    } elif st.current().ste_type != ModuleBlock {
        raise st_syntax_error(
            st, "import * only allowed at module level", alias_loc(a)
        );
    }
}

def symtable_visit_comprehension(st: cpy_symtable, lc: comprehension) {
    cur = st.current();
    cur.comp_iter_target = 1;
    symtable_visit_expr(st, lc.target);
    cur.comp_iter_target = 0;
    cur.comp_iter_expr += 1;
    symtable_visit_expr(st, lc.iter);
    cur.comp_iter_expr -= 1;
    symtable_visit_exprs(st, lc.ifs);
    if lc.is_async {
        cur.coroutine = 1;
    }
}

def symtable_handle_comprehension(
    st: cpy_symtable,
    e: expr,
    scope_name: str,
    comprehension_type: int,
    generators: list[comprehension],
    elt: expr,
    value: expr | None
) {
    is_generator = comprehension_type == GeneratorExpression;
    outermost = generators[0];
    outer = st.current();
    outer.comp_iter_expr += 1;
    symtable_visit_expr(st, outermost.iter);
    outer.comp_iter_expr -= 1;
    symtable_enter_block(st, scope_name, FunctionBlock, cpy_st_key(e), expr_loc(e));
    cur = st.current();
    cur.comprehension = comprehension_type;
    if outermost.is_async {
        cur.coroutine = 1;
    }
    symtable_implicit_arg(st, 0);
    cur.comp_iter_target = 1;
    symtable_visit_expr(st, outermost.target);
    cur.comp_iter_target = 0;
    symtable_visit_exprs(st, outermost.ifs);
    i = 1;
    while i < len(generators) {
        symtable_visit_comprehension(st, generators[i]);
        i += 1;
    }
    if value is not None {
        symtable_visit_expr(st, value);
    }
    symtable_visit_expr(st, elt);
    cur.generator = 1 if is_generator else 0;
    is_async = bool(cur.coroutine) and not is_generator;
    symtable_exit_block(st);
    if is_async
        and not is_async_def(st)
        and st.current().comprehension == NoComprehension
        and not allows_top_level_await(st) {
        raise st_syntax_error(
            st,
            "asynchronous comprehension outside of an asynchronous function",
            expr_loc(e)
        );
    }
    if is_async {
        st.current().coroutine = 1;
    }
}

def symtable_raise_if_annotation_block(st: cpy_symtable, name: str, e: expr) {
    cur = st.current();
    block = cur.ste_type;
    if block == AnnotationBlock {
        raise st_syntax_error(
            st, f"{name} cannot be used within an annotation", expr_loc(e)
        );
    } elif block == TypeVariableBlock {
        raise st_syntax_error(
            st, f"{name} cannot be used within {cur.scope_info}", expr_loc(e)
        );
    } elif block == TypeAliasBlock {
        raise st_syntax_error(
            st, f"{name} cannot be used within a type alias", expr_loc(e)
        );
    } elif block == TypeParametersBlock {
        raise st_syntax_error(
            st, f"{name} cannot be used within the definition of a generic", expr_loc(e)
        );
    }
}

def symtable_raise_if_comprehension_block(st: cpy_symtable, e: expr) {
    block = st.current().comprehension;
    msg = "'yield' inside generator expression";
    if block == ListComprehension {
        msg = "'yield' inside list comprehension";
    } elif block == SetComprehension {
        msg = "'yield' inside set comprehension";
    } elif block == DictComprehension {
        msg = "'yield' inside dict comprehension";
    }
    raise st_syntax_error(st, msg, expr_loc(e));
}

def symtable_raise_if_not_coroutine(st: cpy_symtable, msg: str, loc: srcloc) {
    if not st.current().coroutine {
        raise st_syntax_error(st, msg, loc);
    }
}

def cpy_maybe_mangle(private: str | None, ste: cpy_ste, name: str) -> str {
    mangled_names = ste.mangled_names;
    if mangled_names is not None and name not in mangled_names {
        return name;
    }
    return cpy_mangle(private, name);
}

def cpy_mangle(private: str | None, name: str) -> str {
    if private is None {
        return name;
    }
    nlen = len(name);
    if nlen < 2 or name[0] != "_" or name[1] != "_" {
        return name;
    }
    if (name[nlen - 1] == "_" and name[nlen - 2] == "_") or "." in name {
        return name;
    }
    plen = len(private);
    ipriv = 0;
    while ipriv < plen and private[ipriv] == "_" {
        ipriv += 1;
    }
    if ipriv == plen {
        return name;
    }
    return "_" + private[ipriv:] + name;
}
