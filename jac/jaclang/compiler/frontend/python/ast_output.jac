"""Typed conversion from Jac-owned AST nodes to retained CPython AST values."""
import from jaclang.compiler.frontend.python.ast_nodes {
    ast_node,
    Module,
    Interactive,
    Expression,
    FunctionType,
    FunctionDef,
    AsyncFunctionDef,
    ClassDef,
    Return,
    Delete,
    Assign,
    TypeAlias,
    AugAssign,
    AnnAssign,
    For,
    AsyncFor,
    While,
    If,
    With,
    AsyncWith,
    Match,
    Raise,
    Try,
    TryStar,
    Assert,
    Import,
    ImportFrom,
    Global,
    Nonlocal,
    Expr,
    Pass,
    Break,
    Continue,
    BoolOp,
    NamedExpr,
    BinOp,
    UnaryOp,
    Lambda,
    IfExp,
    Dict,
    Set,
    ListComp,
    SetComp,
    DictComp,
    GeneratorExp,
    Await,
    Yield,
    YieldFrom,
    Compare,
    Call,
    FormattedValue,
    Interpolation,
    JoinedStr,
    TemplateStr,
    Constant,
    Attribute,
    Subscript,
    Starred,
    Name,
    List,
    Tuple,
    Slice,
    Load,
    Store,
    Del,
    And,
    Or,
    Add,
    Sub,
    Mult,
    MatMult,
    Div,
    Mod,
    Pow,
    LShift,
    RShift,
    BitOr,
    BitXor,
    BitAnd,
    FloorDiv,
    Invert,
    Not,
    UAdd,
    USub,
    Eq,
    NotEq,
    Lt,
    LtE,
    Gt,
    GtE,
    Is,
    IsNot,
    In,
    NotIn,
    comprehension,
    ExceptHandler,
    arguments,
    arg,
    keyword,
    alias,
    withitem,
    match_case,
    MatchValue,
    MatchSingleton,
    MatchSequence,
    MatchMapping,
    MatchClass,
    MatchStar,
    MatchAs,
    MatchOr,
    TypeIgnore,
    TypeVar,
    ParamSpec,
    TypeVarTuple
}
import from jaclang.runtime.python.native_services { runtime_failure }
import from jaclang.runtime.python.objects { PyObj }
import from jaclang.compiler.backends.py.jacpython.marshal_writer { marshal_constant }
import from c {
    def jacpy_ast_new(name: str) -> u64;  def jacpy_set_owned(
        target: u64, name: str, value: u64
    ) -> i64;  def jacpy_list_new -> u64;  def jacpy_list_append_owned(
        target: u64, value: u64
    ) -> i64;  def jacpy_none -> u64;  def jacpy_int(value: i64) -> u64;  def jacpy_text(
        value: str, size: i64
    ) -> u64;  def jacpy_release(handle: u64);  def jacpy_buffer_new(
        size: i64
    ) -> u64;  def jacpy_buffer_set(handle: u64, index: i64, value: i64);  def jacpy_unmarshal(
        handle: u64
    ) -> u64;
}

def ast_output_checked(handle: u64) -> u64 {
    if handle == 0 {
        raise runtime_failure();
    }
    return handle;
}

def ast_output_set_owned(target: u64, name: str, value: u64) {
    if jacpy_set_owned(target, name, value) < 0 {
        raise runtime_failure();
    }
}

def ast_output_append_owned(target: u64, value: u64) {
    if jacpy_list_append_owned(target, value) < 0 {
        raise runtime_failure();
    }
}

def ast_write_text(value: str) -> u64 {
    return ast_output_checked(
        jacpy_text(value, i64(len(value.encode("utf-8", "surrogatepass"))))
    );
}

def ast_write_optional_text(value: str | None) -> u64 {
    return ast_write_text(value)
        if value is not None
        else ast_output_checked(jacpy_none());
}

def ast_write_optional_int(value: int | None) -> u64 {
    return ast_output_checked(jacpy_int(i64(value)))
        if value is not None
        else ast_output_checked(jacpy_none());
}

def ast_write_optional_node(value: ast_node | None) -> u64 {
    return ast_write_node(value)
        if value is not None
        else ast_output_checked(jacpy_none());
}

def ast_write_constant(value: PyObj) -> u64 {
    packet = marshal_constant(value);
    if packet.error {
        raise ValueError(packet.error);
    }
    buffer = ast_output_checked(jacpy_buffer_new(i64(len(packet.data))));
    try {
        for index in range(len(packet.data)) {
            jacpy_buffer_set(buffer, i64(index), i64(packet.data[index]));
        }
        return ast_output_checked(jacpy_unmarshal(buffer));
    } finally {
        jacpy_release(buffer);
    }
}

def ast_write_Module(value: Module) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Module"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.type_ignores {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "type_ignores", items);
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Interactive(value: Interactive) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Interactive"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Expression(value: Expression) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Expression"));
    try {
        ast_output_set_owned(result, "body", ast_write_node(value.body));
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_FunctionType(value: FunctionType) -> u64 {
    result = ast_output_checked(jacpy_ast_new("FunctionType"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.argtypes {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "argtypes", items);
        ast_output_set_owned(result, "returns", ast_write_node(value.returns));
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_FunctionDef(value: FunctionDef) -> u64 {
    result = ast_output_checked(jacpy_ast_new("FunctionDef"));
    try {
        ast_output_set_owned(result, "name", ast_write_text(value.name));
        ast_output_set_owned(result, "args", ast_write_node(value.args));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.decorator_list {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "decorator_list", items);
        ast_output_set_owned(result, "returns", ast_write_optional_node(value.returns));
        ast_output_set_owned(
            result, "type_comment", ast_write_optional_text(value.type_comment)
        );
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.type_params {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "type_params", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_AsyncFunctionDef(value: AsyncFunctionDef) -> u64 {
    result = ast_output_checked(jacpy_ast_new("AsyncFunctionDef"));
    try {
        ast_output_set_owned(result, "name", ast_write_text(value.name));
        ast_output_set_owned(result, "args", ast_write_node(value.args));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.decorator_list {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "decorator_list", items);
        ast_output_set_owned(result, "returns", ast_write_optional_node(value.returns));
        ast_output_set_owned(
            result, "type_comment", ast_write_optional_text(value.type_comment)
        );
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.type_params {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "type_params", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_ClassDef(value: ClassDef) -> u64 {
    result = ast_output_checked(jacpy_ast_new("ClassDef"));
    try {
        ast_output_set_owned(result, "name", ast_write_text(value.name));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.bases {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "bases", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.keywords {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "keywords", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.decorator_list {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "decorator_list", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.type_params {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "type_params", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Return(value: Return) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Return"));
    try {
        ast_output_set_owned(result, "value", ast_write_optional_node(value.value));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Delete(value: Delete) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Delete"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.targets {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "targets", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Assign(value: Assign) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Assign"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.targets {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "targets", items);
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(
            result, "type_comment", ast_write_optional_text(value.type_comment)
        );
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_TypeAlias(value: TypeAlias) -> u64 {
    result = ast_output_checked(jacpy_ast_new("TypeAlias"));
    try {
        ast_output_set_owned(result, "name", ast_write_node(value.name));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.type_params {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "type_params", items);
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_AugAssign(value: AugAssign) -> u64 {
    result = ast_output_checked(jacpy_ast_new("AugAssign"));
    try {
        ast_output_set_owned(result, "target", ast_write_node(value.target));
        ast_output_set_owned(result, "op", ast_write_node(value.op));
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_AnnAssign(value: AnnAssign) -> u64 {
    result = ast_output_checked(jacpy_ast_new("AnnAssign"));
    try {
        ast_output_set_owned(result, "target", ast_write_node(value.target));
        ast_output_set_owned(result, "annotation", ast_write_node(value.annotation));
        ast_output_set_owned(result, "value", ast_write_optional_node(value.value));
        ast_output_set_owned(
            result, "simple", ast_output_checked(jacpy_int(i64(value.simple)))
        );
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_For(value: For) -> u64 {
    result = ast_output_checked(jacpy_ast_new("For"));
    try {
        ast_output_set_owned(result, "target", ast_write_node(value.target));
        ast_output_set_owned(result, "iter", ast_write_node(value.iter));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.orelse {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "orelse", items);
        ast_output_set_owned(
            result, "type_comment", ast_write_optional_text(value.type_comment)
        );
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_AsyncFor(value: AsyncFor) -> u64 {
    result = ast_output_checked(jacpy_ast_new("AsyncFor"));
    try {
        ast_output_set_owned(result, "target", ast_write_node(value.target));
        ast_output_set_owned(result, "iter", ast_write_node(value.iter));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.orelse {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "orelse", items);
        ast_output_set_owned(
            result, "type_comment", ast_write_optional_text(value.type_comment)
        );
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_While(value: While) -> u64 {
    result = ast_output_checked(jacpy_ast_new("While"));
    try {
        ast_output_set_owned(result, "test", ast_write_node(value.`test));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.orelse {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "orelse", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_If(value: If) -> u64 {
    result = ast_output_checked(jacpy_ast_new("If"));
    try {
        ast_output_set_owned(result, "test", ast_write_node(value.`test));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.orelse {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "orelse", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_With(value: With) -> u64 {
    result = ast_output_checked(jacpy_ast_new("With"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.items {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "items", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        ast_output_set_owned(
            result, "type_comment", ast_write_optional_text(value.type_comment)
        );
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_AsyncWith(value: AsyncWith) -> u64 {
    result = ast_output_checked(jacpy_ast_new("AsyncWith"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.items {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "items", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        ast_output_set_owned(
            result, "type_comment", ast_write_optional_text(value.type_comment)
        );
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Match(value: Match) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Match"));
    try {
        ast_output_set_owned(result, "subject", ast_write_node(value.subject));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.cases {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "cases", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Raise(value: Raise) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Raise"));
    try {
        ast_output_set_owned(result, "exc", ast_write_optional_node(value.exc));
        ast_output_set_owned(result, "cause", ast_write_optional_node(value.cause));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Try(value: Try) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Try"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.handlers {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "handlers", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.orelse {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "orelse", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.finalbody {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "finalbody", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_TryStar(value: TryStar) -> u64 {
    result = ast_output_checked(jacpy_ast_new("TryStar"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.handlers {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "handlers", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.orelse {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "orelse", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.finalbody {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "finalbody", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Assert(value: Assert) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Assert"));
    try {
        ast_output_set_owned(result, "test", ast_write_node(value.`test));
        ast_output_set_owned(result, "msg", ast_write_optional_node(value.msg));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Import(value: Import) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Import"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.names {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "names", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_ImportFrom(value: ImportFrom) -> u64 {
    result = ast_output_checked(jacpy_ast_new("ImportFrom"));
    try {
        ast_output_set_owned(result, "module", ast_write_optional_text(value.module));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.names {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "names", items);
        ast_output_set_owned(result, "level", ast_write_optional_int(value.level));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Global(value: Global) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Global"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.names {
                ast_output_append_owned(items, ast_write_text(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "names", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Nonlocal(value: Nonlocal) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Nonlocal"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.names {
                ast_output_append_owned(items, ast_write_text(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "names", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Expr(value: Expr) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Expr"));
    try {
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Pass(value: Pass) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Pass"));
    try {
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Break(value: Break) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Break"));
    try {
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Continue(value: Continue) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Continue"));
    try {
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_BoolOp(value: BoolOp) -> u64 {
    result = ast_output_checked(jacpy_ast_new("BoolOp"));
    try {
        ast_output_set_owned(result, "op", ast_write_node(value.op));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.values {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "values", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_NamedExpr(value: NamedExpr) -> u64 {
    result = ast_output_checked(jacpy_ast_new("NamedExpr"));
    try {
        ast_output_set_owned(result, "target", ast_write_node(value.target));
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_BinOp(value: BinOp) -> u64 {
    result = ast_output_checked(jacpy_ast_new("BinOp"));
    try {
        ast_output_set_owned(result, "left", ast_write_node(value.left));
        ast_output_set_owned(result, "op", ast_write_node(value.op));
        ast_output_set_owned(result, "right", ast_write_node(value.right));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_UnaryOp(value: UnaryOp) -> u64 {
    result = ast_output_checked(jacpy_ast_new("UnaryOp"));
    try {
        ast_output_set_owned(result, "op", ast_write_node(value.op));
        ast_output_set_owned(result, "operand", ast_write_node(value.operand));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Lambda(value: Lambda) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Lambda"));
    try {
        ast_output_set_owned(result, "args", ast_write_node(value.args));
        ast_output_set_owned(result, "body", ast_write_node(value.body));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_IfExp(value: IfExp) -> u64 {
    result = ast_output_checked(jacpy_ast_new("IfExp"));
    try {
        ast_output_set_owned(result, "test", ast_write_node(value.`test));
        ast_output_set_owned(result, "body", ast_write_node(value.body));
        ast_output_set_owned(result, "orelse", ast_write_node(value.orelse));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Dict(value: Dict) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Dict"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.keys {
                ast_output_append_owned(items, ast_write_optional_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "keys", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.values {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "values", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Set(value: Set) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Set"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.elts {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "elts", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_ListComp(value: ListComp) -> u64 {
    result = ast_output_checked(jacpy_ast_new("ListComp"));
    try {
        ast_output_set_owned(result, "elt", ast_write_node(value.elt));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.generators {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "generators", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_SetComp(value: SetComp) -> u64 {
    result = ast_output_checked(jacpy_ast_new("SetComp"));
    try {
        ast_output_set_owned(result, "elt", ast_write_node(value.elt));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.generators {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "generators", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_DictComp(value: DictComp) -> u64 {
    result = ast_output_checked(jacpy_ast_new("DictComp"));
    try {
        ast_output_set_owned(result, "key", ast_write_node(value.key));
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.generators {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "generators", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_GeneratorExp(value: GeneratorExp) -> u64 {
    result = ast_output_checked(jacpy_ast_new("GeneratorExp"));
    try {
        ast_output_set_owned(result, "elt", ast_write_node(value.elt));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.generators {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "generators", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Await(value: Await) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Await"));
    try {
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Yield(value: Yield) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Yield"));
    try {
        ast_output_set_owned(result, "value", ast_write_optional_node(value.value));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_YieldFrom(value: YieldFrom) -> u64 {
    result = ast_output_checked(jacpy_ast_new("YieldFrom"));
    try {
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Compare(value: Compare) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Compare"));
    try {
        ast_output_set_owned(result, "left", ast_write_node(value.left));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.ops {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "ops", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.comparators {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "comparators", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Call(value: Call) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Call"));
    try {
        ast_output_set_owned(result, "func", ast_write_node(value.func));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.args {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "args", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.keywords {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "keywords", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_FormattedValue(value: FormattedValue) -> u64 {
    result = ast_output_checked(jacpy_ast_new("FormattedValue"));
    try {
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(
            result, "conversion", ast_output_checked(jacpy_int(i64(value.conversion)))
        );
        ast_output_set_owned(
            result, "format_spec", ast_write_optional_node(value.format_spec)
        );
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Interpolation(value: Interpolation) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Interpolation"));
    try {
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(result, "str", ast_write_constant(value.str));
        ast_output_set_owned(
            result, "conversion", ast_output_checked(jacpy_int(i64(value.conversion)))
        );
        ast_output_set_owned(
            result, "format_spec", ast_write_optional_node(value.format_spec)
        );
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_JoinedStr(value: JoinedStr) -> u64 {
    result = ast_output_checked(jacpy_ast_new("JoinedStr"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.values {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "values", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_TemplateStr(value: TemplateStr) -> u64 {
    result = ast_output_checked(jacpy_ast_new("TemplateStr"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.values {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "values", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Constant(value: Constant) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Constant"));
    try {
        ast_output_set_owned(result, "value", ast_write_constant(value.value));
        ast_output_set_owned(result, "kind", ast_write_optional_text(value.kind));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Attribute(value: Attribute) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Attribute"));
    try {
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(result, "attr", ast_write_text(value.attr));
        ast_output_set_owned(result, "ctx", ast_write_node(value.ctx));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Subscript(value: Subscript) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Subscript"));
    try {
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(result, "slice", ast_write_node(value.slice));
        ast_output_set_owned(result, "ctx", ast_write_node(value.ctx));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Starred(value: Starred) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Starred"));
    try {
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(result, "ctx", ast_write_node(value.ctx));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Name(value: Name) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Name"));
    try {
        ast_output_set_owned(result, "id", ast_write_text(value.id));
        ast_output_set_owned(result, "ctx", ast_write_node(value.ctx));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_List(value: List) -> u64 {
    result = ast_output_checked(jacpy_ast_new("List"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.elts {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "elts", items);
        ast_output_set_owned(result, "ctx", ast_write_node(value.ctx));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Tuple(value: Tuple) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Tuple"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.elts {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "elts", items);
        ast_output_set_owned(result, "ctx", ast_write_node(value.ctx));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Slice(value: Slice) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Slice"));
    try {
        ast_output_set_owned(result, "lower", ast_write_optional_node(value.lower));
        ast_output_set_owned(result, "upper", ast_write_optional_node(value.upper));
        ast_output_set_owned(result, "step", ast_write_optional_node(value.step));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Load(value: Load) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Load"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Store(value: Store) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Store"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Del(value: Del) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Del"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_And(value: And) -> u64 {
    result = ast_output_checked(jacpy_ast_new("And"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Or(value: Or) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Or"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Add(value: Add) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Add"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Sub(value: Sub) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Sub"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Mult(value: Mult) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Mult"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatMult(value: MatMult) -> u64 {
    result = ast_output_checked(jacpy_ast_new("MatMult"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Div(value: Div) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Div"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Mod(value: Mod) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Mod"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Pow(value: Pow) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Pow"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_LShift(value: LShift) -> u64 {
    result = ast_output_checked(jacpy_ast_new("LShift"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_RShift(value: RShift) -> u64 {
    result = ast_output_checked(jacpy_ast_new("RShift"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_BitOr(value: BitOr) -> u64 {
    result = ast_output_checked(jacpy_ast_new("BitOr"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_BitXor(value: BitXor) -> u64 {
    result = ast_output_checked(jacpy_ast_new("BitXor"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_BitAnd(value: BitAnd) -> u64 {
    result = ast_output_checked(jacpy_ast_new("BitAnd"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_FloorDiv(value: FloorDiv) -> u64 {
    result = ast_output_checked(jacpy_ast_new("FloorDiv"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Invert(value: Invert) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Invert"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Not(value: Not) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Not"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_UAdd(value: UAdd) -> u64 {
    result = ast_output_checked(jacpy_ast_new("UAdd"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_USub(value: USub) -> u64 {
    result = ast_output_checked(jacpy_ast_new("USub"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Eq(value: Eq) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Eq"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_NotEq(value: NotEq) -> u64 {
    result = ast_output_checked(jacpy_ast_new("NotEq"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Lt(value: Lt) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Lt"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_LtE(value: LtE) -> u64 {
    result = ast_output_checked(jacpy_ast_new("LtE"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Gt(value: Gt) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Gt"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_GtE(value: GtE) -> u64 {
    result = ast_output_checked(jacpy_ast_new("GtE"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Is(value: Is) -> u64 {
    result = ast_output_checked(jacpy_ast_new("Is"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_IsNot(value: IsNot) -> u64 {
    result = ast_output_checked(jacpy_ast_new("IsNot"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_In(value: In) -> u64 {
    result = ast_output_checked(jacpy_ast_new("In"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_NotIn(value: NotIn) -> u64 {
    result = ast_output_checked(jacpy_ast_new("NotIn"));
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_comprehension(value: comprehension) -> u64 {
    result = ast_output_checked(jacpy_ast_new("comprehension"));
    try {
        ast_output_set_owned(result, "target", ast_write_node(value.target));
        ast_output_set_owned(result, "iter", ast_write_node(value.iter));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.ifs {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "ifs", items);
        ast_output_set_owned(
            result, "is_async", ast_output_checked(jacpy_int(i64(value.is_async)))
        );
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_ExceptHandler(value: ExceptHandler) -> u64 {
    result = ast_output_checked(jacpy_ast_new("ExceptHandler"));
    try {
        ast_output_set_owned(result, "type", ast_write_optional_node(value.type));
        ast_output_set_owned(result, "name", ast_write_optional_text(value.name));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_arguments(value: arguments) -> u64 {
    result = ast_output_checked(jacpy_ast_new("arguments"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.posonlyargs {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "posonlyargs", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.args {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "args", items);
        ast_output_set_owned(result, "vararg", ast_write_optional_node(value.vararg));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.kwonlyargs {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "kwonlyargs", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.kw_defaults {
                ast_output_append_owned(items, ast_write_optional_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "kw_defaults", items);
        ast_output_set_owned(result, "kwarg", ast_write_optional_node(value.kwarg));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.defaults {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "defaults", items);
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_arg(value: arg) -> u64 {
    result = ast_output_checked(jacpy_ast_new("arg"));
    try {
        ast_output_set_owned(result, "arg", ast_write_text(value.arg));
        ast_output_set_owned(
            result, "annotation", ast_write_optional_node(value.annotation)
        );
        ast_output_set_owned(
            result, "type_comment", ast_write_optional_text(value.type_comment)
        );
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_keyword(value: keyword) -> u64 {
    result = ast_output_checked(jacpy_ast_new("keyword"));
    try {
        ast_output_set_owned(result, "arg", ast_write_optional_text(value.arg));
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_alias(value: alias) -> u64 {
    result = ast_output_checked(jacpy_ast_new("alias"));
    try {
        ast_output_set_owned(result, "name", ast_write_text(value.name));
        ast_output_set_owned(result, "asname", ast_write_optional_text(value.asname));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_withitem(value: withitem) -> u64 {
    result = ast_output_checked(jacpy_ast_new("withitem"));
    try {
        ast_output_set_owned(
            result, "context_expr", ast_write_node(value.context_expr)
        );
        ast_output_set_owned(
            result, "optional_vars", ast_write_optional_node(value.optional_vars)
        );
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_match_case(value: match_case) -> u64 {
    result = ast_output_checked(jacpy_ast_new("match_case"));
    try {
        ast_output_set_owned(result, "pattern", ast_write_node(value.pattern));
        ast_output_set_owned(result, "guard", ast_write_optional_node(value.guard));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "body", items);
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchValue(value: MatchValue) -> u64 {
    result = ast_output_checked(jacpy_ast_new("MatchValue"));
    try {
        ast_output_set_owned(result, "value", ast_write_node(value.value));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchSingleton(value: MatchSingleton) -> u64 {
    result = ast_output_checked(jacpy_ast_new("MatchSingleton"));
    try {
        ast_output_set_owned(result, "value", ast_write_constant(value.value));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchSequence(value: MatchSequence) -> u64 {
    result = ast_output_checked(jacpy_ast_new("MatchSequence"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.patterns {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "patterns", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchMapping(value: MatchMapping) -> u64 {
    result = ast_output_checked(jacpy_ast_new("MatchMapping"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.keys {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "keys", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.patterns {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "patterns", items);
        ast_output_set_owned(result, "rest", ast_write_optional_text(value.rest));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchClass(value: MatchClass) -> u64 {
    result = ast_output_checked(jacpy_ast_new("MatchClass"));
    try {
        ast_output_set_owned(result, "cls", ast_write_node(value.cls));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.patterns {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "patterns", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.kwd_attrs {
                ast_output_append_owned(items, ast_write_text(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "kwd_attrs", items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.kwd_patterns {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "kwd_patterns", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchStar(value: MatchStar) -> u64 {
    result = ast_output_checked(jacpy_ast_new("MatchStar"));
    try {
        ast_output_set_owned(result, "name", ast_write_optional_text(value.name));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchAs(value: MatchAs) -> u64 {
    result = ast_output_checked(jacpy_ast_new("MatchAs"));
    try {
        ast_output_set_owned(result, "pattern", ast_write_optional_node(value.pattern));
        ast_output_set_owned(result, "name", ast_write_optional_text(value.name));
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchOr(value: MatchOr) -> u64 {
    result = ast_output_checked(jacpy_ast_new("MatchOr"));
    try {
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.patterns {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, "patterns", items);
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_TypeIgnore(value: TypeIgnore) -> u64 {
    result = ast_output_checked(jacpy_ast_new("TypeIgnore"));
    try {
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(result, "tag", ast_write_text(value.tag));
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_TypeVar(value: TypeVar) -> u64 {
    result = ast_output_checked(jacpy_ast_new("TypeVar"));
    try {
        ast_output_set_owned(result, "name", ast_write_text(value.name));
        ast_output_set_owned(result, "bound", ast_write_optional_node(value.bound));
        ast_output_set_owned(
            result, "default_value", ast_write_optional_node(value.default_value)
        );
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_ParamSpec(value: ParamSpec) -> u64 {
    result = ast_output_checked(jacpy_ast_new("ParamSpec"));
    try {
        ast_output_set_owned(result, "name", ast_write_text(value.name));
        ast_output_set_owned(
            result, "default_value", ast_write_optional_node(value.default_value)
        );
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_TypeVarTuple(value: TypeVarTuple) -> u64 {
    result = ast_output_checked(jacpy_ast_new("TypeVarTuple"));
    try {
        ast_output_set_owned(result, "name", ast_write_text(value.name));
        ast_output_set_owned(
            result, "default_value", ast_write_optional_node(value.default_value)
        );
        ast_output_set_owned(
            result, "lineno", ast_output_checked(jacpy_int(i64(value.lineno)))
        );
        ast_output_set_owned(
            result, "col_offset", ast_output_checked(jacpy_int(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, "end_lineno", ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result, "end_col_offset", ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def:pub ast_write_node(value: ast_node) -> u64 {
    if isinstance(value, Module) {
        return ast_write_Module(value);
    }
    if isinstance(value, Interactive) {
        return ast_write_Interactive(value);
    }
    if isinstance(value, Expression) {
        return ast_write_Expression(value);
    }
    if isinstance(value, FunctionType) {
        return ast_write_FunctionType(value);
    }
    if isinstance(value, FunctionDef) {
        return ast_write_FunctionDef(value);
    }
    if isinstance(value, AsyncFunctionDef) {
        return ast_write_AsyncFunctionDef(value);
    }
    if isinstance(value, ClassDef) {
        return ast_write_ClassDef(value);
    }
    if isinstance(value, Return) {
        return ast_write_Return(value);
    }
    if isinstance(value, Delete) {
        return ast_write_Delete(value);
    }
    if isinstance(value, Assign) {
        return ast_write_Assign(value);
    }
    if isinstance(value, TypeAlias) {
        return ast_write_TypeAlias(value);
    }
    if isinstance(value, AugAssign) {
        return ast_write_AugAssign(value);
    }
    if isinstance(value, AnnAssign) {
        return ast_write_AnnAssign(value);
    }
    if isinstance(value, For) {
        return ast_write_For(value);
    }
    if isinstance(value, AsyncFor) {
        return ast_write_AsyncFor(value);
    }
    if isinstance(value, While) {
        return ast_write_While(value);
    }
    if isinstance(value, If) {
        return ast_write_If(value);
    }
    if isinstance(value, With) {
        return ast_write_With(value);
    }
    if isinstance(value, AsyncWith) {
        return ast_write_AsyncWith(value);
    }
    if isinstance(value, Match) {
        return ast_write_Match(value);
    }
    if isinstance(value, Raise) {
        return ast_write_Raise(value);
    }
    if isinstance(value, Try) {
        return ast_write_Try(value);
    }
    if isinstance(value, TryStar) {
        return ast_write_TryStar(value);
    }
    if isinstance(value, Assert) {
        return ast_write_Assert(value);
    }
    if isinstance(value, Import) {
        return ast_write_Import(value);
    }
    if isinstance(value, ImportFrom) {
        return ast_write_ImportFrom(value);
    }
    if isinstance(value, Global) {
        return ast_write_Global(value);
    }
    if isinstance(value, Nonlocal) {
        return ast_write_Nonlocal(value);
    }
    if isinstance(value, Expr) {
        return ast_write_Expr(value);
    }
    if isinstance(value, Pass) {
        return ast_write_Pass(value);
    }
    if isinstance(value, Break) {
        return ast_write_Break(value);
    }
    if isinstance(value, Continue) {
        return ast_write_Continue(value);
    }
    if isinstance(value, BoolOp) {
        return ast_write_BoolOp(value);
    }
    if isinstance(value, NamedExpr) {
        return ast_write_NamedExpr(value);
    }
    if isinstance(value, BinOp) {
        return ast_write_BinOp(value);
    }
    if isinstance(value, UnaryOp) {
        return ast_write_UnaryOp(value);
    }
    if isinstance(value, Lambda) {
        return ast_write_Lambda(value);
    }
    if isinstance(value, IfExp) {
        return ast_write_IfExp(value);
    }
    if isinstance(value, Dict) {
        return ast_write_Dict(value);
    }
    if isinstance(value, Set) {
        return ast_write_Set(value);
    }
    if isinstance(value, ListComp) {
        return ast_write_ListComp(value);
    }
    if isinstance(value, SetComp) {
        return ast_write_SetComp(value);
    }
    if isinstance(value, DictComp) {
        return ast_write_DictComp(value);
    }
    if isinstance(value, GeneratorExp) {
        return ast_write_GeneratorExp(value);
    }
    if isinstance(value, Await) {
        return ast_write_Await(value);
    }
    if isinstance(value, Yield) {
        return ast_write_Yield(value);
    }
    if isinstance(value, YieldFrom) {
        return ast_write_YieldFrom(value);
    }
    if isinstance(value, Compare) {
        return ast_write_Compare(value);
    }
    if isinstance(value, Call) {
        return ast_write_Call(value);
    }
    if isinstance(value, FormattedValue) {
        return ast_write_FormattedValue(value);
    }
    if isinstance(value, Interpolation) {
        return ast_write_Interpolation(value);
    }
    if isinstance(value, JoinedStr) {
        return ast_write_JoinedStr(value);
    }
    if isinstance(value, TemplateStr) {
        return ast_write_TemplateStr(value);
    }
    if isinstance(value, Constant) {
        return ast_write_Constant(value);
    }
    if isinstance(value, Attribute) {
        return ast_write_Attribute(value);
    }
    if isinstance(value, Subscript) {
        return ast_write_Subscript(value);
    }
    if isinstance(value, Starred) {
        return ast_write_Starred(value);
    }
    if isinstance(value, Name) {
        return ast_write_Name(value);
    }
    if isinstance(value, List) {
        return ast_write_List(value);
    }
    if isinstance(value, Tuple) {
        return ast_write_Tuple(value);
    }
    if isinstance(value, Slice) {
        return ast_write_Slice(value);
    }
    if isinstance(value, Load) {
        return ast_write_Load(value);
    }
    if isinstance(value, Store) {
        return ast_write_Store(value);
    }
    if isinstance(value, Del) {
        return ast_write_Del(value);
    }
    if isinstance(value, And) {
        return ast_write_And(value);
    }
    if isinstance(value, Or) {
        return ast_write_Or(value);
    }
    if isinstance(value, Add) {
        return ast_write_Add(value);
    }
    if isinstance(value, Sub) {
        return ast_write_Sub(value);
    }
    if isinstance(value, Mult) {
        return ast_write_Mult(value);
    }
    if isinstance(value, MatMult) {
        return ast_write_MatMult(value);
    }
    if isinstance(value, Div) {
        return ast_write_Div(value);
    }
    if isinstance(value, Mod) {
        return ast_write_Mod(value);
    }
    if isinstance(value, Pow) {
        return ast_write_Pow(value);
    }
    if isinstance(value, LShift) {
        return ast_write_LShift(value);
    }
    if isinstance(value, RShift) {
        return ast_write_RShift(value);
    }
    if isinstance(value, BitOr) {
        return ast_write_BitOr(value);
    }
    if isinstance(value, BitXor) {
        return ast_write_BitXor(value);
    }
    if isinstance(value, BitAnd) {
        return ast_write_BitAnd(value);
    }
    if isinstance(value, FloorDiv) {
        return ast_write_FloorDiv(value);
    }
    if isinstance(value, Invert) {
        return ast_write_Invert(value);
    }
    if isinstance(value, Not) {
        return ast_write_Not(value);
    }
    if isinstance(value, UAdd) {
        return ast_write_UAdd(value);
    }
    if isinstance(value, USub) {
        return ast_write_USub(value);
    }
    if isinstance(value, Eq) {
        return ast_write_Eq(value);
    }
    if isinstance(value, NotEq) {
        return ast_write_NotEq(value);
    }
    if isinstance(value, Lt) {
        return ast_write_Lt(value);
    }
    if isinstance(value, LtE) {
        return ast_write_LtE(value);
    }
    if isinstance(value, Gt) {
        return ast_write_Gt(value);
    }
    if isinstance(value, GtE) {
        return ast_write_GtE(value);
    }
    if isinstance(value, Is) {
        return ast_write_Is(value);
    }
    if isinstance(value, IsNot) {
        return ast_write_IsNot(value);
    }
    if isinstance(value, In) {
        return ast_write_In(value);
    }
    if isinstance(value, NotIn) {
        return ast_write_NotIn(value);
    }
    if isinstance(value, comprehension) {
        return ast_write_comprehension(value);
    }
    if isinstance(value, ExceptHandler) {
        return ast_write_ExceptHandler(value);
    }
    if isinstance(value, arguments) {
        return ast_write_arguments(value);
    }
    if isinstance(value, arg) {
        return ast_write_arg(value);
    }
    if isinstance(value, keyword) {
        return ast_write_keyword(value);
    }
    if isinstance(value, alias) {
        return ast_write_alias(value);
    }
    if isinstance(value, withitem) {
        return ast_write_withitem(value);
    }
    if isinstance(value, match_case) {
        return ast_write_match_case(value);
    }
    if isinstance(value, MatchValue) {
        return ast_write_MatchValue(value);
    }
    if isinstance(value, MatchSingleton) {
        return ast_write_MatchSingleton(value);
    }
    if isinstance(value, MatchSequence) {
        return ast_write_MatchSequence(value);
    }
    if isinstance(value, MatchMapping) {
        return ast_write_MatchMapping(value);
    }
    if isinstance(value, MatchClass) {
        return ast_write_MatchClass(value);
    }
    if isinstance(value, MatchStar) {
        return ast_write_MatchStar(value);
    }
    if isinstance(value, MatchAs) {
        return ast_write_MatchAs(value);
    }
    if isinstance(value, MatchOr) {
        return ast_write_MatchOr(value);
    }
    if isinstance(value, TypeIgnore) {
        return ast_write_TypeIgnore(value);
    }
    if isinstance(value, TypeVar) {
        return ast_write_TypeVar(value);
    }
    if isinstance(value, ParamSpec) {
        return ast_write_ParamSpec(value);
    }
    if isinstance(value, TypeVarTuple) {
        return ast_write_TypeVarTuple(value);
    }
    raise ValueError("Unsupported AST node");
}
