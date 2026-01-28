"""Constants across the project."""

from enum import Enum, IntEnum, IntFlag, StrEnum


class SymbolType(Enum):
    """Symbol types."""

    MODULE = "module"  # LSP: Module
    MOD_VAR = "mod_var"  # LSP: Variable
    VAR = "variable"  # LSP: Variable
    IMM_VAR = "immutable"  # LSP: Constant
    ABILITY = "ability"  # LSP: Function
    OBJECT_ARCH = "object"  # LSP: Class
    NODE_ARCH = "node"  # LSP: Class
    EDGE_ARCH = "edge"  # LSP: Class
    WALKER_ARCH = "walker"  # LSP: Class
    ENUM_ARCH = "enum"  # LSP: Enum
    TEST = "test"  # LSP: Function
    TYPE = "type"  # LSP: TypeParameter
    IMPL = "impl"  # LSP: Interface or Property
    SEM = "sem"  # LSP: Property
    HAS_VAR = "field"  # LSP: Field
    METHOD = "method"  # LSP: Method
    CONSTRUCTOR = "constructor"  # LSP: Constructor
    ENUM_MEMBER = "enum_member"  # LSP: EnumMember
    NUMBER = "number"  # LSP: Number
    STRING = "string"  # LSP: String
    BOOL = "bool"  # LSP: Boolean
    SEQUENCE = "sequence"  # LSP: Array
    NULL = "null"  # LSP: Null
    UNKNOWN = "unknown"  # LSP: Unknown

    def __str__(self) -> str:
        return self.value


class JacSemTokenType(IntEnum):
    """LSP Token types for Jac."""

    NAMESPACE = 0
    TYPE = 1
    CLASS = 2
    ENUM = 3
    INTERFACE = 4
    STRUCT = 5
    TYPE_PARAMETER = 6
    PARAMETER = 7
    VARIABLE = 8
    PROPERTY = 9
    ENUM_MEMBER = 10
    EVENT = 11
    FUNCTION = 12
    METHOD = 13
    MACRO = 14
    KEYWORD = 15
    MODIFIER = 16
    COMMENT = 17
    STRING = 18
    NUMBER = 19
    REGEXP = 20
    OPERATOR = 21

    @staticmethod
    def as_str_list() -> list[str]:
        return [i.name.lower() for i in JacSemTokenType]


class JacSemTokenModifier(IntFlag):
    """LSP Token modifiers for Jac."""

    DECLARATION = 1 << 0
    DEFINITION = 1 << 1
    READONLY = 1 << 2
    STATIC = 1 << 3
    DEPRECATED = 1 << 4
    ABSTRACT = 1 << 5
    ASYNC = 1 << 6
    MODIFICATION = 1 << 7
    DOCUMENTATION = 1 << 8
    DEFAULT_LIBRARY = 1 << 9

    @staticmethod
    def as_str_list() -> list[str]:
        """Return the string representation of the token."""
        return [i.name.lower() for i in JacSemTokenModifier if i.name]


class Constants(StrEnum):
    """Token constants for Jac."""

    HERE = "here"
    ROOT = "root"
    VISITOR = "visitor"
    JAC_CHECK = "_check"
    SUPER_ROOT_UUID = "00000000-0000-0000-0000-000000000000"

    def __str__(self) -> str:
        """Return the string representation of the token."""
        return self.value


class CodeContext(Enum):
    """Code execution context for client/server/native separation."""

    SERVER = "server"  # Default: runs on server (Python)
    CLIENT = "client"  # Runs on client (JavaScript/browser)
    NATIVE = "native"  # Runs as native binary (LLVM IR)

    def __str__(self) -> str:
        """Return the string representation of the context."""
        return self.value

    @property
    def is_server(self) -> bool:
        """Check if this is server context."""
        return self == CodeContext.SERVER

    @property
    def is_client(self) -> bool:
        """Check if this is client context."""
        return self == CodeContext.CLIENT

    @property
    def is_native(self) -> bool:
        """Check if this is native context."""
        return self == CodeContext.NATIVE


class EdgeDir(Enum):
    """Edge direction indicator."""

    IN = 1  # <--
    OUT = 2  # -->
    ANY = 3  # <-->


class SymbolAccess(Enum):
    """Symbol types."""

    PRIVATE = "private"
    PUBLIC = "public"
    PROTECTED = "protected"

    def __str__(self) -> str:
        """Stringify."""
        return self.value


# Done like this for type checker
# validated synced with test
class Tokens(str, Enum):
    """Token constants for the lexer."""

    FLOAT = "FLOAT"
    STRING = "STRING"
    PYNLINE = "PYNLINE"
    BOOL = "BOOL"
    INT = "INT"
    HEX = "HEX"
    BIN = "BIN"
    OCT = "OCT"
    NULL = "NULL"
    NAME = "NAME"
    KWESC_NAME = "KWESC_NAME"
    TYP_STRING = "TYP_STRING"
    TYP_INT = "TYP_INT"
    TYP_FLOAT = "TYP_FLOAT"
    TYP_LIST = "TYP_LIST"
    TYP_TUPLE = "TYP_TUPLE"
    TYP_SET = "TYP_SET"
    TYP_DICT = "TYP_DICT"
    TYP_BOOL = "TYP_BOOL"
    TYP_BYTES = "TYP_BYTES"
    TYP_ANY = "TYP_ANY"
    TYP_TYPE = "TYP_TYPE"
    KW_ABSTRACT = "KW_ABSTRACT"
    KW_OBJECT = "KW_OBJECT"
    KW_CLASS = "KW_CLASS"
    KW_ENUM = "KW_ENUM"
    KW_NODE = "KW_NODE"
    KW_VISIT = "KW_VISIT"
    KW_SPAWN = "KW_SPAWN"
    KW_WITH = "KW_WITH"
    KW_LAMBDA = "KW_LAMBDA"
    KW_ENTRY = "KW_ENTRY"
    KW_EXIT = "KW_EXIT"
    KW_IMPORT = "KW_IMPORT"
    KW_INCLUDE = "KW_INCLUDE"
    KW_FROM = "KW_FROM"
    KW_AS = "KW_AS"
    KW_EDGE = "KW_EDGE"
    KW_WALKER = "KW_WALKER"
    KW_ASYNC = "KW_ASYNC"
    KW_AWAIT = "KW_AWAIT"
    KW_FLOW = "KW_FLOW"
    KW_WAIT = "KW_WAIT"
    KW_TEST = "KW_TEST"
    KW_ASSERT = "KW_ASSERT"
    COLON = "COLON"
    PIPE_FWD = "PIPE_FWD"
    PIPE_BKWD = "PIPE_BKWD"
    DOT_FWD = "DOT_FWD"
    DOT_BKWD = "DOT_BKWD"
    LBRACE = "LBRACE"
    RBRACE = "RBRACE"
    SEMI = "SEMI"
    EQ = "EQ"
    ADD_EQ = "ADD_EQ"
    SUB_EQ = "SUB_EQ"
    MUL_EQ = "MUL_EQ"
    STAR_POW_EQ = "STAR_POW_EQ"
    FLOOR_DIV_EQ = "FLOOR_DIV_EQ"
    DIV_EQ = "DIV_EQ"
    MOD_EQ = "MOD_EQ"
    BW_AND_EQ = "BW_AND_EQ"
    BW_OR_EQ = "BW_OR_EQ"
    BW_XOR_EQ = "BW_XOR_EQ"
    LSHIFT_EQ = "LSHIFT_EQ"
    RSHIFT_EQ = "RSHIFT_EQ"
    WALRUS_EQ = "WALRUS_EQ"
    MATMUL_EQ = "MATMUL_EQ"
    KW_AND = "KW_AND"
    KW_OR = "KW_OR"
    KW_IF = "KW_IF"
    KW_ELIF = "KW_ELIF"
    KW_ELSE = "KW_ELSE"
    KW_FOR = "KW_FOR"
    KW_TO = "KW_TO"
    KW_BY = "KW_BY"
    KW_WHILE = "KW_WHILE"
    KW_CONTINUE = "KW_CONTINUE"
    KW_BREAK = "KW_BREAK"
    KW_DISENGAGE = "KW_DISENGAGE"
    KW_YIELD = "KW_YIELD"
    KW_SKIP = "KW_SKIP"
    KW_REPORT = "KW_REPORT"
    KW_RETURN = "KW_RETURN"
    KW_DELETE = "KW_DELETE"
    KW_TRY = "KW_TRY"
    KW_EXCEPT = "KW_EXCEPT"
    KW_FINALLY = "KW_FINALLY"
    KW_RAISE = "KW_RAISE"
    ELLIPSIS = "ELLIPSIS"
    DOT = "DOT"
    NOT = "NOT"
    EE = "EE"
    LT = "LT"
    GT = "GT"
    LTE = "LTE"
    GTE = "GTE"
    NE = "NE"
    KW_IN = "KW_IN"
    KW_IS = "KW_IS"
    KW_NIN = "KW_NIN"
    KW_ISN = "KW_ISN"
    KW_PRIV = "KW_PRIV"
    KW_PUB = "KW_PUB"
    KW_PROT = "KW_PROT"
    KW_HAS = "KW_HAS"
    KW_GLOBAL = "KW_GLOBAL"
    COMMA = "COMMA"
    KW_CAN = "KW_CAN"
    KW_DEF = "KW_DEF"
    KW_STATIC = "KW_STATIC"
    KW_OVERRIDE = "KW_OVERRIDE"
    KW_MATCH = "KW_MATCH"
    KW_SWITCH = "KW_SWITCH"
    KW_CASE = "KW_CASE"
    KW_DEFAULT = "KW_DEFAULT"
    KW_CLIENT = "KW_CLIENT"
    KW_SERVER = "KW_SERVER"
    KW_NATIVE = "KW_NATIVE"
    PLUS = "PLUS"
    MINUS = "MINUS"
    STAR_MUL = "STAR_MUL"
    FLOOR_DIV = "FLOOR_DIV"
    DIV = "DIV"
    MOD = "MOD"
    BW_AND = "BW_AND"
    BW_OR = "BW_OR"
    BW_XOR = "BW_XOR"
    BW_NOT = "BW_NOT"
    LSHIFT = "LSHIFT"
    RSHIFT = "RSHIFT"
    STAR_POW = "STAR_POW"
    LPAREN = "LPAREN"
    RPAREN = "RPAREN"
    LSQUARE = "LSQUARE"
    RSQUARE = "RSQUARE"
    ARROW_L = "ARROW_L"
    ARROW_R = "ARROW_R"
    ARROW_BI = "ARROW_BI"
    ARROW_L_P1 = "ARROW_L_P1"
    ARROW_L_P2 = "ARROW_L_P2"
    ARROW_R_P1 = "ARROW_R_P1"
    ARROW_R_P2 = "ARROW_R_P2"
    CARROW_L = "CARROW_L"
    CARROW_R = "CARROW_R"
    CARROW_BI = "CARROW_BI"
    CARROW_L_P1 = "CARROW_L_P1"
    CARROW_L_P2 = "CARROW_L_P2"
    CARROW_R_P1 = "CARROW_R_P1"
    CARROW_R_P2 = "CARROW_R_P2"
    GLOBAL_OP = "GLOBAL_OP"
    NONLOCAL_OP = "NONLOCAL_OP"
    KW_HERE = "KW_HERE"
    KW_VISITOR = "KW_VISITOR"
    KW_SELF = "KW_SELF"
    KW_PROPS = "KW_PROPS"
    KW_INIT = "KW_INIT"
    KW_SUPER = "KW_SUPER"
    KW_ROOT = "KW_ROOT"
    KW_POST_INIT = "KW_POST_INIT"
    KW_IMPL = "KW_IMPL"
    KW_SEM = "KW_SEM"
    TYPE_OP = "TYPE_OP"
    A_PIPE_FWD = "A_PIPE_FWD"
    A_PIPE_BKWD = "A_PIPE_BKWD"
    RETURN_HINT = "RETURN_HINT"
    NULL_OK = "NULL_OK"
    DECOR_OP = "DECOR_OP"
    JSX_TEXT = "JSX_TEXT"
    JSX_OPEN_START = "JSX_OPEN_START"
    JSX_SELF_CLOSE = "JSX_SELF_CLOSE"
    JSX_TAG_END = "JSX_TAG_END"
    JSX_CLOSE_START = "JSX_CLOSE_START"
    JSX_FRAG_OPEN = "JSX_FRAG_OPEN"
    JSX_FRAG_CLOSE = "JSX_FRAG_CLOSE"
    JSX_NAME = "JSX_NAME"
    COMMENT = "COMMENT"
    WS = "WS"
    F_DQ_START = "F_DQ_START"
    F_SQ_START = "F_SQ_START"
    F_TDQ_START = "F_TDQ_START"
    F_TSQ_START = "F_TSQ_START"
    RF_DQ_START = "RF_DQ_START"
    RF_SQ_START = "RF_SQ_START"
    RF_TDQ_START = "RF_TDQ_START"
    RF_TSQ_START = "RF_TSQ_START"
    F_DQ_END = "F_DQ_END"
    F_SQ_END = "F_SQ_END"
    F_TDQ_END = "F_TDQ_END"
    F_TSQ_END = "F_TSQ_END"
    F_TEXT_DQ = "F_TEXT_DQ"
    F_TEXT_SQ = "F_TEXT_SQ"
    F_TEXT_TDQ = "F_TEXT_TDQ"
    F_TEXT_TSQ = "F_TEXT_TSQ"
    RF_TEXT_DQ = "RF_TEXT_DQ"
    RF_TEXT_SQ = "RF_TEXT_SQ"
    RF_TEXT_TDQ = "RF_TEXT_TDQ"
    RF_TEXT_TSQ = "RF_TEXT_TSQ"
    D_LBRACE = "D_LBRACE"
    D_RBRACE = "D_RBRACE"
    CONV = "CONV"
    F_FORMAT_TEXT = "F_FORMAT_TEXT"

    def __str__(self) -> str:
        return self.value


DELIM_MAP = {
    Tokens.COMMA: ",",
    Tokens.EQ: "=",
    Tokens.DECOR_OP: "@",
    Tokens.WS: "\n",
    Tokens.SEMI: ";",
    Tokens.COLON: ":",
    Tokens.LBRACE: "{",
    Tokens.RBRACE: "}",
    Tokens.LSQUARE: "[",
    Tokens.RSQUARE: "]",
    Tokens.LPAREN: "(",
    Tokens.RPAREN: ")",
    Tokens.RETURN_HINT: "->",
    Tokens.DOT: ".",
}

colors = [
    "#FFE9E9",
    "#F0FFF0",
    "#F5E5FF",
    "#FFFFE0",
    "#D2FEFF",
    "#E8FFD7",
    "#FFDEAD",
    "#FFF0F5",
    "#F5FFFA",
    "#FFC0CB",
    "#7FFFD4",
    "#C0C0C0",
    "#ADD8E6",
    "#FFFAF0",
    "#f4f3f7",
    "#f5efff",
    "#b5d7fd",
    "#ffc0cb",
    "#FFC0CB",
    "#e1d4c0",
    "#FCDFFF",
    "#F0FFFF",
    "#F0F8FF",
    "#F8F8FF",
    "#F0FFFF",
]


# =============================================================================
# TypeScript/JavaScript Parser Constants
# =============================================================================


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


# Token to string value mapping for TypeScript
TS_TOKEN_VALUES = {
    # Keywords - Declarations
    TsTokens.KW_VAR: "var",
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
