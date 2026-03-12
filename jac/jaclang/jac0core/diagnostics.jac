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

    def format_message(self: DiagnosticInfo, **kwargs: object) -> str {
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
         "E0023",
         Category.SYNTAX,
         "Expected augmented assignment in for...to...by step"
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
         "E0033", Category.SYNTAX, "'{modifier}' is not a valid prefix modifier"
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
     E0050 = _err("E0050", Category.SYNTAX, "Duplicate '{param}' in parameter list"),
     E0051 = _err(
         "E0051",
         Category.SYNTAX,
         "'{first}' must appear before '{second}' in parameter list"
     ),
     W0060 = _warn(
         "W0060",
         Category.SYNTAX,
         "Docstrings in Jac go before the declaration, not inside the body. Move this string before the enclosing test/can/obj/etc."
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
     E1040 = _err("E1040", Category.TYPE, "Type \"{type}\" is not subscriptable"),
     E1041 = _err("E1041", Category.TYPE, "Type \"{type}\" is not awaitable"),
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
         "E1094", Category.TYPE, "Visit target must be a node type, got {type}"
     ),
     E1095 = _err(
         "E1095",
         Category.TYPE,
         "Field '{field}' declared 'by postinit' is never assigned in {arch}.postinit"
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
     W1100 = _warn("W1100", Category.IMPORT, "Module not found"),
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
     E2008 = _err(
         "E2008", Category.SEMANTIC, "Invalid target for context update: {target}"
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
         "W3006",
         Category.LINT,
         "Unnecessary keyword escape on '{name}' [remove-kwesc]"
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
         "no-print": "E3012"
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
     W5050 = _warn(
         "W5050",
         Category.CODEGEN,
         "Comment could not be placed precisely; emitting near the end of the formatted output: {preview}"
     ),
     E5060 = _err(
         "E5060",
         Category.CODEGEN,
         "C library import declaration '{name}' must not have a body"
     ),
     E5070 = _err("E5070", Category.CODEGEN, "Error during type check: {error}"),
     E5071 = _err("E5071", Category.CODEGEN, "Error during formatting: {error}"),
     W5072 = _warn(
         "W5072",
         Category.CODEGEN,
         "Attribute error when accessing node attributes: {error}"
     ),
     E9001 = _err("E9001", Category.ICE, "ICE: Pass {pass_name} -- {details}");
# Parser: keyword restrictions

# Parser: operator/expression errors

# Parser: statement-level errors

# Parser: block/body requirements

# Parser: parameter list errors

# Parser: warnings

# Lexer errors

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Type errors (E1xxx) — type checker and type evaluator
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Assignment / return type mismatches

# Operator errors

# Iterability / callable

# Attribute access

# Subscript / await

# Function call errors

# TypeVar errors

# Callable type errors

# Variance errors

# Exception / context manager / yield

# Connection type errors

# Import warnings

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Semantic errors/warnings (E2xxx/W2xxx)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Static analysis warnings

# Semantic analysis errors

# Def-impl match errors

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Lint warnings (W3xxx)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Old kebab-case name -> code mapping for jac.toml backward compat

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Codegen errors (E5xxx/W5xxx)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# PyAST gen

# ES AST gen

# Native compile

# Layout pass

# Bytecode gen

# PyAST load

# Comment injection

# Native IR gen

# Language server

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Internal compiler errors (E9xxx)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
