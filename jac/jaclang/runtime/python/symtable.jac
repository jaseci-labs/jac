"""Native public symbol-table data and projection from compiler scopes."""
import from jaclang.compiler.frontend.python.compiler_symtable { sym_block }
import from jaclang.compiler.frontend.python.compiler_symtable {
    DEF_PARAM,
    DEF_BOUND,
    SYM_USE,
    SCOPE_OFFSET,
    SCOPE_LOCAL,
    SCOPE_CELL
}

glob PUBLIC_DEF_FREE_CLASS: int = 64,
     PUBLIC_DEF_COMP_CELL: int = 2048,
     TYPE_FUNCTION: int = 0,
     TYPE_CLASS: int = 1,
     TYPE_MODULE: int = 2,
     TYPE_ANNOTATION: int = 3,
     TYPE_TYPE_ALIAS: int = 4,
     TYPE_TYPE_PARAMETERS: int = 5,
     TYPE_TYPE_VARIABLE: int = 6,
     SCOPE_MASK: int = 15;


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

def _entry_from_block(b: sym_block, nested: bool = False) -> SymtableEntry {
    kind = TYPE_FUNCTION;
    name = b.name;
    if b.block_type == "module" {
        kind = TYPE_MODULE;
    } elif b.block_type == "class" {
        kind = TYPE_CLASS;
    } elif b.generic_parameters {
        kind = TYPE_TYPE_PARAMETERS;
        name = name.removeprefix("<generic parameters of ").removesuffix(">");
    } elif b.annotation_kind == "an annotation" {
        kind = TYPE_ANNOTATION;
    } elif b.annotation_kind == "a type alias" {
        kind = TYPE_TYPE_ALIAS;
    } elif b.type_parameter_key {
        kind = TYPE_TYPE_VARIABLE;
    }
    symbols = dict(b.symbols);
    varnames = list(b.varnames);
    if kind == TYPE_TYPE_PARAMETERS
        and ".defaults" not in symbols
        and any(
            child.block_type == "function" and not child.annotation_kind
            for child in b.children
        ) {
        # The public table includes CPython's generic-function defaults slot
        # even when Jac's factory does not need to pass a defaults tuple.
        symbols = {".defaults": DEF_PARAM | (SCOPE_LOCAL << SCOPE_OFFSET), ** symbols};
        varnames.insert(0, ".defaults");
    }
    table = SymtableEntry(
        _name=name,
        _type=kind,
        _lineno=b.lineno,
        _nested=nested,
        _symbols=symbols,
        _varnames=varnames,
        _children=[]
    );
    if b.annotation_kind and ".format" in table.symbols {
        table.symbols[".format"] |= SYM_USE;
    }
    for free_name in b.class_free_names {
        if free_name in table.symbols and table.symbols[free_name] & DEF_BOUND {
            table.symbols[free_name] |= PUBLIC_DEF_FREE_CLASS;
        }
    }
    _entry_children(table, b, nested or b.block_type == "function");
    return table;
}

def _entry_children(table: SymtableEntry, b: sym_block, nested: bool) {
    for child in b.children {
        if child.inlined {
            for (name, flags) in child.symbols.items() {
                scope = (flags >> SCOPE_OFFSET) & SCOPE_MASK;
                if scope == SCOPE_CELL {
                    flags |= PUBLIC_DEF_COMP_CELL;
                }
                if name in table.symbols {
                    previous = table.symbols[name];
                    if flags & PUBLIC_DEF_COMP_CELL {
                        table.symbols[name] = (previous & ((1 << SCOPE_OFFSET) - 1))
                            | PUBLIC_DEF_COMP_CELL
                            | (SCOPE_CELL << SCOPE_OFFSET);
                    }
                } else {
                    table.symbols[name] = flags;
                }
            }
            _entry_children(table, child, True);
        } else {
            table.children.append(_entry_from_block(child, nested));
        }
    }
}


import from jaclang.compiler.frontend.python.ast_output {
    ast_output_checked,
    ast_write_text,
    ast_output_append_owned
}
import from jaclang.compiler.frontend.python.ast_nodes { stmt, Expr }
import from jaclang.compiler.frontend.python.parser {
    parse_file,
    parse_eval_expr,
    parse_interactive
}
import from jaclang.compiler.frontend.python.compiler_validate { future_features }
import from jaclang.compiler.frontend.python.compiler_symtable { build_module_symtable }
import from jaclang.compiler.frontend.python.compiler_diagnostics {
    compiler_diag_to_pyobj
}
import from jaclang.compiler.backends.py.jacpython.compiler_context { compile_context }
import from jaclang.runtime.python.objects { PyObj, py_error }
import from jaclang.runtime.python.native_services { runtime_failure }
import from c {
    def jacpy_symtable_entry(
        name: u64,
        kind: i64,
        line: i64,
        nested: i64,
        symbols: u64,
        varnames: u64,
        children: u64
    ) -> u64;  def jacpy_dict_new -> u64;  def jacpy_dict_set_owned(
        dictionary: u64, key: u64, value: u64
    ) -> i64;  def jacpy_list_new -> u64;  def jacpy_int(value: i64) -> u64;  def jacpy_release(
        handle: u64
    );
}

def source_symtable(source: str, filename: str, mode: str) -> SymtableEntry | PyObj {
    body: list[stmt] = [];
    if mode == "eval" {
        expression = parse_eval_expr(source, filename);
        if expression is None {
            return py_error("SyntaxError", "invalid syntax");
        }
        body = [
            Expr(
                value=expression,
                lineno=expression.lineno,
                col_offset=expression.col_offset,
                end_lineno=expression.end_lineno,
                end_col_offset=expression.end_col_offset
            )
        ];
    } elif mode == "single" {
        interactive = parse_interactive(source, filename);
        if interactive is None {
            return py_error("SyntaxError", "invalid syntax");
        }
        body = interactive.body;
    } elif mode == "exec" {
        module = parse_file(source, filename);
        if module is None {
            return py_error("SyntaxError", "invalid syntax");
        }
        body = module.body;
    } else {
        return py_error(
            "ValueError", "symtable() arg 3 must be 'exec' or 'eval' or 'single'"
        );
    }
    (flags, validation) = future_features(body, False);
    if validation.diag is not None {
        return compiler_diag_to_pyobj(validation.diag);
    }
    result = build_module_symtable(body, compile_context(flags=flags));
    if result.diag is not None {
        return compiler_diag_to_pyobj(result.diag);
    }
    if result.top is None {
        return py_error("SystemError", "symbol table has no module table");
    }
    return _entry_from_block(result.top);
}

def symtable_to_object(table: SymtableEntry) -> u64 {
    name = ast_write_text(table.name);
    symbols: u64 = 0;
    varnames: u64 = 0;
    children: u64 = 0;
    try {
        symbols = ast_output_checked(jacpy_dict_new());
        for (key, value) in table.symbols.items() {
            key_object = ast_write_text(key);
            value_object = jacpy_int(i64(value));
            if jacpy_dict_set_owned(symbols, key_object, value_object) < 0 {
                raise runtime_failure();
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
