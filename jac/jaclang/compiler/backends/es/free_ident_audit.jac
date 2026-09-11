import re;
import from jaclang.compiler.ir.enums { BROWSER_SEED_GLOBALS }
import jaclang.compiler.backends.es.estree as es;

obj FreeIdentifier {
    has name: str,
        line: int,
        column: int;
}

glob RUNTIME_PRELUDE_GLOBALS: set[str] = {"__jacJsx", "__jacSpawn"};

def client_ambient_globals -> set[str];
def free_identifiers(program: es.Program, allowed: set[str]) -> list[FreeIdentifier];

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
