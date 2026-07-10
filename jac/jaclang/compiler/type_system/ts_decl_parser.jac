enum TsTypeKind {
    ANY = "any",
    NEVER = "never",
    VOID = "void",
    PRIM = "prim",
    LITERAL_STR = "literal-str",
    LITERAL_NUM = "literal-num",
    LITERAL_BOOL = "literal-bool",
    UNION = "union",
    ARRAY = "array",
    TUPLE = "tuple",
    FUNC = "func",
    REF = "ref"
}

enum TsDeclKind {
    ANY = "any",
    FUNCTION = "function",
    CONST = "const",
    TYPEALIAS = "typealias",
    INTERFACE = "interface",
    CLASS = "class",
    ENUM = "enum",
    NAMESPACE = "namespace",
    REEXPORT = "reexport"
}

enum TsAccess { PUBLIC = "public", PRIVATE = "private", PROTECTED = "protected" }

obj TsParam {
    has name: str = "",
        ty: (TsType | None) = None,
        optional: bool = False,
        rest: bool = False;
}

obj TsType {
    has kind: TsTypeKind = TsTypeKind.ANY,
        name: str = "",
        args: list[TsType] = [],
        params: list[TsParam] = [],
        ret: (TsType | None) = None;
}

obj TsMember {
    has name: str = "",
        ty: (TsType | None) = None,
        optional: bool = False,
        readonly: bool = False,
        is_method: bool = False,
        is_static: bool = False,
        access: TsAccess = TsAccess.PUBLIC;
}

obj TsDecl {
    has name: str = "",
        kind: TsDeclKind = TsDeclKind.ANY,
        ty: (TsType | None) = None,
        members: list[TsMember] = [],
        heritage: list[str] = [],
        call_sig: (TsType | None) = None;
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
        return TsType(kind=TsTypeKind.FUNC, params=params, ret=ret);
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
            return TsType(kind=TsTypeKind.ANY);
        }
        if is_p('{') {
            skip_balanced('{', '}');
            return TsType(kind=TsTypeKind.ANY);
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
            return TsType(kind=TsTypeKind.TUPLE, args=args);
        }
        if kind_at() == 'str' {
            t = TsType(kind=TsTypeKind.LITERAL_STR, name=val_at());
            advance();
            return t;
        }
        if kind_at() == 'num' {
            t = TsType(kind=TsTypeKind.LITERAL_NUM, name=val_at());
            advance();
            return t;
        }
        if kind_at() == 'tmpl' {
            advance();
            return TsType(kind=TsTypeKind.PRIM, name='string');
        }
        if (is_p('-') and kind_at(1) == 'num') {
            advance();
            t = TsType(kind=TsTypeKind.LITERAL_NUM, name='-' + val_at());
            advance();
            return t;
        }
        if kind_at() == 'id' {
            v = val_at();
            if v in ('true', 'false') {
                advance();
                return TsType(kind=TsTypeKind.LITERAL_BOOL, name=v);
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
                return TsType(kind=TsTypeKind.ANY);
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
                return TsType(kind=TsTypeKind.ANY);
            }
            if v in ('keyof', 'unique', 'infer') {
                advance();
                parse_postfix();
                return TsType(kind=TsTypeKind.ANY);
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
                return TsType(kind=TsTypeKind.VOID);
            }
            if v in _ANY_NAMES {
                advance();
                return TsType(kind=TsTypeKind.ANY);
            }
            if v in _VOID_NAMES {
                advance();
                return TsType(kind=TsTypeKind.VOID);
            }
            if v == 'never' {
                advance();
                return TsType(kind=TsTypeKind.NEVER);
            }
            if v in _PRIM_NAMES {
                advance();
                return TsType(kind=TsTypeKind.PRIM, name=v);
            }
            name = parse_qualified_name();
            args: list[TsType] = [];
            if is_p('<') {
                args = parse_generic_args();
            }
            if in_typevars(name) {
                return TsType(kind=TsTypeKind.ANY);
            }
            if (name in ('Array', 'ReadonlyArray') and len(args) == 1) {
                return TsType(kind=TsTypeKind.ARRAY, args=[args[0]]);
            }
            return TsType(kind=TsTypeKind.REF, name=name, args=args);
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
                    t = TsType(kind=TsTypeKind.ARRAY, args=[t]);
                    continue;
                }
                skip_balanced('[', ']');
                t = TsType(kind=TsTypeKind.ANY);
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
        return parts[0] if len(parts) == 1 else TsType(kind=TsTypeKind.ANY);
    }

    def parse_union -> TsType {
        eat_p('|');
        parts = [parse_intersection()];
        while eat_p('|') {
            parts.append(parse_intersection());
        }
        return parts[0]
            if len(parts) == 1
            else TsType(kind=TsTypeKind.UNION, args=parts);
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
            return TsType(kind=TsTypeKind.ANY);
        }
        return t;
    }

    def parse_return_type -> TsType {
        if (kind_at() == 'id' and kind_at(1) == 'id' and val_at(1) == 'is') {
            advance();
            advance();
            parse_type_full();
            return TsType(kind=TsTypeKind.PRIM, name='boolean');
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
            ret: TsType = TsType(kind=TsTypeKind.ANY);
            if eat_p(':') {
                ret = parse_return_type();
            }
        } finally {
            typevar_stack.pop();
        }
        eat_p(';');
        return TsDecl(
            name=fname,
            kind=TsDeclKind.FUNCTION,
            ty=TsType(kind=TsTypeKind.FUNC, params=params, ret=ret)
        );
    }

    def parse_heritage -> list[str] {
        nonlocal pos;
        bases: list[str] = [];
        while (pos < n and not is_p('{')) {
            if (is_id('extends') or is_id('implements')) {
                advance();
                continue;
            }
            if kind_at() == 'id' {
                name = parse_qualified_name();
                if is_p('<') {
                    collect_generics();
                }
                bases.append(name);
                continue;
            }
            advance();
        }
        return bases;
    }

    def parse_members -> tuple[(list[TsMember], (TsType | None))] {
        nonlocal pos;
        members: list[TsMember] = [];
        call_sig: (TsType | None) = None;
        expect_p('{');
        while (pos < n and not is_p('}')) {
            if (is_p(';') or is_p(',')) {
                advance();
                continue;
            }
            is_static = False;
            access = TsAccess.PUBLIC;
            while (
                is_id('public')
                or is_id('private')
                or is_id('protected')
                or is_id('static')
                or is_id('abstract')
                or is_id('declare')
            ) {
                if is_id('static') {
                    is_static = True;
                } elif is_id('private') {
                    access = TsAccess.PRIVATE;
                } elif is_id('protected') {
                    access = TsAccess.PROTECTED;
                } elif is_id('public') {
                    access = TsAccess.PUBLIC;
                }
                advance();
            }
            readonly = eat_id('readonly');

            if is_p('[') {
                skip_balanced('[', ']');
                if eat_p(':') {
                    parse_type_full();
                }
                eat_p(';');
                eat_p(',');
                continue;
            }
            if (
                is_p('(')
                or is_p('<')
                or (is_id('new') and kind_at(1) == 'punct' and val_at(1) == '(')
            ) {
                is_construct = is_id('new');
                if is_construct {
                    advance();
                }
                ctvs = collect_generics() if is_p('<') else set();
                typevar_stack.append(ctvs);
                try {
                    cs_params = parse_params();
                    cs_ret: TsType = TsType(kind=TsTypeKind.ANY);
                    if eat_p(':') {
                        cs_ret = parse_return_type();
                    }
                } finally {
                    typevar_stack.pop();
                }

                if (not is_construct and call_sig is None) {
                    call_sig = TsType(
                        kind=TsTypeKind.FUNC, params=cs_params, ret=cs_ret
                    );
                }
                eat_p(';');
                eat_p(',');
                continue;
            }
            if kind_at() not in ('id', 'str', 'num') {
                advance();
                continue;
            }
            mname = val_at();
            advance();
            optional = eat_p('?');
            is_method = False;
            mty: (TsType | None) = None;
            if (is_p('<') or is_p('(')) {
                is_method = True;
                mtvs = collect_generics() if is_p('<') else set();
                typevar_stack.append(mtvs);
                try {
                    mparams = parse_params();
                    mret: TsType = TsType(kind=TsTypeKind.ANY);
                    if eat_p(':') {
                        mret = parse_return_type();
                    }
                } finally {
                    typevar_stack.pop();
                }
                mty = TsType(kind=TsTypeKind.FUNC, params=mparams, ret=mret);
            } elif eat_p(':') {
                mty = parse_type_full();
            }
            members.append(
                TsMember(
                    name=mname,
                    ty=mty,
                    optional=optional,
                    readonly=readonly,
                    is_method=is_method,
                    is_static=is_static,
                    access=access,
                )
            );
            eat_p(';');
            eat_p(',');
        }
        expect_p('}');
        return (members, call_sig);
    }

    def _parse_struct_decl(kind: TsDeclKind) -> TsDecl {
        sname = val_at();
        advance();
        stvs = collect_generics() if is_p('<') else set();
        typevar_stack.append(stvs);
        sheritage: list[str] = [];
        smembers: list[TsMember] = [];
        scall_sig: (TsType | None) = None;
        try {
            sheritage = parse_heritage();
            (smembers, scall_sig) = parse_members();
        } finally {
            typevar_stack.pop();
        }
        return TsDecl(
            name=sname,
            kind=kind,
            members=smembers,
            heritage=sheritage,
            call_sig=scall_sig
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
                        _parse_export_list();
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
                        _parse_export_list();
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
            common = _parse_common_decl();
            if common is not None {
                for d in common {
                    record(d, is_export);
                }
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
                    exported_direct[nsname] = TsDecl(
                        name=nsname, kind=TsDeclKind.NAMESPACE
                    );
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
            common = _parse_common_decl();
            if common is not None {
                for d in common {
                    if (d.name and d.name not in ns_decls) {
                        ns_decls[d.name] = d;
                    }
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

    def _parse_common_decl -> (list[TsDecl] | None) {
        nonlocal pos;
        if eat_id('function') {
            return [parse_function_decl()];
        }
        if (is_id('const') or is_id('let') or is_id('var')) {
            advance();
            if eat_id('enum') {
                ed = _parse_enum_body();
                return [ed] if ed is not None else [];
            }
            out: list[TsDecl] = [];
            while kind_at() == 'id' {
                vname = val_at();
                advance();
                vty: TsType = TsType(kind=TsTypeKind.ANY);
                if eat_p(':') {
                    vty = parse_type_full();
                }
                out.append(TsDecl(name=vname, kind=TsDeclKind.CONST, ty=vty));
                if not eat_p(',') {
                    break;
                }
            }
            eat_p(';');
            return out;
        }
        if eat_id('type') {
            tname = val_at();
            advance();
            has_generics = is_p('<');
            if has_generics {
                collect_generics();
            }
            expect_p('=');
            if has_generics {
                skip_to_semi();
                return [
                    TsDecl(
                        name=tname,
                        kind=TsDeclKind.TYPEALIAS,
                        ty=TsType(kind=TsTypeKind.ANY)
                    )
                ];
            }
            aty = parse_type_full();
            eat_p(';');
            return [TsDecl(name=tname, kind=TsDeclKind.TYPEALIAS, ty=aty)];
        }
        if eat_id('interface') {
            return [_parse_struct_decl(TsDeclKind.INTERFACE)];
        }
        if eat_id('class') {
            return [_parse_struct_decl(TsDeclKind.CLASS)];
        }
        if eat_id('enum') {
            ed = _parse_enum_body();
            return [ed] if ed is not None else [];
        }
        return None;
    }

    def _parse_enum_body -> (TsDecl | None) {
        nonlocal pos;
        ename = val_at() if kind_at() == 'id' else '';
        if ename {
            advance();
        }
        if is_p('{') {
            skip_balanced('{', '}');
        }
        if ename {
            return TsDecl(name=ename, kind=TsDeclKind.ENUM);
        }
        return None;
    }

    def _parse_export_list {
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
                exported_direct[exp_name] = TsDecl(
                    name=exp_name, kind=TsDeclKind.REEXPORT
                );
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
            if (is_id('extends') or is_id('implements') or is_p('{') or is_p('<')) {
                atvs = collect_generics() if is_p('<') else set();
                typevar_stack.append(atvs);
                try {
                    aherit = parse_heritage();
                    (amembers, acall_sig) = parse_members();
                } finally {
                    typevar_stack.pop();
                }
                exported_direct['default'] = TsDecl(
                    name='default',
                    kind=TsDeclKind.CLASS,
                    members=amembers,
                    heritage=aherit,
                    call_sig=acall_sig
                );
                return;
            }

            d = _parse_struct_decl(TsDeclKind.CLASS);
            exported_direct['default'] = d;
            if (d.name and d.name not in decls) {
                decls[d.name] = d;
            }
            return;
        }
        if (kind_at() == 'id' and kind_at(1) == 'punct' and val_at(1) == ';') {
            export_pairs.append((val_at(), 'default'));
            advance();
            advance();
            return;
        }
        skip_to_semi();
        exported_direct['default'] = TsDecl(name='default', kind=TsDeclKind.CONST);
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
                d = TsDecl(name=local, kind=TsDeclKind.NAMESPACE);
            }
            if d is None {
                d = TsDecl(name=local, kind=TsDeclKind.REEXPORT);
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
                result.setdefault(
                    nsname, TsDecl(name=nsname, kind=TsDeclKind.NAMESPACE)
                );
            }
        }
    }
    if not result {
        return None;
    }
    return result;
}
