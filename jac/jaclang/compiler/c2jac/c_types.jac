import from jaclang.vendor.pycparser { c_ast }

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
         "int": "int",
         "float": "float",
         "double": "float",
         "char": "str",
         "void": "None",
         "long": "int",
         "short": "int",
         "unsigned": "int",
         "signed": "int",
         "bool": "bool",

     };

def jac_prim(names: list) -> str {
    if not names {
        return "int";
    }
    if "char" in names {
        if "signed" in names or "unsigned" in names {
            return "int";
        }
        return "str";
    }
    return C_PRIM_MAP.get(names[-1], "int");
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

def ptr_typename(ptr_decl: object) -> str {
    inner = ptr_decl.type;
    if isinstance(inner, c_ast.TypeDecl) {
        names = inner.type?.names or [];

        if "char" in names and jac_prim(names) == "str" {
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
    t = decl_type;
    while not isinstance(t, c_ast.TypeDecl) {
        if isinstance(t, c_ast.ArrayDecl) {
            return "list";
        }
        if isinstance(t, c_ast.PtrDecl) {
            return ptr_typename(t);
        }
        if isinstance(t, c_ast.FuncDecl) {
            t = t.type;
            continue;
        }
        t = t?.type;
        if t is None {
            return "int";
        }
    }
    if resolve_user {
        user = user_type_name(t.type);
        if user is not None {
            return user;
        }
    }
    names = t.type?.names or ["int"];
    return jac_prim(names);
}

def typename(decl_type: object) -> str {
    return _resolve_decl(decl_type, False);
}

def elem_typename(decl_type: object) -> str {
    return _resolve_decl(decl_type, True);
}
