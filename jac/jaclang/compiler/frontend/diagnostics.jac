enum Severity { ERROR = "error", WARNING = "warning", NOTE = "note", HELP = "help" }

enum Category {
    SYNTAX = "syntax",
    TYPE = "type",
    SEMANTIC = "semantic",
    LINT = "lint",
    IMPORT = "import",
    CODEGEN = "codegen",
    RUNTIME = "runtime",
    ICE = "ice"
}

obj DiagnosticInfo {
    has code: str,
        severity: Severity,
        category: Category,
        message_template: str,
        help_text: str | None = None,
        url_slug: str | None = None,
        blocks_codegen: bool = False;

    def format_message(**kwargs: object) -> str {
        filled = _fill_template(self.message_template, kwargs);
        if filled is None {
            return f"{self.message_template} (missing key)";
        }
        return filled;
    }

    def format_help(**kwargs: object) -> (str | None) {
        if self.help_text is None {
            return None;
        }
        filled = _fill_template(self.help_text, kwargs);
        if filled is None {
            return self.help_text;
        }
        return filled;
    }
}

def _fill_template(template: str, kwargs: dict[str, object]) -> (str | None) {
    esc_open = chr(1);
    esc_close = chr(2);
    out = template.replace("{{", esc_open).replace("}}", esc_close);
    for (k, v) in kwargs.items() {
        key = "{" + str(k) + "}";
        out = out.replace(key, str(v));
    }
    scan = 0;
    while True {
        b_open = out.find("{", scan);
        if b_open < 0 {
            break;
        }
        b_close = out.find("}", b_open + 1);
        if b_close < 0 {
            break;
        }
        inner = out[b_open + 1:b_close];
        is_name = len(inner) > 0;
        for ch in inner {
            if not (ch.isalnum() or ch == "_") {
                is_name = False;
                break;
            }
        }
        if is_name {
            return None;
        }
        scan = b_open + 1;
    }
    return out.replace(esc_open, "{").replace(esc_close, "}");
}

glob DIAGNOSTICS: dict[str, DiagnosticInfo] = {};

def _reg(
    code: str,
    severity: Severity,
    category: Category,
    template: str,
    help_text: str | None = None,
    blocks_codegen: bool = False
) -> DiagnosticInfo {
    sitting = DIAGNOSTICS.get(code);
    if sitting is not None {
        raise ValueError(
            f"diagnostic code {code} is claimed twice. It is already "
            f"registered as {sitting.severity.value}/{sitting.category.value} "
            f"'{sitting.message_template}' and is registered again as "
            f"{severity.value}/{category.value} '{template}'. A code names "
            "exactly one diagnostic: the second registration would shadow "
            "the first everywhere it is referenced, and the native link "
            "refuses this module on the duplicate symbol. Give the later "
            "claimant a code of its own and move its pins."
        );
    }
    info = DiagnosticInfo(
        code=code,
        severity=severity,
        category=category,
        message_template=template,
        help_text=help_text,
        url_slug=code.lower(),
        blocks_codegen=blocks_codegen
    );
    DIAGNOSTICS[code] = info;
    return info;
}

def _err(
    code: str,
    cat: Category,
    tmpl: str,
    help: str | None = None,
    blocks_codegen: bool = False
) -> DiagnosticInfo {
    return _reg(code, Severity.ERROR, cat, tmpl, help, blocks_codegen);
}

def _warn(
    code: str, cat: Category, tmpl: str, help: str | None = None
) -> DiagnosticInfo {
    return _reg(code, Severity.WARNING, cat, tmpl, help);
}

glob E0001 = _err("E0001", Category.SYNTAX, "Expected '{expected}', got '{got}'"),
     E0002 = _err("E0002", Category.SYNTAX, "Missing '{token}'"),
     E0003 = _err("E0003", Category.SYNTAX, "Expected identifier, got '{got}'"),
     E0004 = _err("E0004", Category.SYNTAX, "Unexpected token in expression: '{got}'"),
     E0005 = _err("E0005", Category.SYNTAX, "Unexpected token '{token}'"),
     E0006 = _err("E0006", Category.SYNTAX, "Unexpected token"),
     E0010 = _err(
         "E0010",
         Category.SYNTAX,
         "'{keyword}' is not supported in Jac",
         help="Jac uses different syntax for this construct."
     ),
     E0012 = _err(
         "E0012",
         Category.SYNTAX,
         "Use the `new(target, ...args)` ambient builtin to create new instances",
         help="`new` is a portable constructor: it lowers to `Cls(*args)` on the server and to `Reflect.construct(Cls, [args])` in cl blocks."
     ),
     E0013 = _err(
         "E0013",
         Category.SYNTAX,
         "'{keyword}' is a keyword and cannot be used as a {context} name",
         help="The backtick escape is a prefix, not a pair. Put one backtick immediately before the keyword, with nothing after the name."
     ),
     E0014 = _err(
         "E0014",
         Category.SYNTAX,
         "'{name}' is not a keyword -- remove the backtick",
         help="The backtick escape exists only to use a reserved keyword as an identifier. On a name that is not a keyword it is a stray mark, so write the name directly."
     ),
     E0020 = _err(
         "E0020",
         Category.SYNTAX,
         "Walrus operator ':=' requires a simple name on the left side"
     ),
     E0021 = _err(
         "E0021", Category.SYNTAX, "Expected :<+ or :+> to close connect operator"
     ),
     E0022 = _err(
         "E0022",
         Category.SYNTAX,
         "Expected '{{' after lambda parameters",
         help="Lambda bodies are braced; a single expression statement is the implicit return, e.g. 'lambda (x: int) { x + 1; }'."
     ),
     E0023 = _err(
         "E0023",
         Category.SYNTAX,
         "Expected augmented assignment in for-loop step (for init while cond with step)"
     ),
     E0024 = _err(
         "E0024",
         Category.SYNTAX,
         "Cannot assign to '{name}' -- it is a built-in reference, not a variable",
         help="Use a different variable name, or use backtick escaping (e.g. `root) to create a local variable with the same name."
     ),
     E0025 = _err(
         "E0025",
         Category.SYNTAX,
         "JavaScript arrow function syntax ('=>') is not supported in Jac",
         help="Use Jac lambda syntax instead: 'lambda (e: ChangeEvent) { ... }' or 'lambda (x: int) { x + 1; }'."
     ),
     E0026 = _err(
         "E0026",
         Category.SYNTAX,
         "Connect/disconnect operator requires a right operand",
         help="Connect (`++>`, `+>:T:+>`) and disconnect (`del -->`, `del ->:T:->`) operators are binary -- supply the right-hand side, e.g. `a ++> b;` or `a del --> b;`."
     ),
     E0027 = _err(
         "E0027",
         Category.SYNTAX,
         "Expected ':+>' to close forward typed connection -- did you mean '+>: <EdgeType> :+> <node>'?"
     ),
     E0028 = _err(
         "E0028",
         Category.SYNTAX,
         "Expected ':<+' or ':+>' to close backward typed connection -- did you mean '<+: <EdgeType> :<+ <node>' (backward) or '<+: <EdgeType> :+> <node>' (bidirectional)?"
     ),
     E0030 = _err("E0030", Category.SYNTAX, "Unexpected semicolon at module level"),
     E0031 = _err(
         "E0031",
         Category.SYNTAX,
         "Module-level 'with' blocks only support 'entry', not 'exit'"
     ),
     E0032 = _err(
         "E0032",
         Category.SYNTAX,
         "Unexpected '{token}' -- must follow its parent statement (if/try/match/switch)"
     ),
     E0033 = _err(
         "E0033",
         Category.SEMANTIC,
         "{what} is not known at compile time{reason}",
         help="A comptime site needs a value the compiler can compute: a literal, a comptime binding, a comptime parameter, an enum member, a type, or a call to an evaluable function whose arguments are all comptime-known. Plain 'glob' bindings and runtime values do not qualify.",
         blocks_codegen=True
     ),
     E0034 = _err(
         "E0034",
         Category.SYNTAX,
         "Expected 'with' after 'can' ability name (use 'def' for function-style declarations)"
     ),
     E0040 = _err(
         "E0040",
         Category.SYNTAX,
         "try statement requires at least one except or finally block"
     ),
     E0041 = _err(
         "E0041", Category.SYNTAX, "match statement requires at least one case"
     ),
     E0042 = _err(
         "E0042", Category.SYNTAX, "switch statement requires at least one case"
     ),
     E0043 = _err(
         "E0043", Category.SYNTAX, "enum body must contain at least one member"
     ),
     E0044 = _err(
         "E0044", Category.SYNTAX, "import statement must specify at least one item"
     ),
     E0045 = _err(
         "E0045",
         Category.SYNTAX,
         "Expected literal (INT, FLOAT, or STRING) as mapping pattern key"
     ),
     E0046 = _err("E0046", Category.SYNTAX, "Unexpected token in archetype body"),
     E0047 = _err("E0047", Category.SYNTAX, "Expected '{{' or 'by' for impl body"),
     E0048 = _err(
         "E0048",
         Category.SYNTAX,
         "Parenthesized filter syntax '(?:...)' was removed. Use bracket syntax '[?:...]' instead.",
         "Replace (?:Type, cond) with [?:Type, cond]"
     ),
     E0049 = _err(
         "E0049",
         Category.SYNTAX,
         "'root()' was removed. Use bare 'root' instead.",
         "'root' is a reserved keyword that resolves to the graph anchor — drop the parentheses."
     ),
     E0050 = _err("E0050", Category.SYNTAX, "Duplicate '{param}' in parameter list"),
     E0051 = _err(
         "E0051",
         Category.SYNTAX,
         "'{first}' must appear before '{second}' in parameter list"
     ),
     E0052 = _err(
         "E0052",
         Category.SYNTAX,
         "Parameter '{name}' is missing a type annotation",
         help="All function and method parameters require explicit type annotations in Jac."
     ),
     E0055 = _err(
         "E0055", Category.SYNTAX, "'yield' is only valid inside a function body"
     ),
     E0058 = _err("E0058", Category.SYNTAX, "'{keyword}' is only valid inside a loop"),
     E0063 = _err(
         "E0063",
         Category.SYNTAX,
         "'glob' is only valid at module level, perhaps you mean global",
         help="Move the glob declaration to the top of the file, outside any function or code block.",
         blocks_codegen=True
     ),
     E0064 = _err(
         "E0064",
         Category.SEMANTIC,
         "Typed declaration of '{name}' shadows an outer binding that was already rebound in this scope",
         "Assignments bind to the nearest enclosing declaration; to introduce a shadowing local, place the typed declaration before the first assignment or use of '{name}', or rename the local."
     ),
     E0065 = _err("E0065", Category.SYNTAX, "Duplicate keyword argument '{name}'"),
     E0066 = _err(
         "E0066", Category.SYNTAX, "Positional argument follows keyword argument"
     ),
     E0067 = _err(
         "E0067",
         Category.SEMANTIC,
         "'{name}' is a Python reserved word and cannot be used as a {context} name",
         "Backtick escaping cannot help here — the generated Python for fields and parameters uses the name as a real identifier, which would be invalid. Rename the {context}."
     ),
     E0071 = _err("E0071", Category.SYNTAX, "Default 'except' clause must be last"),
     E0075 = _err("E0075", Category.SYNTAX, "Duplicate base class '{name}'"),
     E0076 = _err("E0076", Category.SYNTAX, "Duplicate method '{name}' in class body"),
     E0077 = _err(
         "E0077",
         Category.SYNTAX,
         "Duplicate declaration of '{name}' (already declared as {kind})",
         help="Jac supports decl/impl separation, not decl/decl. Either inline the body into the first `obj/node/edge/walker/enum` block, or split into a body-less declaration plus an `impl` block."
     ),
     E0080 = _err(
         "E0080",
         Category.SYNTAX,
         "Property declarations cannot have an initializer",
         help="Declare backing storage as a separate `has` field (e.g. `has _x: T = value;`) and reference it from your accessors."
     ),
     E0081 = _err(
         "E0081",
         Category.SYNTAX,
         "Property declaration must contain at least one of `getter`, `setter`, `deleter`"
     ),
     E0082 = _err(
         "E0082",
         Category.SEMANTIC,
         "Cannot assign to state field '{name}' during render",
         help="Component body statements run on every render, and state writes are immediately visible, so this assignment would re-render forever. Move it into a `can` ability, an event handler, or a method.",
         blocks_codegen=True
     ),
     E0083 = _err(
         "E0083",
         Category.SYNTAX,
         "Cannot delete {what}",
         help="`del` takes either a location to unbind -- a name, an attribute, or a subscript -- or an expression yielding graph objects to destroy. This target is neither."
     ),
     W0060 = _warn(
         "W0060",
         Category.SYNTAX,
         "Docstrings in Jac go before the declaration, not inside the body. Move this string before the enclosing test/can/obj/etc."
     ),
     W0063 = _warn(
         "W0063",
         Category.SYNTAX,
         "JSX spread '{{...expr}}' is JS-idiomatic. Prefer '{{**expr}}' in Jac.",
         "Jac uses ** for dict unpacking -- use {**expr} instead of {...expr} in JSX attributes."
     ),
     E0100 = _err("E0100", Category.SYNTAX, "Unterminated string literal"),
     E0101 = _err("E0101", Category.SYNTAX, "Unterminated block comment"),
     E0102 = _err("E0102", Category.SYNTAX, "Unterminated f-string"),
     E0103 = _err("E0103", Category.SYNTAX, "Unterminated inline Python block"),
     E0104 = _err("E0104", Category.SYNTAX, "Unexpected end of JSX content"),
     E0105 = _err("E0105", Category.SYNTAX, "Unexpected character: '{ch}'"),
     E0106 = _err("E0106", Category.SYNTAX, "Unexpected character in JSX tag: '{ch}'"),
     E0107 = _err(
         "E0107", Category.SYNTAX, "Lexer stuck at EOF in mode {mode} (pos={pos})"
     ),
     E0108 = _err(
         "E0108",
         Category.SEMANTIC,
         "Compile-time evaluation failed: {reason}",
         help="Comptime code runs inside the compiler on a pure subset of Jac: no I/O, no foreign calls, no walkers, no module-level side effects, and a bounded amount of work ([build] comptime_fuel in jac.toml raises the budget).",
         blocks_codegen=True
     ),
     E0109 = _err(
         "E0109",
         Category.SEMANTIC,
         "Compile-time assertion failed{message}",
         blocks_codegen=True
     ),
     E0110 = _err(
         "E0110",
         Category.SYNTAX,
         "Unsupported escape sequence '\\N{{...}}'",
         help="Resolving a Unicode character name needs the name database, which the compiler does not carry. Write the code point as \\uXXXX or \\UXXXXXXXX, or prefix the string with r to keep the backslash."
     ),
     W0100 = _warn(
         "W0100",
         Category.SYNTAX,
         "Invalid escape sequence '{esc}'",
         "Double the backslash for a literal backslash, or prefix the string with r to make it raw."
     ),
     E1001 = _err("E1001", Category.TYPE, "Cannot assign {actual} to {expected}"),
     E1002 = _err(
         "E1002", Category.TYPE, "Cannot return {actual}, expected {expected}"
     ),
     E1003 = _err(
         "E1003",
         Category.TYPE,
         "Return type annotation required when function returns a value"
     ),
     E1004 = _err(
         "E1004",
         Category.TYPE,
         "Function '{name}' declared return type {ret_type} but may implicitly return None"
     ),
     E1005 = _err(
         "E1005",
         Category.TYPE,
         "Cannot assign to read-only property '{name}' (no setter defined)"
     ),
     E1010 = _err(
         "E1010", Category.TYPE, "Operator \"{op}\" not supported for type \"{type}\""
     ),
     E1011 = _err(
         "E1011",
         Category.TYPE,
         "Unsupported operand types for {op}: {left} and {right}"
     ),
     E1020 = _err("E1020", Category.TYPE, "Cannot unpack non-iterable {type}"),
     E1021 = _err("E1021", Category.TYPE, "Type \"{type}\" is not iterable"),
     E1022 = _err(
         "E1022", Category.TYPE, "Type {type} is not iterable (no __iter__ method)"
     ),
     E1023 = _err("E1023", Category.TYPE, "Type \"{type}\" is not callable"),
     E1030 = _err(
         "E1030", Category.TYPE, "Type \"{base_type}\" has no attribute \"{attr}\""
     ),
     E1031 = _err(
         "E1031",
         Category.TYPE,
         "Cannot access attribute \"{attr}\" for type \"{type}\""
     ),
     E1032 = _err(
         "E1032", Category.TYPE, "Type is Unknown, cannot access attribute \"{attr}\""
     ),
     E1033 = _err(
         "E1033", Category.TYPE, "Member \"{member}\" not found on type \"{type}\""
     ),
     E1034 = _err(
         "E1034",
         Category.TYPE,
         "Cannot perform assignment comprehension on type \"{type}\""
     ),
     E1035 = _err(
         "E1035", Category.TYPE, "Type \"{src}\" is not assignable to type \"{dest}\""
     ),
     W1036 = _warn(
         "W1036",
         Category.TYPE,
         "Generic type \"{type}\" used without type arguments, defaulting to"
         " \"{type}[any]\"; consider adding explicit type arguments"
     ),
     W1037 = _warn(
         "W1037",
         Category.TYPE,
         "Explicit 'any' type annotation disables type checking here;"
         " consider a more specific type"
     ),
     E1040 = _err("E1040", Category.TYPE, "Type \"{type}\" is not subscriptable"),
     E1041 = _err("E1041", Category.TYPE, "Type \"{type}\" is not awaitable"),
     E1042 = _err(
         "E1042",
         Category.TYPE,
         "Expected {expected}, but got {actual} -- this call returns a coroutine "
         "that was not awaited",
         help="Add 'await' to the call, e.g. 'await foo()'. 'sv import' (server) "
         "functions are async RPC stubs on the client and always need 'await'."
     ),
     E1043 = _err(
         "E1043",
         Category.TYPE,
         "TypedDict \"{type}\" has no key \"{key}\"",
         help="Add the key to the TypedDict definition, or index with a key "
         "declared on the type."
     ),
     E1044 = _err(
         "E1044",
         Category.TYPE,
         "Cast target is not a type: \"{type}\"",
         help="The right-hand side of 'as' must be a type expression, e.g. "
         "'int', 'list[int]', or 'int | None'."
     ),
     E1050 = _err(
         "E1050",
         Category.TYPE,
         "Not all required parameters were provided in the function call: {params}"
     ),
     E1051 = _err("E1051", Category.TYPE, "Too many positional arguments"),
     E1052 = _err(
         "E1052", Category.TYPE, "Named argument '{name}' does not match any parameter"
     ),
     E1053 = _err(
         "E1053",
         Category.TYPE,
         "Cannot assign {actual} to parameter '{name}' of type {expected}"
     ),
     E1054 = _err(
         "E1054",
         Category.TYPE,
         "No matching overload found for the function call with the given arguments"
     ),
     E1055 = _err(
         "E1055",
         Category.TYPE,
         "No matching overload found for method \"{method}\" with the given arguments"
     ),
     E1056 = _err(
         "E1056",
         Category.TYPE,
         "Positional only parameter '{name}' cannot be matched with a named argument"
     ),
     E1057 = _err("E1057", Category.TYPE, "Parameter '{name}' already matched"),
     E1060 = _err(
         "E1060",
         Category.TYPE,
         "TypeVar \"{name}\" must be assigned to a simple variable, not an index or member expression"
     ),
     E1061 = _err(
         "E1061",
         Category.TYPE,
         "TypeVar name \"{name}\" must match the assigned variable name \"{var}\""
     ),
     E1062 = _err(
         "E1062",
         Category.TYPE,
         "TypeVar \"{name}\" is already in use by an outer scope"
     ),
     E1063 = _err(
         "E1063",
         Category.TYPE,
         "TypeVar() requires a string literal as the first argument"
     ),
     E1064 = _err(
         "E1064", Category.TYPE, "TypeVar requires at least two constrained types"
     ),
     E1065 = _err(
         "E1065",
         Category.TYPE,
         "Type variable \"{name}\" has no meaning in this context"
     ),
     E1070 = _err(
         "E1070",
         Category.TYPE,
         "Callable requires at least one type argument for return type"
     ),
     E1071 = _err(
         "E1071",
         Category.TYPE,
         "First argument to Callable must be a list of types [...] or ellipsis (...)"
     ),
     E1072 = _err(
         "E1072", Category.TYPE, "Callable requires a return type as second argument"
     ),
     E1073 = _err(
         "E1073",
         Category.TYPE,
         "Callable accepts only two type arguments: parameter types and return type"
     ),
     E1080 = _err(
         "E1080",
         Category.TYPE,
         "Contravariant type variable cannot be used in return type"
     ),
     E1081 = _err(
         "E1081",
         Category.TYPE,
         "Covariant type variable cannot be used in parameter type"
     ),
     E1090 = _err(
         "E1090", Category.TYPE, "Cannot raise {type} (not an exception type)"
     ),
     E1091 = _err(
         "E1091",
         Category.TYPE,
         "Type {type} cannot be used in 'with' statement (no __enter__ method)"
     ),
     E1092 = _err(
         "E1092",
         Category.TYPE,
         "Type {type} cannot be used in 'with' statement (no __exit__ method)"
     ),
     E1093 = _err("E1093", Category.TYPE, "Cannot yield {actual}, expected {expected}"),
     E1094 = _err(
         "E1094",
         Category.TYPE,
         "Visit target must be a node, edge, path, or collection thereof, got {type}"
     ),
     E1095 = _err(
         "E1095",
         Category.TYPE,
         "Field '{field}' declared 'postinit' is never assigned in {arch}.postinit"
     ),
     E1096 = _err(
         "E1096", Category.TYPE, "Connection left operand must be a node instance"
     ),
     E1097 = _err(
         "E1097", Category.TYPE, "Connection right operand must be a node instance"
     ),
     E1098 = _err("E1098", Category.TYPE, "Connection type must be an edge instance"),
     E1099 = _err(
         "E1099",
         Category.TYPE,
         "Cannot access attribute \"{attr}\" for type \"{type}\"; attribute is missing from {missing}"
     ),
     E1100 = _err(
         "E1100",
         Category.TYPE,
         "Cannot assign {actual} to JSX prop '{name}' of type {expected}"
     ),
     E1101 = _err(
         "E1101", Category.TYPE, "Component '{component}' has no prop '{name}'"
     ),
     E1102 = _err(
         "E1102", Category.TYPE, "Component '{component}' requires prop '{name}'"
     ),
     E1103 = _err(
         "E1103",
         Category.TYPE,
         "Cannot assign {actual} to intrinsic prop '{name}' of type {expected}"
     ),
     E1104 = _err(
         "E1104",
         Category.TYPE,
         "Cannot spread type {actual} into '{component}' (expected dict)"
     ),
     E1105 = _err(
         "E1105",
         Category.TYPE,
         "JSX tag '<{tag}>' is not in scope in a mobUI project;"
         " use {suggestion} instead",
         "mobUI projects target React Native as well as the web, where raw"
         " HTML host elements do not exist. If the tag is meant to be a"
         " component, make sure it is imported and in scope. Otherwise, replace"
         " it with a @jac/mobui primitive (View, Text, Pressable, TextInput,"
         " Image, ScrollView, ...). Lowercase tags that resolve to imported"
         " components are"
         " allowed; only unresolved names are rejected.",
         blocks_codegen=True
     ),
     E1106 = _err(
         "E1106",
         Category.TYPE,
         "Archetype '{name}' inherits builtin primitive '{base}', which has no"
         " defined lowering",
         help="Subclassing a builtin primitive gives each backend a different"
         " semantics (dataclass constructors shadow the builtin's, native has"
         " no boxed layout for it). For a zero-cost branded id, declare"
         " `type {name} := {base};` instead: the brand exists only at"
         " check time and the runtime value stays a plain {base} on every"
         " lowering."
     ),
     E1107 = _err(
         "E1107",
         Category.TYPE,
         "Distinct alias (`:=`) base must be a builtin primitive, got {base}",
         help="An erased distinct type is a check-time brand over a primitive"
         " runtime value (int, float, str, bool, bytes). For richer types,"
         " declare an archetype that wraps the value instead."
     ),
     E1110 = _err(
         "E1110",
         Category.TYPE,
         "Operator \"{op}\" not supported between types \"{left}\" and \"{right}\""
     ),
     E1111 = _err(
         "E1111",
         Category.TYPE,
         "Right operand of \"{op}\" must support \"__contains__\"; \"{type}\" does not"
     ),
     E1112 = _err(
         "E1112",
         Category.TYPE,
         "Walker `reports` field must be a list type, got \"{type}\"",
         "Declare it as `has reports: list[T] = [];` so that `report X` and `(spawn W).reports` are typed against `T`."
     ),
     E1113 = _err(
         "E1113", Category.TYPE, "Cannot report \"{actual}\", expected \"{expected}\""
     ),
     E1114 = _err(
         "E1114",
         Category.TYPE,
         "Spawn operator requires a walker instance on one side, got \"{left}\" spawn \"{right}\""
     ),
     E1115 = _err(
         "E1115",
         Category.TYPE,
         "Spawn target must be a node, edge, or collection thereof, got \"{type}\""
     ),
     E1116 = _err(
         "E1116",
         Category.TYPE,
         "Walker ability trigger must be a node, edge, or `Root`, got \"{type}\""
     ),
     E1117 = _err(
         "E1117",
         Category.TYPE,
         "Node/edge ability trigger must be a walker, got \"{type}\""
     ),
     E1118 = _err(
         "E1118",
         Category.TYPE,
         "Connection {side} operand has unparameterized collection type \"{type}\";"
         " element types cannot be verified — use \"{type}[NodeType]\" or pass a"
         " concrete list of nodes instead"
     ),
     E1119 = _err(
         "E1119",
         Category.TYPE,
         "Lambda parameter '{name}' has no type and none could be inferred from context",
         "Jac is strictly typed: a lambda's parameter types must be known. Annotate the"
         " parameter, e.g. `lambda (x: int) { x + 1; }` (the return type is still inferred), or"
         " place the lambda where its type is fixed by context — passed as a typed callback"
         " (`sorted(xs, key=lambda (x) { ... })`) or bound to a `Callable`-typed target."
     ),
     E1120 = _err(
         "E1120",
         Category.IMPORT,
         "Import of '{name}' from untyped external module '{module}' (no type declarations found)",
         "This project sets `[check] untyped-external = \"error\"` in jac.toml, so"
         " every external import must be typed. Install a package that ships"
         " TypeScript declarations (or the matching @types/<package>), or relax"
         " the setting to \"warn\"."
     ),
     E1121 = _err(
         "E1121",
         Category.TYPE,
         "Possibly-None value of type \"{type}\" used where {required} is required",
         help="Native code requires optionals to be narrowed before use at a"
         " site that needs the unwrapped value. Guard the value first, e.g."
         " `if x is not None { ... }`. Equality (`==`, `!=`) and `is None`"
         " checks operate on the optional directly and need no narrowing."
     ),
     E1122 = _err(
         "E1122",
         Category.IMPORT,
         "'Any' cannot be imported from 'typing' -- use jac's builtin `any`",
         help="Jac has its own `any` and will not carry an aliased twin: the two"
         " spell the same type, so a second name for it is redundant. Drop 'Any'"
         " from the import list (remove the import when it was the only name) and"
         " write the lowercase keyword instead -- `x: any`, `dict[str, any]`."
         " If you need the runtime `typing.Any` object itself (reflection over"
         " annotations, not an annotation), reach it in module form: `import"
         " typing;` then `typing.Any`.",
         blocks_codegen=True
     ),
     E1123 = _err(
         "E1123",
         Category.IMPORT,
         "'{name}' cannot be imported from 'typing' -- use the builtin `{remedy}`",
         help="'{name}' is the deprecated typing alias for the builtin"
         " `{remedy}`. The two spell the same type, and jac subscripts the"
         " builtin directly, so the alias buys nothing and costs an import."
         " Drop '{name}' from the import list (remove the import when it was"
         " the only name) and write the builtin instead -- `{remedy}[int]`,"
         " not `{name}[int]`.",
         blocks_codegen=True
     ),
     E1124 = _err(
         "E1124",
         Category.TYPE,
         "Membership test \"{op}\" over an operand with no static type"
         " (\"{type}\"); native code cannot answer it",
         help="Every container answers `in` from its own layout, so the operand"
         " has to carry one by the time the comparison is reached. This one"
         " has no static type at all -- typed `any`, or left unannotated and"
         " never inferred -- so there is no layout to reach and no"
         " dynamic-dispatch tier to fall back on. Annotate the operand with the"
         " container it actually holds (`list[Tag]`, `dict[str, int]`,"
         " `set[str]`), or bind it to a directly-typed local first, so its"
         " layout reaches the comparison.",
         blocks_codegen=True
     ),
     E1125 = _err(
         "E1125",
         Category.IMPORT,
         "'{name}' is ambient and cannot be imported from '{module}'",
         help="Jac provides '{name}' in every module's scope and generated"
         " code re-imports it automatically, so the explicit import is a"
         " second spelling of the same binding -- and when the source is"
         " 'typing', the import alone keeps the module off the native"
         " pathway. Drop '{name}' from the import list (remove the import"
         " when it was the only name) and keep writing '{name}' as before."
         " Binding a different local name on purpose stays legal: alias it"
         " ('{name} as LocalName').",
         blocks_codegen=True
     ),
     E1126 = _err(
         "E1126",
         Category.TYPE,
         "Integer literal {value} does not fit in {type} (range {min}..{max})",
         help="A literal must be in the target's range; a value outside it never"
         " truncates silently. Use a wider type, or spell the modular result"
         " explicitly with `{type}.wrap({value})`."
     ),
     E1127 = _err(
         "E1127",
         Category.TYPE,
         "Cannot implicitly convert {src} to {dest}; the conversion is not value-preserving",
         help="Only widening conversions are implicit (i8 -> i16 -> i32 -> i64 -> int,"
         " u8 -> u16 -> u32 -> u64 -> int, unsigned into a strictly wider signed type,"
         " f32 -> f64 -> float). Narrowing, a same-width sign change, `int` into a"
         " sized type, and 64-bit ints into floats need the checked cast `{dest}(x)`,"
         " which raises OverflowError out of range, or the modular `{dest}.wrap(x)`."
     ),
     E1128 = _err(
         "E1128",
         Category.TYPE,
         "Operands of '{op}' have no common fixed-width type ({left} and {right})",
         help="Neither operand widens into the other, so the operator has no width"
         " to compute at. Cast one operand explicitly, e.g. `{left}(rhs)` or"
         " `{right}(lhs)`, to choose the width and sign of the operation."
     ),
     E1129 = _err(
         "E1129",
         Category.TYPE,
         "Unary minus on unsigned type {type}",
         help="An unsigned type has no negative values, so `-x` cannot be typed."
         " Negate in a signed type (`-i64(x)`), or use `wrapping_neg(x)` for the"
         " two's-complement result at the same width."
     ),
     E1130 = _err(
         "E1130",
         Category.TYPE,
         "Float literal {value} overflows {type} (largest finite magnitude {max})",
         help="The literal is past what the target float can represent, so it"
         " would arrive as `inf`. Use a wider float type, or write the value the"
         " type can actually hold."
     ),
     E1131 = _err(
         "E1131",
         Category.TYPE,
         "'{name}' is a type-only export of '{module}'{scope} and must be"
         " imported with `import type`",
         help="{why} With no runtime binding to import, a plain `import from`"
         " emits a named specifier the loader cannot satisfy -- in the browser"
         " that is an ESM link error that takes the whole module graph down."
         " Move '{name}' to its own `import type from {module} {{ {name} }}`"
         " statement, which the client backend erases and the server backend"
         " lowers to a `typing.TYPE_CHECKING` guard; the value imports from"
         " '{module}' stay where they are.",
         blocks_codegen=True
     ),
     E1132 = _err(
         "E1132",
         Category.TYPE,
         "'{name}' was imported with `import type` and cannot be used as a value",
         help="An `import type` binding exists only for the checker: no"
         " runtime import is emitted for it, so calling it, reading an"
         " attribute off it, passing it to `isinstance`/`issubclass`,"
         " decorating with it, inheriting from it, or assigning it all reach"
         " a name nothing binds. Annotations, `as` casts, `has` field types,"
         " generic arguments and `type` alias right-hand sides are type"
         " position and stay legal. If '{name}' is genuinely needed as a"
         " value, import it with a plain `import from` instead -- which"
         " requires that it actually has a runtime export.",
         blocks_codegen=True
     ),
     E1133 = _err(
         "E1133",
         Category.TYPE,
         "`del` target of type '{type}' can never yield a graph object",
         help="A `del` target that is not a name, an attribute or a subscript is a"
         " destroy request, so it must yield nodes, edges or archetypes. Assign"
         " `None` to the location that holds this value if you meant to drop a"
         " reference."
     ),
     E1134 = _err(
         "E1134",
         Category.IMPORT,
         "Relative import '{module}' names no module",
         help="A dotted relative import addresses a file inside this project, so"
         " its target has to sit beside the importing module: '{module}'"
         " resolves to no .jac, .py, .pyi or .js file and to no package"
         " directory. Create the module, correct the spelling, or drop the"
         " import. Leaving it unresolved erases the binding from the emitted"
         " client bundle, where it fails as an undefined name at runtime. Two"
         " shapes are exempt: a bare specifier, which can name an npm package"
         " installed later, and an import inside a try that catches"
         " ImportError, where the author means the failure and the handler is"
         " the fallback. A string specifier ('./thing.tsx', './libfoo.so') is"
         " not checked here, since another toolchain resolves it.",
         blocks_codegen=True
     ),
     E1301 = _err(
         "E1301",
         Category.SEMANTIC,
         "Use of '{name}' after it was moved",
         help="'{name}' is an `own` binding, so assigning it elsewhere (or passing"
         " it into managed storage) moves the value out. The value now lives at the"
         " destination — read it there, or reassign '{name}' before using it again."
     ),
     E1302 = _err(
         "E1302",
         Category.SEMANTIC,
         "Conflicting mutable borrow of '{name}' while another borrow is live",
         help="A value may have any number of shared (&) borrows or exactly one"
         " mutable (&mut) borrow, never both at once. Let the existing borrow go out"
         " of scope before taking '&mut {name}'."
     ),
     E1303 = _err(
         "E1303",
         Category.SEMANTIC,
         "Cannot mutate '{name}' while a shared borrow of it is live",
         help="While a `&` shared borrow is live, the owner is read-only. Let every"
         " shared borrow go out of scope before mutating '{name}' — reassigning it or"
         " writing one of its fields both count as mutation."
     ),
     E1304 = _err(
         "E1304",
         Category.SEMANTIC,
         "'{name}' is destroyed while still borrowed",
         help="The owner '{name}' goes out of scope (and is destroyed) while a borrow"
         " of it is still live. A borrow must not outlive the value it points to; keep"
         " '{name}' in scope for at least as long as every borrow of it."
     ),
     E1306 = _err(
         "E1306",
         Category.SEMANTIC,
         "Borrow of '{name}' escapes its scope",
         help="Borrows are second-class: a `&`/`&mut` reference may not be stored in a"
         " field, returned (except a single passthrough parameter), or otherwise"
         " outlive the scope that created it."
     ),
     E1307 = _err(
         "E1307",
         Category.SEMANTIC,
         "Reference to '{name}' escapes its region",
         help="A region owns everything allocated under an `in <handle> {}` open"
         " and frees it wholesale when the region is reclaimed. A reference rooted"
         " in the region may not be returned, stored outside, or handed to a"
         " `flow`/`wait` boundary; it would dangle once the region is freed. Keep"
         " the reference inside the region, or move the value out with `own`"
         " before the open ends."
     ),
     E1308 = _err(
         "E1308",
         Category.SEMANTIC,
         "'{name}' is not sendable across a concurrency boundary",
         help="Only a deep-immutable `imm` value or a moved `own` value may cross a"
         " `flow`/`wait`/`thread_run` boundary — those are the only payloads that are"
         " statically race-free. A live `&`/`&mut` borrow or a shared managed value may"
         " not be sent; move it with `own`, or send an `imm` snapshot instead."
     ),
     E1309 = _err(
         "E1309",
         Category.SEMANTIC,
         "Cannot mutate '{name}' through a deep-immutable `imm` binding",
         help="'{name}' is an `imm` value: it is transitively immutable, so it may never"
         " be reassigned, have a field written, or be borrowed `&mut`. Take an `imm` as"
         " read-only, or use an `own`/managed binding if you need to mutate."
     ),
     W1312 = _warn(
         "W1312",
         Category.LINT,
         "Owned value '{name}' silently seals into managed storage",
         help="Passing an owned binding to an unannotated parameter moves it across"
         " the membrane: the callee receives a managed value and '{name}' is"
         " consumed at a distance. Write managed({name}) at the call site to make"
         " the seal explicit, or annotate the callee parameter `own` to take"
         " ownership intentionally."
     ),
     E1311 = _err(
         "E1311",
         Category.SEMANTIC,
         "Cannot freeze '{name}': the value may be aliased",
         help="the `imm` operator needs a statically unique operand so the frozen"
         " value can never be written through another handle: apply it to an `own`"
         " binding (it is consumed) or to a fresh expression. Copy the value first,"
         " or take ownership of it, before freezing."
     ),
     E1313 = _err(
         "E1313",
         Category.SEMANTIC,
         "`flow for` does not allow {name}",
         help="the body of a `flow for` runs as independent tasks over disjoint"
         " elements, and the loop's closing brace is the join: control flow may not"
         " cross it (`continue` skips one element; `break`/`return` cannot), the"
         " collection must be lent (`&xs` or `&mut xs`) so disjointness is checkable,"
         " and nesting `flow for` is not supported yet. Restructure the loop, or use"
         " a plain `for` when sequential semantics are what you want."
     ),
     E1314 = _err(
         "E1314",
         Category.SEMANTIC,
         "`partition(n)` does not allow {name}",
         help="`partition(n)` is sugar for n per-child `partition()` calls: the"
         " count must be an integer literal, the call must be unpacked as"
         " `(a, b, ...) = r.partition(n)` with exactly n plain names, and the"
         " receiver must be an owned `Region` handle. Each unpacked child is an"
         " independently affine owned handle riding the same reabsorb/zombie"
         " contract. Use the per-child call form for dynamic counts."
     ),
     E1315 = _err(
         "E1315",
         Category.SEMANTIC,
         "A view does not allow {name}",
         help="a view is a value that carries a borrow: an archetype with a"
         " `&`-typed field, a container declared over `&T`, or (in a"
         " nogc-enforced module) a step-free string slice. It lives on the stack"
         " and is usable locally; it may not be stored into a field, a container,"
         " or a module global, may not be bound `own`, and may be returned only"
         " when it derives from the function's borrowed parameters (or a method's"
         " `self`), so every caller knows what the result borrows. Materialize an"
         " owned value where it must escape (a stepped slice `s[a:b:1]` for a"
         " string, a fresh archetype otherwise).",
         blocks_codegen=True
     ),
     E1316 = _err(
         "E1316",
         Category.SEMANTIC,
         "Cannot move '{name}' out of '{place}' without take()",
         help="'{place}' is an owned slot inside another value, so reading it into"
         " an owning destination (an `own` binding, an owned field, an `own`"
         " parameter, or an owned return) would leave two owners of one value."
         " Move it out explicitly with `take({place})`, which leaves None behind,"
         " or borrow it with `&{place}` if the destination only needs to read it."
     ),
     E1317 = _err(
         "E1317",
         Category.SEMANTIC,
         "Cannot move '{name}' out of the element '{place}'",
         help="the elements of an owned list are owned by the list, so reading"
         " one into an owning destination (an `own` binding, an owned field, an"
         " `own` parameter, or an owned return) would leave two owners of one"
         " value. Move it out with `pop()` or `pop(i)`, or borrow it in place"
         " with `&{place}`."
     ),
     E1318 = _err(
         "E1318",
         Category.SEMANTIC,
         "Cannot call mutating method '{method}' through a shared borrow of '{name}'",
         help="'{method}' writes to its receiver (it assigns a field, grows a"
         " container field, or calls another mutating method), so it needs an"
         " exclusive receiver. Take the borrow with `&mut`, or call it on the"
         " owner directly."
     ),
     W1310 = _warn(
         "W1310",
         Category.LINT,
         "Region open on '{name}' has an empty body",
         help="Opening a region that allocates nothing pays for an arena and its"
         " teardown with no benefit. Allocate inside the open, or drop the open."
     ),
     E1401 = _err(
         "E1401",
         Category.SEMANTIC,
         "Heap-typed {position} '{name}' has no ownership state in a nogc-enforced module ({provenance})",
         help="Inside a nogc-enforced module every heap-typed contract position"
         " (parameter, return, or `has` field) must be in the owned world: annotate"
         " it `own`, `&`, `&mut`, or `imm`. Locals still infer ownership from a fresh"
         " right-hand side; only contracts must be explicit.",
         blocks_codegen=True
     ),
     E1402 = _err(
         "E1402",
         Category.SEMANTIC,
         "Owned value '{name}' is sealed into managed storage inside a nogc-enforced module ({provenance})",
         help="Storing an owned value into a managed or graph location re-enters the"
         " reference-counted world, which a nogc-enforced module promises not to do."
         " Keep the value owned, or copy it across the membrane explicitly with"
         " `managed(...)` at the module boundary.",
         blocks_codegen=True
     ),
     E1403 = _err(
         "E1403",
         Category.SEMANTIC,
         "Heap value '{name}' crosses implicitly out of a nogc-enforced module ({provenance})",
         help="Heap values may leave a nogc-enforced module only by an explicit copy:"
         " wrap the argument in `managed(...)`, which reboxes it into a"
         " reference-counted allocation on the managed side. Scalars and `imm` values"
         " cross freely.",
         blocks_codegen=True
     ),
     E1404 = _err(
         "E1404",
         Category.SEMANTIC,
         "'{name}' is `any`-typed and could be heap-allocated in a nogc-enforced module ({provenance})",
         help="If the static type cannot say heap-or-not, zero-RC coverage cannot be"
         " enforced. Give '{name}' a concrete type, or confine `any` to scalar values"
         " in enforced modules.",
         blocks_codegen=True
     ),
     E1405 = _err(
         "E1405",
         Category.SEMANTIC,
         "Closure capture of '{name}' escapes its scope in a nogc-enforced module ({provenance})",
         help="An escaping closure keeps its captures alive past the enclosing scope,"
         " which needs reference counting. Pass '{name}' as an explicit parameter, or"
         " restructure so the closure does not outlive the scope.",
         blocks_codegen=True
     ),
     E1406 = _err(
         "E1406",
         Category.SEMANTIC,
         "'{name}' has retaining or aliasing semantics not supported in a nogc-enforced module ({provenance})",
         help="This builtin or construct retains or aliases its heap arguments, which"
         " the zero-RC contract cannot express yet. Containers of str elements"
         " are supported: fresh strings (f-strings, concats, slices, call"
         " results) move into the container and named bindings or literals are"
         " copied in; a borrowed or field-read str must be copied explicitly"
         " (xs.append(f\"{{p}}\")). Containers of archetypes or nested"
         " containers stay on the ownership roadmap: use an owned-compatible"
         " alternative, or move this code outside the enforced module.",
         blocks_codegen=True
     ),
     W1050 = _warn("W1050", Category.TYPE, "Unknown intrinsic JSX element '<{tag}>'"),
     W1051 = _warn(
         "W1051",
         Category.TYPE,
         "Expression type could not be resolved (Unknown)",
         "Often fixed by adding a more specific type annotation to the relevant declaration (e.g., 'list[Task]' instead of bare 'list', or annotating an unannotated parameter or attribute). Can also indicate an unresolved import, a forward reference the checker cannot bind, or fallout from an upstream error."
     ),
     W1052 = _warn(
         "W1052",
         Category.TYPE,
         "JSX component '{component}' uses an untyped props bag ('props: any');"
         " its JSX props cannot be type-checked",
         "Declare explicit typed parameters (e.g. 'def MyComp(title: str, count: int) -> JsxElement'), or annotate 'props' with a typed object. An untyped 'props: any' parameter opts the component out of all prop name and type validation."
     ),
     W1100 = _warn("W1100", Category.IMPORT, "Module not found"),
     W1101 = _warn(
         "W1101", Category.IMPORT, "Cannot import name '{name}' from module '{module}'"
     ),
     W1102 = _warn(
         "W1102",
         Category.IMPORT,
         "Imported name '{name}' from foreign-source module '{module}' typed as any"
     ),
     W1103 = _warn(
         "W1103",
         Category.IMPORT,
         "'{name}' is ambient and does not need to be imported from '{module}'"
     ),
     W1105 = _warn(
         "W1105",
         Category.IMPORT,
         "Local module '{name}' shadows the npm package of the same name",
         help="A bare module name resolves to the local Jac module first. Quote the name (import from \"{name}\") to import the npm package instead."
     ),
     W1106 = _warn(
         "W1106",
         Category.IMPORT,
         "String import '{name}' does not match any declared or installed npm package",
         help="A quoted bare import always means an npm package. Declare '{name}' under [dependencies.npm] in jac.toml and run 'jac install', or use a dotted module path (import from .{name}) for a local Jac module."
     ),
     W2001 = _warn("W2001", Category.SEMANTIC, "Name '{name}' may be undefined"),
     W2002 = _warn("W2002", Category.SEMANTIC, "Unreachable code detected"),
     W2003 = _warn("W2003", Category.SEMANTIC, "'{name}' is defined but never used"),
     E2004 = _err(
         "E2004",
         Category.SEMANTIC,
         "Non default attribute '{name}' follows default attribute"
     ),
     E2005 = _err(
         "E2005",
         Category.SEMANTIC,
         "Missing \"postinit\" method required by uninitialized attribute(s)."
     ),
     W2006 = _warn(
         "W2006",
         Category.SEMANTIC,
         "'@classmethod' decorator is not recommended in '{kind}' definitions. Use 'class def method_name(...)' syntax instead."
     ),
     W2007 = _warn(
         "W2007",
         Category.SEMANTIC,
         "'@staticmethod' is not supported in '{kind}' definitions. Use the 'static' keyword instead (e.g., 'static def method_name')."
     ),
     W2029 = _warn(
         "W2029",
         Category.SEMANTIC,
         "'@{decorator}' is not recommended in '{kind}' definitions. Use native property syntax 'has {name}: {type_name} {{ getter; ... }}' instead.",
         help="Declare the property with an accessor block: 'has {name}: {type_name} "
         "{{ getter {{ ... }} setter(value: {type_name}) {{ ... }} }}'. Backing storage "
         "is a separate 'has _{name}: {type_name} = ...;' field. Run "
         "'jac check --lint --fix' to rewrite it automatically. A Python-compat "
         "'class' is exempt from this rule."
     ),
     E2008 = _err(
         "E2008", Category.SEMANTIC, "Invalid target for context update: {target}"
     ),
     W2058 = _warn(
         "W2058",
         Category.SEMANTIC,
         "Comparison to None should use 'is' or 'is not', not '=='"
     ),
     W2063 = _warn(
         "W2063",
         Category.SEMANTIC,
         "Self-assignment has no effect: '{name}' assigned to itself"
     ),
     W2070 = _warn("W2070", Category.SEMANTIC, "Division by zero"),
     W2074 = _warn(
         "W2074",
         Category.SEMANTIC,
         "f-string has no placeholders — use a regular string"
     ),
     W2075 = _warn(
         "W2075",
         Category.SEMANTIC,
         "Redundant comparison to boolean literal — use the expression directly"
     ),
     W2080 = _warn(
         "W2080",
         Category.SEMANTIC,
         "Attribute '{attr}' assigned in '{method}' body should be declared as a 'has' field on {arch_type} '{name}'"
     ),
     E2055 = _err(
         "E2055",
         Category.SEMANTIC,
         "'return' inside a 'finally' block silences exceptions"
     ),
     E2083 = _err(
         "E2083", Category.SEMANTIC, "'disengage' is only valid inside a walker ability"
     ),
     E2027 = _err(
         "E2027",
         Category.SEMANTIC,
         "Endpoint clause ': Src --> Tgt' is only valid on an 'edge' archetype, not on {arch_type} '{name}'"
     ),
     E2009 = _err(
         "E2009",
         Category.SEMANTIC,
         "Implementation could not be matched to a declaration."
     ),
     W2010 = _warn(
         "W2010",
         Category.SEMANTIC,
         "Abstract ability {name} should not have a definition."
     ),
     E2011 = _err(
         "E2011", Category.SEMANTIC, "Parameter count mismatch for ability {name}."
     ),
     E2012 = _err("E2012", Category.SEMANTIC, "From the declaration of {name}."),
     W2013 = _warn(
         "W2013",
         Category.SEMANTIC,
         "Parameter name mismatch: declaration has '{decl_name}' but implementation has '{impl_name}'."
     ),
     W2014 = _warn(
         "W2014",
         Category.SEMANTIC,
         "Avoid 'return' with a value in an event-driven ability — "
         "abilities are triggered by walkers and their return values are ignored. "
         "Update node or walker fields directly instead."
     ),
     E2015 = _err(
         "E2015",
         Category.SEMANTIC,
         "Explicit 'self' parameter is not allowed in {arch_type} method '{name}' — "
         "'self' is implicit in obj, node, edge, and walker methods.",
         help="write `self` explicitly only to declare the receiver mode:"
         " `self: own T` consumes the receiver, `self: &mut T` mutates it,"
         " `self: &T` reads it. Without a mode the receiver is inferred from the"
         " body."
     ),
     E2016 = _err(
         "E2016",
         Category.SEMANTIC,
         "Cannot provide implementation for a method that already has a body."
     ),
     E2017 = _err(
         "E2017",
         Category.SEMANTIC,
         "Duplicate implementation — an earlier impl already provides the body for this method."
     ),
     E2018 = _err(
         "E2018",
         Category.SEMANTIC,
         "Undefined name '{name}' in {position} — this position requires a defined type"
     ),
     E2019 = _err(
         "E2019",
         Category.SEMANTIC,
         "A JSX slot renders template content and cannot 'return' a value. "
         "Use 'skip;' for slot early-exit, or move the value-producing "
         "expression outside the JSX slot."
     ),
     E2020 = _err(
         "E2020",
         Category.SEMANTIC,
         "Bare 'return;' is not allowed inside a JSX slot — it reads like "
         "it exits the enclosing function, but a slot body is an inlined "
         "IIFE. Use 'skip;' for slot early-exit."
     ),
     E2021 = _err(
         "E2021",
         Category.SEMANTIC,
         "'{kw}' is not allowed inside a '{loop}' loop in a JSX slot. "
         "Use 'continue' to skip an iteration, or 'skip;' to exit the "
         "whole slot."
     ),
     W2019 = _warn(
         "W2019",
         Category.SEMANTIC,
         "'while' loop in a JSX slot renders JSX without a 'key' attribute — "
         "add 'key=' so siblings keep their identity across re-renders."
     ),
     E2022 = _err(
         "E2022",
         Category.SEMANTIC,
         "'finally' is not allowed on a 'try' that has an 'awaiting' clause. "
         "The dispatched-but-not-joined window and finalization semantics "
         "are ambiguous together; move cleanup into an explicit "
         "mount/unmount hook or drop one of the clauses."
     ),
     W2020 = _warn(
         "W2020",
         Category.SEMANTIC,
         "'awaiting' is not yet implemented on the '{target}' target — "
         "the 'awaiting' clause body will be ignored at runtime. Only the "
         "'cl' (react/preact) target currently lowers 'awaiting' to a "
         "Suspense fallback."
     ),
     E2023 = _err(
         "E2023",
         Category.SEMANTIC,
         "Redundant '{{...}}' slot wrapping inside a JSX slot body -- slot "
         "bodies are already in slot mode. Drop the outer braces: write "
         "'{stmt_kw} ... {{ ... }}' directly instead of "
         "'{{{stmt_kw} ... {{ ... }}}}'."
     ),
     E2024 = _err(
         "E2024",
         Category.SEMANTIC,
         "'has' is not allowed inside a JSX slot body. A slot body is a "
         "statement template that re-runs on every render; declaring "
         "reactive state there would compile to a conditional 'useState' "
         "and violate React's rules of hooks. Declare 'has'-fields at the "
         "component scope (the enclosing 'def -> JsxElement' body)."
     ),
     E2028 = _err(
         "E2028",
         Category.SEMANTIC,
         "Redundant '{{...}}' around a single expression inside a JSX slot "
         "body -- slot bodies are already in slot mode, so the value renders "
         "without the extra braces. Drop them: write the expression directly, "
         "terminated with ';' (e.g. 'name;' instead of '{{name}}')."
     ),
     W2021 = _warn(
         "W2021",
         Category.SEMANTIC,
         "'for' loop in a JSX slot renders JSX without a 'key' attribute — "
         "annotate one child element with 'key=' so iteration siblings "
         "keep their identity across re-renders."
     ),
     E2025 = _err(
         "E2025",
         Category.SEMANTIC,
         "A 'has'-field of type 'Ref[...]' must be constructed with an "
         "initializer: write '= Ref()' for a DOM ref, or '= Ref(initial)' "
         "for a value ref. It lowers to React's 'useRef', so a bare "
         "declaration has no ref object to hold — '.current' would never be "
         "defined. This mirrors how every other 'has'-field carries a value."
     ),
     E2026 = _err(
         "E2026",
         Category.SEMANTIC,
         "Definition '{name}' in .impl.jac file is not linked to its declaration stub. "
         "Use an `impl` block instead of a bare re-declaration.",
         help="In Jac, implementation files use `impl Name {{ ... }}` or `impl Name(...) {{ ... }}` blocks to provide bodies for declaration stubs. A bare re-declaration in a `.impl.jac` file is treated as a separate definition and will not be linked to the stub."
     ),
     E2034 = _err(
         "E2034",
         Category.SEMANTIC,
         "'{name}' is a private member of '{owner}' and is only accessible "
         "inside '{owner}'.",
         help="Mark the member `:protect` to share it with subclasses, or `:pub` to expose it. Private (`:priv`) members are visible only in the methods of the class that declares them."
     ),
     W2034 = _warn(
         "W2034",
         Category.SEMANTIC,
         "'{name}' is a private member of '{owner}' and is only accessible "
         "inside '{owner}'.",
         help="Mark the member `:protect` to share it with subclasses, or `:pub` to expose it. Private (`:priv`) members are visible only in the methods of the class that declares them."
     ),
     E2035 = _err(
         "E2035",
         Category.SEMANTIC,
         "'{name}' is a protected member of '{owner}' and is only accessible "
         "inside '{owner}' and its subclasses.",
         help="Access protected (`:protect`) members from within the declaring class or a subclass, or mark the member `:pub` to expose it more broadly."
     ),
     W2035 = _warn(
         "W2035",
         Category.SEMANTIC,
         "'{name}' is a protected member of '{owner}' and is only accessible "
         "inside '{owner}' and its subclasses.",
         help="Access protected (`:protect`) members from within the declaring class or a subclass, or mark the member `:pub` to expose it more broadly."
     ),
     E2037 = _err(
         "E2037",
         Category.SEMANTIC,
         "'{name}' is private to module '{module}' and cannot be used from "
         "another module.",
         help="Private (`:priv`) names are visible only inside their own module. Mark '{name}' `:protect` to use it elsewhere in the project, or `:pub` to export it."
     ),
     W2037 = _warn(
         "W2037",
         Category.SEMANTIC,
         "'{name}' is private to module '{module}' and cannot be used from "
         "another module.",
         help="Private (`:priv`) names are visible only inside their own module. Mark '{name}' `:protect` to use it elsewhere in the project, or `:pub` to export it."
     ),
     E2038 = _err(
         "E2038",
         Category.SEMANTIC,
         "'{name}' is protected to project '{project}' and cannot be used from "
         "another project.",
         help="Protected (`:protect`) names are visible only within their own project (the directory tree rooted at its jac.toml). Mark '{name}' `:pub` to export it as a library endpoint."
     ),
     W2038 = _warn(
         "W2038",
         Category.SEMANTIC,
         "'{name}' is protected to project '{project}' and cannot be used from "
         "another project.",
         help="Protected (`:protect`) names are visible only within their own project (the directory tree rooted at its jac.toml). Mark '{name}' `:pub` to export it as a library endpoint."
     ),
     E2039 = _err(
         "E2039",
         Category.SEMANTIC,
         "'{name}' belongs to app '{app}'; app '{user_app}' may only use it "
         "through shared code or its bridge surface",
         help="An app boundary is structural: modules under one [apps.<name>] root are private to that app. Another app reaches them only through the owner's bridge surface -- a walker or a `def:pub` function the compiler bridges to the owner's server (`:pub` only marks an endpoint unauthenticated; a walker bridges without it) -- or by moving the code to a shared module outside every app root."
     ),
     W2039 = _warn(
         "W2039",
         Category.SEMANTIC,
         "'{name}' belongs to app '{app}'; app '{user_app}' may only use it "
         "through shared code or its bridge surface",
         help="An app boundary is structural: modules under one [apps.<name>] root are private to that app. Another app reaches them only through the owner's bridge surface -- a walker or a `def:pub` function the compiler bridges to the owner's server (`:pub` only marks an endpoint unauthenticated; a walker bridges without it) -- or by moving the code to a shared module outside every app root."
     ),
     E2040 = _err(
         "E2040",
         Category.SEMANTIC,
         "Shared module '{module}' imports '{name}' from app '{app}'; shared "
         "code may not depend on app modules",
         help="Shared modules sit below every app and are compiled once per app that reaches them, so a dependency on one app's module would pull that app into every other. Move '{name}' into shared code, or move the importing module under the app that owns it."
     ),
     W2040 = _warn(
         "W2040",
         Category.SEMANTIC,
         "Shared module '{module}' imports '{name}' from app '{app}'; shared "
         "code may not depend on app modules",
         help="Shared modules sit below every app and are compiled once per app that reaches them, so a dependency on one app's module would pull that app into every other. Move '{name}' into shared code, or move the importing module under the app that owns it."
     ),
     E2084 = _err(
         "E2084",
         Category.SEMANTIC,
         "An expression without a trailing ';' is only treated as an "
         "implicit return when it is the final statement of a function, "
         "ability, or lambda body.",
         help="Add ';' to discard the expression's value, or use an explicit `return` if the value should leave the enclosing function from this position."
     ),
     W3001 = _warn(
         "W3001",
         Category.LINT,
         "@staticmethod should use 'static' keyword [staticmethod-to-static]"
     ),
     W3002 = _warn(
         "W3002",
         Category.LINT,
         "Consecutive 'has' declarations can be combined [combine-has]"
     ),
     W3003 = _warn(
         "W3003",
         Category.LINT,
         "Consecutive 'glob' declarations can be combined [combine-glob]"
     ),
     W3004 = _warn(
         "W3004", Category.LINT, "'{name}' should use Jac keyword [init-to-can]"
     ),
     W3005 = _warn(
         "W3005",
         Category.LINT,
         "Empty parentheses can be removed [remove-empty-parens]"
     ),
     W3007 = _warn(
         "W3007",
         Category.LINT,
         "hasattr() should use null-safe access [hasattr-to-null-ok]"
     ),
     W3008 = _warn(
         "W3008", Category.LINT, "Ternary can be simplified [simplify-ternary]"
     ),
     W3009 = _warn(
         "W3009",
         Category.LINT,
         "'from __future__ import annotations' is unnecessary [remove-future-annotations]"
     ),
     W3010 = _warn(
         "W3010",
         Category.LINT,
         "Implementation signature does not match declaration [fix-impl-signature]"
     ),
     W3013 = _warn(
         "W3013", Category.LINT, "Unnecessary semicolon [remove-redundant-semi]"
     ),
     E3012 = _err(
         "E3012", Category.LINT, "Calling print() is disallowed by rule [no-print]"
     ),
     W3020 = _warn(
         "W3020",
         Category.LINT,
         "Unnecessary 'pass' in non-empty body [unnecessary-pass]"
     ),
     W3021 = _warn(
         "W3021",
         Category.LINT,
         "Unnecessary 'else' after 'return' [unnecessary-else-after-return]"
     ),
     W3022 = _warn(
         "W3022",
         Category.LINT,
         "Nested 'if' in 'else' can be 'elif' [nested-if-to-elif]"
     ),
     W3023 = _warn(
         "W3023",
         Category.LINT,
         "'if cond return True else return False' can be simplified to 'return cond' [simplify-return-bool]"
     ),
     W3024 = _warn(
         "W3024",
         Category.LINT,
         "Repeated condition in if/elif chain [repeated-condition]"
     ),
     W3025 = _warn(
         "W3025",
         Category.LINT,
         "Identical if/else branches — the else is redundant [identical-branches]"
     ),
     W3030 = _warn(
         "W3030",
         Category.LINT,
         "Function has {count} parameters (threshold is {threshold}) [too-many-params]"
     ),
     W3035 = _warn(
         "W3035",
         Category.LINT,
         "Use '==' instead of 'is' when comparing to a literal [is-with-literal]"
     ),
     W3036 = _warn(
         "W3036",
         Category.LINT,
         "Mutable default argument '{type}' — use None and assign inside the function [mutable-default]"
     ),
     W3037 = _warn(
         "W3037",
         Category.LINT,
         "Unnecessary '-> None' return type annotation on '{name}'; "
         "functions without a return statement implicitly return None "
         "[unnecessary-none-return]"
     ),
     W3038 = _warn(
         "W3038",
         Category.LINT,
         "useState hook for '{name}' can be replaced with "
         "'has {name}: {type_name} = {init}' [usestate-to-has]"
         "setter can be replaced with direct assignment to the field in the ability body"
     ),
     W3039 = _warn(
         "W3039",
         Category.LINT,
         "getattr(obj, 'attr', None) should use null-safe access [getattr-to-null-ok]"
     ),
     W3040 = _warn(
         "W3040",
         Category.LINT,
         "Filter comparison '{name} == {name}' is always true — "
         "both sides resolve to the same node field [filter-compare-tautology]"
     ),
     W3041 = _warn(
         "W3041",
         Category.LINT,
         "Reactive `has` field '{name}' is read after being assigned in the same "
         "`can with entry` block; the read returns the closure-captured pre-update "
         "value, not the just-assigned one [stale-has-read]",
         help="The has-field assignment lowers to a React useState setter call, "
         "which is scheduled for the next render. To branch on the new value "
         "in the same block, capture it in a local first: "
         "`local = expr; <field> = local; if local { ... }`."
     ),
     W3042 = _warn(
         "W3042",
         Category.LINT,
         "'.map(lambda {name} -> any {{ return <jsx>; }})' can be replaced with "
         "'[<jsx> for {name} in collection]' comprehension syntax [map-lambda-to-comprehension]"
     ),
     W3043 = _warn(
         "W3043",
         Category.LINT,
         "@property '{name}' can be replaced with native property syntax "
         "'has {name}: {type_name} {{ getter; ... }}' [property-to-native]"
     ),
     W3050 = _warn(
         "W3050",
         Category.LINT,
         "Comment can be removed [strip-comments]",
         help="Opt-in 'deslop' rule. Enable by adding \"strip-comments\" to "
         "[check.lint] select in jac.toml. `jac fmt --lintfix` then removes "
         "all comments; it never fires under select = [\"all\"] or [\"default\"]."
     ),
     W3051 = _warn(
         "W3051",
         Category.LINT,
         "Docstring can be removed [strip-docstrings]",
         help="Opt-in 'deslop' rule. Enable by adding \"strip-docstrings\" to "
         "[check.lint] select in jac.toml. `jac fmt --lintfix` then removes "
         "all docstrings; it never fires under select = [\"all\"] or [\"default\"]."
     ),
     LINT_ALIASES: dict[str, str] = {
         "staticmethod-to-static": "W3001",
         "combine-has": "W3002",
         "combine-glob": "W3003",
         "init-to-can": "W3004",
         "remove-empty-parens": "W3005",
         "hasattr-to-null-ok": "W3007",
         "simplify-ternary": "W3008",
         "remove-future-annotations": "W3009",
         "fix-impl-signature": "W3010",
         "remove-import-semi": "W3013",
         "remove-redundant-semi": "W3013",
         "no-print": "E3012",
         "unnecessary-pass": "W3020",
         "unnecessary-else-after-return": "W3021",
         "nested-if-to-elif": "W3022",
         "simplify-return-bool": "W3023",
         "repeated-condition": "W3024",
         "identical-branches": "W3025",
         "too-many-params": "W3030",
         "is-with-literal": "W3035",
         "usestate-to-has": "W3038",
         "mutable-default": "W3036",
         "unnecessary-none-return": "W3037",
         "getattr-to-null-ok": "W3039",
         "filter-compare-tautology": "W3040",
         "stale-has-read": "W3041",
         "map-lambda-to-comprehension": "W3042",
         "property-to-native": "W3043",
         "strip-comments": "W3050",
         "strip-docstrings": "W3051"
     },
     E5001 = _err(
         "E5001",
         Category.CODEGEN,
         "String literal imports are only supported in client (cl) imports, not Python imports. Use 'cl import from \"{path}\" {{ ... }}' instead."
     ),
     E5002 = _err(
         "E5002",
         Category.CODEGEN,
         "{import_type} imports (using '{name}') are only supported in client (cl) imports, not Python imports"
     ),
     E5003 = _err(
         "E5003",
         Category.CODEGEN,
         "Archetype has no body. Perhaps an impl must be imported."
     ),
     E5004 = _err(
         "E5004", Category.CODEGEN, "Abstract ability {name} should not have a body."
     ),
     E5005 = _err(
         "E5005",
         Category.CODEGEN,
         "Ability has no body. Perhaps an impl must be imported."
     ),
     E5006 = _err("E5006", Category.CODEGEN, "Invalid pipe target."),
     E5007 = _err(
         "E5007",
         Category.CODEGEN,
         "Binary operator {op} not supported in bootstrap Jac"
     ),
     E5008 = _err("E5008", Category.CODEGEN, "Invalid attribute access"),
     E5010 = _err(
         "E5010",
         Category.CODEGEN,
         "Spawn expressions must include a walker constructor on one side."
     ),
     E5011 = _err("E5011", Category.CODEGEN, "Expected expression in spawn argument."),
     E5012 = _err(
         "E5012", Category.CODEGEN, "Expected main module to be a Module node."
     ),
     E5016 = _err(
         "E5016",
         Category.CODEGEN,
         "Could not generate JavaScript for builtin '{name}': {error}"
     ),
     E5017 = _err(
         "E5017",
         Category.CODEGEN,
         "{construct} is not supported by client codegen",
         help="This statement has no ECMAScript lowering yet, and without this error it would be silently dropped from the client bundle. Rewrite it using supported constructs, or move the logic to a server or native codespace.",
         blocks_codegen=True
     ),
     E5018 = _err(
         "E5018",
         Category.CODEGEN,
         "match pattern {construct} is not supported by client codegen",
         help="`match` itself lowers to the client; only this pattern shape does not. {fix}",
         blocks_codegen=True
     ),
     W5013 = _warn(
         "W5013",
         Category.CODEGEN,
         "Both sides of spawn look like walker instantiations; defaulting to the right-hand expression."
     ),
     W5014 = _warn(
         "W5014",
         Category.CODEGEN,
         "Walker spawn has more positional arguments than fields."
     ),
     W5015 = _warn(
         "W5015",
         Category.CODEGEN,
         "Component '{component}' takes a single 'props' bundle — JSX call sites are not type-checked per prop.",
         help="Prefer direct named params (e.g. `def {component}(name: str, age: int)`); suppress with `# jac:ignore[W5015]` only when intentionally forwarding the bundle."
     ),
     E5020 = _err("E5020", Category.CODEGEN, "Native compilation failed: {error}"),
     W5021 = _warn("W5021", Category.CODEGEN, "C library not found: {path}"),
     W5022 = _warn(
         "W5022", Category.CODEGEN, "Failed to load C library '{path}': {error}"
     ),
     W5023 = _warn("W5023", Category.CODEGEN, "Native module not found: {path}"),
     E5024 = _err(
         "E5024",
         Category.CODEGEN,
         "Failed to compile native module {path}: {error}. "
         "Fix the error in the imported module or nacompile will produce a broken binary."
     ),
     E5025 = _err(
         "E5025",
         Category.CODEGEN,
         "Failed to link native module {path}: {error}. "
         "Fix the error in the imported module or nacompile will produce a broken binary."
     ),
     E5026 = _err(
         "E5026",
         Category.CODEGEN,
         "Symbol collision during native link: '{symbol}' is defined in both "
         "'{existing_module}' and '{new_module}'. "
         "Mark one as :priv or rename to avoid a runtime crash."
     ),
     E5027 = _err(
         "E5027",
         Category.CODEGEN,
         "Native module '{path}' was built with different compile options "
         "(cached fingerprint {cached_fp}, current build {current_fp}); "
         "refusing a mixed-options link.",
         help="Every module in a native link must carry the same codegen options fingerprint (gc mode, nogc enforcement, target triple, opt level, debug gates). Rebuild the module under the current options, or scrub the stale native cache with `jac nacompile --scrub`."
     ),
     E5028 = _err(
         "E5028",
         Category.CODEGEN,
         "Native module '{path}' still calls {names} as live after {attempts} "
         "re-emissions, but the defining module's verdict demotes them; the "
         "demotion/emission order did not converge.",
         help="Within one native unit a caller's emitted IR must observe the callee module's final demotion verdicts (verdict-before-emission). A caller emitted under an import cycle is re-emitted once its callees' verdicts land; failing to converge means a verdict keeps flipping between emissions, which is a compiler defect worth reporting with JAC_NA_DEBUG=1 output."
     ),
     E5029 = _err(
         "E5029",
         Category.CODEGEN,
         "Native link of '{path}' tripped the verdict blast-radius guard: "
         "{detail}. Refusing to compose further instead of grinding.",
         help="A healthy native link keeps the unverified-live set near zero and compiles at most a handful of modules at link time. Numbers this size mean verdict resolution is missing systematically -- every miss fails closed into conflict-on-all and another full compile -- which presents as a silent multi-hour build. The counts in the message say which lever moved: taint means the emission lane is recording where it should not, link-time compiles mean dependency identity is splitting, and verdict misses mean the resolver cannot see modules that are already compiled. Report with JAC_NA_DEBUG=1 output."
     ),
     E5030 = _err(
         "E5030",
         Category.CODEGEN,
         "Cannot compute C3 MRO for {name}: inconsistent hierarchy"
     ),
     W5031 = _warn(
         "W5031",
         Category.CODEGEN,
         "obj '{arch}' field '{field}' has no type annotation. All obj fields require explicit types for CType struct layout."
     ),
     W5032 = _warn(
         "W5032",
         Category.CODEGEN,
         "obj '{arch}' field '{field}' has type '{type}' which is not layout-compatible."
     ),
     E5040 = _err("E5040", Category.CODEGEN, "Unable to find ast for module {path}."),
     E5041 = _err("E5041", Category.CODEGEN, "Length mismatch in import names"),
     E5042 = _err("E5042", Category.CODEGEN, "Length mismatch in async for body"),
     E5043 = _err("E5043", Category.CODEGEN, "Bytecode compilation failed: {error}"),
     W5096 = _warn(
         "W5096",
         Category.CODEGEN,
         "Graph traversal materialized in object space: {reason}",
         help="This traversal loads every match before the operation runs, so "
         "its cost is O(degree) in the node's edge count. Shapes that resolve "
         "in the query instead: a predicate or an ordering term inside "
         "[?...], a range slice, len(), and a truthiness test. sorted() folds "
         "when its key is `lambda (x: T) { x.field; }`, its negation, or a "
         "tuple of those. An in-place .sort() cannot fold because it mutates a "
         "binding -- use sorted(), or write the ordering into the reference. A "
         "field named in a sort key or a range predicate needs promoting "
         "through [scale.database] indexes to reach an index rather than a "
         "sort."
     ),
     W5050 = _warn(
         "W5050",
         Category.CODEGEN,
         "Comment could not be placed precisely; emitting near the end of the formatted output: {preview}"
     ),
     E5051 = _err(
         "E5051",
         Category.CODEGEN,
         "Formatter displaced {count} comment(s) to end of file -- refusing to save (use 'jac format' to inspect)"
     ),
     E5060 = _err(
         "E5060",
         Category.CODEGEN,
         "C library import declaration '{name}' must not have a body"
     ),
     E5090 = _err(
         "E5090",
         Category.CODEGEN,
         "Native pathway does not yet support {kind} '{name}'",
         help="This Jac construct is supported on the @sv/Python pathway but is not implemented in the native compiler yet. Move the code to a non-native context, or extend NaIRGenPass to handle this node type."
     ),
     E5091 = _err(
         "E5091",
         Category.CODEGEN,
         "Native union trigger members {members} disagree on the layout of field '{field}'",
         help="A tuple/union trigger like `with (A, B) entry` lowers field access on `here`/`visitor` through a single shared layout, so every member must place the common field at the same offset and type. Reorder the `has` declarations so the shared fields line up, or split the trigger into separate abilities per archetype."
     ),
     E5092 = _err(
         "E5092",
         Category.CODEGEN,
         "Native lowering failed for {kind} '{name}'",
         help="The construct is within the native capability set, but this specific shape (its types, values, or runtime bindings) could not be lowered by NaIRGenPass. Adjust the shape, add type annotations, or move the code to a non-native context. Statically-known unsupported constructs are reported as E5090 by the capability check instead."
     ),
     E5096 = _err(
         "E5096",
         Category.CODEGEN,
         "Client pathway does not yet support {kind}",
         help="This Jac construct is supported on the server/Python pathway but has no ES lowering yet; previously it was dropped silently from the client bundle, which produced wrong behavior at runtime. Move the element to a server context (or restructure without the construct)."
     ),
     E5097 = _err(
         "E5097",
         Category.CODEGEN,
         "Client pathway failed to lower {kind} in an expression position",
         help="The ES backend produced no JavaScript for this expression, so without this error it would silently become 'undefined' in the browser. The expression's shape is outside what the client lowering handles; adjust the shape or move the code to a server context."
     ),
     E5099 = _err(
         "E5099",
         Category.CODEGEN,
         "Client pathway lowered the keyword-argument key of call '{func}' to an unusable shape: {shape}",
         help="A keyword-argument key names a parameter of the callee, so it must lower to a plain identifier or a string literal. Reaching the argument resolver as any other shape means an earlier lowering rewrote the key as if it were a scope reference; the resolver used to demote such a pair to a trailing '...spread', which left the named parameter as 'undefined' at runtime. This is an internal compiler bug; please report it with the call site.",
         blocks_codegen=True
     ),
     E5098 = _err(
         "E5098",
         Category.CODEGEN,
         "Multi-statement lambda '{name}' could not be hoisted into a valid scope",
         help="On the Python (server) target a multi-statement lambda lowers to a "
         "helper `def` placed in the nearest enclosing function-or-module scope "
         "before any reference to it is evaluated. This fires when a hoisted helper "
         "is left without a placement because a scope (ability/test) was entered but "
         "never drained on exit -- an internal compiler bug; please report it. "
         "Codegen is blocked rather than shipping a module that would fail at runtime "
         "with `NameError: name '{name}' is not defined`.",
         blocks_codegen=True
     ),
     E5094 = _err(
         "E5094",
         Category.CODEGEN,
         "Graph query filter outside the closed sublanguage: {reason}",
         help="A term inside [?...] on a graph reference, or between the "
         "colons of a typed hop, is one of three shapes. A predicate is "
         "`field <op> value` with op one of ==, !=, <, <=, >, >=, in, where "
         "the value is a scalar expression evaluated once at query "
         "construction. A composite key compares a tuple of field names "
         "against a tuple value of the same arity, for keyset paging. An "
         "ordering term is a bare field name (ascending) or its negation "
         "(descending), written after every predicate on that hop, and only "
         "on the final hop of a chain. Move anything else to a list "
         "comprehension over the query result, where its object-space cost "
         "is visible.",
         blocks_codegen=True
     ),
     E5095 = _err(
         "E5095",
         Category.CODEGEN,
         "Invalid call to reserved intrinsic '{name}': {reason}",
         help="Double-underscore names in the compiler's intrinsic registry are reserved: every call lowers to the registered intrinsic, whose signature is fixed by the registry. Match the registered arity and operand types; an invalid intrinsic call never falls back to a user definition or a default value."
     ),
     E5093 = _err(
         "E5093",
         Category.CODEGEN,
         "Type '{type}' on {what} of '{name}' cannot cross the native->Python call boundary",
         help="Native code calling a Python-context function marshals through a fixed ctypes callback table: int (c_int64), float (c_double), bool (c_bool), str (c_char_p), sized ints, plus None returns. Any other type would be reinterpreted as a raw c_int64 and produce garbage values at runtime. Use a supported primitive at the boundary, or move the callee into the native context. (Python calling INTO native code is unaffected: that direction goes through the native marshal bridge, which handles lists, structs, and enums.)"
     ),
     E5080 = _err(
         "E5080",
         Category.CODEGEN,
         "Argument '{name}' for server function '{func}' is given both positionally and by keyword"
     ),
     E5081 = _err("E5081", Category.CODEGEN, "Unknown client framework '{framework}'"),
     E5083 = _err(
         "E5083",
         Category.CODEGEN,
         "na import targets collide on wasm artifact '{stem}.wasm': '{path}' vs '{other}'",
         help="Every `na import` target emits /static/<stem>.wasm named by its file stem, and set_na_env / __na_bind address the module by that stem, so two different native modules with the same basename would overwrite each other's artifact and bind to the wrong exports. Rename one of the files."
     ),
     E5082 = _err(
         "E5082",
         Category.CODEGEN,
         "Client code imports '{name}' from '{module}', but '{name}' has no client-side presence",
         help="A plain import into client code can only reference client declarations; server `def:pub` endpoints bridge automatically over RPC. Make '{name}' a `def:pub` endpoint, mark it (or its module) client, or move it into client code."
     ),
     E5085 = _err(
         "E5085",
         Category.CODEGEN,
         "Internal client codegen error: declaration(s) for {names} hoisted into scope '{scope}' were never emitted",
         help="Client codegen queued a `let` for these variables in the scope that owns their symbols, but the scope's body was built without draining the queue, so the declarations would be silently dropped and their assignments would emit bare -- a strict-mode ReferenceError at runtime. Every body builder for a scope must drain pending hoists (see _prepend_hoisted / _build_block_statement) before the scope is popped. Please report this as a jac compiler bug."
     ),
     E5084 = _err(
         "E5084",
         Category.CODEGEN,
         "Client code uses '{name}' from bare import '{module}', which resolves to no client-reachable module",
         help="A bare import resolves to a local Jac module, a declared or installed npm package, or the client framework's own packages; '{module}' is none of these, so it stays on the server and the client bundle never binds '{name}' -- the page fails at runtime with a ReferenceError. Install or declare the npm package in [dependencies.npm] (or quote the module: `import from \"{module}\" {{ {name} }}`), or keep the use server-side behind a `def:pub` endpoint."
     ),
     E5086 = _err(
         "E5086",
         Category.CODEGEN,
         "Client code emits '{name}', which has no binding in the client bundle",
         help="The bundle carries only what is placed in the client codespace, plus `def:pub` endpoints, which are bound to a client-side forwarder that calls them over RPC. '{name}' is neither, so the emitted identifier resolves to nothing and the module fails at load with a ReferenceError. Give it client presence -- drop a `[placement.pins]` server pin, or make it `def:pub` so it bridges as an endpoint -- or keep the use out of client code.",
         blocks_codegen=True
     ),
     E5087 = _err(
         "E5087",
         Category.CODEGEN,
         "App kind '{kind}' has no server, but '{name}' needs one ({reason})",
         help="A '{kind}' app builds a client-only artifact: there is no server codespace to place this in, and no endpoint route to bridge to, so a server placement here could only fail at runtime. Drop the server dependency, or give the app a `kind` that has a server.",
         blocks_codegen=True
     ),
     E5088 = _err(
         "E5088",
         Category.CODEGEN,
         "Constructing '{cls}' would run '{owner}.postinit' on a Python shadow the native object cannot see",
         help="A native class over a Python-side base owns two halves: its own slots live in the native struct, the base's live on a Python shadow instance the bridge keeps beside it. Construction runs the base's `__post_init__` on that shadow, where the subclass's native slots do not exist and its method overrides are not on the shadow's class -- so a store the base initializer makes is invisible natively, and a call it dispatches reaches the base's body rather than the override. The object comes out with its declared defaults and nothing says so. Give '{cls}' a `postinit` of its own -- it suppresses the base's and can chain into it with `super.postinit()`, which does bridge -- or bring the base into the native unit so the whole chain lowers."
     ),
     E5100 = _err(
         "E5100",
         Category.CODEGEN,
         "Client code imports '{name}' from native module '{module}', but '{name}' is not a function",
         help="A client import of a native module is the cl->na edge: every name is bound to a lazily instantiated wasm export via `__na_bind`. A wasm module exports only functions, so a type, a variable, or an enum has no export to bind to -- '{name}' would come back as a plain async callable, and the page fails the first time it is constructed or read with a TypeError. This holds even where '{name}' is only used as an annotation, because the binding is emitted either way. Import the native functions that operate on '{name}' and keep the declaration itself in a client or shared module.",
         blocks_codegen=True
     ),
     E5101 = _err(
         "E5101",
         Category.CODEGEN,
         "Client codegen emitted '{name}', which the module never binds",
         help="After emission the client module is audited for free identifiers: every name it references has to resolve to a declaration in the module, an import, a parameter, or the ambient surface a browser provides. '{name}' resolves to none of these, and the compiler did resolve it in the Jac source, so the module would load and then throw a ReferenceError on first use -- with `jac check` green and the build exiting 0, which is how this shipped twice before the audit existed. If '{name}' is yours, give it client presence: declare it, import it, or make it a `def:pub` endpoint so it bridges over RPC. If it is a browser or host global the compiler does not know about, reach it through `globalThis` so the intent is explicit. If neither is true, a lowering dropped a binding it was supposed to emit; please report it with the source line.",
         blocks_codegen=True
     ),
     E5103 = _err(
         "E5103",
         Category.CODEGEN,
         "Client codegen emitted the builtin '{name}' unlowered",
         help="A builtin has no JavaScript definition of its own: the client"
         " backend rewrites every builtin call into its runtime form"
         " (`_jac.builtin.{name}(...)` or an inline equivalent), so a bare"
         " '{name}' in the bundle is a call the backend did not recognise as a"
         " builtin and left as a free name -- the page loads and then throws"
         " ReferenceError on first use. The classification the backend reads"
         " ('FuncCall.call_kind') is stamped by the checker, so this means the"
         " module reached codegen without its checker facts: it was served or"
         " ingested with an analysis-free schedule and never re-analyzed."
         " Compiling the module from source produces a correct bundle, so this"
         " is a compiler defect rather than something the source can fix;"
         " please report it with the module path.",
         blocks_codegen=True
     ),
     E5102 = _err(
         "E5102",
         Category.CODEGEN,
         "OSP type-tag collision: archetypes '{name}' and '{other}' share one dispatch tag",
         help="Object-spatial dispatch keys every archetype by a stable hash of its bare name, shared across backends. Two archetypes with the same bare name (or, astronomically rarely, colliding hashes) would dispatch each other's abilities; the server runtime also refuses the second registration at first use. Rename one of the archetypes."
     ),
     E5108 = _err(
         "E5108",
         Category.CODEGEN,
         "App '{consumer}' imports '{name}', a {kind} owned by app '{provider}'; nodes and edges never cross an app boundary",
         help="A node or edge lives in the graph of the app that owns it, so another app cannot construct or hold one. Spawn one of '{provider}''s walkers and work with what it reports, or move the type into shared code as an obj.",
         blocks_codegen=True
     ),
     E5107 = _err(
         "E5107",
         Category.CODEGEN,
         "Server-placed shared module '{module}' has no single owner: reached by serving apps {apps}; declare it as a service app or pin an owner",
         help="A shared module with server-placed elements runs on exactly one app's server so that every other app bridges to the same owner. With more than one serving app in the workspace the compiler cannot pick one. Give the module its own `[apps.<name>]` table (`kind = \"service\"`, `entry-point = \"<path>\"`), or pin it to an owner with `[apps.<owner>.placement.pins] \"<module>\" = \"server\"`.",
         blocks_codegen=True
     ),
     E5104 = _err(
         "E5104",
         Category.CODEGEN,
         "App dependency cycle: {cycle}",
         help="Apps bridge to their providers over the wire and providers boot first, so the app graph has to be a DAG. Break the cycle by moving the code both apps need into a shared module, or by folding one of the apps into the other.",
         blocks_codegen=True
     ),
     E5105 = _err(
         "E5105",
         Category.CODEGEN,
         "Variant '{variant}' disagrees with '{base}' on '{name}': {detail}",
         help="A `.native.jac` variant stands in for its sibling module on the react-native target, so the two have to expose the same public surface: the same names, the same kinds of declaration, the same parameters and annotations. Bring the variant's declaration of '{name}' in line with the base module, or remove it from both."
     ),
     E5106 = _err(
         "E5106",
         Category.CODEGEN,
         "App '{consumer}' bridges to '{name}', which is not a pub element of app '{provider}'",
         help="An app's bridge surface is its walkers and its `def:pub` functions; everything else is private to the app's own server. Make '{name}' a walker or mark it `:pub` in app '{provider}' to expose it, or move it into shared code if both apps need it in-process.",
         blocks_codegen=True
     ),
     E5089 = _err(
         "E5089",
         Category.CODEGEN,
         "Calling '{cls}.{meth}' runs '{base}.{meth}' on a Python shadow that does not carry '{cls}.{over}'",
         help="The bridge builds the Python shadow as `type(name, (base,), {{}})`: it carries the Python-side base chain and none of the native subclass's bodies. '{base}.{meth}' dispatches to `self.{over}` and would find the base's body, not the override '{cls}' declares, because that override is not on the shadow's class -- the wrong body would run and nothing would say so. Override '{meth}' on '{cls}' as well, so the native lane owns the entry point and no shadow dispatch is needed; or bring '{base}' into the native unit so the whole chain lowers and dispatches through the vtable."
     ),
     W6001 = _warn(
         "W6001",
         Category.SEMANTIC,
         "Use of JS-specific global '{name}' — use '{alternative}' for cross-codespace portability",
         help="Jac provides common primitives that work across all codespaces (Python, JS, native)."
     ),
     W6002 = _warn(
         "W6002",
         Category.SEMANTIC,
         "Use of JS-idiomatic method '.{method}()' — use '{alternative}' for cross-codespace portability",
         help="Use Jac common primitives instead of JS-specific methods."
     ),
     W6003 = _warn(
         "W6003",
         Category.SEMANTIC,
         "Use of JS-specific keyword '{name}' — use '{alternative}' for cross-codespace portability",
         help="Use Jac common primitives instead of JS-specific keywords."
     ),
     W6004 = _warn(
         "W6004",
         Category.SEMANTIC,
         "Use of JS-specific property '.{prop}' — use '{alternative}' for cross-codespace portability",
         help="Use Jac common builtins instead of JS-specific properties."
     ),
     W6005 = _warn(
         "W6005",
         Category.CODEGEN,
         "Client call to server endpoint '{func}' passes function-typed parameter '{param}' — functions cannot cross the RPC boundary",
         help="A def:pub function in a server-placed module is an HTTP endpoint whose arguments serialize over the wire. Shared client-side logic should drop ':pub' so it is placed in the browser with its callers."
     ),
     W6006 = _warn(
         "W6006",
         Category.CODEGEN,
         "Mutable glob '{name}' is emitted into both the server and the client — each side gets an independent copy (state fork)",
         help="Dual emission duplicates state, not just code: server writes and client writes land in different copies. Home the glob with its writers by marking it (or its module) 'sv' or 'cl', or bridge reads through a def:pub accessor."
     ),
     W6007 = _warn(
         "W6007",
         Category.CODEGEN,
         "Client code uses server-placed function '{name}' as a value — function values cannot cross the placement boundary",
         help="A function reference that flows into client-side data (stored, returned, or passed along) needs client presence; only calls to def:pub endpoints bridge over RPC. Drop ':pub' so the function is pulled client-side, or restructure so the client stores data instead of the function."
     ),
     W6009 = _warn(
         "W6009",
         Category.CODEGEN,
         "Client binding for server endpoint '{name}' is async: it hands back a Promise where the server function hands back '{ret}'",
         help="A server endpoint reachable from client code is bound to a client-side forwarder that calls it over HTTP, so the forwarder is necessarily async. That is transparent where the result is awaited or ignored (a command handler, an event listener) and wrong where a plain value is required (a sort comparator, a reducer). Await the call, or drop ':pub' so the function is placed client-side and stays synchronous."
     ),
     W6008 = _warn(
         "W6008",
         Category.CODEGEN,
         "Definition of '{name}' collides with the reserved native intrinsic of the same name",
         help="'{name}' is in the compiler's intrinsic registry, so native code always lowers calls to the registered intrinsic — this definition is never called from a native context. It stays callable as an ordinary function from non-native (Python/JS) contexts; rename it if that shadowing is not intended."
     ),
     E9001 = _err("E9001", Category.ICE, "ICE: Pass {pass_name} -- {details}"),
     E9002 = _err(
         "E9002",
         Category.ICE,
         "ICE: missing semantic annotation -- {details}",
         help="Codegen required a fact the central analysis pipeline never recorded on the unitree. This is a compiler bug, not an error in your program."
     ),
     E7001 = _err(
         "E7001",
         Category.RUNTIME,
         "The module '{module}' has no export named '{name}'",
         help="The browser refused to link the module: it loaded '{module}' and found no runtime binding called '{name}'. The usual cause is a type-only export -- a TypeScript interface or type alias that lives in the package's .d.ts and is erased before the module runs -- so a value import of it always fails at link time. Import it with 'import type' if that is the case; otherwise check the package's exports for the name's real spelling, since a value import can only bind a name the package actually exports at runtime."
     ),
     E7002 = _err(
         "E7002",
         Category.RUNTIME,
         "Failed to resolve import '{name}' from '{importer}'",
         help="The dev server resolves every import in the compiled module graph before the browser runs it, and this one resolved to nothing. The location above is the Jac import the compiled module was lowered from, so check the path it names. When '{name}' is a bare npm package rather than a path, this diagnostic instead carries W1106's guidance and points at the jac.toml table that has to declare it."
     ),
     E7003 = _err(
         "E7003",
         Category.RUNTIME,
         "Uncaught {kind} in client code: {message}",
         help="The stack was resolved through the client source maps to the Jac line above. The raw JavaScript stack is kept on the diagnostic for frames that do not belong to your Jac sources."
     ),
     E7004 = _err(
         "E7004",
         Category.RUNTIME,
         "Vite dev-server error: {message}",
         help="The dev server rejected a module before the browser ever ran it. The location above is the Jac source of the compiled module Vite named."
     ),
     E7005 = _err(
         "E7005",
         Category.CODEGEN,
         "Client build failed: {message}",
         help="The client build could not produce a loadable module for this file. The compiler's own diagnostics are reported in place of this one whenever it emitted any; this code carries the failures that reach the dev loop as a bare exception."
     ),
     E7006 = _err(
         "E7006",
         Category.RUNTIME,
         "Client error could not be traced to Jac source: {message}",
         help="The dev loop kept the raw location it was given, but nothing under .jac/client/compiled claims it -- a browser extension, a dependency with no source map, or an artifact from a build that has since been replaced. Reload after a clean build if the location should be yours."
     );
