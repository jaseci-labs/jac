"""Constants for TypeScript/JavaScript parser."""

from enum import Enum, StrEnum


class TsTokens(str, Enum):
    """Token constants for the TypeScript/JavaScript lexer."""

    # Literals
    NUMBER = "NUMBER"
    STRING = "STRING"
    TEMPLATE_STRING = "TEMPLATE_STRING"
    TEMPLATE_HEAD = "TEMPLATE_HEAD"
    TEMPLATE_MIDDLE = "TEMPLATE_MIDDLE"
    TEMPLATE_TAIL = "TEMPLATE_TAIL"
    REGEX = "REGEX"
    TRUE = "TRUE"
    FALSE = "FALSE"
    NULL = "NULL"
    UNDEFINED = "UNDEFINED"

    # Identifiers
    NAME = "NAME"
    PRIVATE_NAME = "PRIVATE_NAME"  # #privateField

    # Keywords - Declarations
    KW_VAR = "KW_VAR"
    KW_LET = "KW_LET"
    KW_CONST = "KW_CONST"
    KW_FUNCTION = "KW_FUNCTION"
    KW_CLASS = "KW_CLASS"
    KW_INTERFACE = "KW_INTERFACE"
    KW_TYPE = "KW_TYPE"
    KW_ENUM = "KW_ENUM"
    KW_NAMESPACE = "KW_NAMESPACE"
    KW_MODULE = "KW_MODULE"
    KW_DECLARE = "KW_DECLARE"

    # Keywords - Class/Interface
    KW_EXTENDS = "KW_EXTENDS"
    KW_IMPLEMENTS = "KW_IMPLEMENTS"
    KW_STATIC = "KW_STATIC"
    KW_PUBLIC = "KW_PUBLIC"
    KW_PRIVATE = "KW_PRIVATE"
    KW_PROTECTED = "KW_PROTECTED"
    KW_READONLY = "KW_READONLY"
    KW_ABSTRACT = "KW_ABSTRACT"
    KW_OVERRIDE = "KW_OVERRIDE"
    KW_CONSTRUCTOR = "KW_CONSTRUCTOR"
    KW_GET = "KW_GET"
    KW_SET = "KW_SET"

    # Keywords - Control Flow
    KW_IF = "KW_IF"
    KW_ELSE = "KW_ELSE"
    KW_SWITCH = "KW_SWITCH"
    KW_CASE = "KW_CASE"
    KW_DEFAULT = "KW_DEFAULT"
    KW_FOR = "KW_FOR"
    KW_WHILE = "KW_WHILE"
    KW_DO = "KW_DO"
    KW_BREAK = "KW_BREAK"
    KW_CONTINUE = "KW_CONTINUE"
    KW_RETURN = "KW_RETURN"
    KW_THROW = "KW_THROW"
    KW_TRY = "KW_TRY"
    KW_CATCH = "KW_CATCH"
    KW_FINALLY = "KW_FINALLY"
    KW_WITH = "KW_WITH"
    KW_DEBUGGER = "KW_DEBUGGER"

    # Keywords - Operators
    KW_NEW = "KW_NEW"
    KW_DELETE = "KW_DELETE"
    KW_TYPEOF = "KW_TYPEOF"
    KW_VOID = "KW_VOID"
    KW_IN = "KW_IN"
    KW_OF = "KW_OF"
    KW_INSTANCEOF = "KW_INSTANCEOF"

    # Keywords - Async
    KW_ASYNC = "KW_ASYNC"
    KW_AWAIT = "KW_AWAIT"
    KW_YIELD = "KW_YIELD"

    # Keywords - Module
    KW_IMPORT = "KW_IMPORT"
    KW_EXPORT = "KW_EXPORT"
    KW_FROM = "KW_FROM"
    KW_AS = "KW_AS"

    # Keywords - Special
    KW_THIS = "KW_THIS"
    KW_SUPER = "KW_SUPER"

    # TypeScript Type Keywords
    KW_ANY = "KW_ANY"
    KW_UNKNOWN = "KW_UNKNOWN"
    KW_NEVER = "KW_NEVER"
    KW_STRING_TYPE = "KW_STRING_TYPE"
    KW_NUMBER_TYPE = "KW_NUMBER_TYPE"
    KW_BOOLEAN_TYPE = "KW_BOOLEAN_TYPE"
    KW_SYMBOL_TYPE = "KW_SYMBOL_TYPE"
    KW_BIGINT_TYPE = "KW_BIGINT_TYPE"
    KW_OBJECT_TYPE = "KW_OBJECT_TYPE"
    KW_KEYOF = "KW_KEYOF"
    KW_INFER = "KW_INFER"
    KW_IS = "KW_IS"
    KW_ASSERTS = "KW_ASSERTS"
    KW_SATISFIES = "KW_SATISFIES"

    # Delimiters
    LBRACE = "LBRACE"  # {
    RBRACE = "RBRACE"  # }
    LPAREN = "LPAREN"  # (
    RPAREN = "RPAREN"  # )
    LSQUARE = "LSQUARE"  # [
    RSQUARE = "RSQUARE"  # ]
    SEMI = "SEMI"  # ;
    COMMA = "COMMA"  # ,
    COLON = "COLON"  # :
    DOT = "DOT"  # .
    ELLIPSIS = "ELLIPSIS"  # ...
    QUESTION = "QUESTION"  # ?
    OPTIONAL_CHAIN = "OPTIONAL_CHAIN"  # ?.
    NULLISH_COALESCE = "NULLISH_COALESCE"  # ??
    AT = "AT"  # @ (decorator)
    HASH = "HASH"  # # (private field prefix)
    BACKTICK = "BACKTICK"  # `

    # Arrow
    ARROW = "ARROW"  # =>

    # Assignment Operators
    EQ = "EQ"  # =
    ADD_EQ = "ADD_EQ"  # +=
    SUB_EQ = "SUB_EQ"  # -=
    MUL_EQ = "MUL_EQ"  # *=
    DIV_EQ = "DIV_EQ"  # /=
    MOD_EQ = "MOD_EQ"  # %=
    EXP_EQ = "EXP_EQ"  # **=
    AND_EQ = "AND_EQ"  # &=
    OR_EQ = "OR_EQ"  # |=
    XOR_EQ = "XOR_EQ"  # ^=
    LSHIFT_EQ = "LSHIFT_EQ"  # <<=
    RSHIFT_EQ = "RSHIFT_EQ"  # >>=
    URSHIFT_EQ = "URSHIFT_EQ"  # >>>=
    LOGICAL_AND_EQ = "LOGICAL_AND_EQ"  # &&=
    LOGICAL_OR_EQ = "LOGICAL_OR_EQ"  # ||=
    NULLISH_EQ = "NULLISH_EQ"  # ??=

    # Comparison Operators
    EE = "EE"  # ==
    NE = "NE"  # !=
    EEE = "EEE"  # ===
    NEE = "NEE"  # !==
    LT = "LT"  # <
    GT = "GT"  # >
    LTE = "LTE"  # <=
    GTE = "GTE"  # >=

    # Arithmetic Operators
    PLUS = "PLUS"  # +
    MINUS = "MINUS"  # -
    STAR = "STAR"  # *
    SLASH = "SLASH"  # /
    PERCENT = "PERCENT"  # %
    STAR_STAR = "STAR_STAR"  # **
    PLUS_PLUS = "PLUS_PLUS"  # ++
    MINUS_MINUS = "MINUS_MINUS"  # --

    # Bitwise Operators
    BW_AND = "BW_AND"  # &
    BW_OR = "BW_OR"  # |
    BW_XOR = "BW_XOR"  # ^
    BW_NOT = "BW_NOT"  # ~
    LSHIFT = "LSHIFT"  # <<
    RSHIFT = "RSHIFT"  # >>
    URSHIFT = "URSHIFT"  # >>>

    # Logical Operators
    NOT = "NOT"  # !
    AND = "AND"  # &&
    OR = "OR"  # ||

    # JSX Tokens
    JSX_OPEN_START = "JSX_OPEN_START"  # < (in JSX context)
    JSX_CLOSE_START = "JSX_CLOSE_START"  # </
    JSX_SELF_CLOSE = "JSX_SELF_CLOSE"  # />
    JSX_TAG_END = "JSX_TAG_END"  # > (in JSX context)
    JSX_FRAG_OPEN = "JSX_FRAG_OPEN"  # <>
    JSX_FRAG_CLOSE = "JSX_FRAG_CLOSE"  # </>
    JSX_NAME = "JSX_NAME"
    JSX_TEXT = "JSX_TEXT"

    # Comments (for lexer callback)
    COMMENT = "COMMENT"
    MULTILINE_COMMENT = "MULTILINE_COMMENT"

    # Whitespace/Newline (for ASI)
    NEWLINE = "NEWLINE"
    WS = "WS"


# Token to string value mapping
TS_TOKEN_VALUES = {
    # Keywords - Declarations
    TsTokens.KW_VAR: "var",
    TsTokens.KW_LET: "let",
    TsTokens.KW_CONST: "const",
    TsTokens.KW_FUNCTION: "function",
    TsTokens.KW_CLASS: "class",
    TsTokens.KW_INTERFACE: "interface",
    TsTokens.KW_TYPE: "type",
    TsTokens.KW_ENUM: "enum",
    TsTokens.KW_NAMESPACE: "namespace",
    TsTokens.KW_MODULE: "module",
    TsTokens.KW_DECLARE: "declare",
    # Keywords - Class/Interface
    TsTokens.KW_EXTENDS: "extends",
    TsTokens.KW_IMPLEMENTS: "implements",
    TsTokens.KW_STATIC: "static",
    TsTokens.KW_PUBLIC: "public",
    TsTokens.KW_PRIVATE: "private",
    TsTokens.KW_PROTECTED: "protected",
    TsTokens.KW_READONLY: "readonly",
    TsTokens.KW_ABSTRACT: "abstract",
    TsTokens.KW_OVERRIDE: "override",
    TsTokens.KW_CONSTRUCTOR: "constructor",
    TsTokens.KW_GET: "get",
    TsTokens.KW_SET: "set",
    # Keywords - Control Flow
    TsTokens.KW_IF: "if",
    TsTokens.KW_ELSE: "else",
    TsTokens.KW_SWITCH: "switch",
    TsTokens.KW_CASE: "case",
    TsTokens.KW_DEFAULT: "default",
    TsTokens.KW_FOR: "for",
    TsTokens.KW_WHILE: "while",
    TsTokens.KW_DO: "do",
    TsTokens.KW_BREAK: "break",
    TsTokens.KW_CONTINUE: "continue",
    TsTokens.KW_RETURN: "return",
    TsTokens.KW_THROW: "throw",
    TsTokens.KW_TRY: "try",
    TsTokens.KW_CATCH: "catch",
    TsTokens.KW_FINALLY: "finally",
    TsTokens.KW_WITH: "with",
    TsTokens.KW_DEBUGGER: "debugger",
    # Keywords - Operators
    TsTokens.KW_NEW: "new",
    TsTokens.KW_DELETE: "delete",
    TsTokens.KW_TYPEOF: "typeof",
    TsTokens.KW_VOID: "void",
    TsTokens.KW_IN: "in",
    TsTokens.KW_OF: "of",
    TsTokens.KW_INSTANCEOF: "instanceof",
    # Keywords - Async
    TsTokens.KW_ASYNC: "async",
    TsTokens.KW_AWAIT: "await",
    TsTokens.KW_YIELD: "yield",
    # Keywords - Module
    TsTokens.KW_IMPORT: "import",
    TsTokens.KW_EXPORT: "export",
    TsTokens.KW_FROM: "from",
    TsTokens.KW_AS: "as",
    # Keywords - Special
    TsTokens.KW_THIS: "this",
    TsTokens.KW_SUPER: "super",
    # Literals
    TsTokens.TRUE: "true",
    TsTokens.FALSE: "false",
    TsTokens.NULL: "null",
    TsTokens.UNDEFINED: "undefined",
    # TypeScript Type Keywords
    TsTokens.KW_ANY: "any",
    TsTokens.KW_UNKNOWN: "unknown",
    TsTokens.KW_NEVER: "never",
    TsTokens.KW_STRING_TYPE: "string",
    TsTokens.KW_NUMBER_TYPE: "number",
    TsTokens.KW_BOOLEAN_TYPE: "boolean",
    TsTokens.KW_SYMBOL_TYPE: "symbol",
    TsTokens.KW_BIGINT_TYPE: "bigint",
    TsTokens.KW_OBJECT_TYPE: "object",
    TsTokens.KW_KEYOF: "keyof",
    TsTokens.KW_INFER: "infer",
    TsTokens.KW_IS: "is",
    TsTokens.KW_ASSERTS: "asserts",
    TsTokens.KW_SATISFIES: "satisfies",
    # Delimiters
    TsTokens.LBRACE: "{",
    TsTokens.RBRACE: "}",
    TsTokens.LPAREN: "(",
    TsTokens.RPAREN: ")",
    TsTokens.LSQUARE: "[",
    TsTokens.RSQUARE: "]",
    TsTokens.SEMI: ";",
    TsTokens.COMMA: ",",
    TsTokens.COLON: ":",
    TsTokens.DOT: ".",
    TsTokens.ELLIPSIS: "...",
    TsTokens.QUESTION: "?",
    TsTokens.OPTIONAL_CHAIN: "?.",
    TsTokens.NULLISH_COALESCE: "??",
    TsTokens.AT: "@",
    TsTokens.HASH: "#",
    TsTokens.BACKTICK: "`",
    # Arrow
    TsTokens.ARROW: "=>",
    # Assignment Operators
    TsTokens.EQ: "=",
    TsTokens.ADD_EQ: "+=",
    TsTokens.SUB_EQ: "-=",
    TsTokens.MUL_EQ: "*=",
    TsTokens.DIV_EQ: "/=",
    TsTokens.MOD_EQ: "%=",
    TsTokens.EXP_EQ: "**=",
    TsTokens.AND_EQ: "&=",
    TsTokens.OR_EQ: "|=",
    TsTokens.XOR_EQ: "^=",
    TsTokens.LSHIFT_EQ: "<<=",
    TsTokens.RSHIFT_EQ: ">>=",
    TsTokens.URSHIFT_EQ: ">>>=",
    TsTokens.LOGICAL_AND_EQ: "&&=",
    TsTokens.LOGICAL_OR_EQ: "||=",
    TsTokens.NULLISH_EQ: "??=",
    # Comparison Operators
    TsTokens.EE: "==",
    TsTokens.NE: "!=",
    TsTokens.EEE: "===",
    TsTokens.NEE: "!==",
    TsTokens.LT: "<",
    TsTokens.GT: ">",
    TsTokens.LTE: "<=",
    TsTokens.GTE: ">=",
    # Arithmetic Operators
    TsTokens.PLUS: "+",
    TsTokens.MINUS: "-",
    TsTokens.STAR: "*",
    TsTokens.SLASH: "/",
    TsTokens.PERCENT: "%",
    TsTokens.STAR_STAR: "**",
    TsTokens.PLUS_PLUS: "++",
    TsTokens.MINUS_MINUS: "--",
    # Bitwise Operators
    TsTokens.BW_AND: "&",
    TsTokens.BW_OR: "|",
    TsTokens.BW_XOR: "^",
    TsTokens.BW_NOT: "~",
    TsTokens.LSHIFT: "<<",
    TsTokens.RSHIFT: ">>",
    TsTokens.URSHIFT: ">>>",
    # Logical Operators
    TsTokens.NOT: "!",
    TsTokens.AND: "&&",
    TsTokens.OR: "||",
    # JSX
    TsTokens.JSX_SELF_CLOSE: "/>",
    TsTokens.JSX_CLOSE_START: "</",
    TsTokens.JSX_FRAG_OPEN: "<>",
    TsTokens.JSX_FRAG_CLOSE: "</>",
}


class TsSymbolType(StrEnum):
    """TypeScript-specific symbol types."""

    VARIABLE = "variable"
    FUNCTION = "function"
    CLASS = "class"
    INTERFACE = "interface"
    TYPE_ALIAS = "type_alias"
    ENUM = "enum"
    ENUM_MEMBER = "enum_member"
    NAMESPACE = "namespace"
    METHOD = "method"
    PROPERTY = "property"
    PARAMETER = "parameter"
    TYPE_PARAMETER = "type_parameter"
    GETTER = "getter"
    SETTER = "setter"
    CONSTRUCTOR = "constructor"
    IMPORT = "import"
    EXPORT = "export"


class TsModifier(StrEnum):
    """TypeScript modifiers."""

    PUBLIC = "public"
    PRIVATE = "private"
    PROTECTED = "protected"
    STATIC = "static"
    READONLY = "readonly"
    ABSTRACT = "abstract"
    ASYNC = "async"
    CONST = "const"
    DECLARE = "declare"
    EXPORT = "export"
    DEFAULT = "default"
    OVERRIDE = "override"
