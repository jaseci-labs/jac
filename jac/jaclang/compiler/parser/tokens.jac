"""Token definitions for the Jac lexer and parser.

This module defines all token kinds and the Token class used by the
hand-written recursive descent parser. The token definitions are designed
to be compile-time constants with no runtime reflection needed.
"""

# =============================================================================
# Token Kind Enumeration
# =============================================================================
enum TokenKind {
    # -------------------------------------------------------------------------
    # Literals
    # -------------------------------------------------------------------------
    INT = "INT",
    HEX = "HEX",
    BIN = "BIN",
    OCT = "OCT",
    FLOAT = "FLOAT",
    STRING = "STRING",
    BOOL = "BOOL",
    NULL = "NULL",
    ELLIPSIS = "ELLIPSIS",
    PYNLINE = "PYNLINE",
    # -------------------------------------------------------------------------
    # Identifiers
    # -------------------------------------------------------------------------
    NAME = "NAME",
    KWESC_NAME = "KWESC_NAME",  # Escaped keyword used as identifier
    # -------------------------------------------------------------------------
    # Built-in Type Keywords
    # -------------------------------------------------------------------------
    TYP_STRING = "str",
    TYP_INT = "int",
    TYP_FLOAT = "float",
    TYP_LIST = "list",
    TYP_TUPLE = "tuple",
    TYP_SET = "set",
    TYP_DICT = "dict",
    TYP_BOOL = "bool",
    TYP_BYTES = "bytes",
    TYP_ANY = "any",
    TYP_TYPE = "type",
    # -------------------------------------------------------------------------
    # Keywords - Declarations
    # -------------------------------------------------------------------------
    KW_ABSTRACT = "abs",
    KW_OBJECT = "obj",
    KW_CLASS = "class",
    KW_ENUM = "enum",
    KW_NODE = "node",
    KW_EDGE = "edge",
    KW_WALKER = "walker",
    KW_HAS = "has",
    KW_CAN = "can",
    KW_DEF = "def",
    KW_STATIC = "static",
    KW_OVERRIDE = "override",
    KW_IMPL = "impl",
    KW_SEM = "sem",
    KW_TEST = "test",
    KW_GLOBAL = "glob",
    KW_GLOBAL_REF = "global",
    KW_NONLOCAL = "nonlocal",
    # -------------------------------------------------------------------------
    # Keywords - Import/Include
    # -------------------------------------------------------------------------
    KW_IMPORT = "import",
    KW_INCLUDE = "include",
    KW_FROM = "from",
    KW_AS = "as",
    # -------------------------------------------------------------------------
    # Keywords - Control Flow
    # -------------------------------------------------------------------------
    KW_IF = "if",
    KW_ELIF = "elif",
    KW_ELSE = "else",
    KW_FOR = "for",
    KW_TO = "to",
    KW_BY = "by",
    KW_WHILE = "while",
    KW_MATCH = "match",
    KW_SWITCH = "switch",
    KW_CASE = "case",
    KW_DEFAULT = "default",
    KW_TRY = "try",
    KW_EXCEPT = "except",
    KW_FINALLY = "finally",
    KW_WITH = "with",
    # -------------------------------------------------------------------------
    # Keywords - Jump Statements
    # -------------------------------------------------------------------------
    KW_RETURN = "return",
    KW_YIELD = "yield",
    KW_BREAK = "break",
    KW_CONTINUE = "continue",
    KW_RAISE = "raise",
    KW_DELETE = "del",
    KW_ASSERT = "assert",
    KW_SKIP = "skip",
    KW_REPORT = "report",
    # -------------------------------------------------------------------------
    # Keywords - Walker/Graph
    # -------------------------------------------------------------------------
    KW_VISIT = "visit",
    KW_SPAWN = "spawn",
    KW_ENTRY = "entry",
    KW_EXIT = "exit",
    KW_DISENGAGE = "disengage",
    KW_HERE = "here",
    KW_VISITOR = "visitor",
    KW_ROOT = "root",
    # -------------------------------------------------------------------------
    # Keywords - Async
    # -------------------------------------------------------------------------
    KW_ASYNC = "async",
    KW_AWAIT = "await",
    KW_FLOW = "flow",
    KW_WAIT = "wait",
    # -------------------------------------------------------------------------
    # Keywords - Boolean/Logic
    # -------------------------------------------------------------------------
    KW_AND = "and",
    KW_OR = "or",
    KW_NOT = "not",
    KW_IN = "in",
    KW_IS = "is",
    KW_NIN = "not in",
    KW_ISN = "is not",
    KW_LAMBDA = "lambda",
    # -------------------------------------------------------------------------
    # Keywords - Access Modifiers
    # -------------------------------------------------------------------------
    KW_PUB = "pub",
    KW_PRIV = "priv",
    KW_PROT = "protect",
    # -------------------------------------------------------------------------
    # Keywords - Context
    # -------------------------------------------------------------------------
    KW_CLIENT = "cl",
    KW_SERVER = "sv",
    KW_NATIVE = "na",
    # -------------------------------------------------------------------------
    # Keywords - Special
    # -------------------------------------------------------------------------
    KW_SELF = "self",
    KW_PROPS = "props",
    KW_INIT = "init",
    KW_SUPER = "super",
    KW_POST_INIT = "postinit",
    # -------------------------------------------------------------------------
    # Delimiters
    # -------------------------------------------------------------------------
    LPAREN = "(",
    RPAREN = ")",
    LBRACE = "{",
    RBRACE = "}",
    LSQUARE = "[",
    RSQUARE = "]",
    COMMA = ",",
    COLON = ":",
    SEMI = ";",
    DOT = ".",
    # -------------------------------------------------------------------------
    # Assignment Operators
    # -------------------------------------------------------------------------
    EQ = "=",
    WALRUS_EQ = ":=",
    ADD_EQ = "+=",
    SUB_EQ = "-=",
    MUL_EQ = "*=",
    DIV_EQ = "/=",
    FLOOR_DIV_EQ = "//=",
    MOD_EQ = "%=",
    STAR_POW_EQ = "**=",
    BW_AND_EQ = "&=",
    BW_OR_EQ = "|=",
    BW_XOR_EQ = "^=",
    LSHIFT_EQ = "<<=",
    RSHIFT_EQ = ">>=",
    MATMUL_EQ = "@=",
    # -------------------------------------------------------------------------
    # Comparison Operators
    # -------------------------------------------------------------------------
    EE = "==",
    NE = "!=",
    LT = "<",
    GT = ">",
    LTE = "<=",
    GTE = ">=",
    # -------------------------------------------------------------------------
    # Arithmetic Operators
    # -------------------------------------------------------------------------
    PLUS = "+",
    MINUS = "-",
    STAR_MUL = "*",
    DIV = "/",
    FLOOR_DIV = "//",
    MOD = "%",
    STAR_POW = "**",
    # -------------------------------------------------------------------------
    # Bitwise Operators
    # -------------------------------------------------------------------------
    BW_AND = "&",
    BW_OR = "|",
    BW_XOR = "^",
    BW_NOT = "~",
    LSHIFT = "<<",
    RSHIFT = ">>",
    # -------------------------------------------------------------------------
    # Pipe Operators
    # -------------------------------------------------------------------------
    PIPE_FWD = "|>",
    PIPE_BKWD = "<|",
    A_PIPE_FWD = ":>",
    A_PIPE_BKWD = "<:",
    DOT_FWD = ".>",
    DOT_BKWD = "<.",
    # -------------------------------------------------------------------------
    # Arrow Operators (Graph Navigation)
    # -------------------------------------------------------------------------
    ARROW_L = "<--",
    ARROW_R = "-->",
    ARROW_BI = "<-->",
    ARROW_L_P1 = "<-:",
    ARROW_L_P2 = ":<-",
    ARROW_R_P1 = "->:",
    ARROW_R_P2 = ":->",
    # -------------------------------------------------------------------------
    # Connect Arrows (Graph Modification)
    # -------------------------------------------------------------------------
    CARROW_L = "<++",
    CARROW_R = "++>",
    CARROW_BI = "<++>",
    CARROW_L_P1 = "<+:",
    CARROW_L_P2 = ":<+",
    CARROW_R_P1 = "+>:",
    CARROW_R_P2 = ":+>",
    # -------------------------------------------------------------------------
    # Special Operators
    # -------------------------------------------------------------------------
    RETURN_HINT = "->",
    NULL_OK = "?",
    DECOR_OP = "@",
    TYPE_OP = "`",
    GLOBAL_OP = ":g:",
    NONLOCAL_OP = ":nl:",
    TYPE_OP_ALIAS = ":typ:",  # Type alias definition
    # -------------------------------------------------------------------------
    # F-String Tokens
    # -------------------------------------------------------------------------
    F_DQ_START = "f\"",
    F_SQ_START = "f'",
    F_TDQ_START = "f\"\"\"",
    F_TSQ_START = "f'''",
    RF_DQ_START = "rf\"",
    RF_SQ_START = "rf'",
    RF_TDQ_START = "rf\"\"\"",
    RF_TSQ_START = "rf'''",
    F_DQ_END = "F_DQ_END",
    F_SQ_END = "F_SQ_END",
    F_TDQ_END = "F_TDQ_END",
    F_TSQ_END = "F_TSQ_END",
    F_TEXT_DQ = "F_TEXT_DQ",
    F_TEXT_SQ = "F_TEXT_SQ",
    F_TEXT_TDQ = "F_TEXT_TDQ",
    F_TEXT_TSQ = "F_TEXT_TSQ",
    RF_TEXT_DQ = "RF_TEXT_DQ",
    RF_TEXT_SQ = "RF_TEXT_SQ",
    RF_TEXT_TDQ = "RF_TEXT_TDQ",
    RF_TEXT_TSQ = "RF_TEXT_TSQ",
    D_LBRACE = "{{",
    D_RBRACE = "}}",
    CONV = "CONV",
    F_FORMAT_TEXT = "F_FORMAT_TEXT",
    # -------------------------------------------------------------------------
    # JSX Tokens
    # -------------------------------------------------------------------------
    JSX_TEXT = "JSX_TEXT",
    JSX_OPEN_START = "JSX_OPEN_START",
    JSX_SELF_CLOSE = "/>",
    JSX_TAG_END = "JSX_TAG_END",
    JSX_CLOSE_START = "</",
    JSX_FRAG_OPEN = "<>",
    JSX_FRAG_CLOSE = "</>",
    JSX_NAME = "JSX_NAME",
    # -------------------------------------------------------------------------
    # Special
    # -------------------------------------------------------------------------
    COMMENT = "COMMENT",
    WS = "WS",
    NEWLINE = "NEWLINE",
    EOF = "EOF",
    ERROR = "ERROR"
}

# =============================================================================
# Source Location
# =============================================================================
obj SourceLoc {
    has file_path: str = "",
        line: int = 0,
        end_line: int = 0,
        col_start: int = 0,
        col_end: int = 0,
        pos_start: int = 0,
        pos_end: int = 0;

    def span_to(other: SourceLoc) -> SourceLoc;
}

# =============================================================================
# Token Class
# =============================================================================
obj Token {
    has kind: TokenKind,
        value: str,
        loc: SourceLoc;

    def is_keyword -> bool;
    def __str__ -> str;
}

# =============================================================================
# Keyword Lookup Table (Compile-time constant)
# =============================================================================
glob KEYWORDS:
         dict[str, TokenKind] = {
         # Built-in types
         "str": TokenKind.TYP_STRING,
         "int": TokenKind.TYP_INT,
         "float": TokenKind.TYP_FLOAT,
         "list": TokenKind.TYP_LIST,
         "tuple": TokenKind.TYP_TUPLE,
         "set": TokenKind.TYP_SET,
         "dict": TokenKind.TYP_DICT,
         "bool": TokenKind.TYP_BOOL,
         "bytes": TokenKind.TYP_BYTES,
         "any": TokenKind.TYP_ANY,
         "type": TokenKind.TYP_TYPE,
         # Declaration keywords
         "abs": TokenKind.KW_ABSTRACT,
         "obj": TokenKind.KW_OBJECT,
         "class": TokenKind.KW_CLASS,
         "enum": TokenKind.KW_ENUM,
         "node": TokenKind.KW_NODE,
         "edge": TokenKind.KW_EDGE,
         "walker": TokenKind.KW_WALKER,
         "has": TokenKind.KW_HAS,
         "can": TokenKind.KW_CAN,
         "def": TokenKind.KW_DEF,
         "static": TokenKind.KW_STATIC,
         "override": TokenKind.KW_OVERRIDE,
         "impl": TokenKind.KW_IMPL,
         "sem": TokenKind.KW_SEM,
         "test": TokenKind.KW_TEST,
         "glob": TokenKind.KW_GLOBAL,
         "global": TokenKind.KW_GLOBAL_REF,
         "nonlocal": TokenKind.KW_NONLOCAL,
         # Import keywords
         "import": TokenKind.KW_IMPORT,
         "include": TokenKind.KW_INCLUDE,
         "from": TokenKind.KW_FROM,
         "as": TokenKind.KW_AS,
         # Control flow
         "if": TokenKind.KW_IF,
         "elif": TokenKind.KW_ELIF,
         "else": TokenKind.KW_ELSE,
         "for": TokenKind.KW_FOR,
         "to": TokenKind.KW_TO,
         "by": TokenKind.KW_BY,
         "while": TokenKind.KW_WHILE,
         "match": TokenKind.KW_MATCH,
         "switch": TokenKind.KW_SWITCH,
         "case": TokenKind.KW_CASE,
         "default": TokenKind.KW_DEFAULT,
         "try": TokenKind.KW_TRY,
         "except": TokenKind.KW_EXCEPT,
         "finally": TokenKind.KW_FINALLY,
         "with": TokenKind.KW_WITH,
         # Jump statements
         "return": TokenKind.KW_RETURN,
         "yield": TokenKind.KW_YIELD,
         "break": TokenKind.KW_BREAK,
         "continue": TokenKind.KW_CONTINUE,
         "raise": TokenKind.KW_RAISE,
         "del": TokenKind.KW_DELETE,
         "assert": TokenKind.KW_ASSERT,
         "skip": TokenKind.KW_SKIP,
         "report": TokenKind.KW_REPORT,
         # Walker/Graph keywords
         "visit": TokenKind.KW_VISIT,
         "spawn": TokenKind.KW_SPAWN,
         "entry": TokenKind.KW_ENTRY,
         "exit": TokenKind.KW_EXIT,
         "disengage": TokenKind.KW_DISENGAGE,
         "here": TokenKind.KW_HERE,
         "visitor": TokenKind.KW_VISITOR,
         "root": TokenKind.KW_ROOT,
         # Async keywords
         "async": TokenKind.KW_ASYNC,
         "await": TokenKind.KW_AWAIT,
         "flow": TokenKind.KW_FLOW,
         "wait": TokenKind.KW_WAIT,
         # Boolean/Logic keywords
         "and": TokenKind.KW_AND,
         "or": TokenKind.KW_OR,
         "not": TokenKind.KW_NOT,
         "in": TokenKind.KW_IN,
         "is": TokenKind.KW_IS,
         "lambda": TokenKind.KW_LAMBDA,
         # Access modifiers
         "pub": TokenKind.KW_PUB,
         "priv": TokenKind.KW_PRIV,
         "protect": TokenKind.KW_PROT,
         # Context keywords
         "cl": TokenKind.KW_CLIENT,
         "sv": TokenKind.KW_SERVER,
         "na": TokenKind.KW_NATIVE,
         # Special keywords
         "self": TokenKind.KW_SELF,
         "props": TokenKind.KW_PROPS,
         "init": TokenKind.KW_INIT,
         "super": TokenKind.KW_SUPER,
         "postinit": TokenKind.KW_POST_INIT,
         # Boolean literals (treated as keywords)
         "True": TokenKind.BOOL,
         "False": TokenKind.BOOL,
         "None": TokenKind.NULL
     };

def lookup_keyword(text: str) -> TokenKind | None {
    return KEYWORDS.get(text, None);
}
