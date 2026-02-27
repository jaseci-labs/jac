"""Constants across the project."""
import from enum { Enum, IntEnum, IntFlag, StrEnum }

"""Symbol types."""
enum SymbolType {
    MODULE = 'module',
    MOD_VAR = 'mod_var',
    VAR = 'variable',
    IMM_VAR = 'immutable',
    ABILITY = 'ability',
    OBJECT_ARCH = 'object',
    NODE_ARCH = 'node',
    EDGE_ARCH = 'edge',
    WALKER_ARCH = 'walker',
    ENUM_ARCH = 'enum',
    TEST = 'test',
    TYPE = 'type',
    IMPL = 'impl',
    SEM = 'sem',
    HAS_VAR = 'field',
    METHOD = 'method',
    CONSTRUCTOR = 'constructor',
    ENUM_MEMBER = 'enum_member',
    NUMBER = 'number',
    STRING = 'string',
    BOOL = 'bool',
    SEQUENCE = 'sequence',
    NULL = 'null',
    UNKNOWN = 'unknown',
    with entry {
        def __str__(self: SymbolType) -> str {
            return self.value;
        }
    }
}

"""LSP Token types for Jac."""
class JacSemTokenType(IntEnum) {
    with entry {
        NAMESPACE = 0;
        TYPE = 1;
        CLASS = 2;
        ENUM = 3;
        INTERFACE = 4;
        STRUCT = 5;
        TYPE_PARAMETER = 6;
        PARAMETER = 7;
        VARIABLE = 8;
        PROPERTY = 9;
        ENUM_MEMBER = 10;
        EVENT = 11;
        FUNCTION = 12;
        METHOD = 13;
        MACRO = 14;
        KEYWORD = 15;
        MODIFIER = 16;
        COMMENT = 17;
        STRING = 18;
        NUMBER = 19;
        REGEXP = 20;
        OPERATOR = 21;
    }

    static def as_str_list -> list {
        return [
            i.name.lower()
            for i in JacSemTokenType
            if i.name
        ];
    }
}

"""LSP Token modifiers for Jac."""
class JacSemTokenModifier(IntFlag) {
    with entry {
        DECLARATION = 1 << 0;
        DEFINITION = 1 << 1;
        READONLY = 1 << 2;
        STATIC = 1 << 3;
        DEPRECATED = 1 << 4;
        ABSTRACT = 1 << 5;
        ASYNC = 1 << 6;
        MODIFICATION = 1 << 7;
        DOCUMENTATION = 1 << 8;
        DEFAULT_LIBRARY = 1 << 9;
    }

    """Return the string representation of the token."""
    static def as_str_list -> list {
        return [
            i.name.lower()
            for i in JacSemTokenModifier
            if i.name
        ];
    }
}

"""Token constants for Jac."""
class Constants(StrEnum) {
    with entry {
        HERE = 'here';
        ROOT = 'root';
        VISITOR = 'visitor';
        JAC_CHECK = '_check';
        SUPER_ROOT_UUID = '00000000-0000-0000-0000-000000000000';
    }

    """Return the string representation of the token."""
    def __str__(self: Constants) -> str {
        return self.value;
    }
}

"""Code execution context for client/server/native separation."""
enum CodeContext {
    SERVER = 'server',
    CLIENT = 'client',
    NATIVE = 'native',
    with entry {
        def __str__(self: CodeContext) -> str {
            return self.value;
        }

        @property
        def is_server(self: CodeContext) -> bool {
            return (self == CodeContext.SERVER);
        }

        @property
        def is_client(self: CodeContext) -> bool {
            return (self == CodeContext.CLIENT);
        }

        @property
        def is_native(self: CodeContext) -> bool {
            return (self == CodeContext.NATIVE);
        }
    }
}

"""Edge direction indicator."""
enum EdgeDir {
    IN = 1,
    OUT = 2,
    ANY = 3
}

"""Symbol access levels."""
enum SymbolAccess {
    PRIVATE = 'private',
    PUBLIC = 'public',
    PROTECTED = 'protected',
    with entry {
        def __str__(self: SymbolAccess) -> str {
            return self.value;
        }
    }
}

"""Token constants for the lexer."""
class Tokens(StrEnum) {
    with entry {
        FLOAT = 'FLOAT';
        STRING = 'STRING';
        PYNLINE = 'PYNLINE';
        BOOL = 'BOOL';
        INT = 'INT';
        HEX = 'HEX';
        BIN = 'BIN';
        OCT = 'OCT';
        NULL = 'NULL';
        NAME = 'NAME';
        KWESC_NAME = 'KWESC_NAME';
        TYP_STRING = 'TYP_STRING';
        TYP_INT = 'TYP_INT';
        TYP_FLOAT = 'TYP_FLOAT';
        TYP_LIST = 'TYP_LIST';
        TYP_TUPLE = 'TYP_TUPLE';
        TYP_SET = 'TYP_SET';
        TYP_DICT = 'TYP_DICT';
        TYP_BOOL = 'TYP_BOOL';
        TYP_BYTES = 'TYP_BYTES';
        TYP_ANY = 'TYP_ANY';
        TYP_TYPE = 'TYP_TYPE';
        KW_ABSTRACT = 'KW_ABSTRACT';
        KW_OBJECT = 'KW_OBJECT';
        KW_CLASS = 'KW_CLASS';
        KW_ENUM = 'KW_ENUM';
        KW_NODE = 'KW_NODE';
        KW_VISIT = 'KW_VISIT';
        KW_SPAWN = 'KW_SPAWN';
        KW_WITH = 'KW_WITH';
        KW_LAMBDA = 'KW_LAMBDA';
        KW_ENTRY = 'KW_ENTRY';
        KW_EXIT = 'KW_EXIT';
        KW_IMPORT = 'KW_IMPORT';
        KW_INCLUDE = 'KW_INCLUDE';
        KW_FROM = 'KW_FROM';
        KW_AS = 'KW_AS';
        KW_EDGE = 'KW_EDGE';
        KW_WALKER = 'KW_WALKER';
        KW_ASYNC = 'KW_ASYNC';
        KW_AWAIT = 'KW_AWAIT';
        KW_FLOW = 'KW_FLOW';
        KW_WAIT = 'KW_WAIT';
        KW_TEST = 'KW_TEST';
        KW_ASSERT = 'KW_ASSERT';
        COLON = 'COLON';
        PIPE_FWD = 'PIPE_FWD';
        PIPE_BKWD = 'PIPE_BKWD';
        DOT_FWD = 'DOT_FWD';
        DOT_BKWD = 'DOT_BKWD';
        LBRACE = 'LBRACE';
        RBRACE = 'RBRACE';
        SEMI = 'SEMI';
        EQ = 'EQ';
        ADD_EQ = 'ADD_EQ';
        SUB_EQ = 'SUB_EQ';
        MUL_EQ = 'MUL_EQ';
        STAR_POW_EQ = 'STAR_POW_EQ';
        FLOOR_DIV_EQ = 'FLOOR_DIV_EQ';
        DIV_EQ = 'DIV_EQ';
        MOD_EQ = 'MOD_EQ';
        BW_AND_EQ = 'BW_AND_EQ';
        BW_OR_EQ = 'BW_OR_EQ';
        BW_XOR_EQ = 'BW_XOR_EQ';
        LSHIFT_EQ = 'LSHIFT_EQ';
        RSHIFT_EQ = 'RSHIFT_EQ';
        WALRUS_EQ = 'WALRUS_EQ';
        MATMUL_EQ = 'MATMUL_EQ';
        KW_AND = 'KW_AND';
        KW_OR = 'KW_OR';
        KW_IF = 'KW_IF';
        KW_ELIF = 'KW_ELIF';
        KW_ELSE = 'KW_ELSE';
        KW_FOR = 'KW_FOR';
        KW_TO = 'KW_TO';
        KW_BY = 'KW_BY';
        KW_WHILE = 'KW_WHILE';
        KW_CONTINUE = 'KW_CONTINUE';
        KW_BREAK = 'KW_BREAK';
        KW_DISENGAGE = 'KW_DISENGAGE';
        KW_YIELD = 'KW_YIELD';
        KW_SKIP = 'KW_SKIP';
        KW_REPORT = 'KW_REPORT';
        KW_RETURN = 'KW_RETURN';
        KW_DELETE = 'KW_DELETE';
        KW_TRY = 'KW_TRY';
        KW_EXCEPT = 'KW_EXCEPT';
        KW_FINALLY = 'KW_FINALLY';
        KW_RAISE = 'KW_RAISE';
        ELLIPSIS = 'ELLIPSIS';
        DOT = 'DOT';
        NOT = 'NOT';
        EE = 'EE';
        LT = 'LT';
        GT = 'GT';
        LTE = 'LTE';
        GTE = 'GTE';
        NE = 'NE';
        KW_IN = 'KW_IN';
        KW_IS = 'KW_IS';
        KW_NIN = 'KW_NIN';
        KW_ISN = 'KW_ISN';
        KW_PRIV = 'KW_PRIV';
        KW_PUB = 'KW_PUB';
        KW_PROT = 'KW_PROT';
        KW_HAS = 'KW_HAS';
        KW_GLOBAL = 'KW_GLOBAL';
        COMMA = 'COMMA';
        KW_CAN = 'KW_CAN';
        KW_DEF = 'KW_DEF';
        KW_STATIC = 'KW_STATIC';
        KW_OVERRIDE = 'KW_OVERRIDE';
        KW_MATCH = 'KW_MATCH';
        KW_SWITCH = 'KW_SWITCH';
        KW_CASE = 'KW_CASE';
        KW_DEFAULT = 'KW_DEFAULT';
        KW_CLIENT = 'KW_CLIENT';
        KW_SERVER = 'KW_SERVER';
        KW_NATIVE = 'KW_NATIVE';
        PLUS = 'PLUS';
        MINUS = 'MINUS';
        STAR_MUL = 'STAR_MUL';
        FLOOR_DIV = 'FLOOR_DIV';
        DIV = 'DIV';
        MOD = 'MOD';
        BW_AND = 'BW_AND';
        BW_OR = 'BW_OR';
        BW_XOR = 'BW_XOR';
        BW_NOT = 'BW_NOT';
        LSHIFT = 'LSHIFT';
        RSHIFT = 'RSHIFT';
        STAR_POW = 'STAR_POW';
        LPAREN = 'LPAREN';
        RPAREN = 'RPAREN';
        LSQUARE = 'LSQUARE';
        RSQUARE = 'RSQUARE';
        ARROW_L = 'ARROW_L';
        ARROW_R = 'ARROW_R';
        ARROW_BI = 'ARROW_BI';
        ARROW_L_P1 = 'ARROW_L_P1';
        ARROW_L_P2 = 'ARROW_L_P2';
        ARROW_R_P1 = 'ARROW_R_P1';
        ARROW_R_P2 = 'ARROW_R_P2';
        CARROW_L = 'CARROW_L';
        CARROW_R = 'CARROW_R';
        CARROW_BI = 'CARROW_BI';
        CARROW_L_P1 = 'CARROW_L_P1';
        CARROW_L_P2 = 'CARROW_L_P2';
        CARROW_R_P1 = 'CARROW_R_P1';
        CARROW_R_P2 = 'CARROW_R_P2';
        GLOBAL_OP = 'GLOBAL_OP';
        NONLOCAL_OP = 'NONLOCAL_OP';
        KW_HERE = 'KW_HERE';
        KW_VISITOR = 'KW_VISITOR';
        KW_SELF = 'KW_SELF';
        KW_PROPS = 'KW_PROPS';
        KW_INIT = 'KW_INIT';
        KW_SUPER = 'KW_SUPER';
        KW_ROOT = 'KW_ROOT';
        KW_POST_INIT = 'KW_POST_INIT';
        KW_IMPL = 'KW_IMPL';
        KW_SEM = 'KW_SEM';
        A_PIPE_FWD = 'A_PIPE_FWD';
        A_PIPE_BKWD = 'A_PIPE_BKWD';
        RETURN_HINT = 'RETURN_HINT';
        NULL_OK = 'NULL_OK';
        DECOR_OP = 'DECOR_OP';
        JSX_TEXT = 'JSX_TEXT';
        JSX_OPEN_START = 'JSX_OPEN_START';
        JSX_SELF_CLOSE = 'JSX_SELF_CLOSE';
        JSX_TAG_END = 'JSX_TAG_END';
        JSX_CLOSE_START = 'JSX_CLOSE_START';
        JSX_FRAG_OPEN = 'JSX_FRAG_OPEN';
        JSX_FRAG_CLOSE = 'JSX_FRAG_CLOSE';
        JSX_NAME = 'JSX_NAME';
        COMMENT = 'COMMENT';
        WS = 'WS';
        F_DQ_START = 'F_DQ_START';
        F_SQ_START = 'F_SQ_START';
        F_TDQ_START = 'F_TDQ_START';
        F_TSQ_START = 'F_TSQ_START';
        RF_DQ_START = 'RF_DQ_START';
        RF_SQ_START = 'RF_SQ_START';
        RF_TDQ_START = 'RF_TDQ_START';
        RF_TSQ_START = 'RF_TSQ_START';
        F_DQ_END = 'F_DQ_END';
        F_SQ_END = 'F_SQ_END';
        F_TDQ_END = 'F_TDQ_END';
        F_TSQ_END = 'F_TSQ_END';
        F_TEXT_DQ = 'F_TEXT_DQ';
        F_TEXT_SQ = 'F_TEXT_SQ';
        F_TEXT_TDQ = 'F_TEXT_TDQ';
        F_TEXT_TSQ = 'F_TEXT_TSQ';
        RF_TEXT_DQ = 'RF_TEXT_DQ';
        RF_TEXT_SQ = 'RF_TEXT_SQ';
        RF_TEXT_TDQ = 'RF_TEXT_TDQ';
        RF_TEXT_TSQ = 'RF_TEXT_TSQ';
        D_LBRACE = 'D_LBRACE';
        D_RBRACE = 'D_RBRACE';
        CONV = 'CONV';
        F_FORMAT_TEXT = 'F_FORMAT_TEXT';
    }
}

"""Token name to string value mapping."""
glob TOKEN_MAP: dict[str, str] = {
         'ABILITY_OP': ':can:',
         'ADD_EQ': '+=',
         'ARROW_BI': '<-->',
         'ARROW_L': '<--',
         'ARROW_L_P1': '<-:',
         'ARROW_L_P2': ':<-',
         'ARROW_R': '-->',
         'ARROW_R_P1': '->:',
         'ARROW_R_P2': ':->',
         'A_PIPE_BKWD': '<:',
         'A_PIPE_FWD': ':>',
         'BIN': '0b',
         'BOOL': 'True',
         'BW_AND': '&',
         'BW_AND_EQ': '&=',
         'BW_NOT': '~',
         'BW_NOT_EQ': '~=',
         'BW_OR': '|',
         'BW_OR_EQ': '|=',
         'BW_XOR': '^',
         'BW_XOR_EQ': '^=',
         'CARROW_BI': '<++>',
         'CARROW_L': '<++',
         'CARROW_L_P1': '<+:',
         'CARROW_L_P2': ':<+',
         'CARROW_R': '++>',
         'CARROW_R_P1': '+>:',
         'CARROW_R_P2': ':+>',
         'CLASS_OP': ':class:',
         'COLON': ':',
         'COMMA': ',',
         'COMMENT': '#',
         'CONV': '!',
         'DECOR_OP': '@',
         'DIV': '/',
         'DIV_EQ': '/=',
         'DOT': '.',
         'DOT_BKWD': '<.',
         'DOT_FWD': '.>',
         'D_LBRACE': '{{',
         'D_RBRACE': '}}',
         'EDGE_OP': ':edge:',
         'EE': '==',
         'ELLIPSIS': '...',
         'EQ': '=',
         'FLOAT': '0.0',
         'FLOOR_DIV': '//',
         'FLOOR_DIV_EQ': '//=',
         'F_DQ_END': '"',
         'F_DQ_START': 'f"',
         'F_FORMAT_TEXT': '',
         'F_SQ_END': "'",
         'F_SQ_START': "f'",
         'F_TDQ_END': '"""',
         'F_TDQ_START': 'f"""',
         'F_TEXT_DQ': '',
         'F_TEXT_SQ': '',
         'F_TEXT_TDQ': '',
         'F_TEXT_TSQ': '',
         'F_TSQ_END': "'''",
         'F_TSQ_START': "f'''",
         'GLOBAL_OP': 'global',
         'GT': '>',
         'GTE': '>=',
         'HEX': '0x',
         'INT': '0',
         'JSX_CLOSE_START': '</',
         'JSX_FRAG_CLOSE': '</>',
         'JSX_FRAG_OPEN': '<>',
         'JSX_NAME': '',
         'JSX_OPEN_START': '<',
         'JSX_SELF_CLOSE': '/>',
         'JSX_TAG_END': '>',
         'JSX_TEXT': '',
         'KWESC_NAME': '`',
         'KW_ABSTRACT': 'abs',
         'KW_AND': 'and',
         'KW_AS': 'as',
         'KW_ASSERT': 'assert',
         'KW_ASYNC': 'async',
         'KW_AWAIT': 'await',
         'KW_BREAK': 'break',
         'KW_BY': 'by',
         'KW_CAN': 'can',
         'KW_CASE': 'case',
         'KW_CLASS': 'class',
         'KW_CLIENT': 'cl',
         'KW_CONTINUE': 'continue',
         'KW_DEF': 'def',
         'KW_DEFAULT': 'default',
         'KW_DELETE': 'del',
         'KW_DISENGAGE': 'disengage',
         'KW_EDGE': 'edge',
         'KW_ELIF': 'elif',
         'KW_ELSE': 'else',
         'KW_ENTRY': 'entry',
         'KW_ENUM': 'enum',
         'KW_EXCEPT': 'except',
         'KW_EXIT': 'exit',
         'KW_FINALLY': 'finally',
         'KW_FLOW': 'flow',
         'KW_FOR': 'for',
         'KW_FROM': 'from',
         'KW_GLOBAL': 'glob',
         'KW_HAS': 'has',
         'KW_HERE': 'here',
         'KW_IF': 'if',
         'KW_IMPL': 'impl',
         'KW_IMPORT': 'import',
         'KW_IN': 'in',
         'KW_INCLUDE': 'include',
         'KW_INIT': 'init',
         'KW_IS': 'is',
         'KW_ISN': 'is not',
         'KW_LAMBDA': 'lambda',
         'KW_MATCH': 'match',
         'KW_NATIVE': 'na',
         'KW_NIN': 'not in',
         'KW_NODE': 'node',
         'KW_OBJECT': 'obj',
         'KW_OR': '|',
         'KW_OVERRIDE': 'override',
         'KW_POST_INIT': 'postinit',
         'KW_PRIV': 'priv',
         'KW_PROPS': 'props',
         'KW_PROT': 'protect',
         'KW_PUB': 'pub',
         'KW_RAISE': 'raise',
         'KW_REPORT': 'report',
         'KW_RETURN': 'return',
         'KW_ROOT': 'root',
         'KW_SELF': 'self',
         'KW_SEM': 'sem',
         'KW_SERVER': 'sv',
         'KW_SKIP': 'skip',
         'KW_SPAWN': 'spawn',
         'KW_STATIC': 'static',
         'KW_SUPER': 'super',
         'KW_SWITCH': 'switch',
         'KW_TEST': 'test',
         'KW_TO': 'to',
         'KW_TRY': 'try',
         'KW_VISIT': 'visit',
         'KW_VISITOR': 'visitor',
         'KW_WAIT': 'wait',
         'KW_WALKER': 'walker',
         'KW_WHILE': 'while',
         'KW_WITH': 'with',
         'KW_YIELD': 'yield',
         'LBRACE': '{',
         'LPAREN': '(',
         'LSHIFT': '<<',
         'LSHIFT_EQ': '<<=',
         'LSQUARE': '[',
         'LT': '<',
         'LTE': '<=',
         'MATMUL_EQ': '@=',
         'MINUS': '-',
         'MOD': '%',
         'MOD_EQ': '%=',
         'MUL_EQ': '*=',
         'NAME': '',
         'NE': '!=',
         'NODE_OP': ':node:',
         'NONLOCAL_OP': 'nonlocal',
         'NOT': 'not',
         'NULL': 'None',
         'NULL_OK': '?',
         'OBJECT_OP': ':obj:',
         'OCT': '0o',
         'PIPE_BKWD': '<|',
         'PIPE_FWD': '|>',
         'PLUS': '+',
         'PYNLINE': '::py::',
         'RBRACE': '}',
         'RETURN_HINT': '->',
         'RF_DQ_START': 'rf"',
         'RF_SQ_START': "rf'",
         'RF_TDQ_START': 'rf"""',
         'RF_TEXT_DQ': '',
         'RF_TEXT_SQ': '',
         'RF_TEXT_TDQ': '',
         'RF_TEXT_TSQ': '',
         'RF_TSQ_START': "rf'''",
         'RPAREN': ')',
         'RSHIFT': '>>',
         'RSHIFT_EQ': '>>=',
         'RSQUARE': ']',
         'SEMI': ';',
         'STAR_MUL': '*',
         'STAR_POW': '**',
         'STAR_POW_EQ': '**=',
         'STRING': '',
         'SUB_EQ': '-=',
         'TYP_ANY': 'any',
         'TYP_BOOL': 'bool',
         'TYP_BYTES': 'bytes',
         'TYP_DICT': 'dict',
         'TYP_FLOAT': 'float',
         'TYP_INT': 'int',
         'TYP_LIST': 'list',
         'TYP_SET': 'set',
         'TYP_STRING': 'str',
         'TYP_TUPLE': 'tuple',
         'TYP_TYPE': 'type',
         'WALKER_OP': ':walker:',
         'WALRUS_EQ': ':=',
         'WS': ' '
     },
     DELIM_MAP = {
         Tokens.COMMA: ',',
         Tokens.EQ: '=',
         Tokens.DECOR_OP: '@',
         Tokens.WS: '\n',
         Tokens.SEMI: ';',
         Tokens.COLON: ':',
         Tokens.LBRACE: '{',
         Tokens.RBRACE: '}',
         Tokens.LSQUARE: '[',
         Tokens.RSQUARE: ']',
         Tokens.LPAREN: '(',
         Tokens.RPAREN: ')',
         Tokens.RETURN_HINT: '->',
         Tokens.DOT: '.'
     },
     colors = [
         '#FFE9E9',
         '#F0FFF0',
         '#F5E5FF',
         '#FFFFE0',
         '#D2FEFF',
         '#E8FFD7',
         '#FFDEAD',
         '#FFF0F5',
         '#F5FFFA',
         '#FFC0CB',
         '#7FFFD4',
         '#C0C0C0',
         '#ADD8E6',
         '#FFFAF0',
         '#f4f3f7',
         '#f5efff',
         '#b5d7fd',
         '#ffc0cb',
         '#FFC0CB',
         '#e1d4c0',
         '#FCDFFF',
         '#F0FFFF',
         '#F0F8FF',
         '#F8F8FF',
         '#F0FFFF'
     ];
