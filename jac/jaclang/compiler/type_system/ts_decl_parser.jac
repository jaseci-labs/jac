obj TsParam {
    has name: str = "",
        ty: (TsType | None) = None,
        optional: bool = False,
        rest: bool = False;
}

obj TsType {
    has kind: str = "any",
        name: str = "",
        args: list[TsType] = [],
        params: list[TsParam] = [],
        ret: (TsType | None) = None;
}

obj TsDecl {
    has name: str = "",
        kind: str = "any",
        ty: (TsType | None) = None;
}

glob _PRIM_NAMES: frozenset = frozenset(
         {'string', 'number', 'boolean', 'object', 'symbol', 'bigint'}
     ),
     _ANY_NAMES: frozenset = frozenset({'any', 'unknown', 'this'}),
     _VOID_NAMES: frozenset = frozenset({'void', 'undefined', 'null'});

def _tokenize(src: str) -> (list[tuple[(str, str)]] | None) {
    toks: list[tuple[(str, str)]] = [];
    i = 0;
    n = len(src);
    while i < n {
        ch = src[i];
        if ch in ' \t\r\n' {
            i += 1;
            continue;
        }
        if (ch == '/' and i + 1 < n) {
            if src[i + 1] == '/' {
                while (i < n and src[i] != '\n') {
                    i += 1;
                }
                continue;
            }
            if src[i + 1] == '*' {
                end = src.find('*/', i + 2);
                if end == -1 {
                    return None;
                }
                i = end + 2;
                continue;
            }
        }
        if ch in '\'"' {
            quote = ch;
            i += 1;
            buf = '';
            while i < n {
                c = src[i];
                if c == '\\' {
                    buf += src[i + 1] if i + 1 < n else '';
                    i += 2;
                    continue;
                }
                if c == quote {
                    break;
                }
                buf += c;
                i += 1;
            }
            if i >= n {
                return None;
            }
            i += 1;
            toks.append(('str', buf));
            continue;
        }
        if ch == '`' {
            i += 1;
            depth = 0;
            while i < n {
                c = src[i];
                if c == '\\' {
                    i += 2;
                    continue;
                }
                if (c == '$' and i + 1 < n and src[i + 1] == '{') {
                    depth += 1;
                    i += 2;
                    continue;
                }
                if (c == '}' and depth > 0) {
                    depth -= 1;
                    i += 1;
                    continue;
                }
                if (c == '`' and depth == 0) {
                    break;
                }
                i += 1;
            }
            if i >= n {
                return None;
            }
            i += 1;
            toks.append(('tmpl', ''));
            continue;
        }
        if (ch.isalpha() or ch in '_$') {
            start = i;
            while (i < n and (src[i].isalnum() or src[i] in '_$')) {
                i += 1;
            }
            toks.append(('id', src[start:i]));
            continue;
        }
        if ch.isdigit() {
            start = i;
            while (i < n and (src[i].isalnum() or src[i] in '._')) {
                i += 1;
            }
            toks.append(('num', src[start:i]));
            continue;
        }
        if src[i:i + 3] == '...' {
            toks.append(('punct', '...'));
            i += 3;
            continue;
        }
        if src[i:i + 2] == '=>' {
            toks.append(('punct', '=>'));
            i += 2;
            continue;
        }
        toks.append(('punct', ch));
        i += 1;
    }
    return toks;
}

def parse_dts(source: str) -> (dict[str, TsDecl] | None) {
    try {
        return _parse_dts_inner(source);
    } except Exception {
        return None;
    }
}

def _parse_dts_inner(source: str) -> (dict[str, TsDecl] | None) {
    toks = _tokenize(source);
    if toks is None {
        return None;
    }
    pos = 0;
    n = len(toks);
    decls: dict[str, TsDecl] = {};
    exported_direct: dict[str, TsDecl] = {};
    export_pairs: list[tuple[(str, str)]] = [];
    namespaces: dict[str, dict[str, TsDecl]] = {};
    export_eq: (str | None) = None;
    saw_export = False;
    typevar_stack: list[set] = [];

    def kind_at(k: int = 0) -> str {
        return toks[pos + k][0] if pos + k < n else '';
    }
    def val_at(k: int = 0) -> str {
        return toks[pos + k][1] if pos + k < n else '';
    }
    def is_p(v: str) -> bool {
        return kind_at() == 'punct' and val_at() == v;
    }
    def is_id(v: (str | None) = None) -> bool {
        return kind_at() == 'id' and (v is None or val_at() == v);
    }
    def advance {
        nonlocal pos;
        pos += 1;
    }
    def eat_p(v: str) -> bool {
        nonlocal pos;
        if is_p(v) {
            pos += 1;
            return True;
        }
        return False;
    }
    def eat_id(v: str) -> bool {
        nonlocal pos;
        if is_id(v) {
            pos += 1;
            return True;
        }
        return False;
    }
    def expect_p(v: str) {
        if not eat_p(v) {
            raise ValueError(f"expected '{v}'");
        }
    }

    def skip_balanced(open_p: str, close_p: str) {
        nonlocal pos;
        expect_p(open_p);
        depth = 1;
        while (pos < n and depth > 0) {
            if is_p(open_p) {
                depth += 1;
            } elif is_p(close_p) {
                depth -= 1;
            }
            pos += 1;
        }
        if depth != 0 {
            raise ValueError('unbalanced brackets');
        }
    }

    def skip_to_semi -> None {
        nonlocal pos;
        depth = 0;
        while pos < n {
            if kind_at() == 'punct' {
                v = val_at();
                if v in '({[' {
                    depth += 1;
                } elif v in ')}]' {
                    depth -= 1;
                } elif (v == ';' and depth <= 0) {
                    pos += 1;
                    return;
                }
            }
            pos += 1;
        }
    }

    def in_typevars(name: str) -> bool {
        for tv in typevar_stack {
            if name in tv {
                return True;
            }
        }
        return False;
    }

    def collect_generics -> set {
        nonlocal pos;
        names: set = set();
        if not is_p('<') {
            return names;
        }
        pos += 1;
        depth = 1;
        expecting = True;
        while (pos < n and depth > 0) {
            if is_p('<') {
                depth += 1;
            } elif is_p('>') {
                depth -= 1;
            } elif (depth == 1 and is_p(',')) {
                expecting = True;
            } elif (depth == 1 and expecting and kind_at() == 'id') {
                names.add(val_at());
                expecting = False;
            }
            pos += 1;
        }
        if depth != 0 {
            raise ValueError('unbalanced generics');
        }
        return names;
    }

    def parse_qualified_name -> str {
        nonlocal pos;
        name = val_at();
        advance();
        while (is_p('.') and kind_at(1) == 'id') {
            advance();
            name += '.' + val_at();
            advance();
        }
        return name;
    }

    def parse_generic_args -> list[TsType] {
        args: list[TsType] = [];
        expect_p('<');
        while (pos < n and not is_p('>')) {
            args.append(parse_type_full());
            if not eat_p(',') {
                break;
            }
        }
        expect_p('>');
        return args;
    }

    def looks_like_fn_type -> bool {
        depth = 0;
        p = pos;
        while p < n {
            (k, v) = toks[p];
            if k == 'punct' {
                if v == '(' {
                    depth += 1;
                } elif v == ')' {
                    depth -= 1;
                    if depth == 0 {
                        return p + 1 < n and toks[p + 1] == ('punct', '=>');
                    }
                }
            }
            p += 1;
        }
        return False;
    }

    def parse_params -> list[TsParam] {
        nonlocal pos;
        params: list[TsParam] = [];
        expect_p('(');
        while (pos < n and not is_p(')')) {
            rest = eat_p('...');
            pname = 'arg';
            if kind_at() == 'id' {
                pname = val_at();
                advance();
            } elif is_p('{') {
                skip_balanced('{', '}');
            } elif is_p('[') {
                skip_balanced('[', ']');
            } else {
                raise ValueError('unexpected param token');
            }
            optional = eat_p('?');
            pty: (TsType | None) = None;
            if eat_p(':') {
                pty = parse_type_full();
            }
            if eat_p('=') {
                optional = True;
                depth = 0;
                while pos < n {
                    if kind_at() == 'punct' {
                        v = val_at();
                        if v in '({[<' {
                            depth += 1;
                        } elif v in ')}]>' {
                            if (depth == 0 and v == ')') {
                                break;
                            }
                            depth -= 1;
                        } elif (v == ',' and depth == 0) {
                            break;
                        }
                    }
                    advance();
                }
            }
            if pname == 'this' {
                eat_p(',');
                continue;
            }
            params.append(TsParam(name=pname, ty=pty, optional=optional, rest=rest));
            if not eat_p(',') {
                break;
            }
        }
        expect_p(')');
        return params;
    }

    def parse_fn_type -> TsType {
        params = parse_params();
        expect_p('=>');
        ret = parse_type_full();
        return TsType(kind='func', params=params, ret=ret);
    }

    def parse_primary -> TsType {
        nonlocal pos;
        if is_p('(') {
            if looks_like_fn_type() {
                return parse_fn_type();
            }
            advance();
            inner = parse_type_full();
            expect_p(')');
            return inner;
        }
        if is_id('new') {
            advance();
            if is_p('<') {
                collect_generics();
            }
            parse_fn_type();
            return TsType(kind='any');
        }
        if is_p('{') {
            skip_balanced('{', '}');
            return TsType(kind='any');
        }
        if is_p('[') {
            advance();
            args: list[TsType] = [];
            while (pos < n and not is_p(']')) {
                eat_p('...');
                if (kind_at() == 'id' and kind_at(1) == 'punct' and val_at(1) == ':') {
                    advance();
                    advance();
                }
                args.append(parse_type_full());
                eat_p('?');
                if not eat_p(',') {
                    break;
                }
            }
            expect_p(']');
            return TsType(kind='tuple', args=args);
        }
        if kind_at() == 'str' {
            t = TsType(kind='literal-str', name=val_at());
            advance();
            return t;
        }
        if kind_at() == 'num' {
            t = TsType(kind='literal-num', name=val_at());
            advance();
            return t;
        }
        if kind_at() == 'tmpl' {
            advance();
            return TsType(kind='prim', name='string');
        }
        if (is_p('-') and kind_at(1) == 'num') {
            advance();
            t = TsType(kind='literal-num', name='-' + val_at());
            advance();
            return t;
        }
        if kind_at() == 'id' {
            v = val_at();
            if v in ('true', 'false') {
                advance();
                return TsType(kind='literal-bool', name=v);
            }
            if v == 'typeof' {
                advance();
                if is_id('import') {
                    advance();
                    skip_balanced('(', ')');
                    while (is_p('.') and kind_at(1) == 'id') {
                        advance();
                        advance();
                    }
                } else {
                    parse_qualified_name();
                }
                if is_p('<') {
                    parse_generic_args();
                }
                return TsType(kind='any');
            }
            if v == 'import' {
                advance();
                skip_balanced('(', ')');
                while (is_p('.') and kind_at(1) == 'id') {
                    advance();
                    advance();
                }
                if is_p('<') {
                    parse_generic_args();
                }
                return TsType(kind='any');
            }
            if v in ('keyof', 'unique', 'infer') {
                advance();
                parse_postfix();
                return TsType(kind='any');
            }
            if v == 'readonly' {
                advance();
                return parse_postfix();
            }
            if v == 'asserts' {
                advance();
                if kind_at() == 'id' {
                    advance();
                }
                if eat_id('is') {
                    parse_type_full();
                }
                return TsType(kind='void');
            }
            if v in _ANY_NAMES {
                advance();
                return TsType(kind='any');
            }
            if v in _VOID_NAMES {
                advance();
                return TsType(kind='void');
            }
            if v == 'never' {
                advance();
                return TsType(kind='never');
            }
            if v in _PRIM_NAMES {
                advance();
                return TsType(kind='prim', name=v);
            }
            name = parse_qualified_name();
            args: list[TsType] = [];
            if is_p('<') {
                args = parse_generic_args();
            }
            if in_typevars(name) {
                return TsType(kind='any');
            }
            if (name in ('Array', 'ReadonlyArray') and len(args) == 1) {
                return TsType(kind='array', args=[args[0]]);
            }
            return TsType(kind='ref', name=name, args=args);
        }
        raise ValueError('unexpected type token');
    }

    def parse_postfix -> TsType {
        nonlocal pos;
        t = parse_primary();
        while pos < n {
            if is_p('[') {
                if (kind_at(1) == 'punct' and val_at(1) == ']') {
                    advance();
                    advance();
                    t = TsType(kind='array', args=[t]);
                    continue;
                }
                skip_balanced('[', ']');
                t = TsType(kind='any');
                continue;
            }
            break;
        }
        return t;
    }

    def parse_intersection -> TsType {
        parts = [parse_postfix()];
        while eat_p('&') {
            parts.append(parse_postfix());
        }
        return parts[0] if len(parts) == 1 else TsType(kind='any');
    }

    def parse_union -> TsType {
        eat_p('|');
        parts = [parse_intersection()];
        while eat_p('|') {
            parts.append(parse_intersection());
        }
        return parts[0] if len(parts) == 1 else TsType(kind='union', args=parts);
    }

    def parse_type_full -> TsType {
        t = parse_union();
        if is_id('extends') {
            advance();
            parse_union();
            expect_p('?');
            parse_type_full();
            expect_p(':');
            parse_type_full();
            return TsType(kind='any');
        }
        return t;
    }

    def parse_return_type -> TsType {
        if (kind_at() == 'id' and kind_at(1) == 'id' and val_at(1) == 'is') {
            advance();
            advance();
            parse_type_full();
            return TsType(kind='prim', name='boolean');
        }
        return parse_type_full();
    }

    def parse_function_decl -> TsDecl {
        nonlocal pos;
        fname = '';
        if kind_at() == 'id' {
            fname = val_at();
            advance();
        }
        tvs = collect_generics() if is_p('<') else set();
        typevar_stack.append(tvs);
        try {
            params = parse_params();
            ret: TsType = TsType(kind='any');
            if eat_p(':') {
                ret = parse_return_type();
            }
        } finally {
            typevar_stack.pop();
        }
        eat_p(';');
        return TsDecl(
            name=fname, kind='function', ty=TsType(kind='func', params=params, ret=ret)
        );
    }

    def record(decl: TsDecl, is_export: bool) {
        if (decl.name and decl.name not in decls) {
            decls[decl.name] = decl;
        }
        if is_export {
            exported_direct[decl.name] = decls.get(decl.name, decl);
        }
    }

    def parse_statements(stop_at_brace: bool) -> None {
        nonlocal pos , export_eq , saw_export;
        while pos < n {
            if (stop_at_brace and is_p('}')) {
                return;
            }
            start_pos = pos;
            if eat_p(';') {
                continue;
            }
            is_export = False;
            handled = False;
            while True {
                if eat_id('declare') {
                    continue;
                }
                if eat_id('abstract') {
                    continue;
                }
                if eat_id('async') {
                    continue;
                }
                if is_id('export') {
                    nxt_kind = kind_at(1);
                    nxt_val = val_at(1);
                    if (nxt_kind == 'punct' and nxt_val == '{') {
                        advance();
                        _parse_export_list(False);
                        handled = True;
                        break;
                    }
                    if (nxt_kind == 'punct' and nxt_val == '*') {
                        saw_export = True;
                        skip_to_semi();
                        handled = True;
                        break;
                    }
                    if (nxt_kind == 'punct' and nxt_val == '=') {
                        advance();
                        advance();
                        saw_export = True;
                        if kind_at() == 'id' {
                            export_eq = val_at();
                        }
                        skip_to_semi();
                        handled = True;
                        break;
                    }
                    if (nxt_kind == 'id' and nxt_val == 'default') {
                        advance();
                        advance();
                        saw_export = True;
                        _parse_export_default();
                        handled = True;
                        break;
                    }
                    if (nxt_kind == 'id' and nxt_val == 'as') {
                        skip_to_semi();
                        handled = True;
                        break;
                    }
                    if (
                        nxt_kind == 'id'
                        and nxt_val == 'type'
                        and kind_at(2) == 'punct'
                        and val_at(2) == '{'
                    ) {
                        advance();
                        advance();
                        _parse_export_list(True);
                        handled = True;
                        break;
                    }
                    if (nxt_kind == 'id' and nxt_val == 'import') {
                        skip_to_semi();
                        handled = True;
                        break;
                    }
                    advance();
                    is_export = True;
                    saw_export = True;
                    continue;
                }
                break;
            }
            if handled {
                continue;
            }
            if eat_id('function') {
                record(parse_function_decl(), is_export);
            } elif (is_id('const') or is_id('let') or is_id('var')) {
                advance();
                if eat_id('enum') {
                    _parse_enum_decl(is_export);
                    continue;
                }
                while kind_at() == 'id' {
                    vname = val_at();
                    advance();
                    vty: TsType = TsType(kind='any');
                    if eat_p(':') {
                        vty = parse_type_full();
                    }
                    record(TsDecl(name=vname, kind='const', ty=vty), is_export);
                    if not eat_p(',') {
                        break;
                    }
                }
                eat_p(';');
            } elif eat_id('type') {
                tname = val_at();
                advance();
                has_generics = is_p('<');
                if has_generics {
                    collect_generics();
                }
                expect_p('=');
                if has_generics {
                    skip_to_semi();
                    record(
                        TsDecl(name=tname, kind='typealias', ty=TsType(kind='any')),
                        is_export
                    );
                } else {
                    aty = parse_type_full();
                    eat_p(';');
                    record(TsDecl(name=tname, kind='typealias', ty=aty), is_export);
                }
            } elif eat_id('interface') {
                iname = val_at();
                advance();
                if is_p('<') {
                    collect_generics();
                }
                while (pos < n and not is_p('{')) {
                    advance();
                }
                skip_balanced('{', '}');
                record(TsDecl(name=iname, kind='interface'), is_export);
            } elif eat_id('class') {
                cname = val_at();
                advance();
                if is_p('<') {
                    collect_generics();
                }
                while (pos < n and not is_p('{')) {
                    advance();
                }
                skip_balanced('{', '}');
                record(TsDecl(name=cname, kind='class'), is_export);
            } elif eat_id('enum') {
                _parse_enum_decl(is_export);
            } elif (is_id('namespace') or is_id('module')) {
                advance();
                if kind_at() == 'str' {
                    advance();
                    if is_p('{') {
                        skip_balanced('{', '}');
                    } else {
                        eat_p(';');
                    }
                    continue;
                }
                nsname = parse_qualified_name();
                if not is_p('{') {
                    skip_to_semi();
                    continue;
                }
                ns_decls: dict[str, TsDecl] = namespaces.get(nsname, {});
                expect_p('{');
                _parse_namespace_body(ns_decls);
                expect_p('}');
                namespaces[nsname] = ns_decls;
                if is_export {
                    exported_direct[nsname] = TsDecl(name=nsname, kind='namespace');
                }
            } elif eat_id('import') {
                skip_to_semi();
            } elif eat_id('global') {
                if is_p('{') {
                    skip_balanced('{', '}');
                }
            } else {
                if pos == start_pos {
                    advance();
                }
            }
        }
    }

    def _parse_namespace_body(ns_decls: dict[str, TsDecl]) {
        nonlocal pos;
        while (pos < n and not is_p('}')) {
            if eat_p(';') {
                continue;
            }
            start_pos = pos;
            while (eat_id('export') or eat_id('declare')) {
                ;
            }
            if eat_id('function') {
                d = parse_function_decl();
                if (d.name and d.name not in ns_decls) {
                    ns_decls[d.name] = d;
                }
            } elif (is_id('const') or is_id('let') or is_id('var')) {
                advance();
                while kind_at() == 'id' {
                    vname = val_at();
                    advance();
                    vty: TsType = TsType(kind='any');
                    if eat_p(':') {
                        vty = parse_type_full();
                    }
                    if vname not in ns_decls {
                        ns_decls[vname] = TsDecl(name=vname, kind='const', ty=vty);
                    }
                    if not eat_p(',') {
                        break;
                    }
                }
                eat_p(';');
            } elif eat_id('type') {
                tname = val_at();
                advance();
                if is_p('<') {
                    collect_generics();
                    expect_p('=');
                    skip_to_semi();
                    ns_decls.setdefault(
                        tname,
                        TsDecl(name=tname, kind='typealias', ty=TsType(kind='any'))
                    );
                } else {
                    expect_p('=');
                    aty = parse_type_full();
                    eat_p(';');
                    ns_decls.setdefault(
                        tname, TsDecl(name=tname, kind='typealias', ty=aty)
                    );
                }
            } elif (is_id('interface') or is_id('class') or is_id('enum')) {
                dkind = val_at();
                advance();
                dname = val_at() if kind_at() == 'id' else '';
                advance();
                if is_p('<') {
                    collect_generics();
                }
                while (pos < n and not is_p('{')) {
                    advance();
                }
                skip_balanced('{', '}');
                if dname {
                    ns_decls.setdefault(dname, TsDecl(name=dname, kind=dkind));
                }
            } elif (is_id('namespace') or is_id('module')) {
                advance();
                if kind_at() == 'id' {
                    advance();
                }
                if is_p('{') {
                    skip_balanced('{', '}');
                }
            } else {
                if pos == start_pos {
                    advance();
                }
            }
        }
    }

    def _parse_enum_decl(is_export: bool) {
        nonlocal pos;
        ename = val_at() if kind_at() == 'id' else '';
        if ename {
            advance();
        }
        if is_p('{') {
            skip_balanced('{', '}');
        }
        if ename {
            record(TsDecl(name=ename, kind='enum'), is_export);
        }
    }

    def _parse_export_list(type_only: bool) {
        nonlocal pos , saw_export;
        saw_export = True;
        expect_p('{');
        entries: list[tuple[(str, str)]] = [];
        while (pos < n and not is_p('}')) {
            eat_id('type');
            if kind_at() != 'id' and kind_at() != 'str' {
                if not eat_p(',') {
                    break;
                }
                continue;
            }
            local = val_at();
            advance();
            exp_name = local;
            if eat_id('as') {
                exp_name = val_at();
                advance();
            }
            entries.append((local, exp_name));
            if not eat_p(',') {
                break;
            }
        }
        expect_p('}');
        if eat_id('from') {
            if kind_at() == 'str' {
                advance();
            }
            for (_, exp_name) in entries {
                exported_direct[exp_name] = TsDecl(name=exp_name, kind='reexport');
            }
        } else {
            for pair in entries {
                export_pairs.append(pair);
            }
        }
        eat_p(';');
    }

    def _parse_export_default -> None {
        nonlocal pos;
        eat_id('abstract');
        eat_id('async');
        if eat_id('function') {
            d = parse_function_decl();
            exported_direct['default'] = d;
            if (d.name and d.name not in decls) {
                decls[d.name] = d;
            }
            return;
        }
        if eat_id('class') {
            if kind_at() == 'id' {
                advance();
            }
            while (pos < n and not is_p('{')) {
                advance();
            }
            skip_balanced('{', '}');
            exported_direct['default'] = TsDecl(name='default', kind='class');
            return;
        }
        if (kind_at() == 'id' and kind_at(1) == 'punct' and val_at(1) == ';') {
            export_pairs.append((val_at(), 'default'));
            advance();
            advance();
            return;
        }
        skip_to_semi();
        exported_direct['default'] = TsDecl(name='default', kind='const');
    }

    parse_statements(False);

    result: dict[str, TsDecl] = {};
    if export_eq is not None {
        if export_eq in namespaces {
            for (k, v) in namespaces[export_eq].items() {
                result[k] = v;
            }
        }
        if export_eq in decls {
            result['default'] = decls[export_eq];
        }
    } else {
        for (local, exp_name) in export_pairs {
            d = decls.get(local);
            if (d is None and local in namespaces) {
                d = TsDecl(name=local, kind='namespace');
            }
            if d is None {
                d = TsDecl(name=local, kind='reexport');
            }
            result[exp_name] = d;
        }
        for (name, d) in exported_direct.items() {
            result[name] = d;
        }
        if not saw_export {
            for (name, d) in decls.items() {
                result.setdefault(name, d);
            }
            for nsname in namespaces.keys() {
                result.setdefault(nsname, TsDecl(name=nsname, kind='namespace'));
            }
        }
    }
    if not result {
        return None;
    }
    return result;
}
