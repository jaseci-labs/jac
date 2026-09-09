import re;
import jaclang.compiler.backends.es.estree as es;
import from jaclang.compiler.frontend.constant { BROWSER_SEED_GLOBALS }

glob _AMBIENT_CACHE: set[str] = set(),
     _RAW_DECL_RE: re.Pattern = re.compile(
         r"\b(?:function|class|const|let|var)\s+\*?\s*([A-Za-z_$][A-Za-z0-9_$]*)"
     );

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

def _stub_names(path: str) -> set[str] {
    import ast;
    out: set[str] = set();
    try {
        with open(path, encoding="utf-8") as handle {
            tree = ast.parse(handle.read());
        }
    } except Exception {
        return out;
    }

    for node in tree.body {
        if isinstance(node, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)) {
            out.add(node.name);
        } elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) {
            out.add(node.target.id);
        } elif isinstance(node, ast.Assign) {
            for tgt in node.targets {
                if not isinstance(tgt, ast.Name) {
                    continue;
                }
                out.add(tgt.id);
                if tgt.id != "__all__" {
                    continue;
                }
                for elt in getattr(node.value, "elts", []) {
                    if isinstance(elt, ast.Constant) and isinstance(elt.value, str) {
                        out.add(elt.value);
                    }
                }
            }
        }
    }
    return out;
}

impl client_ambient_globals -> set[str] {
    if _AMBIENT_CACHE {
        return _AMBIENT_CACHE;
    }
    import os;
    names: set[str] = set(_JS_LANGUAGE_GLOBALS);
    names.update(BROWSER_SEED_GLOBALS);

    import jaclang;
    stub_dir = os.path.join(
        os.path.dirname(str(jaclang.__file__)), "compiler", "types"
    );
    for stub in ("js_globals.pyi", "dom_types.pyi") {
        names.update(_stub_names(os.path.join(stub_dir, stub)));
    }
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

def _harvest_raw(source: str, decls: set[str]) {
    for hit in _RAW_DECL_RE.finditer(source) {
        decls.add(hit.group(1));
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
