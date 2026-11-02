"""Typed conversion from Jac-owned AST nodes to retained CPython AST values."""

def ast_output_checked(handle: ptr[PyObject]) -> ptr[PyObject] {
    if handle == 0 {
        raise boundary_failure();
    }
    return handle;
}

def ast_output_node(kind: ast_kind) -> ptr[PyObject] {
    return ast_output_checked(jacpy_ast_new(i64(kind.value)));
}

def ast_output_set_owned(
    target: ptr[PyObject], field: ast_field, value: ptr[PyObject]
) {
    if jacpy_set_owned(target, i64(field.value), value) < 0 {
        raise boundary_failure();
    }
}

def ast_output_append_owned(target: ptr[PyObject], value: ptr[PyObject]) {
    if jacpy_list_append_owned(target, value) < 0 {
        raise boundary_failure();
    }
}

def ast_write_text(value: str) -> ptr[PyObject] {
    return ast_output_checked(
        jacpy_text(value, i64(len(value.encode("utf-8", "surrogatepass"))))
    );
}

def ast_write_optional_text(value: str | None) -> ptr[PyObject] {
    return ast_write_text(value)
        if value is not None
        else ast_output_checked(Py_NewRef(Py_None));
}

def ast_write_optional_int(value: int | None) -> ptr[PyObject] {
    return ast_output_checked(PyLong_FromLongLong(i64(value)))
        if value is not None
        else ast_output_checked(Py_NewRef(Py_None));
}

def ast_write_optional_node(value: ast_node | None) -> ptr[PyObject] {
    return ast_write_node(value)
        if value is not None
        else ast_output_checked(Py_NewRef(Py_None));
}

def ast_write_constant(value: PyObj) -> ptr[PyObject] {
    return constant_object(value);
}

def ast_write_Module(value: Module) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Module);
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
        ast_output_set_owned(result, ast_field.BODY, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.type_ignores {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.TYPE_IGNORES, items);
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Interactive(value: Interactive) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Interactive);
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
        ast_output_set_owned(result, ast_field.BODY, items);
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Expression(value: Expression) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Expression);
    try {
        ast_output_set_owned(result, ast_field.BODY, ast_write_node(value.body));
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_FunctionType(value: FunctionType) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.FunctionType);
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
        ast_output_set_owned(result, ast_field.ARGTYPES, items);
        ast_output_set_owned(result, ast_field.RETURNS, ast_write_node(value.returns));
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_FunctionDef(value: FunctionDef) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.FunctionDef);
    try {
        ast_output_set_owned(result, ast_field.NAME, ast_write_text(value.name));
        ast_output_set_owned(result, ast_field.ARGS, ast_write_node(value.args));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.BODY, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.decorator_list {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.DECORATOR_LIST, items);
        ast_output_set_owned(
            result, ast_field.RETURNS, ast_write_optional_node(value.returns)
        );
        ast_output_set_owned(
            result, ast_field.TYPE_COMMENT, ast_write_optional_text(value.type_comment)
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
        ast_output_set_owned(result, ast_field.TYPE_PARAMS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_AsyncFunctionDef(value: AsyncFunctionDef) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.AsyncFunctionDef);
    try {
        ast_output_set_owned(result, ast_field.NAME, ast_write_text(value.name));
        ast_output_set_owned(result, ast_field.ARGS, ast_write_node(value.args));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.BODY, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.decorator_list {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.DECORATOR_LIST, items);
        ast_output_set_owned(
            result, ast_field.RETURNS, ast_write_optional_node(value.returns)
        );
        ast_output_set_owned(
            result, ast_field.TYPE_COMMENT, ast_write_optional_text(value.type_comment)
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
        ast_output_set_owned(result, ast_field.TYPE_PARAMS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_ClassDef(value: ClassDef) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.ClassDef);
    try {
        ast_output_set_owned(result, ast_field.NAME, ast_write_text(value.name));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.bases {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.BASES, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.keywords {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.KEYWORDS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.BODY, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.decorator_list {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.DECORATOR_LIST, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.type_params {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.TYPE_PARAMS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Return(value: Return) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Return);
    try {
        ast_output_set_owned(
            result, ast_field.VALUE, ast_write_optional_node(value.value)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Delete(value: Delete) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Delete);
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
        ast_output_set_owned(result, ast_field.TARGETS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Assign(value: Assign) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Assign);
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
        ast_output_set_owned(result, ast_field.TARGETS, items);
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(
            result, ast_field.TYPE_COMMENT, ast_write_optional_text(value.type_comment)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_TypeAlias(value: TypeAlias) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.TypeAlias);
    try {
        ast_output_set_owned(result, ast_field.NAME, ast_write_node(value.name));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.type_params {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.TYPE_PARAMS, items);
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_AugAssign(value: AugAssign) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.AugAssign);
    try {
        ast_output_set_owned(result, ast_field.TARGET, ast_write_node(value.target));
        ast_output_set_owned(result, ast_field.OP, ast_write_node(value.op));
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_AnnAssign(value: AnnAssign) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.AnnAssign);
    try {
        ast_output_set_owned(result, ast_field.TARGET, ast_write_node(value.target));
        ast_output_set_owned(
            result, ast_field.ANNOTATION, ast_write_node(value.annotation)
        );
        ast_output_set_owned(
            result, ast_field.VALUE, ast_write_optional_node(value.value)
        );
        ast_output_set_owned(
            result,
            ast_field.SIMPLE,
            ast_output_checked(PyLong_FromLongLong(i64(value.simple)))
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_For(value: For) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.For);
    try {
        ast_output_set_owned(result, ast_field.TARGET, ast_write_node(value.target));
        ast_output_set_owned(result, ast_field.ITER, ast_write_node(value.iter));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.BODY, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.orelse {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.ORELSE, items);
        ast_output_set_owned(
            result, ast_field.TYPE_COMMENT, ast_write_optional_text(value.type_comment)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_AsyncFor(value: AsyncFor) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.AsyncFor);
    try {
        ast_output_set_owned(result, ast_field.TARGET, ast_write_node(value.target));
        ast_output_set_owned(result, ast_field.ITER, ast_write_node(value.iter));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.BODY, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.orelse {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.ORELSE, items);
        ast_output_set_owned(
            result, ast_field.TYPE_COMMENT, ast_write_optional_text(value.type_comment)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_While(value: While) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.While);
    try {
        ast_output_set_owned(result, ast_field.TEST, ast_write_node(value.`test));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.BODY, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.orelse {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.ORELSE, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_If(value: If) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.If);
    try {
        ast_output_set_owned(result, ast_field.TEST, ast_write_node(value.`test));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.BODY, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.orelse {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.ORELSE, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_With(value: With) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.With);
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
        ast_output_set_owned(result, ast_field.ITEMS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.BODY, items);
        ast_output_set_owned(
            result, ast_field.TYPE_COMMENT, ast_write_optional_text(value.type_comment)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_AsyncWith(value: AsyncWith) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.AsyncWith);
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
        ast_output_set_owned(result, ast_field.ITEMS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.BODY, items);
        ast_output_set_owned(
            result, ast_field.TYPE_COMMENT, ast_write_optional_text(value.type_comment)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Match(value: Match) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Match);
    try {
        ast_output_set_owned(result, ast_field.SUBJECT, ast_write_node(value.subject));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.cases {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.CASES, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Raise(value: Raise) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Raise);
    try {
        ast_output_set_owned(result, ast_field.EXC, ast_write_optional_node(value.exc));
        ast_output_set_owned(
            result, ast_field.CAUSE, ast_write_optional_node(value.cause)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Try(value: Try) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Try);
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
        ast_output_set_owned(result, ast_field.BODY, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.handlers {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.HANDLERS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.orelse {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.ORELSE, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.finalbody {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.FINALBODY, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_TryStar(value: TryStar) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.TryStar);
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
        ast_output_set_owned(result, ast_field.BODY, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.handlers {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.HANDLERS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.orelse {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.ORELSE, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.finalbody {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.FINALBODY, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Assert(value: Assert) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Assert);
    try {
        ast_output_set_owned(result, ast_field.TEST, ast_write_node(value.`test));
        ast_output_set_owned(result, ast_field.MSG, ast_write_optional_node(value.msg));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Import(value: Import) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Import);
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
        ast_output_set_owned(result, ast_field.NAMES, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_ImportFrom(value: ImportFrom) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.ImportFrom);
    try {
        ast_output_set_owned(
            result, ast_field.MODULE, ast_write_optional_text(value.module)
        );
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.names {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.NAMES, items);
        ast_output_set_owned(
            result, ast_field.LEVEL, ast_write_optional_int(value.level)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Global(value: Global) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Global);
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
        ast_output_set_owned(result, ast_field.NAMES, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Nonlocal(value: Nonlocal) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Nonlocal);
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
        ast_output_set_owned(result, ast_field.NAMES, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Expr(value: Expr) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Expr);
    try {
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Pass(value: Pass) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Pass);
    try {
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Break(value: Break) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Break);
    try {
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Continue(value: Continue) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Continue);
    try {
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_BoolOp(value: BoolOp) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.BoolOp);
    try {
        ast_output_set_owned(result, ast_field.OP, ast_write_node(value.op));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.values {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.VALUES, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_NamedExpr(value: NamedExpr) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.NamedExpr);
    try {
        ast_output_set_owned(result, ast_field.TARGET, ast_write_node(value.target));
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_BinOp(value: BinOp) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.BinOp);
    try {
        ast_output_set_owned(result, ast_field.LEFT, ast_write_node(value.left));
        ast_output_set_owned(result, ast_field.OP, ast_write_node(value.op));
        ast_output_set_owned(result, ast_field.RIGHT, ast_write_node(value.right));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_UnaryOp(value: UnaryOp) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.UnaryOp);
    try {
        ast_output_set_owned(result, ast_field.OP, ast_write_node(value.op));
        ast_output_set_owned(result, ast_field.OPERAND, ast_write_node(value.operand));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Lambda(value: Lambda) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Lambda);
    try {
        ast_output_set_owned(result, ast_field.ARGS, ast_write_node(value.args));
        ast_output_set_owned(result, ast_field.BODY, ast_write_node(value.body));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_IfExp(value: IfExp) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.IfExp);
    try {
        ast_output_set_owned(result, ast_field.TEST, ast_write_node(value.`test));
        ast_output_set_owned(result, ast_field.BODY, ast_write_node(value.body));
        ast_output_set_owned(result, ast_field.ORELSE, ast_write_node(value.orelse));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Dict(value: Dict) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Dict);
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
        ast_output_set_owned(result, ast_field.KEYS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.values {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.VALUES, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Set(value: Set) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Set);
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
        ast_output_set_owned(result, ast_field.ELTS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_ListComp(value: ListComp) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.ListComp);
    try {
        ast_output_set_owned(result, ast_field.ELT, ast_write_node(value.elt));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.generators {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.GENERATORS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_SetComp(value: SetComp) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.SetComp);
    try {
        ast_output_set_owned(result, ast_field.ELT, ast_write_node(value.elt));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.generators {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.GENERATORS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_DictComp(value: DictComp) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.DictComp);
    try {
        ast_output_set_owned(result, ast_field.KEY, ast_write_node(value.key));
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.generators {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.GENERATORS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_GeneratorExp(value: GeneratorExp) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.GeneratorExp);
    try {
        ast_output_set_owned(result, ast_field.ELT, ast_write_node(value.elt));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.generators {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.GENERATORS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Await(value: Await) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Await);
    try {
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Yield(value: Yield) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Yield);
    try {
        ast_output_set_owned(
            result, ast_field.VALUE, ast_write_optional_node(value.value)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_YieldFrom(value: YieldFrom) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.YieldFrom);
    try {
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Compare(value: Compare) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Compare);
    try {
        ast_output_set_owned(result, ast_field.LEFT, ast_write_node(value.left));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.ops {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.OPS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.comparators {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.COMPARATORS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Call(value: Call) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Call);
    try {
        ast_output_set_owned(result, ast_field.FUNC, ast_write_node(value.func));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.args {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.ARGS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.keywords {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.KEYWORDS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_FormattedValue(value: FormattedValue) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.FormattedValue);
    try {
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(
            result,
            ast_field.CONVERSION,
            ast_output_checked(PyLong_FromLongLong(i64(value.conversion)))
        );
        ast_output_set_owned(
            result, ast_field.FORMAT_SPEC, ast_write_optional_node(value.format_spec)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Interpolation(value: Interpolation) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Interpolation);
    try {
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(result, ast_field.STR, ast_write_constant(value.str));
        ast_output_set_owned(
            result,
            ast_field.CONVERSION,
            ast_output_checked(PyLong_FromLongLong(i64(value.conversion)))
        );
        ast_output_set_owned(
            result, ast_field.FORMAT_SPEC, ast_write_optional_node(value.format_spec)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_JoinedStr(value: JoinedStr) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.JoinedStr);
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
        ast_output_set_owned(result, ast_field.VALUES, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_TemplateStr(value: TemplateStr) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.TemplateStr);
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
        ast_output_set_owned(result, ast_field.VALUES, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Constant(value: Constant) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Constant);
    try {
        ast_output_set_owned(result, ast_field.VALUE, ast_write_constant(value.value));
        ast_output_set_owned(
            result, ast_field.KIND, ast_write_optional_text(value.kind)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Attribute(value: Attribute) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Attribute);
    try {
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(result, ast_field.ATTR, ast_write_text(value.attr));
        ast_output_set_owned(result, ast_field.CTX, ast_write_node(value.ctx));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Subscript(value: Subscript) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Subscript);
    try {
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(result, ast_field.SLICE, ast_write_node(value.slice));
        ast_output_set_owned(result, ast_field.CTX, ast_write_node(value.ctx));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Starred(value: Starred) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Starred);
    try {
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(result, ast_field.CTX, ast_write_node(value.ctx));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Name(value: Name) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Name);
    try {
        ast_output_set_owned(result, ast_field.ID, ast_write_text(value.id));
        ast_output_set_owned(result, ast_field.CTX, ast_write_node(value.ctx));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_List(value: List) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.List);
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
        ast_output_set_owned(result, ast_field.ELTS, items);
        ast_output_set_owned(result, ast_field.CTX, ast_write_node(value.ctx));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Tuple(value: Tuple) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Tuple);
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
        ast_output_set_owned(result, ast_field.ELTS, items);
        ast_output_set_owned(result, ast_field.CTX, ast_write_node(value.ctx));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Slice(value: Slice) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Slice);
    try {
        ast_output_set_owned(
            result, ast_field.LOWER, ast_write_optional_node(value.lower)
        );
        ast_output_set_owned(
            result, ast_field.UPPER, ast_write_optional_node(value.upper)
        );
        ast_output_set_owned(
            result, ast_field.STEP, ast_write_optional_node(value.step)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Load(value: Load) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Load);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Store(value: Store) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Store);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Del(value: Del) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Del);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_And(value: And) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.And);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Or(value: Or) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Or);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Add(value: Add) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Add);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Sub(value: Sub) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Sub);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Mult(value: Mult) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Mult);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatMult(value: MatMult) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.MatMult);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Div(value: Div) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Div);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Mod(value: Mod) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Mod);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Pow(value: Pow) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Pow);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_LShift(value: LShift) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.LShift);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_RShift(value: RShift) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.RShift);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_BitOr(value: BitOr) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.BitOr);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_BitXor(value: BitXor) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.BitXor);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_BitAnd(value: BitAnd) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.BitAnd);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_FloorDiv(value: FloorDiv) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.FloorDiv);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Invert(value: Invert) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Invert);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Not(value: Not) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Not);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_UAdd(value: UAdd) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.UAdd);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_USub(value: USub) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.USub);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Eq(value: Eq) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Eq);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_NotEq(value: NotEq) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.NotEq);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Lt(value: Lt) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Lt);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_LtE(value: LtE) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.LtE);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Gt(value: Gt) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Gt);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_GtE(value: GtE) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.GtE);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_Is(value: Is) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.Is);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_IsNot(value: IsNot) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.IsNot);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_In(value: In) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.In);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_NotIn(value: NotIn) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.NotIn);
    try {
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_comprehension(value: comprehension) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.comprehension);
    try {
        ast_output_set_owned(result, ast_field.TARGET, ast_write_node(value.target));
        ast_output_set_owned(result, ast_field.ITER, ast_write_node(value.iter));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.ifs {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.IFS, items);
        ast_output_set_owned(
            result,
            ast_field.IS_ASYNC,
            ast_output_checked(PyLong_FromLongLong(i64(value.is_async)))
        );
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_ExceptHandler(value: ExceptHandler) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.ExceptHandler);
    try {
        ast_output_set_owned(
            result, ast_field.TYPE, ast_write_optional_node(value.type)
        );
        ast_output_set_owned(
            result, ast_field.NAME, ast_write_optional_text(value.name)
        );
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.BODY, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_arguments(value: arguments) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.arguments);
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
        ast_output_set_owned(result, ast_field.POSONLYARGS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.args {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.ARGS, items);
        ast_output_set_owned(
            result, ast_field.VARARG, ast_write_optional_node(value.vararg)
        );
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.kwonlyargs {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.KWONLYARGS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.kw_defaults {
                ast_output_append_owned(items, ast_write_optional_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.KW_DEFAULTS, items);
        ast_output_set_owned(
            result, ast_field.KWARG, ast_write_optional_node(value.kwarg)
        );
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.defaults {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.DEFAULTS, items);
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_arg(value: arg) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.arg);
    try {
        ast_output_set_owned(result, ast_field.ARG, ast_write_text(value.arg));
        ast_output_set_owned(
            result, ast_field.ANNOTATION, ast_write_optional_node(value.annotation)
        );
        ast_output_set_owned(
            result, ast_field.TYPE_COMMENT, ast_write_optional_text(value.type_comment)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_keyword(value: keyword) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.keyword);
    try {
        ast_output_set_owned(result, ast_field.ARG, ast_write_optional_text(value.arg));
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_alias(value: alias) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.alias);
    try {
        ast_output_set_owned(result, ast_field.NAME, ast_write_text(value.name));
        ast_output_set_owned(
            result, ast_field.ASNAME, ast_write_optional_text(value.asname)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_withitem(value: withitem) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.withitem);
    try {
        ast_output_set_owned(
            result, ast_field.CONTEXT_EXPR, ast_write_node(value.context_expr)
        );
        ast_output_set_owned(
            result,
            ast_field.OPTIONAL_VARS,
            ast_write_optional_node(value.optional_vars)
        );
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_match_case(value: match_case) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.match_case);
    try {
        ast_output_set_owned(result, ast_field.PATTERN, ast_write_node(value.pattern));
        ast_output_set_owned(
            result, ast_field.GUARD, ast_write_optional_node(value.guard)
        );
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.body {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.BODY, items);
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchValue(value: MatchValue) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.MatchValue);
    try {
        ast_output_set_owned(result, ast_field.VALUE, ast_write_node(value.value));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchSingleton(value: MatchSingleton) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.MatchSingleton);
    try {
        ast_output_set_owned(result, ast_field.VALUE, ast_write_constant(value.value));
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchSequence(value: MatchSequence) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.MatchSequence);
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
        ast_output_set_owned(result, ast_field.PATTERNS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchMapping(value: MatchMapping) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.MatchMapping);
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
        ast_output_set_owned(result, ast_field.KEYS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.patterns {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.PATTERNS, items);
        ast_output_set_owned(
            result, ast_field.REST, ast_write_optional_text(value.rest)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchClass(value: MatchClass) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.MatchClass);
    try {
        ast_output_set_owned(result, ast_field.CLS, ast_write_node(value.cls));
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.patterns {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.PATTERNS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.kwd_attrs {
                ast_output_append_owned(items, ast_write_text(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.KWD_ATTRS, items);
        items = ast_output_checked(jacpy_list_new());
        try {
            for item in value.kwd_patterns {
                ast_output_append_owned(items, ast_write_node(item));
            }
        } except Exception {
            jacpy_release(items);
            raise;
        }
        ast_output_set_owned(result, ast_field.KWD_PATTERNS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchStar(value: MatchStar) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.MatchStar);
    try {
        ast_output_set_owned(
            result, ast_field.NAME, ast_write_optional_text(value.name)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchAs(value: MatchAs) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.MatchAs);
    try {
        ast_output_set_owned(
            result, ast_field.PATTERN, ast_write_optional_node(value.pattern)
        );
        ast_output_set_owned(
            result, ast_field.NAME, ast_write_optional_text(value.name)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_MatchOr(value: MatchOr) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.MatchOr);
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
        ast_output_set_owned(result, ast_field.PATTERNS, items);
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_TypeIgnore(value: TypeIgnore) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.TypeIgnore);
    try {
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(result, ast_field.TAG, ast_write_text(value.tag));
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_TypeVar(value: TypeVar) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.TypeVar);
    try {
        ast_output_set_owned(result, ast_field.NAME, ast_write_text(value.name));
        ast_output_set_owned(
            result, ast_field.BOUND, ast_write_optional_node(value.bound)
        );
        ast_output_set_owned(
            result,
            ast_field.DEFAULT_VALUE,
            ast_write_optional_node(value.default_value)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_ParamSpec(value: ParamSpec) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.ParamSpec);
    try {
        ast_output_set_owned(result, ast_field.NAME, ast_write_text(value.name));
        ast_output_set_owned(
            result,
            ast_field.DEFAULT_VALUE,
            ast_write_optional_node(value.default_value)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def ast_write_TypeVarTuple(value: TypeVarTuple) -> ptr[PyObject] {
    result = ast_output_node(ast_kind.TypeVarTuple);
    try {
        ast_output_set_owned(result, ast_field.NAME, ast_write_text(value.name));
        ast_output_set_owned(
            result,
            ast_field.DEFAULT_VALUE,
            ast_write_optional_node(value.default_value)
        );
        ast_output_set_owned(
            result,
            ast_field.LINENO,
            ast_output_checked(PyLong_FromLongLong(i64(value.lineno)))
        );
        ast_output_set_owned(
            result,
            ast_field.COL_OFFSET,
            ast_output_checked(PyLong_FromLongLong(i64(value.col_offset)))
        );
        if value.end_lineno is not None {
            ast_output_set_owned(
                result, ast_field.END_LINENO, ast_write_optional_int(value.end_lineno)
            );
        }
        if value.end_col_offset is not None {
            ast_output_set_owned(
                result,
                ast_field.END_COL_OFFSET,
                ast_write_optional_int(value.end_col_offset)
            );
        }
        return result;
    } except Exception {
        jacpy_release(result);
        raise;
    }
}

def:pub ast_write_node(value: ast_node) -> ptr[PyObject] {
    kind = value.node_kind();
    if kind == ast_kind.Module and isinstance(value, Module) {
        return ast_write_Module(value);
    }
    if kind == ast_kind.Interactive and isinstance(value, Interactive) {
        return ast_write_Interactive(value);
    }
    if kind == ast_kind.Expression and isinstance(value, Expression) {
        return ast_write_Expression(value);
    }
    if kind == ast_kind.FunctionType and isinstance(value, FunctionType) {
        return ast_write_FunctionType(value);
    }
    if kind == ast_kind.FunctionDef and isinstance(value, FunctionDef) {
        return ast_write_FunctionDef(value);
    }
    if kind == ast_kind.AsyncFunctionDef and isinstance(value, AsyncFunctionDef) {
        return ast_write_AsyncFunctionDef(value);
    }
    if kind == ast_kind.ClassDef and isinstance(value, ClassDef) {
        return ast_write_ClassDef(value);
    }
    if kind == ast_kind.Return and isinstance(value, Return) {
        return ast_write_Return(value);
    }
    if kind == ast_kind.Delete and isinstance(value, Delete) {
        return ast_write_Delete(value);
    }
    if kind == ast_kind.Assign and isinstance(value, Assign) {
        return ast_write_Assign(value);
    }
    if kind == ast_kind.TypeAlias and isinstance(value, TypeAlias) {
        return ast_write_TypeAlias(value);
    }
    if kind == ast_kind.AugAssign and isinstance(value, AugAssign) {
        return ast_write_AugAssign(value);
    }
    if kind == ast_kind.AnnAssign and isinstance(value, AnnAssign) {
        return ast_write_AnnAssign(value);
    }
    if kind == ast_kind.For and isinstance(value, For) {
        return ast_write_For(value);
    }
    if kind == ast_kind.AsyncFor and isinstance(value, AsyncFor) {
        return ast_write_AsyncFor(value);
    }
    if kind == ast_kind.While and isinstance(value, While) {
        return ast_write_While(value);
    }
    if kind == ast_kind.If and isinstance(value, If) {
        return ast_write_If(value);
    }
    if kind == ast_kind.With and isinstance(value, With) {
        return ast_write_With(value);
    }
    if kind == ast_kind.AsyncWith and isinstance(value, AsyncWith) {
        return ast_write_AsyncWith(value);
    }
    if kind == ast_kind.Match and isinstance(value, Match) {
        return ast_write_Match(value);
    }
    if kind == ast_kind.Raise and isinstance(value, Raise) {
        return ast_write_Raise(value);
    }
    if kind == ast_kind.Try and isinstance(value, Try) {
        return ast_write_Try(value);
    }
    if kind == ast_kind.TryStar and isinstance(value, TryStar) {
        return ast_write_TryStar(value);
    }
    if kind == ast_kind.Assert and isinstance(value, Assert) {
        return ast_write_Assert(value);
    }
    if kind == ast_kind.Import and isinstance(value, Import) {
        return ast_write_Import(value);
    }
    if kind == ast_kind.ImportFrom and isinstance(value, ImportFrom) {
        return ast_write_ImportFrom(value);
    }
    if kind == ast_kind.Global and isinstance(value, Global) {
        return ast_write_Global(value);
    }
    if kind == ast_kind.Nonlocal and isinstance(value, Nonlocal) {
        return ast_write_Nonlocal(value);
    }
    if kind == ast_kind.Expr and isinstance(value, Expr) {
        return ast_write_Expr(value);
    }
    if kind == ast_kind.Pass and isinstance(value, Pass) {
        return ast_write_Pass(value);
    }
    if kind == ast_kind.Break and isinstance(value, Break) {
        return ast_write_Break(value);
    }
    if kind == ast_kind.Continue and isinstance(value, Continue) {
        return ast_write_Continue(value);
    }
    if kind == ast_kind.BoolOp and isinstance(value, BoolOp) {
        return ast_write_BoolOp(value);
    }
    if kind == ast_kind.NamedExpr and isinstance(value, NamedExpr) {
        return ast_write_NamedExpr(value);
    }
    if kind == ast_kind.BinOp and isinstance(value, BinOp) {
        return ast_write_BinOp(value);
    }
    if kind == ast_kind.UnaryOp and isinstance(value, UnaryOp) {
        return ast_write_UnaryOp(value);
    }
    if kind == ast_kind.Lambda and isinstance(value, Lambda) {
        return ast_write_Lambda(value);
    }
    if kind == ast_kind.IfExp and isinstance(value, IfExp) {
        return ast_write_IfExp(value);
    }
    if kind == ast_kind.Dict and isinstance(value, Dict) {
        return ast_write_Dict(value);
    }
    if kind == ast_kind.Set and isinstance(value, Set) {
        return ast_write_Set(value);
    }
    if kind == ast_kind.ListComp and isinstance(value, ListComp) {
        return ast_write_ListComp(value);
    }
    if kind == ast_kind.SetComp and isinstance(value, SetComp) {
        return ast_write_SetComp(value);
    }
    if kind == ast_kind.DictComp and isinstance(value, DictComp) {
        return ast_write_DictComp(value);
    }
    if kind == ast_kind.GeneratorExp and isinstance(value, GeneratorExp) {
        return ast_write_GeneratorExp(value);
    }
    if kind == ast_kind.Await and isinstance(value, Await) {
        return ast_write_Await(value);
    }
    if kind == ast_kind.Yield and isinstance(value, Yield) {
        return ast_write_Yield(value);
    }
    if kind == ast_kind.YieldFrom and isinstance(value, YieldFrom) {
        return ast_write_YieldFrom(value);
    }
    if kind == ast_kind.Compare and isinstance(value, Compare) {
        return ast_write_Compare(value);
    }
    if kind == ast_kind.Call and isinstance(value, Call) {
        return ast_write_Call(value);
    }
    if kind == ast_kind.FormattedValue and isinstance(value, FormattedValue) {
        return ast_write_FormattedValue(value);
    }
    if kind == ast_kind.Interpolation and isinstance(value, Interpolation) {
        return ast_write_Interpolation(value);
    }
    if kind == ast_kind.JoinedStr and isinstance(value, JoinedStr) {
        return ast_write_JoinedStr(value);
    }
    if kind == ast_kind.TemplateStr and isinstance(value, TemplateStr) {
        return ast_write_TemplateStr(value);
    }
    if kind == ast_kind.Constant and isinstance(value, Constant) {
        return ast_write_Constant(value);
    }
    if kind == ast_kind.Attribute and isinstance(value, Attribute) {
        return ast_write_Attribute(value);
    }
    if kind == ast_kind.Subscript and isinstance(value, Subscript) {
        return ast_write_Subscript(value);
    }
    if kind == ast_kind.Starred and isinstance(value, Starred) {
        return ast_write_Starred(value);
    }
    if kind == ast_kind.Name and isinstance(value, Name) {
        return ast_write_Name(value);
    }
    if kind == ast_kind.List and isinstance(value, List) {
        return ast_write_List(value);
    }
    if kind == ast_kind.Tuple and isinstance(value, Tuple) {
        return ast_write_Tuple(value);
    }
    if kind == ast_kind.Slice and isinstance(value, Slice) {
        return ast_write_Slice(value);
    }
    if kind == ast_kind.Load and isinstance(value, Load) {
        return ast_write_Load(value);
    }
    if kind == ast_kind.Store and isinstance(value, Store) {
        return ast_write_Store(value);
    }
    if kind == ast_kind.Del and isinstance(value, Del) {
        return ast_write_Del(value);
    }
    if kind == ast_kind.And and isinstance(value, And) {
        return ast_write_And(value);
    }
    if kind == ast_kind.Or and isinstance(value, Or) {
        return ast_write_Or(value);
    }
    if kind == ast_kind.Add and isinstance(value, Add) {
        return ast_write_Add(value);
    }
    if kind == ast_kind.Sub and isinstance(value, Sub) {
        return ast_write_Sub(value);
    }
    if kind == ast_kind.Mult and isinstance(value, Mult) {
        return ast_write_Mult(value);
    }
    if kind == ast_kind.MatMult and isinstance(value, MatMult) {
        return ast_write_MatMult(value);
    }
    if kind == ast_kind.Div and isinstance(value, Div) {
        return ast_write_Div(value);
    }
    if kind == ast_kind.Mod and isinstance(value, Mod) {
        return ast_write_Mod(value);
    }
    if kind == ast_kind.Pow and isinstance(value, Pow) {
        return ast_write_Pow(value);
    }
    if kind == ast_kind.LShift and isinstance(value, LShift) {
        return ast_write_LShift(value);
    }
    if kind == ast_kind.RShift and isinstance(value, RShift) {
        return ast_write_RShift(value);
    }
    if kind == ast_kind.BitOr and isinstance(value, BitOr) {
        return ast_write_BitOr(value);
    }
    if kind == ast_kind.BitXor and isinstance(value, BitXor) {
        return ast_write_BitXor(value);
    }
    if kind == ast_kind.BitAnd and isinstance(value, BitAnd) {
        return ast_write_BitAnd(value);
    }
    if kind == ast_kind.FloorDiv and isinstance(value, FloorDiv) {
        return ast_write_FloorDiv(value);
    }
    if kind == ast_kind.Invert and isinstance(value, Invert) {
        return ast_write_Invert(value);
    }
    if kind == ast_kind.Not and isinstance(value, Not) {
        return ast_write_Not(value);
    }
    if kind == ast_kind.UAdd and isinstance(value, UAdd) {
        return ast_write_UAdd(value);
    }
    if kind == ast_kind.USub and isinstance(value, USub) {
        return ast_write_USub(value);
    }
    if kind == ast_kind.Eq and isinstance(value, Eq) {
        return ast_write_Eq(value);
    }
    if kind == ast_kind.NotEq and isinstance(value, NotEq) {
        return ast_write_NotEq(value);
    }
    if kind == ast_kind.Lt and isinstance(value, Lt) {
        return ast_write_Lt(value);
    }
    if kind == ast_kind.LtE and isinstance(value, LtE) {
        return ast_write_LtE(value);
    }
    if kind == ast_kind.Gt and isinstance(value, Gt) {
        return ast_write_Gt(value);
    }
    if kind == ast_kind.GtE and isinstance(value, GtE) {
        return ast_write_GtE(value);
    }
    if kind == ast_kind.Is and isinstance(value, Is) {
        return ast_write_Is(value);
    }
    if kind == ast_kind.IsNot and isinstance(value, IsNot) {
        return ast_write_IsNot(value);
    }
    if kind == ast_kind.In and isinstance(value, In) {
        return ast_write_In(value);
    }
    if kind == ast_kind.NotIn and isinstance(value, NotIn) {
        return ast_write_NotIn(value);
    }
    if kind == ast_kind.comprehension and isinstance(value, comprehension) {
        return ast_write_comprehension(value);
    }
    if kind == ast_kind.ExceptHandler and isinstance(value, ExceptHandler) {
        return ast_write_ExceptHandler(value);
    }
    if kind == ast_kind.arguments and isinstance(value, arguments) {
        return ast_write_arguments(value);
    }
    if kind == ast_kind.arg and isinstance(value, arg) {
        return ast_write_arg(value);
    }
    if kind == ast_kind.keyword and isinstance(value, keyword) {
        return ast_write_keyword(value);
    }
    if kind == ast_kind.alias and isinstance(value, alias) {
        return ast_write_alias(value);
    }
    if kind == ast_kind.withitem and isinstance(value, withitem) {
        return ast_write_withitem(value);
    }
    if kind == ast_kind.match_case and isinstance(value, match_case) {
        return ast_write_match_case(value);
    }
    if kind == ast_kind.MatchValue and isinstance(value, MatchValue) {
        return ast_write_MatchValue(value);
    }
    if kind == ast_kind.MatchSingleton and isinstance(value, MatchSingleton) {
        return ast_write_MatchSingleton(value);
    }
    if kind == ast_kind.MatchSequence and isinstance(value, MatchSequence) {
        return ast_write_MatchSequence(value);
    }
    if kind == ast_kind.MatchMapping and isinstance(value, MatchMapping) {
        return ast_write_MatchMapping(value);
    }
    if kind == ast_kind.MatchClass and isinstance(value, MatchClass) {
        return ast_write_MatchClass(value);
    }
    if kind == ast_kind.MatchStar and isinstance(value, MatchStar) {
        return ast_write_MatchStar(value);
    }
    if kind == ast_kind.MatchAs and isinstance(value, MatchAs) {
        return ast_write_MatchAs(value);
    }
    if kind == ast_kind.MatchOr and isinstance(value, MatchOr) {
        return ast_write_MatchOr(value);
    }
    if kind == ast_kind.TypeIgnore and isinstance(value, TypeIgnore) {
        return ast_write_TypeIgnore(value);
    }
    if kind == ast_kind.TypeVar and isinstance(value, TypeVar) {
        return ast_write_TypeVar(value);
    }
    if kind == ast_kind.ParamSpec and isinstance(value, ParamSpec) {
        return ast_write_ParamSpec(value);
    }
    if kind == ast_kind.TypeVarTuple and isinstance(value, TypeVarTuple) {
        return ast_write_TypeVarTuple(value);
    }
    raise ValueError("Unsupported AST node");
}
