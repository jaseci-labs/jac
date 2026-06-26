"""C type-name resolution: pycparser type nodes → Jac builtin/user type names.

Extracted from mapper.jac so the type model lives in one place rather than
threaded through every declaration handler. These functions are pure (no AST
node-building, no tagging, no `CMapper` state) — they answer "what Jac type
name does this C declarator resolve to". The mapper's `_type_ann`/`_ret_ann`
helpers wrap these to build the stamped `ast` annotation nodes.

This is the seed of roadmap #15 (a canonical internal C type model): centralizing
name resolution here is the first step toward replacing the ad-hoc scatter.
"""

import from pycparser { c_ast }

# C primitive/builtin type names that must NOT be treated as struct/typedef
# names when resolving a pointer or sizeof target to a Jac type reference.
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
     # Canonical C-primitive → Jac builtin type-name map. Any C type name absent
     # here resolves to "int" (the conservative scalar default). Single source of
     # truth for every scalar type-name lookup in c2jac.
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
    # Map a C IdentifierType name list to a Jac builtin type name.
    # `char` alone is treated as text (→ str), but `signed char` /
    # `unsigned char` are byte-numeric integers (→ int) — keying on
    # names[-1]=="char" alone would wrongly call those str.
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
    # Return the user-defined (struct tag / typedef) name carried by a type
    # node, or None when it names only C builtins. Shared by pointer
    # resolution and malloc(sizeof(T)) struct detection.
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
    # Resolve a PtrDecl to a Jac type name:
    #   char*      → str
    #   struct T*  → T   (PTR_REF; also non-builtin typedef pointers)
    #   otherwise  → object
    inner = ptr_decl.type;
    if isinstance(inner, c_ast.TypeDecl) {
        names = inner.type?.names or [];
        # Only a plain `char *` is a C string; `signed/unsigned char *`
        # are byte buffers, so route the decision through jac_prim.
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

def typename(decl_type: object) -> str {
    # Canonical scalar/pointer/array type-name resolver. Walks the declarator
    # chain (FuncDecl wrappers, etc.) down to the underlying TypeDecl.
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
    names = t.type?.names or ["int"];
    return jac_prim(names);
}
