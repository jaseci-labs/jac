import ast;
import marshal;
import struct;
import sys;
import types;

import from jaclang.compiler.backends.py.codegen_ir {
    CirContainer,
    CirDiag,
    CirModule,
    CodegenIrFormatError,
    CodegenIrVersionError,
    DIAG_ERROR,
    OP_BYTES,
    OP_ELLIPSIS,
    OP_END,
    OP_FALSE,
    OP_FLOAT,
    OP_INT,
    OP_INT_BIG,
    OP_LIST,
    OP_LOC,
    OP_NODE,
    OP_NONE,
    OP_PARSE_SPLICE,
    OP_STR,
    OP_TRUE,
    OP_TUPLE,
    read_container,
    _r_svarint,
    _r_varint
}

def decode_ops(code: bytes, container: CirContainer) -> list {
    ops: list = [];
    pos = 0;
    loc_l1 = 0;
    loc_c1 = 0;
    loc_l2 = 0;
    loc_c2 = 0;
    ended = False;
    while pos < len(code) {
        if ended {
            raise CodegenIrFormatError(
                f"{len(code) - pos} bytes follow OP_END in a module stream"
            );
        }
        op = code[pos];
        at = pos;
        pos += 1;
        if op == OP_NONE or op == OP_TRUE or op == OP_FALSE or op == OP_ELLIPSIS {
            ops.append((op, ));
        } elif op == OP_INT {
            (v, pos) = _r_svarint(code, pos, "OP_INT operand");
            ops.append((OP_INT, v, ));
        } elif op == OP_INT_BIG {
            if pos >= len(code) {
                raise CodegenIrFormatError(
                    "truncated stream: OP_INT_BIG sign byte missing"
                );
            }
            sign = code[pos];
            pos += 1;
            (nbytes, pos) = _r_varint(code, pos, "OP_INT_BIG length");
            if pos + nbytes > len(code) {
                raise CodegenIrFormatError(
                    "truncated stream: OP_INT_BIG magnitude runs past the end"
                );
            }
            mag = int.from_bytes(code[pos:pos + nbytes], "little");
            pos += nbytes;
            ops.append((OP_INT, -mag if sign else mag, ));
        } elif op == OP_FLOAT {
            if pos + 8 > len(code) {
                raise CodegenIrFormatError(
                    "truncated stream: OP_FLOAT operand runs past the end"
                );
            }
            (v, ) = struct.unpack("<d", code[pos:pos + 8]);
            pos += 8;
            ops.append((OP_FLOAT, v, ));
        } elif op == OP_STR {
            (r, pos) = _r_varint(code, pos, "OP_STR ref");
            if r >= len(container.strings) {
                raise CodegenIrFormatError(
                    f"OP_STR ref {r} is outside the string pool"
                );
            }
            ops.append((OP_STR, container.strings[r], ));
        } elif op == OP_BYTES {
            (n, pos) = _r_varint(code, pos, "OP_BYTES length");
            if pos + n > len(code) {
                raise CodegenIrFormatError(
                    "truncated stream: OP_BYTES body runs past the end"
                );
            }
            ops.append((OP_BYTES, code[pos:pos + n], ));
            pos += n;
        } elif op == OP_LIST or op == OP_TUPLE {
            (n, pos) = _r_varint(code, pos, "aggregate arity");
            ops.append((op, n, ));
        } elif op == OP_NODE {
            (cref, pos) = _r_varint(code, pos, "OP_NODE class ref");
            if cref >= len(container.class_names) {
                raise CodegenIrFormatError(
                    f"OP_NODE class ref {cref} is outside the class table"
                );
            }
            (nk, pos) = _r_varint(code, pos, "OP_NODE field count");
            krefs: list[int] = [];
            j = 0;
            while j < nk {
                (kr, pos) = _r_varint(code, pos, "OP_NODE key ref");
                if kr >= len(container.key_names) {
                    raise CodegenIrFormatError(
                        f"OP_NODE key ref {kr} is outside the key table"
                    );
                }
                krefs.append(kr);
                j += 1;
            }
            ops.append((OP_NODE, cref, krefs, ));
        } elif op == OP_LOC {
            (d1, pos) = _r_svarint(code, pos, "OP_LOC first_line delta");
            (d2, pos) = _r_svarint(code, pos, "OP_LOC col_start delta");
            (d3, pos) = _r_svarint(code, pos, "OP_LOC last_line delta");
            (d4, pos) = _r_svarint(code, pos, "OP_LOC col_end delta");
            loc_l1 += d1;
            loc_c1 += d2;
            loc_l2 += d3;
            loc_c2 += d4;
            ops.append((OP_LOC, loc_l1, loc_c1, loc_l2, loc_c2, ));
        } elif op == OP_PARSE_SPLICE {
            (r, pos) = _r_varint(code, pos, "OP_PARSE_SPLICE source ref");
            if r >= len(container.strings) {
                raise CodegenIrFormatError(
                    f"OP_PARSE_SPLICE ref {r} is outside the string pool"
                );
            }
            (off, pos) = _r_varint(code, pos, "OP_PARSE_SPLICE line offset");
            ops.append((OP_PARSE_SPLICE, container.strings[r], off, ));
        } elif op == OP_END {
            ops.append((OP_END, ));
            ended = True;
        } else {
            raise CodegenIrFormatError(
                f"unknown opcode {op} at byte {at} of a module stream: this "
                f"container claims format version {container.format_version} "
                "but uses an instruction this runtime does not know; refusing "
                "to guess"
            );
        }
    }
    if not ended {
        raise CodegenIrFormatError("module stream has no OP_END");
    }
    return ops;
}

glob _KW_CALL_CACHE: list = [];

def _call_kw(cls: any, kw: dict) -> any {
    if not _KW_CALL_CACHE {
        _KW_CALL_CACHE.append(eval("lambda cls, kw: cls(**kw)"));
    }
    return _KW_CALL_CACHE[0](cls, kw);
}

obj CirSplice {
    has stmts: list = [];
}

obj CirCompiledModule {
    has mod_path: str,
        tree: ast.Module,
        code_obj: any = None,
        bytecode: bytes = b"";
}

obj CirResult {
    has modules: list = [],
        diags: list = [];
}

def cir_bind_classes(class_names: list) -> list {
    out: list = [];
    for name in class_names {
        cls = getattr(ast, name, None);
        if cls is None {
            raise CodegenIrVersionError(
                f"container names ast class {name} which this CPython "
                f"({sys.version_info.major}.{sys.version_info.minor}) does not "
                "provide; the producer and this runtime disagree"
            );
        }
        out.append(cls);
    }
    return out;
}

def cir_bind_keys(key_names: list) -> list {
    out: list = [];
    for name in key_names {
        out.append(sys.intern(name));
    }
    return out;
}

def _parse_splice(src: str, line_offset: int) -> CirSplice {
    tree = ast.parse(src);
    if line_offset {
        for w in ast.walk(tree) {
            for field in ("lineno", "end_lineno") {
                cur = getattr(w, field, None);
                if isinstance(cur, int) {
                    setattr(w, field, cur + line_offset);
                }
            }
        }
    }
    return CirSplice(stmts=list(tree.body));
}

def _pop_values(stack: list, n: int, what: str) -> list {
    if n > len(stack) {
        raise CodegenIrFormatError(
            f"{what} pops {n} values but only {len(stack)} are on the stack"
        );
    }
    vals: list = [];
    i = 0;
    while i < n {
        vals.append(stack.pop());
        i += 1;
    }
    vals.reverse();
    return vals;
}

def transcribe_module(
    mod: CirModule, classes: list, keys: list, container: CirContainer
) -> any {
    ops = decode_ops(mod.code, container);
    stack: list = [];
    loc_set = False;
    l1 = 0;
    c1 = 0;
    l2 = 0;
    c2 = 0;
    for op in ops {
        kind = op[0];
        if kind == OP_NODE {
            if not loc_set {
                raise CodegenIrFormatError(
                    f"OP_NODE before any OP_LOC in {mod.mod_path}: the location "
                    "register is unset"
                );
            }
            cls = classes[op[1]];
            krefs = op[2];
            vals = _pop_values(stack, len(krefs), f"OP_NODE {cls.__name__}");
            kw: dict = {};
            j = 0;
            while j < len(krefs) {
                if isinstance(vals[j], CirSplice) {
                    raise CodegenIrFormatError(
                        f"a splice chunk reached OP_NODE {cls.__name__} as a "
                        "field value; splices may only be spliced into OP_LIST"
                    );
                }
                kw[keys[krefs[j]]] = vals[j];
                j += 1;
            }
            try {
                built = _call_kw(cls, kw);
            } except TypeError as e {
                raise CodegenIrFormatError(
                    f"ast.{cls.__name__} rejected its fields in {mod.mod_path}: {e}"
                );
            }
            built.lineno = l1;
            built.col_offset = c1;
            built.end_lineno = l2;
            built.end_col_offset = c2;
            stack.append(built);
        } elif kind == OP_LOC {
            l1 = op[1];
            c1 = op[2];
            l2 = op[3];
            c2 = op[4];
            loc_set = True;
        } elif kind == OP_STR
            or kind == OP_INT
            or kind == OP_FLOAT
            or kind == OP_BYTES {
            stack.append(op[1]);
        } elif kind == OP_NONE {
            stack.append(None);
        } elif kind == OP_TRUE {
            stack.append(True);
        } elif kind == OP_FALSE {
            stack.append(False);
        } elif kind == OP_ELLIPSIS {
            stack.append(Ellipsis);
        } elif kind == OP_LIST {
            vals = _pop_values(stack, op[1], "OP_LIST");
            out: list = [];
            for v in vals {
                if isinstance(v, CirSplice) {
                    out.extend(v.stmts);
                } else {
                    out.append(v);
                }
            }
            stack.append(out);
        } elif kind == OP_TUPLE {
            vals = _pop_values(stack, op[1], "OP_TUPLE");
            for v in vals {
                if isinstance(v, CirSplice) {
                    raise CodegenIrFormatError(
                        "a splice chunk reached OP_TUPLE; splices may only be spliced into OP_LIST"
                    );
                }
            }
            stack.append(tuple(vals));
        } elif kind == OP_PARSE_SPLICE {
            stack.append(_parse_splice(op[1], op[2]));
        } elif kind == OP_END {
            if len(stack) != 1 {
                raise CodegenIrFormatError(
                    f"module stream for {mod.mod_path} ended with stack depth "
                    f"{len(stack)}; exactly one root is required"
                );
            }
            built_root = stack[0];
            if not isinstance(built_root, ast.Module) {
                raise CodegenIrFormatError(
                    f"module stream for {mod.mod_path} left a "
                    f"{type(built_root).__name__} on the stack; the root must "
                    "be ast.Module"
                );
            }
            return built_root;
        } else {
            raise CodegenIrFormatError(
                f"decoder produced an op this shim does not interpret: {kind}"
            );
        }
    }
    raise CodegenIrFormatError(f"module stream for {mod.mod_path} has no OP_END");
}

def transcribe(ir_bytes: bytes) -> tuple {
    container = read_container(ir_bytes);
    classes = cir_bind_classes(container.class_names);
    keys = cir_bind_keys(container.key_names);
    mods: list = [];
    for m in container.modules {
        mods.append((m.mod_path, transcribe_module(m, classes, keys, container), ));
    }
    return (mods, list(container.diags), );
}

def compile_ir(ir_bytes: bytes) -> CirResult {
    container = read_container(ir_bytes);
    classes = cir_bind_classes(container.class_names);
    keys = cir_bind_keys(container.key_names);
    diags = list(container.diags);
    modules: list = [];
    for m in container.modules {
        built_root: ast.Module = transcribe_module(m, classes, keys, container);
        try {
            code_obj: types.CodeType = compile(built_root, m.mod_path, "exec");
        } except (ValueError, SyntaxError, TypeError) as e {
            diags.append(
                CirDiag(
                    message=str(e),
                    code_str="E5043",
                    mod_path=m.mod_path,
                    severity=DIAG_ERROR
                )
            );
            continue;
        }
        modules.append(
            CirCompiledModule(
                mod_path=m.mod_path,
                tree=built_root,
                code_obj=code_obj,
                bytecode=marshal.dumps(code_obj)
            )
        );
    }
    return CirResult(modules=modules, diags=diags);
}
