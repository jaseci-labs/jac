"""Native public symbol-table data and projection from compiler scopes."""

obj SymtableEntry {
    has _name: str,
        _type: int,
        _lineno: int,
        _nested: bool,
        _symbols: dict[str, int],
        _varnames: list[str],
        _children: list[SymtableEntry];

    has name: str {
        getter {
            return self._name;
        }
    }

    has type: int {
        getter {
            return self._type;
        }
    }

    has lineno: int {
        getter {
            return self._lineno;
        }
    }

    has nested: bool {
        getter {
            return self._nested;
        }
    }

    has symbols: dict[str, int] {
        getter {
            return self._symbols;
        }
    }

    has varnames: list[str] {
        getter {
            return self._varnames;
        }
    }

    has children: list[SymtableEntry] {
        getter {
            return self._children;
        }
    }
}

def _entry_from_ste(ste: cpy_ste) -> SymtableEntry {
    symbols: dict[str, int] = {};
    for name in ste.symbol_order {
        symbols[name] = ste.symbols[name];
    }
    table = SymtableEntry(
        _name=ste.name,
        _type=ste.ste_type,
        _lineno=ste.loc.lineno,
        _nested=bool(ste.nested),
        _symbols=symbols,
        _varnames=list(ste.varnames),
        _children=[]
    );
    for child in ste.children {
        table.children.append(_entry_from_ste(child));
    }
    return table;
}

import from jaclang.compiler.frontend.python.ast_output {
    ast_output_checked,
    ast_write_text,
    ast_output_append_owned
}
import from jaclang.compiler.frontend.python.ast_nodes { Expression, mod }
import from jaclang.compiler.frontend.python.parser {
    parse_file,
    parse_eval_expr,
    parse_interactive
}
import from jaclang.runtime.python.objects { PyObj, py_error }
import from jaclang.runtime.python.capi { boundary_failure }
def source_symtable(source: str, filename: str, mode: str) -> SymtableEntry | PyObj {
    tree: mod | None = None;
    if mode == "eval" {
        expression = parse_eval_expr(source, filename);
        if expression is not None {
            tree = Expression(body=expression);
        }
    } elif mode == "single" {
        tree = parse_interactive(source, filename);
    } elif mode == "exec" {
        tree = parse_file(source, filename);
    } else {
        return py_error(
            "ValueError", "symtable() arg 3 must be 'exec' or 'eval' or 'single'"
        );
    }
    if tree is None {
        return py_error("SyntaxError", "invalid syntax");
    }
    table = cpy_symtable_build(tree, filename, cpy_future_from_ast(tree, filename));
    if table.top is None {
        return py_error("SystemError", "symbol table has no module table");
    }
    return _entry_from_ste(table.top);
}

def symtable_to_object(table: SymtableEntry) -> ptr[PyObject] {
    name = ast_write_text(table.name);
    symbols: ptr[PyObject] = NULL;
    varnames: ptr[PyObject] = NULL;
    children: ptr[PyObject] = NULL;
    try {
        symbols = ast_output_checked(PyDict_New());
        for (key, value) in table.symbols.items() {
            key_object = ast_write_text(key);
            value_object = PyLong_FromLongLong(i64(value));
            if jacpy_dict_set_owned(symbols, key_object, value_object) < 0 {
                raise boundary_failure();
            }
        }
        varnames = ast_output_checked(jacpy_list_new());
        for variable in table.varnames {
            ast_output_append_owned(varnames, ast_write_text(variable));
        }
        children = ast_output_checked(jacpy_list_new());
        for child in table.children {
            ast_output_append_owned(children, symtable_to_object(child));
        }
        return ast_output_checked(
            jacpy_symtable_entry(
                name,
                i64(table.type),
                i64(table.lineno),
                i64(table.nested),
                symbols,
                varnames,
                children
            )
        );
    } finally {
        jacpy_release(name);
        jacpy_release(symbols);
        jacpy_release(varnames);
        jacpy_release(children);
    }
}
