import from jaclang.vendor.pycparser { c_ast }
import from jaclang.compiler.cfront.lp64_scalars { lp64_ffi_scalar }

enum JacPrim {
    INT = "int",
    FLOAT = "float",
    BOOL = "bool",
    STR = "str",
    VOID = "None"
}

enum TypeKind { ARRAY = "array", PTR = "ptr", NONE = "none", SCALAR = "scalar" }

obj TypeChain {
    has kind: TypeKind,
        node: object;
}

glob C_BUILTIN_TYPES: set = {
         "int",
         "float",
         "double",
         "void",
         "char",
         "long",
         "short",
         "unsigned",
         "signed",
         "bool",
         "size_t",
         "ssize_t",
         "ptrdiff_t",
         "intptr_t",
         "uintptr_t",
         "int8_t",
         "uint8_t",
         "int16_t",
         "uint16_t",
         "int32_t",
         "uint32_t",
         "int64_t",
         "uint64_t",
         "intmax_t",
         "uintmax_t",
         "Py_ssize_t",
         "Py_hash_t",

     },
     C_PRIM_MAP: dict = {
         "int": JacPrim.INT,
         "float": JacPrim.FLOAT,
         "double": JacPrim.FLOAT,
         # Plain `char` is an integer type in C (promotion / arithmetic). The
         # string idiom is specifically `char*` — see `is_plain_char_ptr`.
         "char": JacPrim.INT,
         "void": JacPrim.VOID,
         "long": JacPrim.INT,
         "short": JacPrim.INT,
         "unsigned": JacPrim.INT,
         "signed": JacPrim.INT,
         "bool": JacPrim.BOOL,

     };

def _jac_prim_from_lp64(name: str) -> JacPrim | None {
    ffi = lp64_ffi_scalar(name);
    if ffi is None {
        return None;
    }
    if ffi.startswith("f") {
        return JacPrim.FLOAT;
    }
    return JacPrim.INT;
}

def jac_prim(names: list) -> JacPrim {
    if not names {
        return JacPrim.INT;
    }
    if "char" in names {
        # All char flavours are integers as scalars; pointers are handled by
        # `is_plain_char_ptr` / `is_char_ptr`.
        return JacPrim.INT;
    }
    if len(names) == 1 {
        lp = _jac_prim_from_lp64(names[0]);
        if lp is not None {
            return lp;
        }
    }
    return C_PRIM_MAP.get(names[-1], JacPrim.INT);
}

def user_type_name(t: object) -> str | None {
    if isinstance(t, c_ast.Struct) and t.name {
        return t.name;
    }
    names = t?.names;
    if names and names[-1] not in C_BUILTIN_TYPES {
        return names[-1];
    }
    return None;
}

def walk_to_typedecl(decl_type: object) -> TypeChain {
    t = decl_type;
    while not isinstance(t, c_ast.TypeDecl) {
        if isinstance(t, c_ast.ArrayDecl) {
            return TypeChain(kind=TypeKind.ARRAY, node=t);
        }
        if isinstance(t, c_ast.PtrDecl) {
            return TypeChain(kind=TypeKind.PTR, node=t);
        }
        if isinstance(t, c_ast.FuncDecl) {
            t = t.type;
            continue;
        }
        t = t?.type;
        if t is None {
            return TypeChain(kind=TypeKind.NONE, node=None);
        }
    }
    return TypeChain(kind=TypeKind.SCALAR, node=t);
}

def ptr_inner_typedecl(ptr_decl: object) -> object | None {
    inner = ptr_decl.type;
    if isinstance(inner, c_ast.TypeDecl) {
        return inner;
    }
    return None;
}

def _char_ptr_names(ptr_decl: object) -> list | None {
    inner = ptr_inner_typedecl(ptr_decl);
    if inner is None {
        return None;
    }
    names = inner.type?.names or [];
    if "char" not in names {
        return None;
    }
    return names;
}

def is_plain_char_ptr(ptr_decl: object) -> bool {
    # `char*` / `const char*` string idiom (not signed/unsigned byte buffers).
    names = _char_ptr_names(ptr_decl);
    if names is None {
        return False;
    }
    return "signed" not in names and "unsigned" not in names;
}

def is_char_ptr(ptr_decl: object) -> bool {
    # Any single-level pointer to char / signed char / unsigned char. Lift
    # models these as `str` cursors (`*p` → `ord(p[0])`, `p++` → `p[1:]`).
    return _char_ptr_names(ptr_decl) is not None;
}

def ptr_typename(ptr_decl: object) -> str {
    if is_char_ptr(ptr_decl) {
        return "str";
    }
    inner = ptr_inner_typedecl(ptr_decl);
    if inner is not None {
        user = user_type_name(inner.type);
        if user is not None {
            return user;
        }
    }
    return "object";
}

def _resolve_decl(decl_type: object, resolve_user: bool) -> str {
    chain = walk_to_typedecl(decl_type);
    if chain.kind == TypeKind.ARRAY {
        return "list";
    }
    if chain.kind == TypeKind.PTR {
        return ptr_typename(chain.node);
    }
    if chain.kind == TypeKind.NONE {
        return "int";
    }
    if resolve_user {
        user = user_type_name(chain.node.type);
        if user is not None {
            return user;
        }
    }
    names = chain.node.type?.names or ["int"];
    return jac_prim(names).value;
}

def typename(decl_type: object) -> str {
    return _resolve_decl(decl_type, False);
}

def elem_typename(decl_type: object) -> str {
    return _resolve_decl(decl_type, True);
}
