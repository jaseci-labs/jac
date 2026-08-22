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
        c_node: c_ast.Node | None;
}

glob C_BUILTIN_TYPES: set[str] = {
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
     C_PRIM_MAP: dict[str, JacPrim] = {
         "int": JacPrim.INT,
         "float": JacPrim.FLOAT,
         "double": JacPrim.FLOAT,
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

def jac_prim(names: list[str]) -> JacPrim {
    if not names {
        return JacPrim.INT;
    }
    if "char" in names {
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

glob C_UNSIGNED_TYPES: set[str] = {
         "size_t",
         "uintptr_t",
         "uintmax_t",
         "uint8_t",
         "uint16_t",
         "uint32_t",
         "uint64_t"
     };

def c_type_is_unsigned(names: list[str]) -> bool {
    if "unsigned" in names {
        return True;
    }
    if "signed" in names {
        return False;
    }
    for n in names {
        if n in C_UNSIGNED_TYPES {
            return True;
        }
    }
    return False;
}

def user_type_name(t: c_ast.Node) -> str | None {
    if isinstance(t, c_ast.Struct) and t.name {
        return t.name;
    }
    names = t?.names;
    if names and names[-1] not in C_BUILTIN_TYPES {
        return names[-1];
    }
    return None;
}

def walk_to_typedecl(decl_type: c_ast.Node) -> TypeChain {
    t = decl_type;
    while not isinstance(t, c_ast.TypeDecl) {
        if isinstance(t, c_ast.ArrayDecl) {
            return TypeChain(kind=TypeKind.ARRAY, c_node=t);
        }
        if isinstance(t, c_ast.PtrDecl) {
            return TypeChain(kind=TypeKind.PTR, c_node=t);
        }
        if isinstance(t, c_ast.FuncDecl) {
            t = t.type;
            continue;
        }
        t = t?.type;
        if t is None {
            return TypeChain(kind=TypeKind.NONE, c_node=None);
        }
    }
    return TypeChain(kind=TypeKind.SCALAR, c_node=t);
}

def ptr_inner_typedecl(ptr_decl: c_ast.Node) -> c_ast.Node | None {
    inner = ptr_decl.type;
    if isinstance(inner, c_ast.TypeDecl) {
        return inner;
    }
    return None;
}

def _char_ptr_names(ptr_decl: c_ast.Node) -> list | None {
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

def is_plain_char_ptr(ptr_decl: c_ast.Node) -> bool {
    names = _char_ptr_names(ptr_decl);
    if names is None {
        return False;
    }
    return "signed" not in names and "unsigned" not in names;
}

def is_char_ptr(ptr_decl: c_ast.Node) -> bool {
    return _char_ptr_names(ptr_decl) is not None;
}

def is_pyobj_type(t: c_ast.Node) -> bool {
    if isinstance(t, c_ast.Struct) and t.name == "PyObject" {
        return True;
    }
    names = t?.names or [];
    return names and names[-1] == "PyObject";
}

def ptr_depth(decl_type: c_ast.Node) -> int {
    depth = 0;
    t = decl_type;
    while isinstance(t, c_ast.PtrDecl) {
        depth += 1;
        t = t.type;
    }
    return depth;
}

def peel_ptr(decl_type: c_ast.Node) -> c_ast.Node {
    t = decl_type;
    if isinstance(t, c_ast.PtrDecl) {
        return t.type;
    }
    return decl_type;
}

def fn_ptr_typedecl(decl_type: c_ast.Node) -> c_ast.Node | None {
    chain = walk_to_typedecl(decl_type);
    if chain.kind != TypeKind.PTR {
        return None;
    }
    inner = chain.c_node.type;
    if isinstance(inner, c_ast.FuncDecl) {
        return inner;
    }
    return None;
}

def ptr_typename(ptr_decl: c_ast.Node) -> str {
    if is_char_ptr(ptr_decl) {
        return "str";
    }
    inner = ptr_inner_typedecl(ptr_decl);
    if inner is not None {
        if is_pyobj_type(inner.type) {
            return "PyObj";
        }
        user = user_type_name(inner.type);
        if user is not None {
            return "PyObj" if user == "PyObject" else user;
        }
    }
    return "object";
}

def _resolve_decl(decl_type: c_ast.Node, resolve_user: bool) -> str {
    chain = walk_to_typedecl(decl_type);
    if chain.kind == TypeKind.ARRAY {
        return "list";
    }
    if chain.kind == TypeKind.PTR {
        return ptr_typename(chain.c_node);
    }
    if chain.kind == TypeKind.NONE {
        return "int";
    }
    if resolve_user {
        user = user_type_name(chain.c_node.type);
        if user is not None {
            return user;
        }
    }
    names = chain.c_node.type?.names or ["int"];
    return jac_prim(names).value;
}

def typename(decl_type: c_ast.Node) -> str {
    return _resolve_decl(decl_type, False);
}

def elem_typename(decl_type: c_ast.Node) -> str {
    return _resolve_decl(decl_type, True);
}

def param_typename(decl_type: c_ast.Node) -> str {
    if ptr_depth(decl_type) >= 2 {
        return elem_typename(peel_ptr(decl_type));
    }
    return elem_typename(decl_type);
}
