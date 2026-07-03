import from jaclang.vendor.pycparser { c_ast }

enum JacPrim {
    INT = "int",
    FLOAT = "float",
    BOOL = "bool",
    STR = "str",
    VOID = "None"
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

     },
     C_PRIM_MAP: dict = {
         "int": JacPrim.INT,
         "float": JacPrim.FLOAT,
         "double": JacPrim.FLOAT,
         "char": JacPrim.STR,
         "void": JacPrim.VOID,
         "long": JacPrim.INT,
         "short": JacPrim.INT,
         "unsigned": JacPrim.INT,
         "signed": JacPrim.INT,
         "bool": JacPrim.BOOL,

     };

def jac_prim(names: list) -> JacPrim {
    if not names {
        return JacPrim.INT;
    }
    if "char" in names {
        if "signed" in names or "unsigned" in names {
            return JacPrim.INT;
        }
        return JacPrim.STR;
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

def walk_to_typedecl(decl_type: object) -> tuple {
    t = decl_type;
    while not isinstance(t, c_ast.TypeDecl) {
        if isinstance(t, c_ast.ArrayDecl) {
            return ("array", t);
        }
        if isinstance(t, c_ast.PtrDecl) {
            return ("ptr", t);
        }
        if isinstance(t, c_ast.FuncDecl) {
            t = t.type;
            continue;
        }
        t = t?.type;
        if t is None {
            return ("none", None);
        }
    }
    return ("type", t);
}

def ptr_inner_typedecl(ptr_decl: object) -> object | None {
    inner = ptr_decl.type;
    if isinstance(inner, c_ast.TypeDecl) {
        return inner;
    }
    return None;
}

def ptr_typename(ptr_decl: object) -> str {
    inner = ptr_inner_typedecl(ptr_decl);
    if inner is not None {
        names = inner.type?.names or [];

        if "char" in names and jac_prim(names) == JacPrim.STR {
            return "str";
        }
        user = user_type_name(inner.type);
        if user is not None {
            return user;
        }
    }
    return "object";
}

def _resolve_decl(decl_type: object, resolve_user: bool) -> str {
    (kind, node) = walk_to_typedecl(decl_type);
    if kind == "array" {
        return "list";
    }
    if kind == "ptr" {
        return ptr_typename(node);
    }
    if kind == "none" {
        return "int";
    }
    if resolve_user {
        user = user_type_name(node.type);
        if user is not None {
            return user;
        }
    }
    names = node.type?.names or ["int"];
    return jac_prim(names).value;
}

def typename(decl_type: object) -> str {
    return _resolve_decl(decl_type, False);
}

def elem_typename(decl_type: object) -> str {
    return _resolve_decl(decl_type, True);
}
