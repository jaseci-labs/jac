"""Python's public symbol-table entry surface backed by Jac scope analysis."""

import os;
import builtins;
import from jaclang.compiler.frontend.python.ast_nodes { stmt, Expr }
import from jaclang.compiler.frontend.python.compiler_diagnostics {
    compiler_diag_to_pyobj
}
import from jaclang.compiler.frontend.python.parser {
    parse_file,
    parse_eval_expr,
    parse_interactive
}
import from jaclang.compiler.frontend.python.compiler_symtable {
    build_module_symtable,
    sym_block
}
import from jaclang.compiler.frontend.python.compiler_validate { future_features }
import from jaclang.compiler.backends.py.jacpython.compiler_context {
    enter_compile_context,
    exit_compile_context
}
import from jaclang.compiler.backends.py.jacpython.code_object { raise_compiler_error }

glob USE: int = 16,
     DEF_GLOBAL: int = 1,
     DEF_NONLOCAL: int = 8,
     DEF_LOCAL: int = 2,
     DEF_PARAM: int = 4,
     DEF_TYPE_PARAM: int = 1024,
     DEF_FREE_CLASS: int = 64,
     DEF_IMPORT: int = 128,
     DEF_BOUND: int = 134,
     DEF_ANNOT: int = 256,
     DEF_COMP_ITER: int = 512,
     DEF_COMP_CELL: int = 2048,
     TYPE_FUNCTION: int = 0,
     TYPE_CLASS: int = 1,
     TYPE_MODULE: int = 2,
     TYPE_ANNOTATION: int = 3,
     TYPE_TYPE_ALIAS: int = 4,
     TYPE_TYPE_PARAMETERS: int = 5,
     TYPE_TYPE_VARIABLE: int = 6,
     LOCAL: int = 1,
     GLOBAL_EXPLICIT: int = 2,
     GLOBAL_IMPLICIT: int = 3,
     FREE: int = 4,
     CELL: int = 5,
     SCOPE_OFF: int = 12,
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

    has id: int {
        getter {
            return builtins.id(self);
        }
    }

    def __hash__ -> int {
        return builtins.id(self);
    }

    def __eq__(other: object) -> bool {
        return self is other;
    }

    def __repr__ -> str {
        return f"<symtable entry {self.name}({self.id}), line {self.lineno}>";
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
        symbols = {".defaults": DEF_PARAM | (LOCAL << SCOPE_OFF), ** symbols};
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
        table.symbols[".format"] |= USE;
    }
    for free_name in b.class_free_names {
        if free_name in table.symbols and table.symbols[free_name] & DEF_BOUND {
            table.symbols[free_name] |= DEF_FREE_CLASS;
        }
    }
    _entry_children(table, b, nested or b.block_type == "function");
    return table;
}

def _entry_children(table: SymtableEntry, b: sym_block, nested: bool) {
    for child in b.children {
        if child.inlined {
            for (name, flags) in child.symbols.items() {
                scope = (flags >> SCOPE_OFF) & SCOPE_MASK;
                if scope == CELL {
                    flags |= DEF_COMP_CELL;
                }
                if name in table.symbols {
                    previous = table.symbols[name];
                    if flags & DEF_COMP_CELL {
                        table.symbols[name] = (previous & ((1 << SCOPE_OFF) - 1))
                            | DEF_COMP_CELL
                            | (CELL << SCOPE_OFF);
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

def _source_as_str(source: any) -> str {
    if not isinstance(source, str) {
        try {
            raw = bytes(memoryview(source));
        } except TypeError {
            raise TypeError("symtable(): source must be string or bytes");
        }
        import io;
        import tokenize;
        encoding = str(tokenize.detect_encoding(io.BytesIO(raw).readline)[0]);
        try {
            source = raw.decode(encoding);
        } except UnicodeDecodeError as error {
            raise SyntaxError(str(error));
        }
    }
    if "\x00" in source {
        raise SyntaxError("source code string cannot contain null bytes");
    }
    return source as str;
}

def symtable(source: any, filename: any, startstr: any, /) -> SymtableEntry {
    filename = os.fsdecode(os.fspath(filename));
    if "\x00" in filename {
        raise ValueError("embedded null character");
    }
    if not isinstance(startstr, str) {
        raise TypeError("symtable() argument 3 must be str");
    }
    if startstr not in ("exec", "eval", "single") {
        raise ValueError("symtable() arg 3 must be 'exec' or 'eval' or 'single'");
    }
    src = _source_as_str(source);
    body: list[stmt];
    if startstr == "eval" {
        value = parse_eval_expr(src, filename);
        if value is None {
            raise SyntaxError("invalid syntax");
        }
        body = [
            Expr(
                value=value,
                lineno=value.lineno,
                col_offset=value.col_offset,
                end_lineno=value.end_lineno,
                end_col_offset=value.end_col_offset
            )
        ];
    } elif startstr == "single" {
        tree = parse_interactive(src, filename);
        if tree is None {
            raise SyntaxError("invalid syntax");
        }
        body = tree.body;
    } else {
        module_tree = parse_file(src, filename);
        if module_tree is None {
            raise SyntaxError("invalid syntax");
        }
        body = module_tree.body;
    }
    (flags, validation) = future_features(body, False);
    if validation.diag is not None {
        raise_compiler_error(compiler_diag_to_pyobj(validation.diag), src, filename);
    }
    enter_compile_context(0, flags);
    try {
        result = build_module_symtable(body);
    } finally {
        exit_compile_context();
    }
    if result.diag is not None {
        raise_compiler_error(compiler_diag_to_pyobj(result.diag), src, filename);
    }
    if result.top is None {
        raise SystemError("symbol table has no module table");
    }
    return _entry_from_block(result.top);
}
