"""Lowering a finished codegen recipe into JacPython's AST.

The builder makes the AST node objects JacPython's compiler consumes, filling
the fields a recipe leaves out the way CPython's `ast` constructors do:
optional fields become None, list fields empty lists, and `ctx` `Load`."""
class PyAstBuildError(RuntimeError) {}

glob INT_DIGIT_BITS: int = 15,
     INT_DIGIT_MASK: int = 32767;

glob RECIPE_MODULE: int = 0,
     RECIPE_STMT: int = 1,
     RECIPE_EXPR: int = 2,
     RECIPE_OPERATOR: int = 3,
     RECIPE_PATTERN: int = 4,
     RECIPE_PART: int = 5;

glob RECIPE_CATEGORIES: dict[str, int] = {
         "Module": RECIPE_MODULE,
         "FunctionDef": RECIPE_STMT,
         "AsyncFunctionDef": RECIPE_STMT,
         "ClassDef": RECIPE_STMT,
         "Return": RECIPE_STMT,
         "Delete": RECIPE_STMT,
         "Assign": RECIPE_STMT,
         "TypeAlias": RECIPE_STMT,
         "AugAssign": RECIPE_STMT,
         "AnnAssign": RECIPE_STMT,
         "For": RECIPE_STMT,
         "AsyncFor": RECIPE_STMT,
         "While": RECIPE_STMT,
         "If": RECIPE_STMT,
         "With": RECIPE_STMT,
         "AsyncWith": RECIPE_STMT,
         "Match": RECIPE_STMT,
         "Raise": RECIPE_STMT,
         "Try": RECIPE_STMT,
         "TryStar": RECIPE_STMT,
         "Assert": RECIPE_STMT,
         "Import": RECIPE_STMT,
         "ImportFrom": RECIPE_STMT,
         "Global": RECIPE_STMT,
         "Nonlocal": RECIPE_STMT,
         "Expr": RECIPE_STMT,
         "Pass": RECIPE_STMT,
         "Break": RECIPE_STMT,
         "Continue": RECIPE_STMT,
         "BoolOp": RECIPE_EXPR,
         "NamedExpr": RECIPE_EXPR,
         "BinOp": RECIPE_EXPR,
         "UnaryOp": RECIPE_EXPR,
         "Lambda": RECIPE_EXPR,
         "IfExp": RECIPE_EXPR,
         "Dict": RECIPE_EXPR,
         "Set": RECIPE_EXPR,
         "ListComp": RECIPE_EXPR,
         "SetComp": RECIPE_EXPR,
         "DictComp": RECIPE_EXPR,
         "GeneratorExp": RECIPE_EXPR,
         "Await": RECIPE_EXPR,
         "Yield": RECIPE_EXPR,
         "YieldFrom": RECIPE_EXPR,
         "Compare": RECIPE_EXPR,
         "Call": RECIPE_EXPR,
         "FormattedValue": RECIPE_EXPR,
         "Interpolation": RECIPE_EXPR,
         "JoinedStr": RECIPE_EXPR,
         "TemplateStr": RECIPE_EXPR,
         "Constant": RECIPE_EXPR,
         "Attribute": RECIPE_EXPR,
         "Subscript": RECIPE_EXPR,
         "Starred": RECIPE_EXPR,
         "Name": RECIPE_EXPR,
         "List": RECIPE_EXPR,
         "Tuple": RECIPE_EXPR,
         "Slice": RECIPE_EXPR,
         "Load": RECIPE_OPERATOR,
         "Store": RECIPE_OPERATOR,
         "Del": RECIPE_OPERATOR,
         "And": RECIPE_OPERATOR,
         "Or": RECIPE_OPERATOR,
         "Add": RECIPE_OPERATOR,
         "Sub": RECIPE_OPERATOR,
         "Mult": RECIPE_OPERATOR,
         "MatMult": RECIPE_OPERATOR,
         "Div": RECIPE_OPERATOR,
         "Mod": RECIPE_OPERATOR,
         "Pow": RECIPE_OPERATOR,
         "LShift": RECIPE_OPERATOR,
         "RShift": RECIPE_OPERATOR,
         "BitOr": RECIPE_OPERATOR,
         "BitXor": RECIPE_OPERATOR,
         "BitAnd": RECIPE_OPERATOR,
         "FloorDiv": RECIPE_OPERATOR,
         "Invert": RECIPE_OPERATOR,
         "Not": RECIPE_OPERATOR,
         "UAdd": RECIPE_OPERATOR,
         "USub": RECIPE_OPERATOR,
         "Eq": RECIPE_OPERATOR,
         "NotEq": RECIPE_OPERATOR,
         "Lt": RECIPE_OPERATOR,
         "LtE": RECIPE_OPERATOR,
         "Gt": RECIPE_OPERATOR,
         "GtE": RECIPE_OPERATOR,
         "Is": RECIPE_OPERATOR,
         "IsNot": RECIPE_OPERATOR,
         "In": RECIPE_OPERATOR,
         "NotIn": RECIPE_OPERATOR,
         "MatchValue": RECIPE_PATTERN,
         "MatchSingleton": RECIPE_PATTERN,
         "MatchSequence": RECIPE_PATTERN,
         "MatchMapping": RECIPE_PATTERN,
         "MatchClass": RECIPE_PATTERN,
         "MatchStar": RECIPE_PATTERN,
         "MatchAs": RECIPE_PATTERN,
         "MatchOr": RECIPE_PATTERN,
         "comprehension": RECIPE_PART,
         "ExceptHandler": RECIPE_PART,
         "arguments": RECIPE_PART,
         "arg": RECIPE_PART,
         "keyword": RECIPE_PART,
         "alias": RECIPE_PART,
         "withitem": RECIPE_PART,
         "match_case": RECIPE_PART,
         "TypeIgnore": RECIPE_PART,
         "TypeVar": RECIPE_PART,
         "ParamSpec": RECIPE_PART,
         "TypeVarTuple": RECIPE_PART
     };

def wide_integer(value: CgWideInt) -> PyObj;

obj PyAstBuilder {
    has mod_path: str;

    def fail(cg: (CgNode | None), message: str) -> PyAstBuildError;
    def build_module(root: CgNode) -> Module;
    def node_of(item: any) -> ast_node;
    def node(cg: CgNode) -> ast_node;
    def stmt_node(cg: CgNode) -> stmt;
    def expr_node(cg: CgNode) -> expr;
    def pattern_node(cg: CgNode) -> pattern;
    def operator_node(cg: CgNode) -> ast_node;
    def part_node(cg: CgNode) -> ast_node;
    def required(cg: CgNode, key: str) -> any;
    def optional(cg: CgNode, key: str) -> any;
    def sequence(cg: CgNode, key: str) -> list[any];
    def splice(item: CgSplice) -> list[stmt];
    def constant(cg: CgNode, value: any) -> PyObj;
    def stmt_of(item: any) -> stmt;
    def expr_of(item: any) -> expr;
    def pattern_of(item: any) -> pattern;
    def expr_at(cg: CgNode, key: str) -> expr;
    def opt_expr_at(cg: CgNode, key: str) -> (expr | None);
    def exprs_at(cg: CgNode, key: str) -> list[expr];
    def opt_exprs_at(cg: CgNode, key: str) -> list[(expr | None)];
    def stmts_at(cg: CgNode, key: str) -> list[stmt];
    def patterns_at(cg: CgNode, key: str) -> list[pattern];
    def opt_pattern_at(cg: CgNode, key: str) -> (pattern | None);
    def text_at(cg: CgNode, key: str) -> str;
    def opt_text_at(cg: CgNode, key: str) -> (str | None);
    def texts_at(cg: CgNode, key: str) -> list[str];
    def number_at(cg: CgNode, key: str) -> int;
    def opt_number_at(cg: CgNode, key: str) -> (int | None);
    def ctx_at(cg: CgNode) -> expr_context;
    def arguments_at(cg: CgNode, key: str) -> arguments;
    def opt_arg_at(cg: CgNode, key: str) -> (arg | None);
    def args_at(cg: CgNode, key: str) -> list[arg];
    def keywords_at(cg: CgNode, key: str) -> list[keyword];
    def aliases_at(cg: CgNode, key: str) -> list[alias];
    def withitems_at(cg: CgNode, key: str) -> list[withitem];
    def handlers_at(cg: CgNode, key: str) -> list[excepthandler];
    def cases_at(cg: CgNode, key: str) -> list[match_case];
    def generators_at(cg: CgNode, key: str) -> list[comprehension];
    def type_params_at(cg: CgNode, key: str) -> list[type_param];
    def type_ignores_at(cg: CgNode, key: str) -> list[type_ignore];
    def operator_at(cg: CgNode, key: str) -> operator;
    def unaryop_at(cg: CgNode, key: str) -> unaryop;
    def boolop_at(cg: CgNode, key: str) -> boolop;
    def cmpops_at(cg: CgNode, key: str) -> list[cmpop];
}

def build_module_ast(root: CgNode, mod_path: str) -> Module;
