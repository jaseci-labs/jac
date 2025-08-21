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
    JAC_MYPY_CACHE = ".jac_mypy_cache"
    SUPER_ROOT_UUID = "00000000-0000-0000-0000-000000000000"

    def __str__(self) -> str:
        """Return the string representation of the token."""
        return self.value


class EdgeDir(Enum):
    """Edge direction indicator."""

    IN = 1  # <--
    OUT = 2  # -->
    ANY = 3  # <-->


class Values(int, Enum):
    """Token constants for Jac."""

    JAC_ERROR_LINE_RANGE = 3


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
    KW_LET = "KW_LET"
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
    KW_CHECK = "KW_CHECK"
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
    BW_NOT_EQ = "BW_NOT_EQ"
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
    KW_CASE = "KW_CASE"
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
    FSTR_START = "FSTR_START"
    FSTR_END = "FSTR_END"
    FSTR_SQ_START = "FSTR_SQ_START"
    FSTR_SQ_END = "FSTR_SQ_END"
    FSTR_PIECE = "FSTR_PIECE"
    FSTR_SQ_PIECE = "FSTR_SQ_PIECE"
    FSTR_BESC = "FSTR_BESC"
    COMMENT = "COMMENT"
    WS = "WS"

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
