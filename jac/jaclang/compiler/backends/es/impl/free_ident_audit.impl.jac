import jaclang.compiler.backends.es.estree as es;
import from jaclang.compiler.frontend.constant { BROWSER_SEED_GLOBALS }

glob _AMBIENT_CACHE: set[str] = set(),
     _RAW_DECL_KEYWORDS: set[str] = {"function", "class", "const", "let", "var"};

glob _JS_LANGUAGE_GLOBALS: set[str] = {
         "globalThis",
         "import",
         "undefined",
         "NaN",
         "Infinity",
         "arguments",
         "eval",
         "Function",
         "Symbol",
         "Map",
         "Set",
         "WeakMap",
         "WeakSet",
         "WeakRef",
         "FinalizationRegistry",
         "Proxy",
         "Reflect",
         "Intl",
         "Error",
         "AggregateError",
         "EvalError",
         "RangeError",
         "ReferenceError",
         "SyntaxError",
         "TypeError",
         "URIError",
         "Int8Array",
         "Uint8ClampedArray",
         "Int16Array",
         "Uint16Array",
         "BigInt64Array",
         "BigUint64Array",
         "SharedArrayBuffer",
         "Atomics",
         "escape",
         "unescape",
         "atob",
         "btoa",
         "crypto",
         "performance",
         "URL",
         "URLSearchParams",
         "Blob",
         "File",
         "FileReader",
         "FormData",
         "AbortController",
         "AbortSignal",
         "WebSocket",
         "EventSource",
         "Event",
         "CustomEvent",
         "EventTarget",
         "MessageChannel",
         "MessagePort",
         "BroadcastChannel",
         "Worker",
         "IntersectionObserver",
         "ResizeObserver",
         "MutationObserver",
         "PerformanceObserver",
         "requestIdleCallback",
         "cancelIdleCallback",
         "matchMedia",
         "getComputedStyle",
         "customElements",
         "XMLHttpRequest",
         "Image",
         "Audio",
         "DOMParser",
         "XMLSerializer",
         "CSS",
         "Notification",
         "Request",
         "process",
         "require",
         "module",
         "exports",
         "__dirname",
         "__filename",
         "global",
         "Buffer",
         "setImmediate",
         "clearImmediate"
     };

glob _BIND_FIELDS: dict[str, set[str]] = {
         'VariableDeclarator': {'id'},
         'FunctionDeclaration': {'id', 'params'},
         'FunctionExpression': {'id', 'params'},
         'ArrowFunctionExpression': {'params'},
         'ClassDeclaration': {'id'},
         'ClassExpression': {'id'},
         'CatchClause': {'param'},
         'ImportSpecifier': {'local'},
         'ImportDefaultSpecifier': {'local'},
         'ImportNamespaceSpecifier': {'local'}
     };

glob _SKIP_FIELDS: dict[str, set[str]] = {
         'MemberExpression': {'property'},
         'Property': {'key'},
         'MethodDefinition': {'key'},
         'PropertyDefinition': {'key'},
         'ImportSpecifier': {'imported'},
         'ExportSpecifier': {'exported'},
         'ExportAllDeclaration': {'exported'},
         'LabeledStatement': {'label'},
         'BreakStatement': {'label'},
         'ContinueStatement': {'label'}
     };

glob _REF_FIELDS: dict[str, set[str]] = {'AssignmentPattern': {'right'}};

glob _REFERENCE_ONLY_NODES: set[str] = {'MemberExpression', 'CallExpression'};

glob _SYNTACTIC_IDENTIFIERS: set[str] = {
         'this',
         'super',
         'true',
         'false',
         'null',
         'undefined',
         'void'
     };

impl client_ambient_globals -> set[str] {
    if _AMBIENT_CACHE {
        return _AMBIENT_CACHE;
    }
    import from jaclang.compiler.frontend.host { active_host }
    names: set[str] = set(_JS_LANGUAGE_GLOBALS);
    names.update(BROWSER_SEED_GLOBALS);
    names.update(active_host().client_stub_globals());
    _AMBIENT_CACHE.update(names);
    return _AMBIENT_CACHE;
}

def _loc_of(nd: es.Node) -> tuple[int, int] {
    loc = nd.loc;
    if loc is None or loc.start is None {
        return (0, 0);
    }
    return (loc.start.line, loc.start.column);
}

def _word_char(ch: str) -> bool {
    return ch.isalnum() or ch == "_";
}

def _js_ident_char(ch: str) -> bool {
    return ch.isalnum() or ch == "_" or ch == "$";
}

def _harvest_raw(source: str, decls: set[str]) {
    n = len(source);
    i = 0;
    while i < n {
        if not _word_char(source[i]) {
            i += 1;
            continue;
        }
        start = i;
        while i < n and _word_char(source[i]) {
            i += 1;
        }
        if source[start:i] not in _RAW_DECL_KEYWORDS
            or i >= n
            or not source[i].isspace() {
            continue;
        }
        while i < n and source[i].isspace() {
            i += 1;
        }
        if i < n and source[i] == "*" {
            i += 1;
            while i < n and source[i].isspace() {
                i += 1;
            }
        }
        if i < n and _js_ident_char(source[i]) and not source[i].isdigit() {
            name_start = i;
            while i < n and _js_ident_char(source[i]) {
                i += 1;
            }
            decls.add(source[name_start:i]);
        }
    }
}

def _walk_value(
    value: any, binding: bool, decls: set[str], refs: list[FreeIdentifier]
) {
    if isinstance(value, es.Node) {
        _walk(value, binding, decls, refs);
    } elif isinstance(value, (list, tuple)) {
        for item in value {
            _walk_value(item, binding, decls, refs);
        }
    }
}

def _walk(
    nd: es.Node, binding: bool, decls: set[str], refs: list[FreeIdentifier]
) -> None {
    if isinstance(nd, es.RawCode) {
        _harvest_raw(nd.code, decls);
        return;
    }
    if isinstance(nd, es.Identifier) {
        if nd.name in _SYNTACTIC_IDENTIFIERS {
            return;
        }
        if binding {
            decls.add(nd.name);
        } else {
            (line, column) = _loc_of(nd);
            refs.append(FreeIdentifier(name=nd.name, line=line, column=column));
        }
        return;
    }
    kind = nd.__class__.__name__;
    child_binding = binding and (kind not in _REFERENCE_ONLY_NODES);
    bind_fields = _BIND_FIELDS.get(kind, set());
    skip_fields = _SKIP_FIELDS.get(kind, set());
    ref_fields = _REF_FIELDS.get(kind, set());
    computed = bool(getattr(nd, 'computed', False));
    for (field, value) in vars(nd).items() {
        if field in ('loc', 'type') {
            continue;
        }
        if (field in skip_fields) and not computed {
            continue;
        }
        if field in ref_fields {
            sub = False;
        } elif field in bind_fields {
            sub = True;
        } else {
            sub = child_binding;
        }
        _walk_value(value, sub, decls, refs);
    }
}

impl free_identifiers(program: es.Program, allowed: set[str]) -> list[FreeIdentifier] {
    decls: set[str] = set();
    refs: list[FreeIdentifier] = [];
    _walk(program, False, decls, refs);
    out: list[FreeIdentifier] = [];
    seen: set[str] = set();
    for ref in refs {
        if (ref.name in decls) or (ref.name in allowed) or (ref.name in seen) {
            continue;
        }
        seen.add(ref.name);
        out.append(ref);
    }
    return out;
}
