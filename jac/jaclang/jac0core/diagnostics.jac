"""Jac diagnostic code registry.

Every error, warning, and note the Jac compiler can emit is registered here.
Codes follow the pattern: {severity_letter}{category_digit}{sequence:03d}
  E = error, W = warning
  0 = syntax, 1 = type, 2 = semantic, 3 = lint, 4 = import, 5 = codegen, 9 = ICE
"""

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

"""Metadata for a single diagnostic code."""
obj DiagnosticInfo {
    has code: str,
        severity: Severity,
        category: Category,
        message_template: str,
        help_text: str | None = None,
        url_slug: str | None = None;

    def format_message(**kwargs: object) -> str {
        try {
            return self.message_template.format(**kwargs);
        } except KeyError as e {
            return f"{self.message_template} (missing key: {e})";
        }
    }
}

glob DIAGNOSTICS: dict[str, DiagnosticInfo] = {};

def _reg(
    code: str,
    severity: Severity,
    category: Category,
    template: str,
    help_text: str | None = None
) -> DiagnosticInfo {
    info = DiagnosticInfo(
        code=code,
        severity=severity,
        category=category,
        message_template=template,
        help_text=help_text,
        url_slug=code.lower()
    );
    DIAGNOSTICS[code] = info;
    return info;
}

# Shorthand aliases
def _err(
    code: str, cat: Category, tmpl: str, help: str | None = None
) -> DiagnosticInfo {
    return _reg(code, Severity.ERROR, cat, tmpl, help);
}

def _warn(
    code: str, cat: Category, tmpl: str, help: str | None = None
) -> DiagnosticInfo {
    return _reg(code, Severity.WARNING, cat, tmpl, help);
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Syntax errors (E0xxx) — parser and lexer
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Parser: token expectation
glob E0001 = _err("E0001", Category.SYNTAX, "Expected '{expected}', got '{got}'"),
     E0002 = _err("E0002", Category.SYNTAX, "Missing '{token}'"),
     E0003 = _err("E0003", Category.SYNTAX, "Expected identifier, got '{got}'"),
     E0004 = _err("E0004", Category.SYNTAX, "Unexpected token in expression: '{got}'"),
     E0005 = _err("E0005", Category.SYNTAX, "Unexpected token '{token}'"),
     E0006 = _err("E0006", Category.SYNTAX, "Unexpected token"),
     # Parser: keyword restrictions
     E0010 = _err(
         "E0010",
         Category.SYNTAX,
         "'{keyword}' is not supported in Jac",
         help="Jac uses different syntax for this construct."
     ),
     E0011 = _err(
         "E0011",
         Category.SYNTAX,
         "Jac does not allow this keyword in any syntactic position"
     ),
     E0012 = _err(
         "E0012",
         Category.SYNTAX,
         "Use `Reflect.construct(target, argumentsList)` method to create new instances"
     ),
     E0013 = _err(
         "E0013",
         Category.SYNTAX,
         "'{keyword}' is a keyword and cannot be used as a {context} name (prefix with backtick to escape: `{keyword})"
     ),
     # Parser: operator/expression errors
     E0020 = _err(
         "E0020",
         Category.SYNTAX,
         "Walrus operator ':=' requires a simple name on the left side"
     ),
     E0021 = _err(
         "E0021", Category.SYNTAX, "Expected :<+ or :+> to close connect operator"
     ),
     E0022 = _err(
         "E0022", Category.SYNTAX, "Expected ':' or '{{' after lambda parameters"
     ),
     E0023 = _err(
         "E0023", Category.SYNTAX, "Expected augmented assignment in for...to...by step"
     ),
     E0024 = _err(
         "E0024",
         Category.SYNTAX,
         "Cannot assign to '{name}' -- it is a built-in reference, not a variable",
         help="Use a different variable name, or use backtick escaping (e.g. `super) to create a local variable with the same name."
     ),
     # Parser: statement-level errors
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
         "E0033", Category.SYNTAX, "'{modifier}' is not a valid prefix modifier"
     ),
     E0034 = _err(
         "E0034",
         Category.SYNTAX,
         "Expected 'with' after 'can' ability name (use 'def' for function-style declarations)"
     ),
     # Parser: block/body requirements
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
     # Parser: parameter list errors
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
     # Parser: context validity
     E0055 = _err(
         "E0055", Category.SYNTAX, "'yield' is only valid inside a function body"
     ),
     E0058 = _err("E0058", Category.SYNTAX, "'{keyword}' is only valid inside a loop"),
     E0062 = _err("E0062", Category.SYNTAX, "'nonlocal' is not valid at module level"),
     E0065 = _err("E0065", Category.SYNTAX, "Duplicate keyword argument '{name}'"),
     E0066 = _err(
         "E0066", Category.SYNTAX, "Positional argument follows keyword argument"
     ),
     E0071 = _err("E0071", Category.SYNTAX, "Default 'except' clause must be last"),
     E0075 = _err("E0075", Category.SYNTAX, "Duplicate base class '{name}'"),
     E0076 = _err("E0076", Category.SYNTAX, "Duplicate method '{name}' in class body"),
     # Parser: warnings
     W0060 = _warn(
         "W0060",
         Category.SYNTAX,
         "Docstrings in Jac go before the declaration, not inside the body. Move this string before the enclosing test/can/obj/etc."
     ),
     W0061 = _warn(
         "W0061",
         Category.SYNTAX,
         "Parenthesized filter syntax '(?:...)' is deprecated. Use bracket syntax '[?:...]' instead.",
         "Replace (?:Type, cond) with [?:Type, cond]"
     ),
     W0062 = _warn(
         "W0062",
         Category.SYNTAX,
         "Bare 'root' is deprecated. Use 'root()' instead.",
         "'root' is now a builtin function — call it explicitly as 'root()'"
     ),
     W0063 = _warn(
         "W0063",
         Category.SYNTAX,
         "JSX spread '{{...expr}}' is JS-idiomatic. Prefer '{{**expr}}' in Jac.",
         "Jac uses ** for dict unpacking — use {**expr} instead of {...expr} in JSX attributes."
     ),
     W0064 = _warn(
         "W0064",
         Category.SYNTAX,
         "'{keyword} {{ ... }}' block syntax is deprecated. Use the 'to {keyword}:' section header instead.",
         "Replace 'cl {{ ... }}' / 'sv {{ ... }}' / 'na {{ ... }}' with 'to cl:' / 'to sv:' / 'to na:' at module level. The section applies until the next 'to X:' header or end of file."
     ),
     # Lexer errors
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
     # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     # Type errors (E1xxx) — type checker and type evaluator
     # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

     # Assignment / return type mismatches
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
     # Operator errors
     E1010 = _err(
         "E1010", Category.TYPE, "Operator \"{op}\" not supported for type \"{type}\""
     ),
     E1011 = _err(
         "E1011",
         Category.TYPE,
         "Unsupported operand types for {op}: {left} and {right}"
     ),
     # Iterability / callable
     E1020 = _err("E1020", Category.TYPE, "Cannot unpack non-iterable {type}"),
     E1021 = _err("E1021", Category.TYPE, "Type \"{type}\" is not iterable"),
     E1022 = _err(
         "E1022", Category.TYPE, "Type {type} is not iterable (no __iter__ method)"
     ),
     E1023 = _err("E1023", Category.TYPE, "Type \"{type}\" is not callable"),
     # Attribute access
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
     # Bare generic warning
     W1036 = _warn(
         "W1036",
         Category.TYPE,
         "Generic type \"{type}\" used without type arguments, defaulting to"
         " \"{type}[Any]\"; consider adding explicit type arguments"
     ),
     # Subscript / await
     E1040 = _err("E1040", Category.TYPE, "Type \"{type}\" is not subscriptable"),
     E1041 = _err("E1041", Category.TYPE, "Type \"{type}\" is not awaitable"),
     # Function call errors
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
     # TypeVar errors
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
     # Callable type errors
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
     # Variance errors
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
     # Exception / context manager / yield
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
         "E1094", Category.TYPE, "Visit target must be a node type, got {type}"
     ),
     E1095 = _err(
         "E1095",
         Category.TYPE,
         "Field '{field}' declared 'by postinit' is never assigned in {arch}.postinit"
     ),
     # Connection type errors
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
     # JSX type errors
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
     W1050 = _warn("W1050", Category.TYPE, "Unknown intrinsic JSX element '<{tag}>'"),
     # Import warnings
     W1100 = _warn("W1100", Category.IMPORT, "Module not found"),
     W1101 = _warn(
         "W1101", Category.IMPORT, "Cannot import name '{name}' from module '{module}'"
     ),
     W1102 = _warn(
         "W1102",
         Category.IMPORT,
         "Imported name '{name}' from foreign-source module '{module}' typed as Any"
     ),
     # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     # Semantic errors/warnings (E2xxx/W2xxx)
     # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

     # Static analysis warnings
     W2001 = _warn("W2001", Category.SEMANTIC, "Name '{name}' may be undefined"),
     W2002 = _warn("W2002", Category.SEMANTIC, "Unreachable code detected"),
     W2003 = _warn("W2003", Category.SEMANTIC, "'{name}' is defined but never used"),
     # Semantic analysis errors
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
     E2008 = _err(
         "E2008", Category.SEMANTIC, "Invalid target for context update: {target}"
     ),
     # New semantic warnings
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
     E2055 = _err(
         "E2055",
         Category.SEMANTIC,
         "'return' inside a 'finally' block silences exceptions"
     ),
     E2083 = _err(
         "E2083", Category.SEMANTIC, "'disengage' is only valid inside a walker ability"
     ),
     # Def-impl match errors
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
         "'self' is implicit in obj, node, edge, and walker methods."
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
     # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     # Lint warnings (W3xxx)
     # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
     W3006 = _warn(
         "W3006", Category.LINT, "Unnecessary keyword escape on '{name}' [remove-kwesc]"
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
     W3011 = _warn(
         "W3011",
         Category.LINT,
         "Unnecessary semicolon after import [remove-import-semi]"
     ),
     E3012 = _err(
         "E3012", Category.LINT, "Calling print() is disallowed by rule [no-print]"
     ),
     # New lint checks
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
     # Old kebab-case name -> code mapping for jac.toml backward compat
     LINT_ALIASES: dict[str, str] = {
         "staticmethod-to-static": "W3001",
         "combine-has": "W3002",
         "combine-glob": "W3003",
         "init-to-can": "W3004",
         "remove-empty-parens": "W3005",
         "remove-kwesc": "W3006",
         "hasattr-to-null-ok": "W3007",
         "simplify-ternary": "W3008",
         "remove-future-annotations": "W3009",
         "fix-impl-signature": "W3010",
         "remove-import-semi": "W3011",
         "no-print": "E3012",
         "unnecessary-pass": "W3020",
         "unnecessary-else-after-return": "W3021",
         "nested-if-to-elif": "W3022",
         "simplify-return-bool": "W3023",
         "repeated-condition": "W3024",
         "identical-branches": "W3025",
         "too-many-params": "W3030",
         "is-with-literal": "W3035",
         "mutable-default": "W3036",
         "unnecessary-none-return": "W3037"
     },
     # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     # Codegen errors (E5xxx/W5xxx)
     # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

     # PyAST gen
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
     # Native compile
     E5020 = _err("E5020", Category.CODEGEN, "Native compilation failed: {error}"),
     W5021 = _warn("W5021", Category.CODEGEN, "C library not found: {path}"),
     W5022 = _warn(
         "W5022", Category.CODEGEN, "Failed to load C library '{path}': {error}"
     ),
     W5023 = _warn("W5023", Category.CODEGEN, "Native module not found: {path}"),
     W5024 = _warn(
         "W5024", Category.CODEGEN, "Failed to compile native module {path}: {error}"
     ),
     W5025 = _warn(
         "W5025", Category.CODEGEN, "Failed to link native module {path}: {error}"
     ),
     # Layout pass
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
     # Bytecode gen
     E5040 = _err("E5040", Category.CODEGEN, "Unable to find ast for module {path}."),
     E5041 = _err("E5041", Category.CODEGEN, "Length mismatch in import names"),
     E5042 = _err("E5042", Category.CODEGEN, "Length mismatch in async for body"),
     E5043 = _err("E5043", Category.CODEGEN, "Bytecode compilation failed: {error}"),
     # Comment injection
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
     # Native IR gen
     E5060 = _err(
         "E5060",
         Category.CODEGEN,
         "C library import declaration '{name}' must not have a body"
     ),
     # Language server
     E5070 = _err("E5070", Category.CODEGEN, "Error during type check: {error}"),
     E5071 = _err("E5071", Category.CODEGEN, "Error during formatting: {error}"),
     W5072 = _warn(
         "W5072",
         Category.CODEGEN,
         "Attribute error when accessing node attributes: {error}"
     ),
     # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     # Portability warnings (W6xxx) — JS-idiomatic usage that breaks cross-codespace portability
     # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
     # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     # Internal compiler errors (E9xxx)
     # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     E9001 = _err("E9001", Category.ICE, "ICE: Pass {pass_name} -- {details}");
