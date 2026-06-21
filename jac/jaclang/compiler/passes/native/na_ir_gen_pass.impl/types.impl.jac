"""Type resolution and LLVM type helpers."""

"""Lower a semantic TypeBase (from the central type checker) to an LLVM type.

NaIRGenPass runs after TypeCheckPass, so annotation Expr nodes carry a fully
resolved `.type`. This consumes that TypeBase directly instead of re-deriving
type structure from raw annotation AST. Returns None when the type category
is not (yet) handled, so callers can fall back to the legacy AST walk.

Successful lowerings are memoized per LLVM module keyed by the canonical
type key (TypeBase.mangle); a cache hit also implies the type's collection
helpers were already emitted for this module.
"""
impl NaIRGenPass._lower_type(t: any) -> (ir.Type | None) {
    if t is None {
        return None;
    }
    try {
        import from jaclang.compiler.type_system.types {
            ClassType as _ClassType,
            UnionType as _UnionType,
            FunctionType as _FunctionType,
            NeverType as _NeverType,
            AnyType as _AnyType
        }
    } except ImportError {
        return None;
    }
    key = t.mangle() if t?.mangle else None;
    if key is not None and key in self._lowered_type_cache {
        return self._lowered_type_cache[key];
    }
    lowered: (ir.Type | None) = None;
    if isinstance(t, _NeverType) {
        lowered = ir.VoidType();
    } elif isinstance(t, _AnyType) {
        lowered = self.jacval_type;
    } elif isinstance(t, _ClassType) {
        lowered = self._lower_class_type(t);
    } elif isinstance(t, _UnionType) {
        # `T | None` (and general unions) lower to the first non-None member;
        # native pointers are nullable, so the optional wrapper is implicit.
        lowered = ir.VoidType();
        for m in (t.types or []) {
            if isinstance(m, _ClassType)
            and m.shared.class_name in ("NoneType", "None") {
                continue;
            }
            lowered = self._lower_type(m);
            break;
        }
    } elif isinstance(t, _FunctionType) {
        lowered = self._lower_function_type(t);
    }
    if key is not None and lowered is not None {
        self._lowered_type_cache[key] = lowered;
    }
    return lowered;
}

"""Return the canonical type key (TypeBase.mangle) of an expression's checked
type, or None when the expression is untyped. This is the sanctioned way for
native codegen to ask "what Jac type is this expression" — replacing the
legacy variable-name-keyed shadow dicts/sets."""
impl NaIRGenPass._type_key_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    return expr.type.mangle();
}

"""Return the enum class name of an expression's checked type, or None when
the expression is not enum-typed. Handles both an enum instance (ClassType
with is_enum_class) and a specific member (EnumMemberType)."""
impl NaIRGenPass._enum_name_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    try {
        import from jaclang.compiler.type_system.types {
            ClassType as _ClassType,
            EnumMemberType as _EnumMemberType
        }
    } except ImportError {
        return None;
    }
    t = expr.type;
    if isinstance(t, _EnumMemberType) and t.enum_class is not None {
        return t.enum_class.shared.class_name;
    }
    if isinstance(t, _ClassType) and t._shared is not None and t.shared.is_enum_class {
        return t.shared.class_name;
    }
    return None;
}

"""Return the native tuple registry key for an expression's checked type, or
None when the expression is not tuple-typed (or its element types cannot be
lowered). Lowering the type registers the tuple struct as a side effect, so
the returned key is always present in `tuple_types`."""
impl NaIRGenPass._tuple_key_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    tk = expr.type.mangle();
    if not tk.startswith("tuple[") {
        return None;
    }
    lowered = self._lower_type(expr.type);
    if lowered is None
    or not isinstance(lowered, ir.PointerType)
    or not isinstance(lowered.pointee, ir.LiteralStructType) {
        return None;
    }
    elems = lowered.pointee.elements;
    return f"Tuple.{len(elems)}." + ".".join([str(x) for x in elems]);
}

"""Return the native set spec key for an expression's checked set/frozenset
type, or None when the expression is not set-typed. Lowering the type
registers the set struct + helpers as a side effect, so the returned spec is
always present in `set_types`/`set_helpers`."""
impl NaIRGenPass._set_spec_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    tk = expr.type.mangle();
    if not (
        tk in ("set", "frozenset")
        or tk.startswith("set[")
        or tk.startswith("frozenset[")
    ) {
        return None;
    }
    lowered = self._lower_type(expr.type);
    if lowered is None {
        return None;
    }
    for (spec, st) in self.set_types.items() {
        if lowered == st.as_pointer() {
            return spec;
        }
    }
    return None;
}

"""Return the native dict registry key ("k:v" spec) for an expression's
checked dict type, or None when the expression is not dict-typed. Lowering
the type registers the dict struct + helpers as a side effect, so the
returned key is always present in `dict_types`/`dict_helpers`."""
impl NaIRGenPass._dict_key_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    tk = expr.type.mangle();
    if not (tk == "dict" or tk.startswith("dict[")) {
        return None;
    }
    lowered = self._lower_type(expr.type);
    if lowered is None {
        return None;
    }
    for (dkey, dt) in self.dict_types.items() {
        if lowered == dt.as_pointer() {
            return dkey;
        }
    }
    return None;
}

"""Return the native list spec key for an expression's checked list type, or
None when the expression is not list-typed. Lowering the type registers the
list struct + helpers as a side effect, so the returned spec is always
present in `list_types`/`list_helpers`."""
impl NaIRGenPass._list_spec_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    tk = expr.type.mangle();
    if not (tk == "list" or tk.startswith("list[")) {
        return None;
    }
    lowered = self._lower_type(expr.type);
    if lowered is None {
        return None;
    }
    for (spec, lt) in self.list_types.items() {
        if lowered == lt.as_pointer() {
            return spec;
        }
    }
    return None;
}

"""Parse a Callable[[p1, p2, ...], ret] annotation string into an LLVM
function-pointer type ir.FunctionType(ret, [p1, ...]).as_pointer(), or None
if the string is not a recognizable Callable subscript. Spaces are stripped
so both compact ("Callable[[int],int]") and spaced ("Callable [ [ int ] , int ]")
forms are accepted. Only primitive type names (int, i32, i8, str, None, etc.)
are supported as parameter and return types."""
impl NaIRGenPass._parse_callable_type_string(s: str) -> (ir.Type | None) {
    # Normalize: remove all spaces
    s = s.replace(' ', '');
    if not s.startswith('Callable[') {
        return None;
    }
    # Strip "Callable[" (9 chars) and the trailing "]"
    inner = s[9:];
    if not inner.endswith(']') {
        return None;
    }
    inner = inner[:-1];
    # inner is now "[p1,p2,...],ret"
    if not inner.startswith('[') {
        return None;
    }
    # Find the matching ']' for the params list
    depth = 0;
    end_idx = -1;
    for i in range(len(inner)) {
        c = inner[i];
        if c == '[' {
            depth += 1;
        } elif c == ']' {
            depth -= 1;
            if depth == 0 {
                end_idx = i;
                break;
            }
        }
    }
    if end_idx < 0 {
        return None;
    }
    params_str = inner[1:end_idx];
    rest = inner[end_idx + 1:];
    if not rest.startswith(',') {
        return None;
    }
    ret_str = rest[1:];
    _tm: dict = {
        'int': ir.IntType(64),
        'i64': ir.IntType(64),
        'i32': ir.IntType(32),
        'i16': ir.IntType(16),
        'i8': ir.IntType(8),
        'bool': ir.IntType(1),
        'f64': ir.DoubleType(),
        'f32': ir.FloatType(),
        'str': ir.IntType(8).as_pointer(),
        'None': ir.VoidType(),
        'void': ir.VoidType()
    };
    ret_type = _tm.get(ret_str, ir.VoidType());
    param_types: list = [];
    if params_str {
        for p in params_str.split(',') {
            param_types.append(_tm.get(p, ir.IntType(64)));
        }
    }
    return ir.FunctionType(ret_type, param_types).as_pointer();
}

"""Return the native struct name for an expression whose checked type is a
known struct instance, or None otherwise. Unions like `T | None` resolve to
the struct member. `self` resolves to the archetype currently being
codegen'd: inherited methods are re-emitted per subclass with a flattened
layout, so the declaring parent the checker reports would be wrong."""
impl NaIRGenPass._struct_name_of(expr: (uni.UniNode | None)) -> (str | None) {
    if (
        isinstance(expr, uni.Name)
        and expr.value == "self"
        and self._self_arch is not None
    ) {
        return self._self_arch;
    }
    if not isinstance(expr, uni.Expr) or expr.type is None {
        # Fallback for clib struct locals/globals whose type annotation was
        # not stamped by the checker (checker skips clib import blocks).
        # Derive the struct name from the LLVM alloca/global type instead.
        if isinstance(expr, uni.Name) {
            var_name = expr.value;
            alloca = self.local_vars.get(var_name);
            if alloca is not None {
                slot_ty = alloca.type?.pointee;
                if isinstance(slot_ty, ir.PointerType) and slot_ty?.pointee {
                    for sname in self.struct_types {
                        if slot_ty.pointee == self.struct_types.get(sname) {
                            return sname;
                        }
                    }
                }
            }
            gvar = self.global_vars.get(var_name);
            if gvar is not None {
                gslot_ty = gvar.type?.pointee;
                if isinstance(gslot_ty, ir.PointerType) and gslot_ty?.pointee {
                    for sname in self.struct_types {
                        if gslot_ty.pointee == self.struct_types.get(sname) {
                            return sname;
                        }
                    }
                }
            }
        }
        return None;
    }
    tk = expr.type.mangle();
    if tk in self.struct_types {
        return tk;
    }
    if "|" in tk {
        for part in tk.split("|") {
            if part in self.struct_types {
                return part;
            }
        }
    }
    return None;
}

"""Return the lowered LLVM type of a checked list type's element, or None.
For `list[Piece | None]` returns `Piece*`; for `list[list[int]]` returns
`List.i64*`. Lowering registers any needed collection helpers."""
impl NaIRGenPass._list_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    if not expr.type.mangle().startswith("list[") {
        return None;
    }
    args = expr.type.private.type_args or [];
    if not args {
        return None;
    }
    return self._lower_type(args[0]);
}

"""Return the lowered LLVM element type of a checked `Iterator[T]` expression
(the `T` a `next()` call or for-loop over the iterator yields), or None when
the expression isn't a typed iterator. Mirrors `_list_elem_llvm_of` (#6403)."""
impl NaIRGenPass._iter_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    if not expr.type.mangle().startswith("Iterator[") {
        return None;
    }
    args = expr.type.private.type_args or [];
    if not args {
        return None;
    }
    return self._lower_type(args[0]);
}

"""Return the native element spec of a checked list type's element
("i64"/"f64"/"ptr"/"jacval"), or None when the expression isn't a typed list."""
impl NaIRGenPass._elem_spec_of(expr: (uni.UniNode | None)) -> (str | None) {
    et = self._list_elem_llvm_of(expr);
    if et is None {
        return None;
    }
    if isinstance(et, ir.DoubleType) {
        return "f64";
    }
    if isinstance(et, ir.PointerType) {
        return "ptr";
    }
    if self?.jacval_type and et == self.jacval_type {
        return "jacval";
    }
    return "i64";
}

"""Lower a ClassType TypeBase to an LLVM type, or None if unresolved.

Handles primitives (registry-backed), enums, user structs, and the builtin
collections list/dict/set/frozenset/tuple — recursing on type arguments.
"""
impl NaIRGenPass._lower_class_type(t: any) -> (ir.Type | None) {
    cname = t.shared.class_name;
    # Primitive (registry-backed): int/float/bool/str/i8../f64..
    if cname in self.type_map {
        return self.type_map[cname];
    }
    if cname in ("NoneType", "None") {
        return ir.VoidType();
    }
    # Both Jac's lowercase `any` and the central checker's normalised
    # `Any` ClassType wrapper lower to the boxed jacval representation.
    if cname in ("any", "Any", "object") {
        return self.jacval_type;
    }
    # (No enum branch: _codegen_enum registers every enum name in both
    # enum_types and type_map with the same i64 backing, and type_map is
    # checked above -- so an enum_types lookup here could never be reached.)
    # Native runtime `File` (modeled centrally via na_builtins.pyi): register
    # its struct on demand so a `File` annotation lowers even before any file
    # op has emitted the helpers.
    if cname == "File" {
        return self._get_file_struct_type().as_pointer();
    }
    # Native binary file object: open(path, "rb") -> BinaryFile, whose read()
    # returns length-aware bytes (same struct layout as File).
    if cname == "BinaryFile" {
        return self._get_binary_file_struct_type().as_pointer();
    }
    # Length-aware bytes (#6404 Track 0): pointer to { i64 len, [0 x i8] data }.
    if cname == "bytes" {
        return self._get_bytes_struct_type().as_pointer();
    }
    # User-defined object/struct -> pointer to struct.
    if cname in self.struct_types {
        return self.struct_types[cname].as_pointer();
    }
    type_args = t.private.type_args or [];
    # Iterator[T] / Iterable[T] (#6403): a first-class iterator is a boxed
    # JacIter pointer. The element type T is recovered at the use site
    # (next / for-loop) via _iter_elem_llvm_of, not from this layout.
    if cname in ("Iterator", "Iterable") {
        self._ensure_iter_types();
        return self._jac_iter_type.as_pointer();
    }
    # list[T] — bare `list` defaults to a list of i64.
    if cname == "list" {
        elem_llvm: ir.Type = ir.IntType(64);
        if type_args {
            _e = self._lower_type(type_args[0]);
            if _e is None {
                return None;
            }
            elem_llvm = _e;
        }
        spec = "i64";
        if isinstance(elem_llvm, ir.DoubleType) {
            spec = "f64";
        } elif isinstance(elem_llvm, ir.PointerType) {
            spec = "ptr";
        }
        self._emit_list_helpers(spec, elem_llvm);
        return self.list_types[spec].as_pointer();
    }
    # dict[K, V] — bare `dict` defaults to dict[i64, i64].
    if cname == "dict" {
        k_llvm: ir.Type = ir.IntType(64);
        v_llvm: ir.Type = ir.IntType(64);
        if len(type_args) >= 2 {
            _k = self._lower_type(type_args[0]);
            _v = self._lower_type(type_args[1]);
            if _k is None or _v is None {
                return None;
            }
            k_llvm = _k;
            v_llvm = _v;
        }
        # Key spec: i64 / f64 / bytes / tuple{size} / ptr (#6749).
        (k_spec, k_size) = self._dict_key_spec(k_llvm);
        # Value spec: i64 / f64 / ptr / jacval.
        v_spec = "i64";
        if isinstance(v_llvm, ir.DoubleType) {
            v_spec = "f64";
        } elif isinstance(v_llvm, ir.PointerType) {
            v_spec = "ptr";
        } elif self?.jacval_type and v_llvm == self.jacval_type {
            v_spec = "jacval";
        }
        self._emit_dict_helpers(k_spec, v_spec, k_llvm, v_llvm, k_size);
        return self.dict_types[f"{k_spec}:{v_spec}"].as_pointer();
    }
    # set[T] / frozenset[T] — bare forms default to a set of i64.
    if cname in ("set", "frozenset") {
        elem_llvm: ir.Type = ir.IntType(64);
        if type_args {
            _e = self._lower_type(type_args[0]);
            if _e is None {
                return None;
            }
            elem_llvm = _e;
        }
        spec = "i64";
        esize = 0;
        if isinstance(elem_llvm, ir.DoubleType) {
            spec = "f64";
        } elif isinstance(elem_llvm, ir.PointerType) {
            spec = "ptr";
            if isinstance(elem_llvm.pointee, ir.LiteralStructType) {
                esize = self._get_struct_size(elem_llvm.pointee);
                spec = f"tuple{esize}";
            }
        }
        self._emit_set_helpers(spec, elem_llvm, esize);
        return self.set_types[spec].as_pointer();
    }
    # tuple[T1, T2, ...] -> pointer to an LLVM literal struct.
    if cname == "tuple" {
        if not type_args {
            return None;
        }
        elem_types: list[ir.Type] = [];
        for a in type_args {
            _et = self._lower_type(a);
            if _et is None {
                return None;
            }
            elem_types.append(_et);
        }
        n = len(elem_types);
        tuple_key = f"Tuple.{n}." + ".".join([str(x) for x in elem_types]);
        if tuple_key not in self.tuple_types {
            self.tuple_types[tuple_key] = ir.LiteralStructType(elem_types);
        }
        return self.tuple_types[tuple_key].as_pointer();
    }
    return None;
}

"""Lower a FunctionType / Callable annotation to an LLVM function-pointer type.

Unresolved parameter types default to i64 (matching untyped-param handling
for native function pointers); an unresolved return type defaults to void.
"""
impl NaIRGenPass._lower_function_type(t: any) -> ir.Type {
    ret_type: ir.Type = ir.VoidType();
    if t.return_type is not None {
        _r = self._lower_type(t.return_type);
        if _r is not None {
            ret_type = _r;
        }
    }
    param_types: list[ir.Type] = [];
    for p in (t.parameters or []) {
        _p = self._lower_type(p.param_type);
        if _p is None {
            param_types.append(ir.IntType(64));
        } else {
            param_types.append(_p);
        }
    }
    return ir.FunctionType(ret_type, param_types).as_pointer();
}

"""Resolve a Jac type expression to an LLVM type.

An annotation Expr carries a `.type` (TypeBase) populated by TypeCheckPass;
_lower_type maps it to an LLVM type. Every native type now flows through the
central checker -- primitives, user structs/enums, collections, and the
runtime `File` (modeled by na_builtins.pyi) -- including annotations in
imported .na.jac modules (type-checked on load). The former name-based
fallback (struct_types / type_map lookups) is gone.

A present-but-unlowerable type is reported via `_emit_unlowerable_type`
(E2018 for UnknownType, E5090 otherwise) rather than silently defaulting to
i64; it still returns a defensive i64 so codegen can continue.

The exception is clib-import annotations (parameter types on `import from
\"lib\" { def ...; }`). The type checker skips these nodes entirely, so their
`.type` is always None. Rather than forcing the checker to process C-FFI
declarations, the codegen falls back to `_resolve_primitive_name`, which maps
raw primitive type names (int, i32, f64, str, …) directly to LLVM IR types,
defaulting to i64 only when even that fails.
"""
# Primitive type name → LLVM IR type.  Used as a fallback when the type
# checker did not stamp `.type` on an annotation (e.g. clib import params).
impl NaIRGenPass._resolve_primitive_name(
    expr: (uni.UniNode | None)
) -> (ir.Type | None) {
    if expr is None {
        return None;
    }
    # Null literal (the `None` keyword) → void type
    try {
        if isinstance(expr, uni.Null) {
            return ir.VoidType();
        }
    } except NameError {
        pass;
    }
    # Direct Name check (e.g. `f64`, `int`, `None`)
    if isinstance(expr, uni.Name) {
        name = expr.value;
        if name {
            _m: dict = {
                'int': ir.IntType(64),
                'i64': ir.IntType(64),
                'i32': ir.IntType(32),
                'i16': ir.IntType(16),
                'i8': ir.IntType(8),
                'bool': ir.IntType(1),
                'f64': ir.DoubleType(),
                'f32': ir.FloatType(),
                'void': ir.VoidType(),
                'None': ir.VoidType(),
                'str': ir.IntType(8).as_pointer(),
                'Callable': ir.IntType(64),

            };
            if name in _m {
                return _m[name];
            }
            # Check clib struct names — return pointer type for globals/fields
            if name in self.clib_struct_names {
                _st = self.struct_types.get(name);
                if _st is not None {
                    return _st.as_pointer();
                }
            }
            # Unknown primitive name — return None to let caller decide
        }
    }
    _unparsed = expr.unparse() if expr?.unparse else '';
    if _unparsed.startswith('Callable') {
        _fn_ty = self._parse_callable_type_string(_unparsed);
        if _fn_ty is not None {
            return _fn_ty;
        }
        return ir.IntType(64);
    }
    # Fall back: walk sub-nodes for a nested Name (e.g. subscript base,
    # binary union operand). This handles `Callable[[int, int], None]`
    # where the outer node is a Subscript or BinaryExpr, not a Name.
    _kids = expr?.kid;
    if _kids {
        for _kid in _kids {
            _r = self._resolve_primitive_name(_kid);
            if _r is not None {
                return _r;
            }
        }
    }
    return None;
}

impl NaIRGenPass._resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type {
    if type_expr is None {
        return ir.IntType(64);
    }
    # SubTag[Expr] wraps an Expr (HasVar.type_tag); delegate to the inner tag so
    # _resolve_primitive_name can extract the type name (e.g. "int", "Callable[...]").
    if isinstance(type_expr, uni.SubTag) and type_expr?.tag is not None {
        return self._resolve_jac_type(type_expr.tag);
    }
    # Unified path: TypeBase -> ir.Type via the central type checker.
    _ptb = type_expr?.type;
    if _ptb is not None and not isinstance(type_expr, uni.Expr) {
        lowered = self._lower_type(_ptb);
        if lowered is not None {
            return lowered;
        }
        return self._emit_unlowerable_type(type_expr, _ptb);
    }
    if isinstance(type_expr, uni.Expr) {
        if type_expr.type is None {
            # Clib import annotations are not type-checked (the checker
            # skips import-from nodes with clib_decls).  Fall back to
            # resolving the raw Name against the primitive type table so
            # that `def sqrt(x: f64) -> f64;` still produces the correct
            # IR types without requiring a type-checker stamp.
            _prim = self._resolve_primitive_name(type_expr);
            if _prim is not None {
                return _prim;
            }
            # Annotation not resolved by checker or primitive table.
            # Default to i64 (opaque pointer) instead of ICE — this
            # handles user-defined types the checker hasn't stamped.
            return ir.IntType(64);
        }
        lowered = self._lower_type(type_expr.type);
        if lowered is not None {
            return lowered;
        }
        return self._emit_unlowerable_type(type_expr, type_expr.type);
    }
    return ir.IntType(64);
}

"""Emit E2018 for UnknownType, E5090 for other unlowerable types; return defensive i64."""
impl NaIRGenPass._emit_unlowerable_type(type_expr: uni.UniNode, tb: any) -> ir.Type {
    is_unknown = False;
    try {
        import from jaclang.compiler.type_system.types { UnknownType as _UnknownType }
        is_unknown = isinstance(tb, _UnknownType);
    } except ImportError { }
    # Use type_tag for HasVar/Param so E2018 shows the written name, not '<Unknown>'.
    if isinstance(type_expr, uni.Expr) {
        _label = type_expr.unparse();
    } else {
        _tag = type_expr?.type_tag;
        _label = self._get_name(_tag?.tag) or str(tb);
    }
    if is_unknown {
        self.emit(
            E2018,
            node_override=type_expr,
            name=_label,
            position="native type annotation position"
        );
    } else {
        self.emit(E5090, node_override=type_expr, kind="type", name=_label);
    }
    return ir.IntType(64);
}

"""Resolve a type for C library declarations -- clib structs use value types, not pointers."""
impl NaIRGenPass._resolve_clib_type(type_expr: (uni.UniNode | None)) -> ir.Type {
    if type_expr is None {
        # Omitted return on a clib decl is void per Jac semantics, not i64.
        return ir.VoidType();
    }
    # Check if this is a clib struct name -- return VALUE type (not pointer)
    type_name: (str | None) = None;
    if isinstance(type_expr, uni.Name) {
        type_name = type_expr.value;
    } elif type_expr?.value and isinstance(type_expr?.value, str) {
        type_name = type_expr.value;
    }
    if type_name is not None and type_name in self.clib_struct_names {
        # Use ABI-coerced integer type for small structs (matches C calling convention)
        if type_name in self.clib_struct_abi_types {
            return self.clib_struct_abi_types[type_name];
        }
        return self.struct_types[type_name];
    }
    # For all other types, delegate to normal resolution
    return self._resolve_jac_type(type_expr);
}

"""Extract name string from a Name or similar node."""
impl NaIRGenPass._get_name(nd: (uni.UniNode | None)) -> (str | None) {
    if nd is None {
        return None;
    }
    if isinstance(nd, uni.Name) {
        return nd.value;
    }
    if nd?.sym_name {
        return nd.sym_name;
    }
    if nd?.value and isinstance(getattr(nd, "value"), str) {
        return nd.value;
    }
    return None;
}

"""Create an alloca in the function entry block (ensures dominance)."""
impl NaIRGenPass._entry_alloca(var_type: ir.Type, name: str) -> ir.Value {
    func = self.builder.function;
    entry_block = func.entry_basic_block;
    # Save current position
    cur_block = self.builder.block;
    # Position at the start of the entry block (before all instructions)
    if entry_block.instructions {
        self.builder.position_before(entry_block.instructions[0]);
    } else {
        self.builder.position_at_start(entry_block);
    }
    alloca = self.builder.alloca(var_type, name=name);
    # Restore position
    self.builder.position_at_end(cur_block);
    return alloca;
}

"""Convert a value to i1 (boolean)."""
impl NaIRGenPass._to_bool(val: ir.Value) -> ir.Value {
    if isinstance(val.type, ir.IntType) and val.type.width == 1 {
        return val;
    }
    if isinstance(val.type, ir.IntType) {
        return self.builder.icmp_unsigned(
            "!=", val, ir.Constant(val.type, 0), name="tobool"
        );
    }
    if isinstance(val.type, ir.DoubleType) {
        return self.builder.fcmp_ordered(
            "!=", val, ir.Constant(val.type, 0.0), name="tobool"
        );
    }
    if isinstance(val.type, ir.PointerType) {
        # Container truthiness (Python semantics): a list/dict/set is falsy when
        # EMPTY, not when null. Every container struct stores its length as field
        # 0 (i64), so test that instead of the pointer — otherwise `while stack`
        # tests the always-non-null pointer, loops forever, and pop() runs past
        # empty into out-of-bounds memory (see #6435 item 5).
        _is_container = False;
        for (_, _lt) in self.list_types.items() {
            if val.type == _lt.as_pointer() {
                _is_container = True;
                break;
            }
        }
        if not _is_container {
            for (_, _dt) in self.dict_types.items() {
                if val.type == _dt.as_pointer() {
                    _is_container = True;
                    break;
                }
            }
        }
        if not _is_container {
            for (_, _st) in self.set_types.items() {
                if val.type == _st.as_pointer() {
                    _is_container = True;
                    break;
                }
            }
        }
        if _is_container {
            _i32 = ir.IntType(32);
            _len_ptr = self.builder.gep(
                val, [ir.Constant(_i32, 0), ir.Constant(_i32, 0)], name="tobool.len.ptr"
            );
            _len = self.builder.load(_len_ptr, name="tobool.len");
            return self.builder.icmp_unsigned(
                "!=", _len, ir.Constant(ir.IntType(64), 0), name="tobool"
            );
        }
        # bytes: empty is falsy, like the containers above — NOT a null test
        # (a bytes value is never null), which is the bug #6749 item 4 hit.
        if self._is_bytes_value(val) {
            return self._emit_bytes_truthy(val);
        }
        null_ptr = ir.Constant(val.type, None);
        return self.builder.icmp_unsigned("!=", val, null_ptr, name="tobool");
    }
    return val;
}


impl NaIRGenPass._coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value {
    _was_owned = self._is_owned(val);
    _result = self._coerce_type_inner(val, target_type);
    if _was_owned and _result is not val {
        self._mark_owned(_result);
    }
    return _result;
}

"""Original coerce-type body — emits the actual cast/bitcast/inttoptr IR.
Called only via _coerce_type so the ownership marker stays attached.
"""
impl NaIRGenPass._coerce_type_inner(val: ir.Value, target_type: ir.Type) -> ir.Value {
    if val.type == target_type {
        return val;
    }
    # Gradual `any` boxing/unboxing — the single seam through which scalar/pointer
    # values cross the `JacVal` (tagged-union) boundary. Routing it here means call
    # args, returns, local assignments, and every list/dict/tuple element coercion
    # round-trip `any` faithfully (sv parity) instead of mismatching or corrupting
    # the value at each site. See #6449.
    if self?.jacval_type {
        if target_type == self.jacval_type and val.type != self.jacval_type {
            return self._box_to_jacval(val);
        }
        if val.type == self.jacval_type and target_type != self.jacval_type {
            return self._unbox_from_jacval(val, target_type);
        }
    }
    # Int → Double (f64)
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.DoubleType) {
        return self.builder.sitofp(val, target_type, name="cast");
    }
    # Int → Float (f32)
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.FloatType) {
        return self.builder.sitofp(val, target_type, name="cast.f32");
    }
    # Double (f64) → Int
    if isinstance(val.type, ir.DoubleType) and isinstance(target_type, ir.IntType) {
        return self.builder.fptosi(val, target_type, name="cast");
    }
    # Float (f32) → Int
    if isinstance(val.type, ir.FloatType) and isinstance(target_type, ir.IntType) {
        return self.builder.fptosi(val, target_type, name="cast.i");
    }
    # Double (f64) → Float (f32)
    if isinstance(val.type, ir.DoubleType) and isinstance(target_type, ir.FloatType) {
        return self.builder.fptrunc(val, target_type, name="fptrunc");
    }
    # Float (f32) → Double (f64)
    if isinstance(val.type, ir.FloatType) and isinstance(target_type, ir.DoubleType) {
        return self.builder.fpext(val, target_type, name="fpext");
    }
    # Pointer-to-pointer bitcast (e.g., different struct pointer types)
    if isinstance(val.type, ir.PointerType)
    and isinstance(target_type, ir.PointerType) {
        return self.builder.bitcast(val, target_type, name="ptrcast");
    }
    # ir.Function (type=FunctionType) → ir.PointerType(FunctionType).
    # In LLVM IR, a function reference IS its own pointer; bitcast makes
    # the type match when passing a named def as a Callable argument.
    if isinstance(val.type, ir.FunctionType)
    and isinstance(target_type, ir.PointerType) {
        return self.builder.bitcast(val, target_type, name="fn.cast");
    }
    # ir.Function (type=FunctionType) → ir.IntType (e.g. i64).
    # C FFI callbacks declared as i64 (raw function pointer integer):
    #   uv_timer_start(timer, cb: i64, ...)
    # Emit: ptrtoint(bitcast(@fn to fntype*), i64)
    if isinstance(val.type, ir.FunctionType) and isinstance(target_type, ir.IntType) {
        fn_ptr = self.builder.bitcast(val, val.type.as_pointer(), name="fn.ptr");
        return self.builder.ptrtoint(fn_ptr, target_type, name="fn.ptrtoint");
    }
    # PointerType(FunctionType) → IntType: fn pointer already coerced to ptr, ptrtoint it.
    # This handles the case where _codegen_name already loaded a function reference
    # as a function-pointer type (void(i64)*) and the C param is i64.
    if isinstance(val.type, ir.PointerType)
    and isinstance(val.type.pointee, ir.FunctionType)
    and isinstance(target_type, ir.IntType) {
        return self.builder.ptrtoint(val, target_type, name="fn.ptrtoint");
    }
    # Struct pointer → struct value (Jac pointer → C value at call boundary)
    if isinstance(val.type, ir.PointerType)
    and not isinstance(target_type, ir.PointerType) {
        if val.type?.pointee and val.type.pointee == target_type {
            return self.builder.load(val, name="struct.unbox");
        }
        # Struct pointer → ABI integer (e.g., %Color* → i32 for small C structs)
        if isinstance(target_type, ir.IntType) and val.type?.pointee {
            for (sname, abi_type) in self.clib_struct_abi_types.items() {
                if val.type.pointee == self.struct_types.get(sname)
                and abi_type == target_type {
                    int_ptr = self.builder.bitcast(
                        val, target_type.as_pointer(), name="struct.abi.cast"
                    );
                    return self.builder.load(int_ptr, name="struct.abi.unbox");
                }
            }
        }
        # Null pointer → integer -1 sentinel (e.g., None for optional enum T | None)
        if isinstance(target_type, ir.IntType) and isinstance(val, ir.Constant) {
            return ir.Constant(target_type, -1);
        }
        # Generic PointerType → IntType: ptrtoint.
        # Needed for passing Jac obj references (struct pointers) or str (i8*)
        # to C functions declared with int params, e.g. uv_fs_write(bufs: int).
        if isinstance(target_type, ir.IntType) {
            return self.builder.ptrtoint(val, target_type, name="ptr.toint");
        }
    }
    # Struct value → struct pointer (C value → Jac pointer at call boundary)
    if not isinstance(val.type, ir.PointerType)
    and isinstance(target_type, ir.PointerType) {
        if target_type?.pointee and target_type.pointee == val.type {
            null_ptr = ir.Constant(target_type, None);
            size_gep = self.builder.gep(
                null_ptr, [ir.Constant(ir.IntType(32), 1)], name="clib.sizeof.gep"
            );
            size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="clib.sizeof");
            # Read jac_loc stamped by _codegen_tuple_val so attribution is precise.
            _clib_loc = getattr(val, 'jac_loc', '');
            raw_ptr = self._rc_call_with_ctx(
                self.rc_alloc_fn, [size], op="box", loc=_clib_loc, name="clib.box.raw"
            );
            typed_ptr = self.builder.bitcast(raw_ptr, target_type, name="clib.box.ptr");
            self.builder.store(val, typed_ptr);
            # RC: fresh alloc is owned (RC=1) — mark so callers skip extra retain.
            self._mark_owned(typed_ptr);
            # Tag as "tuple" so RC debug log shows the type instead of "raw".
            self._emit_set_type_tag(self.builder, raw_ptr, "tuple");
            return typed_ptr;
        }
        # ABI integer → struct pointer (e.g., i32 → %Color* for small C struct returns)
        if isinstance(val.type, ir.IntType) and target_type?.pointee {
            for (sname, abi_type) in self.clib_struct_abi_types.items() {
                if target_type.pointee == self.struct_types.get(sname)
                and abi_type == val.type {
                    null_ptr = ir.Constant(target_type, None);
                    size_gep = self.builder.gep(
                        null_ptr,
                        [ir.Constant(ir.IntType(32), 1)],
                        name="clib.sizeof.gep"
                    );
                    size = self.builder.ptrtoint(
                        size_gep, ir.IntType(64), name="clib.sizeof"
                    );
                    raw_ptr = self._rc_call_with_ctx(
                        self.rc_alloc_fn, [size], op="box", name="clib.box.raw"
                    );
                    int_ptr = self.builder.bitcast(
                        raw_ptr, val.type.as_pointer(), name="clib.abi.cast"
                    );
                    self.builder.store(val, int_ptr);
                    typed_ptr = self.builder.bitcast(
                        raw_ptr, target_type, name="clib.box.ptr"
                    );
                    # RC: fresh alloc is owned (RC=1) — mark so callers skip extra retain.
                    self._mark_owned(typed_ptr);
                    # Tag as the struct name so RC debug log shows the type.
                    self._emit_set_type_tag(self.builder, raw_ptr, sname);
                    return typed_ptr;
                }
            }
        }
    }
    # Generic IntType → PointerType: inttoptr.
    # Needed for assigning calloc/malloc results (i64) to pointer-typed
    # variables like str (i8*) or obj references, e.g. `txt: str = calloc_result;`
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.PointerType) {
        return self.builder.inttoptr(val, target_type, name="int.toptr");
    }
    # Int width coercion (i1 to i64, etc.)
    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.IntType) {
        if val.type.width < target_type.width {
            return self.builder.zext(val, target_type, name="zext");
        } elif val.type.width > target_type.width {
            return self.builder.trunc(val, target_type, name="trunc");
        }
    }
    # Value tuple auto-boxing: box to pointer then coerce if needed.
    # Detects tuples by checking all elements are primitive (not overflow {i64, i1} etc.)
    if isinstance(val.type, ir.LiteralStructType)
    and val.type != target_type
    and len(val.type.elements) >= 2 {
        _all_prim = True;
        for _el in val.type.elements {
            if not isinstance(
                _el, (ir.IntType, ir.DoubleType, ir.FloatType, ir.PointerType)
            ) {
                _all_prim = False;
                break;
            }
        }
        if _all_prim {
            boxed = self._box_value_tuple(val);
            if boxed.type == target_type {
                return boxed;
            }
            # Pointer-to-pointer bitcast (e.g., {i64,i64}* → i8*)
            if isinstance(boxed.type, ir.PointerType)
            and isinstance(target_type, ir.PointerType) {
                _cast = self.builder.bitcast(boxed, target_type, name="tuple.box.cast");
                # RC: bitcast of owned boxed tuple is still owned.
                self._mark_owned(_cast);
                return _cast;
            }
        }
    }
    return val;
}

"""Promote both operands to float if either is float."""
impl NaIRGenPass._promote_to_float(
    left: ir.Value, right: ir.Value
) -> tuple[(ir.Value, ir.Value)] {
    if isinstance(left.type, ir.IntType) {
        left = self.builder.sitofp(left, ir.DoubleType(), name="cast");
    }
    if isinstance(right.type, ir.IntType) {
        right = self.builder.sitofp(right, ir.DoubleType(), name="cast");
    }
    return (left, right);
}

"""Emit a binary operation."""
impl NaIRGenPass._emit_binary_op(
    op: str, left: ir.Value, right: ir.Value
) -> (ir.Value | None) {
    # String concatenation (i8* + i8*) — check before numeric dispatch
    i8p_type = ir.IntType(8).as_pointer();
    if op == Tok.PLUS and left.type == i8p_type and right.type == i8p_type {
        strlen_fn = self._get_or_declare_extern(
            "strlen", ir.IntType(64), [ir.IntType(8).as_pointer()]
        );
        strcpy_fn = self._get_or_declare_extern(
            "strcpy",
            ir.IntType(8).as_pointer(),
            [ir.IntType(8).as_pointer(), ir.IntType(8).as_pointer()]
        );
        strcat_fn = self._get_or_declare_extern(
            "strcat",
            ir.IntType(8).as_pointer(),
            [ir.IntType(8).as_pointer(), ir.IntType(8).as_pointer()]
        );
        len1 = self.builder.call(strlen_fn, [left], name="len1");
        len2 = self.builder.call(strlen_fn, [right], name="len2");
        total = self.builder.add(len1, len2, name="total_len");
        buf_size = self.builder.add(
            total, ir.Constant(ir.IntType(64), 1), name="buf_size"
        );
        _concat_loc = getattr(left, 'jac_loc', getattr(right, 'jac_loc', ''));
        buf = self._rc_call_with_ctx(
            self.rc_alloc_fn,
            [buf_size],
            op="str_concat",
            loc=_concat_loc,
            name="concat.buf"
        );
        self.builder.call(strcpy_fn, [buf, left]);
        self.builder.call(strcat_fn, [buf, right]);
        # RC: caller owns this freshly-allocated concat result (rc=1 from malloc).
        # Mark it so the assign handler skips the extra RETAIN (avoiding rc=2 leak).
        self._mark_owned(buf);
        return buf;
    }
    # bytes concatenation (jacbytes* + jacbytes*) — check before numeric dispatch.
    # bytes are the length-aware struct, not i8*, so the str branch above misses
    # them; allocate len(a)+len(b) and memcpy both data regions (embedded NULs
    # survive). _bytes_alloc marks the result owned, so the caller owns it (rc=1).
    if op == Tok.PLUS and self._is_bytes_value(left) and self._is_bytes_value(right) {
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        llen = self._bytes_len_val(left);
        rlen = self._bytes_len_val(right);
        total = self.builder.add(llen, rlen, name="by.cat.total");
        result = self._bytes_alloc(total);
        dst = self._bytes_data_ptr(result);
        memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        self.builder.call(memcpy_fn, [dst, self._bytes_data_ptr(left), llen]);
        rdst = self.builder.gep(dst, [llen], name="by.cat.rdst");
        self.builder.call(memcpy_fn, [rdst, self._bytes_data_ptr(right), rlen]);
        return result;
    }
    # bytes repeat (jacbytes* * i64 or i64 * jacbytes*) — length-aware (#6749);
    # the i8* str-repeat path below matches on i8* and would miss the struct.
    if op == Tok.STAR_MUL {
        by_val: (ir.Value | None) = None;
        rep_val: (ir.Value | None) = None;
        if self._is_bytes_value(left) and isinstance(right.type, ir.IntType) {
            by_val = left;
            rep_val = right;
        } elif self._is_bytes_value(right) and isinstance(left.type, ir.IntType) {
            by_val = right;
            rep_val = left;
        }
        if by_val is not None and rep_val is not None {
            return self._emit_bytes_repeat(by_val, rep_val);
        }
    }
    # String repeat (i8* * i64 or i64 * i8*): allocate n*len buffer, loop-copy
    if op == Tok.STAR_MUL {
        str_val: (ir.Value | None) = None;
        int_val: (ir.Value | None) = None;
        if left.type == i8p_type and isinstance(right.type, ir.IntType) {
            str_val = left;
            int_val = right;
        } elif right.type == i8p_type and isinstance(left.type, ir.IntType) {
            str_val = right;
            int_val = left;
        }
        if str_val is not None and int_val is not None {
            i8 = ir.IntType(8);
            i8p = i8.as_pointer();
            i64 = ir.IntType(64);
            strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
            memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
            slen = self.builder.call(strlen_fn, [str_val], name="rep.slen");
            total = self.builder.mul(slen, int_val, name="rep.total");
            alloc = self.builder.add(total, ir.Constant(i64, 1), name="rep.alloc");
            self._set_rc_ctx("str_repeat", "");
            buf = self.builder.call(self.rc_alloc_fn, [alloc], name="rep.buf");
            self._clear_rc_ctx();
            func = self.builder.basic_block.function;
            entry_bb = self.builder.basic_block;
            loop_bb = func.append_basic_block(name="rep.loop");
            body_bb = func.append_basic_block(name="rep.body");
            done_bb = func.append_basic_block(name="rep.done");
            self.builder.branch(loop_bb);
            self.builder.position_at_start(loop_bb);
            offset = self.builder.phi(i64, name="rep.off");
            count = self.builder.phi(i64, name="rep.cnt");
            offset.add_incoming(ir.Constant(i64, 0), entry_bb);
            count.add_incoming(ir.Constant(i64, 0), entry_bb);
            at_end = self.builder.icmp_unsigned(">=", count, int_val, name="rep.atend");
            self.builder.cbranch(at_end, done_bb, body_bb);
            self.builder.position_at_start(body_bb);
            dst = self.builder.gep(buf, [offset], name="rep.dst");
            self.builder.call(memcpy_fn, [dst, str_val, slen]);
            new_off = self.builder.add(offset, slen, name="rep.newoff");
            new_cnt = self.builder.add(count, ir.Constant(i64, 1), name="rep.newcnt");
            offset.add_incoming(new_off, body_bb);
            count.add_incoming(new_cnt, body_bb);
            self.builder.branch(loop_bb);
            self.builder.position_at_start(done_bb);
            null_ptr = self.builder.gep(buf, [total], name="rep.null");
            self.builder.store(ir.Constant(i8, 0), null_ptr);
            return buf;
        }
    }
    # List multiplication (list * int or int * list): repeat list n times
    if op == Tok.STAR_MUL {
        for (lmul_key, lmul_helpers) in self.list_helpers.items() {
            lmul_type = self.list_types.get(lmul_key);
            if lmul_type is None {
                continue;
            }
            lmul_list: (ir.Value | None) = None;
            lmul_int: (ir.Value | None) = None;
            if left.type == lmul_type.as_pointer()
            and isinstance(right.type, ir.IntType) {
                lmul_list = left;
                lmul_int = right;
            } elif right.type == lmul_type.as_pointer()
            and isinstance(left.type, ir.IntType) {
                lmul_list = right;
                lmul_int = left;
            }
            if lmul_list is not None and lmul_int is not None {
                i64 = ir.IntType(64);
                lmul_new = self.builder.call(lmul_helpers["new"], [], name="lmul.new");
                lmul_len = self.builder.call(
                    lmul_helpers["len"], [lmul_list], name="lmul.len"
                );
                func = self.builder.basic_block.function;
                lmul_entry_bb = self.builder.basic_block;
                lmul_outer_bb = func.append_basic_block(name="lmul.outer");
                lmul_iinit_bb = func.append_basic_block(name="lmul.iinit");
                lmul_inner_bb = func.append_basic_block(name="lmul.inner");
                lmul_ibody_bb = func.append_basic_block(name="lmul.ibody");
                lmul_onext_bb = func.append_basic_block(name="lmul.onext");
                lmul_done_bb = func.append_basic_block(name="lmul.done");
                self.builder.branch(lmul_outer_bb);
                self.builder.position_at_start(lmul_outer_bb);
                lmul_rep = self.builder.phi(i64, name="lmul.rep");
                lmul_rep.add_incoming(ir.Constant(i64, 0), lmul_entry_bb);
                lmul_rend = self.builder.icmp_signed(
                    ">=", lmul_rep, lmul_int, name="lmul.rend"
                );
                self.builder.cbranch(lmul_rend, lmul_done_bb, lmul_iinit_bb);
                self.builder.position_at_start(lmul_iinit_bb);
                self.builder.branch(lmul_inner_bb);
                self.builder.position_at_start(lmul_inner_bb);
                lmul_ei = self.builder.phi(i64, name="lmul.ei");
                lmul_ei.add_incoming(ir.Constant(i64, 0), lmul_iinit_bb);
                lmul_eend = self.builder.icmp_unsigned(
                    ">=", lmul_ei, lmul_len, name="lmul.eend"
                );
                self.builder.cbranch(lmul_eend, lmul_onext_bb, lmul_ibody_bb);
                self.builder.position_at_start(lmul_ibody_bb);
                lmul_elem = self.builder.call(
                    lmul_helpers["get"], [lmul_list, lmul_ei], name="lmul.elem"
                );
                self._rc_call_with_ctx(
                    lmul_helpers["append"], [lmul_new, lmul_elem], op="list_mul"
                );
                lmul_ne = self.builder.add(
                    lmul_ei, ir.Constant(i64, 1), name="lmul.ne"
                );
                lmul_ei.add_incoming(lmul_ne, lmul_ibody_bb);
                self.builder.branch(lmul_inner_bb);
                self.builder.position_at_start(lmul_onext_bb);
                lmul_nr = self.builder.add(
                    lmul_rep, ir.Constant(i64, 1), name="lmul.nr"
                );
                lmul_rep.add_incoming(lmul_nr, lmul_onext_bb);
                self.builder.branch(lmul_outer_bb);
                self.builder.position_at_start(lmul_done_bb);
                return lmul_new;
            }
        }
    }
    # List concatenation (list_ptr + list_ptr): create new list, append all
    if op == Tok.PLUS {
        for (list_key, helpers) in self.list_helpers.items() {
            list_type = self.list_types.get(list_key);
            if list_type is not None
            and left.type == list_type.as_pointer()
            and right.type == list_type.as_pointer() {
                i64 = ir.IntType(64);
                new_list = self.builder.call(helpers["new"], [], name="lcat.new");
                # Append all from left
                left_len = self.builder.call(helpers["len"], [left], name="lcat.llen");
                func = self.builder.basic_block.function;
                entry_bb = self.builder.basic_block;
                loop1_bb = func.append_basic_block(name="lcat.l1");
                body1_bb = func.append_basic_block(name="lcat.b1");
                mid_bb = func.append_basic_block(name="lcat.mid");
                loop2_bb = func.append_basic_block(name="lcat.l2");
                body2_bb = func.append_basic_block(name="lcat.b2");
                done_bb = func.append_basic_block(name="lcat.done");
                self.builder.branch(loop1_bb);
                self.builder.position_at_start(loop1_bb);
                i1 = self.builder.phi(i64, name="lcat.i1");
                i1.add_incoming(ir.Constant(i64, 0), entry_bb);
                end1 = self.builder.icmp_unsigned(">=", i1, left_len, name="lcat.end1");
                self.builder.cbranch(end1, mid_bb, body1_bb);
                self.builder.position_at_start(body1_bb);
                e1 = self.builder.call(helpers["get"], [left, i1], name="lcat.e1");
                self._rc_call_with_ctx(
                    helpers["append"], [new_list, e1], op="list_cat"
                );
                n1 = self.builder.add(i1, ir.Constant(i64, 1), name="lcat.n1");
                i1.add_incoming(n1, body1_bb);
                self.builder.branch(loop1_bb);
                # Append all from right
                self.builder.position_at_start(mid_bb);
                right_len = self.builder.call(
                    helpers["len"], [right], name="lcat.rlen"
                );
                self.builder.branch(loop2_bb);
                self.builder.position_at_start(loop2_bb);
                i2 = self.builder.phi(i64, name="lcat.i2");
                i2.add_incoming(ir.Constant(i64, 0), mid_bb);
                end2 = self.builder.icmp_unsigned(
                    ">=", i2, right_len, name="lcat.end2"
                );
                self.builder.cbranch(end2, done_bb, body2_bb);
                self.builder.position_at_start(body2_bb);
                e2 = self.builder.call(helpers["get"], [right, i2], name="lcat.e2");
                self._rc_call_with_ctx(
                    helpers["append"], [new_list, e2], op="list_cat"
                );
                n2 = self.builder.add(i2, ir.Constant(i64, 1), name="lcat.n2");
                i2.add_incoming(n2, body2_bb);
                self.builder.branch(loop2_bb);
                self.builder.position_at_start(done_bb);
                return new_list;
            }
        }
    }
    # Set operators (set_ptr op set_ptr): |, &, -, ^
    for (sk, st) in self.set_types.items() {
        if left.type == st.as_pointer() and right.type == st.as_pointer() {
            self._ensure_emitters();
            _ctx = self._native_emit_ctx_class(pass_ref=self, type_key=sk);
            _se = self._native_emitters.get("set");
            if _se is not None {
                if op == Tok.BW_OR {
                    return _se.emit_union(_ctx, left, [right]);
                }
                if op == Tok.BW_AND {
                    return _se.emit_intersection(_ctx, left, [right]);
                }
                if op == Tok.MINUS {
                    return _se.emit_difference(_ctx, left, [right]);
                }
                if op == Tok.BW_XOR {
                    return _se.emit_symmetric_difference(_ctx, left, [right]);
                }
            }
            break;
        }
    }
    # Complex arithmetic (JacComplex* op JacComplex*)
    ctype_ptr = self.complex_struct_type.as_pointer();
    if left.type == ctype_ptr and right.type == ctype_ptr {
        f64 = ir.DoubleType();
        i64 = ir.IntType(64);
        i32 = ir.IntType(32);
        z0 = ir.Constant(i32, 0);
        z1 = ir.Constant(i32, 1);
        ar = self.builder.load(
            self.builder.gep(left, [z0, z0], name="c.ar.p"), name="c.ar"
        );
        ai = self.builder.load(
            self.builder.gep(left, [z0, z1], name="c.ai.p"), name="c.ai"
        );
        br = self.builder.load(
            self.builder.gep(right, [z0, z0], name="c.br.p"), name="c.br"
        );
        bi = self.builder.load(
            self.builder.gep(right, [z0, z1], name="c.bi.p"), name="c.bi"
        );
        rr: (ir.Value | None) = None;
        ri: (ir.Value | None) = None;
        if op == Tok.PLUS {
            rr = self.builder.fadd(ar, br, name="c.add.r");
            ri = self.builder.fadd(ai, bi, name="c.add.i");
        } elif op == Tok.MINUS {
            rr = self.builder.fsub(ar, br, name="c.sub.r");
            ri = self.builder.fsub(ai, bi, name="c.sub.i");
        } elif op == Tok.STAR_MUL {
            # (ar*br - ai*bi, ar*bi + ai*br)
            rr = self.builder.fsub(
                self.builder.fmul(ar, br, name="c.m1"),
                self.builder.fmul(ai, bi, name="c.m2"),
                name="c.mul.r"
            );
            ri = self.builder.fadd(
                self.builder.fmul(ar, bi, name="c.m3"),
                self.builder.fmul(ai, br, name="c.m4"),
                name="c.mul.i"
            );
        } elif op == Tok.DIV {
            # (ar*br + ai*bi)/(br*br + bi*bi), (ai*br - ar*bi)/(br*br + bi*bi)
            denom = self.builder.fadd(
                self.builder.fmul(br, br, name="c.d1"),
                self.builder.fmul(bi, bi, name="c.d2"),
                name="c.denom"
            );
            rr = self.builder.fdiv(
                self.builder.fadd(
                    self.builder.fmul(ar, br, name="c.d3"),
                    self.builder.fmul(ai, bi, name="c.d4"),
                    name="c.div.rn"
                ),
                denom,
                name="c.div.r"
            );
            ri = self.builder.fdiv(
                self.builder.fsub(
                    self.builder.fmul(ai, br, name="c.d5"),
                    self.builder.fmul(ar, bi, name="c.d6"),
                    name="c.div.in"
                ),
                denom,
                name="c.div.i"
            );
        }
        if rr is not None and ri is not None {
            # Allocate result complex struct
            raw = self.builder.call(
                self.rc_alloc_fn, [ir.Constant(i64, 16)], name="c.res.raw"
            );
            ptr = self.builder.bitcast(raw, ctype_ptr, name="c.res.ptr");
            self.builder.store(rr, self.builder.gep(ptr, [z0, z0], name="c.res.rp"));
            self.builder.store(ri, self.builder.gep(ptr, [z0, z1], name="c.res.ip"));
            return ptr;
        }
    }
    is_float = isinstance(left.type, ir.DoubleType)
    or isinstance(right.type, ir.DoubleType);
    if is_float {
        (left, right) = self._promote_to_float(left, right);
    }
    if is_float {
        if op == Tok.PLUS {
            return self.builder.fadd(left, right, name="fadd");
        } elif op == Tok.MINUS {
            return self.builder.fsub(left, right, name="fsub");
        } elif op == Tok.STAR_MUL {
            return self.builder.fmul(left, right, name="fmul");
        } elif op == Tok.DIV {
            # ZeroDivisionError check for float division
            fzero = ir.Constant(ir.DoubleType(), 0.0);
            is_zero = self.builder.fcmp_ordered(
                "==", right, fzero, name="fdiv.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "float division by zero"
            );
            return self.builder.fdiv(left, right, name="fdiv");
        } elif op == Tok.MOD {
            # ZeroDivisionError check for float modulo
            fzero = ir.Constant(ir.DoubleType(), 0.0);
            is_zero = self.builder.fcmp_ordered(
                "==", right, fzero, name="fmod.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "float modulo by zero"
            );
            return self.builder.frem(left, right, name="fmod");
        } elif op == Tok.FLOOR_DIV {
            # Float floor division: fdiv then floor
            fzero = ir.Constant(ir.DoubleType(), 0.0);
            is_zero = self.builder.fcmp_ordered(
                "==", right, fzero, name="ffloordiv.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "float floor division by zero"
            );
            raw = self.builder.fdiv(left, right, name="ffloordiv.raw");
            floor_fn = self._get_or_declare_extern(
                "floor", ir.DoubleType(), [ir.DoubleType()]
            );
            return self.builder.call(floor_fn, [raw], name="ffloordiv");
        }
    } else {
        i64 = ir.IntType(64);
        i1 = ir.IntType(1);
        if op == Tok.PLUS {
            # OverflowError check via LLVM intrinsic
            overflow_ret = ir.LiteralStructType([i64, i1]);
            intrinsic = self._get_or_declare_extern(
                "llvm.sadd.with.overflow.i64", overflow_ret, [i64, i64]
            );
            result = self.builder.call(intrinsic, [left, right], name="add.ovf");
            val = self.builder.extract_value(result, 0, name="add.val");
            overflow = self.builder.extract_value(result, 1, name="add.overflow");
            self._emit_runtime_raise(overflow, "OverflowError", "integer overflow");
            return val;
        } elif op == Tok.MINUS {
            # OverflowError check via LLVM intrinsic
            overflow_ret = ir.LiteralStructType([i64, i1]);
            intrinsic = self._get_or_declare_extern(
                "llvm.ssub.with.overflow.i64", overflow_ret, [i64, i64]
            );
            result = self.builder.call(intrinsic, [left, right], name="sub.ovf");
            val = self.builder.extract_value(result, 0, name="sub.val");
            overflow = self.builder.extract_value(result, 1, name="sub.overflow");
            self._emit_runtime_raise(overflow, "OverflowError", "integer overflow");
            return val;
        } elif op == Tok.STAR_MUL {
            # OverflowError check via LLVM intrinsic
            overflow_ret = ir.LiteralStructType([i64, i1]);
            intrinsic = self._get_or_declare_extern(
                "llvm.smul.with.overflow.i64", overflow_ret, [i64, i64]
            );
            result = self.builder.call(intrinsic, [left, right], name="mul.ovf");
            val = self.builder.extract_value(result, 0, name="mul.val");
            overflow = self.builder.extract_value(result, 1, name="mul.overflow");
            self._emit_runtime_raise(overflow, "OverflowError", "integer overflow");
            return val;
        } elif op == Tok.DIV {
            # ZeroDivisionError check for integer division
            izero = ir.Constant(i64, 0);
            is_zero = self.builder.icmp_signed("==", right, izero, name="div.zero.chk");
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "integer division or modulo by zero"
            );
            return self.builder.sdiv(left, right, name="div");
        } elif op == Tok.FLOOR_DIV {
            # ZeroDivisionError check for floor division
            izero = ir.Constant(i64, 0);
            is_zero = self.builder.icmp_signed(
                "==", right, izero, name="floordiv.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "integer division or modulo by zero"
            );
            return self.builder.sdiv(left, right, name="floordiv");
        } elif op == Tok.MOD {
            # ZeroDivisionError check for integer modulo
            izero = ir.Constant(i64, 0);
            is_zero = self.builder.icmp_signed("==", right, izero, name="mod.zero.chk");
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "integer division or modulo by zero"
            );
            return self.builder.srem(left, right, name="mod");
        }
    }
    # Power operator (integer exponentiation via loop, float via pow)
    if op == Tok.STAR_POW {
        if is_float {
            pow_fn = self._get_or_declare_extern(
                "pow", ir.DoubleType(), [ir.DoubleType(), ir.DoubleType()]
            );
            return self.builder.call(pow_fn, [left, right], name="pow");
        } else {
            # Integer power: use loop-based exponentiation
            return self._codegen_int_pow(left, right);
        }
    }
    # Bitwise operators (integer only)
    if op == Tok.BW_AND {
        return self.builder.and_(left, right, name="bwand");
    }
    if op == Tok.BW_OR {
        return self.builder.or_(left, right, name="bwor");
    }
    if op == Tok.BW_XOR {
        return self.builder.xor(left, right, name="bwxor");
    }
    if op == Tok.LSHIFT {
        return self.builder.shl(left, right, name="shl");
    }
    if op == Tok.RSHIFT {
        return self.builder.ashr(left, right, name="ashr");
    }
    # Logical operators
    if op == Tok.KW_AND {
        return self.builder.and_(left, right, name="and");
    }
    if op == Tok.KW_OR {
        return self.builder.or_(left, right, name="or");
    }
    # Unknown operator — surface a loud error instead of silently emitting
    # a function body that reads garbage at runtime. Catches walrus (`:=`,
    # WALRUS_EQ), pipe-forward (`|>`), and any other binary operator the
    # NA pass doesn't lower yet.
    self.emit(E5090, node_override=self.cur_node, kind="binary operator", name=op);
    return None;
}

"""Emit a comparison operation."""
impl NaIRGenPass._emit_comparison(
    op: str, left: ir.Value, right: ir.Value, is_float: bool
) -> (ir.Value | None) {
    # Tuple comparison (value/pointer/mixed): must be before pointer block
    _l_is_tval = isinstance(left.type, ir.LiteralStructType);
    _r_is_tval = isinstance(right.type, ir.LiteralStructType);
    _l_is_tptr = isinstance(left.type, ir.PointerType)
    and isinstance(left.type.pointee, ir.LiteralStructType);
    _r_is_tptr = isinstance(right.type, ir.PointerType)
    and isinstance(right.type.pointee, ir.LiteralStructType);
    if _l_is_tval or _r_is_tval or _l_is_tptr or _r_is_tptr {
        tcmp_struct: (ir.LiteralStructType | None) = None;
        tcmp_left_val: (ir.Value | None) = None;
        tcmp_right_val: (ir.Value | None) = None;
        i8_ptr = ir.IntType(8).as_pointer();
        if _l_is_tval and _r_is_tval and str(left.type) == str(right.type) {
            tcmp_struct = left.type;
            tcmp_left_val = left;
            tcmp_right_val = right;
        } elif _l_is_tptr
        and _r_is_tptr
        and str(left.type.pointee) == str(right.type.pointee) {
            tcmp_struct = left.type.pointee;
            tcmp_left_val = self.builder.load(left, name="tcmp.l.val");
            tcmp_right_val = self.builder.load(right, name="tcmp.r.val");
        } elif _l_is_tval
        and _r_is_tptr
        and str(left.type) == str(right.type.pointee) {
            tcmp_struct = left.type;
            tcmp_left_val = left;
            tcmp_right_val = self.builder.load(right, name="tcmp.r.val");
        } elif _r_is_tval
        and _l_is_tptr
        and str(right.type) == str(left.type.pointee) {
            tcmp_struct = right.type;
            tcmp_left_val = self.builder.load(left, name="tcmp.l.val");
            tcmp_right_val = right;
        }
        if tcmp_struct is not None
        and tcmp_left_val is not None
        and tcmp_right_val is not None {
            n = len(tcmp_struct.elements);
            i1_t = ir.IntType(1);
            if op == Tok.EE or op == Tok.NE {
                result = ir.Constant(i1_t, 1);
                for i in range(n) {
                    ea = self.builder.extract_value(
                        tcmp_left_val, i, name=f"tcmp.ea.{i}"
                    );
                    eb = self.builder.extract_value(
                        tcmp_right_val, i, name=f"tcmp.eb.{i}"
                    );
                    if isinstance(ea.type, ir.IntType) {
                        eq_i = self.builder.icmp_signed(
                            "==", ea, eb, name=f"tcmp.eq.{i}"
                        );
                    } elif isinstance(ea.type, ir.DoubleType) {
                        eq_i = self.builder.fcmp_ordered(
                            "==", ea, eb, name=f"tcmp.eq.{i}"
                        );
                    } else {
                        tcmp_strcmp = self._get_or_declare_extern(
                            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
                        );
                        tcmp_sc = self.builder.call(
                            tcmp_strcmp, [ea, eb], name=f"tcmp.sc.{i}"
                        );
                        eq_i = self.builder.icmp_signed(
                            "==",
                            tcmp_sc,
                            ir.Constant(ir.IntType(32), 0),
                            name=f"tcmp.eq.{i}"
                        );
                    }
                    result = self.builder.and_(result, eq_i, name=f"tcmp.all.{i}");
                }
                if op == Tok.NE {
                    return self.builder.not_(result, name="tcmp.ne");
                }
                return result;
            }
            if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) and n > 0 {
                func = self.builder.basic_block.function;
                tcmp_true_bb = func.append_basic_block(name="tcmp.lex.true");
                tcmp_false_bb = func.append_basic_block(name="tcmp.lex.false");
                tcmp_done_bb = func.append_basic_block(name="tcmp.lex.done");
                for i in range(n) {
                    ea = self.builder.extract_value(
                        tcmp_left_val, i, name=f"tcmp.lex.ea.{i}"
                    );
                    eb = self.builder.extract_value(
                        tcmp_right_val, i, name=f"tcmp.lex.eb.{i}"
                    );
                    if isinstance(ea.type, ir.IntType) {
                        lt_i = self.builder.icmp_signed(
                            "<", ea, eb, name=f"tcmp.lt.{i}"
                        );
                        gt_i = self.builder.icmp_signed(
                            ">", ea, eb, name=f"tcmp.gt.{i}"
                        );
                    } elif isinstance(ea.type, ir.DoubleType) {
                        lt_i = self.builder.fcmp_ordered(
                            "<", ea, eb, name=f"tcmp.lt.{i}"
                        );
                        gt_i = self.builder.fcmp_ordered(
                            ">", ea, eb, name=f"tcmp.gt.{i}"
                        );
                    } else {
                        tcmp_strcmp2 = self._get_or_declare_extern(
                            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
                        );
                        tcmp_sc2 = self.builder.call(
                            tcmp_strcmp2, [ea, eb], name=f"tcmp.lex.sc.{i}"
                        );
                        tcmp_z32 = ir.Constant(ir.IntType(32), 0);
                        lt_i = self.builder.icmp_signed(
                            "<", tcmp_sc2, tcmp_z32, name=f"tcmp.lt.{i}"
                        );
                        gt_i = self.builder.icmp_signed(
                            ">", tcmp_sc2, tcmp_z32, name=f"tcmp.gt.{i}"
                        );
                    }
                    next_bb = func.append_basic_block(name=f"tcmp.lex.next.{i}");
                    if op == Tok.LT or op == Tok.LTE {
                        self.builder.cbranch(lt_i, tcmp_true_bb, next_bb);
                        self.builder.position_at_start(next_bb);
                        next2_bb = func.append_basic_block(name=f"tcmp.lex.eq.{i}");
                        self.builder.cbranch(gt_i, tcmp_false_bb, next2_bb);
                        self.builder.position_at_start(next2_bb);
                    } else {
                        self.builder.cbranch(gt_i, tcmp_true_bb, next_bb);
                        self.builder.position_at_start(next_bb);
                        next2_bb = func.append_basic_block(name=f"tcmp.lex.eq.{i}");
                        self.builder.cbranch(lt_i, tcmp_false_bb, next2_bb);
                        self.builder.position_at_start(next2_bb);
                    }
                }
                if op == Tok.LTE or op == Tok.GTE {
                    self.builder.branch(tcmp_true_bb);
                } else {
                    self.builder.branch(tcmp_false_bb);
                }
                self.builder.position_at_start(tcmp_true_bb);
                self.builder.branch(tcmp_done_bb);
                self.builder.position_at_start(tcmp_false_bb);
                self.builder.branch(tcmp_done_bb);
                self.builder.position_at_start(tcmp_done_bb);
                tcmp_res = self.builder.phi(i1_t, name="tcmp.lex.res");
                tcmp_res.add_incoming(ir.Constant(i1_t, 1), tcmp_true_bb);
                tcmp_res.add_incoming(ir.Constant(i1_t, 0), tcmp_false_bb);
                return tcmp_res;
            }
        }
    }
    # Pointer comparisons
    if isinstance(left.type, ir.PointerType)
    and isinstance(right.type, ir.PointerType) {
        i8_ptr = ir.IntType(8).as_pointer();
        # bytes comparison (#6749): == / != via length+memcmp, and ordering
        # < > <= >= lexicographically (unsigned bytes, length tiebreak). A
        # distinct struct type, so this never reaches the i8* string path.
        if self._is_bytes_value(left) and self._is_bytes_value(right) {
            if op == Tok.EE or op == Tok.NE {
                return self._emit_bytes_eq(left, right, negate=op == Tok.NE);
            }
            if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) {
                _sym = "<"
                    if op == Tok.LT
                    else (">" if op == Tok.GT else ("<=" if op == Tok.LTE else ">="));
                _ord = self._emit_bytes_cmp(left, right, _sym);
                _zero = ir.Constant(ir.IntType(32), 0);
                if op == Tok.LT {
                    return self.builder.icmp_signed("<", _ord, _zero, name="by.lt");
                }
                if op == Tok.GT {
                    return self.builder.icmp_signed(">", _ord, _zero, name="by.gt");
                }
                if op == Tok.LTE {
                    return self.builder.icmp_signed("<=", _ord, _zero, name="by.lte");
                }
                return self.builder.icmp_signed(">=", _ord, _zero, name="by.gte");
            }
        }
        # String comparison: both operands must be i8* (char pointers)
        if left.type == i8_ptr and right.type == i8_ptr {
            strcmp_fn = self._get_or_declare_extern(
                "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
            );
            cmp_result = self.builder.call(strcmp_fn, [left, right], name="strcmp");
            zero = ir.Constant(ir.IntType(32), 0);
            if op == Tok.EE {
                return self.builder.icmp_signed("==", cmp_result, zero, name="streq");
            } elif op == Tok.NE {
                return self.builder.icmp_signed("!=", cmp_result, zero, name="strne");
            } elif op == Tok.LT {
                return self.builder.icmp_signed("<", cmp_result, zero, name="strlt");
            } elif op == Tok.GT {
                return self.builder.icmp_signed(">", cmp_result, zero, name="strgt");
            } elif op == Tok.LTE {
                return self.builder.icmp_signed("<=", cmp_result, zero, name="strle");
            } elif op == Tok.GTE {
                return self.builder.icmp_signed(">=", cmp_result, zero, name="strge");
            }
            return None;
        }
        # List comparison: detect list pointer types
        for (lcmp_key, lcmp_type) in self.list_types.items() {
            if left.type == lcmp_type.as_pointer()
            and right.type == lcmp_type.as_pointer() {
                lcmp_h = self.list_helpers.get(lcmp_key);
                if lcmp_h is None {
                    break;
                }
                i64 = ir.IntType(64);
                i1_t = ir.IntType(1);
                lcmp_la = self.builder.call(lcmp_h["len"], [left], name="lcmp.la");
                lcmp_lb = self.builder.call(lcmp_h["len"], [right], name="lcmp.lb");
                func = self.builder.basic_block.function;
                lcmp_entry_bb = self.builder.basic_block;
                lcmp_et = lcmp_h["elem_type"];
                if op == Tok.EE or op == Tok.NE {
                    # == : lengths equal AND all elements equal
                    lcmp_len_eq = self.builder.icmp_unsigned(
                        "==", lcmp_la, lcmp_lb, name="lcmp.leq"
                    );
                    lcmp_chk_bb = func.append_basic_block(name="lcmp.eq.chk");
                    lcmp_false_bb = func.append_basic_block(name="lcmp.eq.false");
                    lcmp_loop_bb = func.append_basic_block(name="lcmp.eq.loop");
                    lcmp_body_bb = func.append_basic_block(name="lcmp.eq.body");
                    lcmp_ne_bb = func.append_basic_block(name="lcmp.eq.ne");
                    lcmp_next_bb = func.append_basic_block(name="lcmp.eq.next");
                    lcmp_done_bb = func.append_basic_block(name="lcmp.eq.done");
                    self.builder.cbranch(lcmp_len_eq, lcmp_chk_bb, lcmp_false_bb);
                    self.builder.position_at_start(lcmp_chk_bb);
                    self.builder.branch(lcmp_loop_bb);
                    self.builder.position_at_start(lcmp_loop_bb);
                    lcmp_i = self.builder.phi(i64, name="lcmp.eq.i");
                    lcmp_i.add_incoming(ir.Constant(i64, 0), lcmp_chk_bb);
                    lcmp_iend = self.builder.icmp_unsigned(
                        ">=", lcmp_i, lcmp_la, name="lcmp.eq.iend"
                    );
                    self.builder.cbranch(lcmp_iend, lcmp_done_bb, lcmp_body_bb);
                    self.builder.position_at_start(lcmp_body_bb);
                    lcmp_ea = self.builder.call(
                        lcmp_h["get"], [left, lcmp_i], name="lcmp.ea"
                    );
                    lcmp_eb = self.builder.call(
                        lcmp_h["get"], [right, lcmp_i], name="lcmp.eb"
                    );
                    if isinstance(lcmp_et, ir.IntType) {
                        lcmp_elem_ne = self.builder.icmp_signed(
                            "!=", lcmp_ea, lcmp_eb, name="lcmp.ene"
                        );
                    } elif isinstance(lcmp_et, ir.DoubleType) {
                        lcmp_elem_ne = self.builder.fcmp_ordered(
                            "!=", lcmp_ea, lcmp_eb, name="lcmp.ene"
                        );
                    } else {
                        lcmp_strcmp = self._get_or_declare_extern(
                            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
                        );
                        lcmp_scmp = self.builder.call(
                            lcmp_strcmp, [lcmp_ea, lcmp_eb], name="lcmp.scmp"
                        );
                        lcmp_elem_ne = self.builder.icmp_signed(
                            "!=",
                            lcmp_scmp,
                            ir.Constant(ir.IntType(32), 0),
                            name="lcmp.ene"
                        );
                    }
                    self.builder.cbranch(lcmp_elem_ne, lcmp_ne_bb, lcmp_next_bb);
                    self.builder.position_at_start(lcmp_ne_bb);
                    self.builder.branch(lcmp_false_bb);
                    self.builder.position_at_start(lcmp_next_bb);
                    lcmp_ni = self.builder.add(
                        lcmp_i, ir.Constant(i64, 1), name="lcmp.ni"
                    );
                    lcmp_i.add_incoming(lcmp_ni, lcmp_next_bb);
                    self.builder.branch(lcmp_loop_bb);
                    self.builder.position_at_start(lcmp_false_bb);
                    self.builder.branch(lcmp_done_bb);
                    self.builder.position_at_start(lcmp_done_bb);
                    lcmp_result = self.builder.phi(i1_t, name="lcmp.eq.result");
                    lcmp_result.add_incoming(ir.Constant(i1_t, 1), lcmp_loop_bb);
                    lcmp_result.add_incoming(ir.Constant(i1_t, 0), lcmp_false_bb);
                    if op == Tok.NE {
                        return self.builder.not_(lcmp_result, name="lcmp.ne");
                    }
                    return lcmp_result;
                }
                # Lexicographic: <, >, <=, >=
                if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) {
                    # min_len = min(la, lb)
                    lcmp_lt_len = self.builder.icmp_unsigned(
                        "<", lcmp_la, lcmp_lb, name="lcmp.lex.ltl"
                    );
                    lcmp_min = self.builder.select(
                        lcmp_lt_len, lcmp_la, lcmp_lb, name="lcmp.min"
                    );
                    lcmp_lex_loop = func.append_basic_block(name="lcmp.lex.loop");
                    lcmp_lex_body = func.append_basic_block(name="lcmp.lex.body");
                    lcmp_lex_lbody = func.append_basic_block(name="lcmp.lex.lbody");
                    lcmp_lex_next = func.append_basic_block(name="lcmp.lex.next");
                    lcmp_lex_after = func.append_basic_block(name="lcmp.lex.after");
                    lcmp_lex_true = func.append_basic_block(name="lcmp.lex.true");
                    lcmp_lex_false = func.append_basic_block(name="lcmp.lex.false");
                    lcmp_lex_done = func.append_basic_block(name="lcmp.lex.done");
                    self.builder.branch(lcmp_lex_loop);
                    self.builder.position_at_start(lcmp_lex_loop);
                    lcmp_li = self.builder.phi(i64, name="lcmp.lex.i");
                    lcmp_li.add_incoming(ir.Constant(i64, 0), lcmp_entry_bb);
                    lcmp_lend = self.builder.icmp_unsigned(
                        ">=", lcmp_li, lcmp_min, name="lcmp.lex.lend"
                    );
                    self.builder.cbranch(lcmp_lend, lcmp_lex_after, lcmp_lex_body);
                    self.builder.position_at_start(lcmp_lex_body);
                    lcmp_lea = self.builder.call(
                        lcmp_h["get"], [left, lcmp_li], name="lcmp.lex.ea"
                    );
                    lcmp_leb = self.builder.call(
                        lcmp_h["get"], [right, lcmp_li], name="lcmp.lex.eb"
                    );
                    if isinstance(lcmp_et, ir.IntType) {
                        lcmp_lex_lt = self.builder.icmp_signed(
                            "<", lcmp_lea, lcmp_leb, name="lcmp.lex.lt"
                        );
                        lcmp_lex_gt = self.builder.icmp_signed(
                            ">", lcmp_lea, lcmp_leb, name="lcmp.lex.gt"
                        );
                    } elif isinstance(lcmp_et, ir.DoubleType) {
                        lcmp_lex_lt = self.builder.fcmp_ordered(
                            "<", lcmp_lea, lcmp_leb, name="lcmp.lex.lt"
                        );
                        lcmp_lex_gt = self.builder.fcmp_ordered(
                            ">", lcmp_lea, lcmp_leb, name="lcmp.lex.gt"
                        );
                    } else {
                        lcmp_strcmp2 = self._get_or_declare_extern(
                            "strcmp", ir.IntType(32), [i8_ptr, i8_ptr]
                        );
                        lcmp_scmp2 = self.builder.call(
                            lcmp_strcmp2, [lcmp_lea, lcmp_leb], name="lcmp.lex.sc"
                        );
                        lcmp_zero32 = ir.Constant(ir.IntType(32), 0);
                        lcmp_lex_lt = self.builder.icmp_signed(
                            "<", lcmp_scmp2, lcmp_zero32, name="lcmp.lex.lt"
                        );
                        lcmp_lex_gt = self.builder.icmp_signed(
                            ">", lcmp_scmp2, lcmp_zero32, name="lcmp.lex.gt"
                        );
                    }
                    # For < and <=: ea < eb → True, ea > eb → False
                    # For > and >=: ea > eb → True, ea < eb → False
                    if op == Tok.LT or op == Tok.LTE {
                        self.builder.cbranch(
                            lcmp_lex_lt, lcmp_lex_true, lcmp_lex_lbody
                        );
                        self.builder.position_at_start(lcmp_lex_lbody);
                        self.builder.cbranch(
                            lcmp_lex_gt, lcmp_lex_false, lcmp_lex_next
                        );
                    } else {
                        self.builder.cbranch(
                            lcmp_lex_gt, lcmp_lex_true, lcmp_lex_lbody
                        );
                        self.builder.position_at_start(lcmp_lex_lbody);
                        self.builder.cbranch(
                            lcmp_lex_lt, lcmp_lex_false, lcmp_lex_next
                        );
                    }
                    self.builder.position_at_start(lcmp_lex_next);
                    lcmp_lni = self.builder.add(
                        lcmp_li, ir.Constant(i64, 1), name="lcmp.lni"
                    );
                    lcmp_li.add_incoming(lcmp_lni, lcmp_lex_next);
                    self.builder.branch(lcmp_lex_loop);
                    self.builder.position_at_start(lcmp_lex_after);
                    # All common elements equal: compare lengths
                    if op == Tok.LT {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            "<", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    } elif op == Tok.GT {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            ">", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    } elif op == Tok.LTE {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            "<=", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    } else {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            ">=", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    }
                    self.builder.cbranch(lcmp_len_res, lcmp_lex_true, lcmp_lex_false);
                    self.builder.position_at_start(lcmp_lex_true);
                    self.builder.branch(lcmp_lex_done);
                    self.builder.position_at_start(lcmp_lex_false);
                    self.builder.branch(lcmp_lex_done);
                    self.builder.position_at_start(lcmp_lex_done);
                    lcmp_lex_res = self.builder.phi(i1_t, name="lcmp.lex.res");
                    lcmp_lex_res.add_incoming(ir.Constant(i1_t, 1), lcmp_lex_true);
                    lcmp_lex_res.add_incoming(ir.Constant(i1_t, 0), lcmp_lex_false);
                    return lcmp_lex_res;
                }
                break;
            }
        }
        # Set comparison: detect set pointer types
        for (sk, st) in self.set_types.items() {
            if left.type == st.as_pointer() and right.type == st.as_pointer() {
                shelpers = self.set_helpers.get(sk);
                if shelpers is not None {
                    self._ensure_emitters();
                    _ctx = self._native_emit_ctx_class(pass_ref=self, type_key=sk);
                    _se = self._native_emitters.get("set");
                    if _se is not None {
                        i64 = ir.IntType(64);
                        i1_t = ir.IntType(1);
                        if op == Tok.LTE {
                            # a <= b: issubset(a, b)
                            sub_val = _se.emit_issubset(_ctx, left, [right]);
                            return self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="sle"
                            );
                        }
                        if op == Tok.GTE {
                            # a >= b: issubset(b, a)
                            sub_val = _se.emit_issubset(_ctx, right, [left]);
                            return self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="sge"
                            );
                        }
                        # ==, !=, <, > need length check + issubset
                        len_a = self.builder.call(
                            shelpers["len"], [left], name="scmp.la"
                        );
                        len_b = self.builder.call(
                            shelpers["len"], [right], name="scmp.lb"
                        );
                        if op == Tok.EE or op == Tok.NE {
                            # == : len(a)==len(b) and issubset(a,b)
                            len_eq = self.builder.icmp_unsigned(
                                "==", len_a, len_b, name="scmp.leq"
                            );
                            func = self.builder.basic_block.function;
                            check_bb = func.append_basic_block(name="scmp.check");
                            false_bb = func.append_basic_block(name="scmp.false");
                            done_bb = func.append_basic_block(name="scmp.done");
                            self.builder.cbranch(len_eq, check_bb, false_bb);
                            self.builder.position_at_start(check_bb);
                            sub_val = _se.emit_issubset(_ctx, left, [right]);
                            after_bb = self.builder.basic_block;
                            is_sub = self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="scmp.issub"
                            );
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(false_bb);
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(done_bb);
                            result = self.builder.phi(i1_t, name="scmp.result");
                            result.add_incoming(is_sub, after_bb);
                            result.add_incoming(ir.Constant(i1_t, 0), false_bb);
                            if op == Tok.NE {
                                return self.builder.not_(result, name="scmp.ne");
                            }
                            return result;
                        }
                        if op == Tok.LT {
                            # a < b: len(a) < len(b) and issubset(a, b)
                            len_lt = self.builder.icmp_unsigned(
                                "<", len_a, len_b, name="slt.lcmp"
                            );
                            func = self.builder.basic_block.function;
                            check_bb = func.append_basic_block(name="slt.check");
                            false_bb = func.append_basic_block(name="slt.false");
                            done_bb = func.append_basic_block(name="slt.done");
                            self.builder.cbranch(len_lt, check_bb, false_bb);
                            self.builder.position_at_start(check_bb);
                            sub_val = _se.emit_issubset(_ctx, left, [right]);
                            after_bb = self.builder.basic_block;
                            is_sub = self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="slt.issub"
                            );
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(false_bb);
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(done_bb);
                            result = self.builder.phi(i1_t, name="slt.result");
                            result.add_incoming(is_sub, after_bb);
                            result.add_incoming(ir.Constant(i1_t, 0), false_bb);
                            return result;
                        }
                        if op == Tok.GT {
                            # a > b: len(b) < len(a) and issubset(b, a)
                            len_gt = self.builder.icmp_unsigned(
                                "<", len_b, len_a, name="sgt.lcmp"
                            );
                            func = self.builder.basic_block.function;
                            check_bb = func.append_basic_block(name="sgt.check");
                            false_bb = func.append_basic_block(name="sgt.false");
                            done_bb = func.append_basic_block(name="sgt.done");
                            self.builder.cbranch(len_gt, check_bb, false_bb);
                            self.builder.position_at_start(check_bb);
                            sub_val = _se.emit_issubset(_ctx, right, [left]);
                            after_bb = self.builder.basic_block;
                            is_sub = self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="sgt.issub"
                            );
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(false_bb);
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(done_bb);
                            result = self.builder.phi(i1_t, name="sgt.result");
                            result.add_incoming(is_sub, after_bb);
                            result.add_incoming(ir.Constant(i1_t, 0), false_bb);
                            return result;
                        }
                    }
                }
                break;
            }
        }
        # Range comparison: JacRange* == / != JacRange*
        rtype_ptr = self.range_struct_type.as_pointer();
        if left.type == rtype_ptr
        and right.type == rtype_ptr
        and (op == Tok.EE or op == Tok.NE) {
            i1_t = ir.IntType(1);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);
            # Compare start, stop, step
            as_ = self.builder.load(
                self.builder.gep(left, [z0, ir.Constant(i32, 0)], name="rcmp.as.p"),
                name="rcmp.as"
            );
            bs_ = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 0)], name="rcmp.bs.p"),
                name="rcmp.bs"
            );
            ae = self.builder.load(
                self.builder.gep(left, [z0, ir.Constant(i32, 1)], name="rcmp.ae.p"),
                name="rcmp.ae"
            );
            be = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 1)], name="rcmp.be.p"),
                name="rcmp.be"
            );
            at = self.builder.load(
                self.builder.gep(left, [z0, ir.Constant(i32, 2)], name="rcmp.at.p"),
                name="rcmp.at"
            );
            bt = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 2)], name="rcmp.bt.p"),
                name="rcmp.bt"
            );
            seq = self.builder.icmp_signed("==", as_, bs_, name="rcmp.seq");
            eeq = self.builder.icmp_signed("==", ae, be, name="rcmp.eeq");
            teq = self.builder.icmp_signed("==", at, bt, name="rcmp.teq");
            result = self.builder.and_(
                seq, self.builder.and_(eeq, teq, name="rcmp.et"), name="rcmp.all"
            );
            if op == Tok.NE {
                return self.builder.not_(result, name="rcmp.ne");
            }
            return result;
        }
        # Complex comparison: JacComplex* == / != JacComplex*
        ctype_ptr = self.complex_struct_type.as_pointer();
        if left.type == ctype_ptr and right.type == ctype_ptr {
            i1_t = ir.IntType(1);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);
            z1 = ir.Constant(i32, 1);
            ar = self.builder.load(
                self.builder.gep(left, [z0, z0], name="ceq.ar.p"), name="ceq.ar"
            );
            ai = self.builder.load(
                self.builder.gep(left, [z0, z1], name="ceq.ai.p"), name="ceq.ai"
            );
            br = self.builder.load(
                self.builder.gep(right, [z0, z0], name="ceq.br.p"), name="ceq.br"
            );
            bi = self.builder.load(
                self.builder.gep(right, [z0, z1], name="ceq.bi.p"), name="ceq.bi"
            );
            req = self.builder.fcmp_ordered("==", ar, br, name="ceq.r");
            ieq = self.builder.fcmp_ordered("==", ai, bi, name="ceq.i");
            result = self.builder.and_(req, ieq, name="ceq.both");
            if op == Tok.EE {
                return result;
            } elif op == Tok.NE {
                return self.builder.not_(result, name="ceq.ne");
            }
        }
        # For other pointer types (structs, tuples), use pointer comparison
        if op == Tok.EE {
            return self.builder.icmp_unsigned("==", left, right, name="ptreq");
        } elif op == Tok.NE {
            return self.builder.icmp_unsigned("!=", left, right, name="ptrne");
        }
        return None;
    }
    if is_float {
        # IEEE 754: != must use unordered compare so NaN != NaN → true.
        # All other comparisons use ordered (NaN → false).
        if op == Tok.NE {
            return self.builder.fcmp_unordered("!=", left, right, name="fcmp");
        }
        fcmp_map: dict[(str, str)] = {
            Tok.EE: "==",
            Tok.LT: "<",
            Tok.GT: ">",
            Tok.LTE: "<=",
            Tok.GTE: ">="
        };
        if op in fcmp_map {
            return self.builder.fcmp_ordered(fcmp_map[op], left, right, name="fcmp");
        }
    } else {
        icmp_map: dict[(str, str)] = {
            Tok.EE: "==",
            Tok.NE: "!=",
            Tok.LT: "<",
            Tok.GT: ">",
            Tok.LTE: "<=",
            Tok.GTE: ">="
        };
        if op in icmp_map {
            # Harmonize integer widths: sign-extend the narrower operand so
            # icmp_signed gets matching types (e.g. i32 == i64(-1) → sext i32).
            if isinstance(left.type, ir.IntType)
            and isinstance(right.type, ir.IntType) {
                if left.type.width < right.type.width {
                    left = self.builder.sext(left, right.type, name="sext.l");
                } elif right.type.width < left.type.width {
                    right = self.builder.sext(right, left.type, name="sext.r");
                }
            }
            return self.builder.icmp_signed(icmp_map[op], left, right, name="icmp");
        }
    }
    return None;
}

# ─── Phase 1: Enums ──────────────────────────────────────────
"""Infer the struct type name from an LLVM value's type."""
impl NaIRGenPass._infer_type_name(val: ir.Value) -> (str | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (sname, stype) in self.struct_types.items() {
        if val.type == stype.as_pointer() {
            return sname;
        }
    }
    return None;
}

"""Infer the list element type name from an LLVM value's type."""
impl NaIRGenPass._infer_list_elem_type(val: ir.Value) -> (str | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (ename, ltype) in self.list_types.items() {
        if val.type == ltype.as_pointer() {
            return ename;
        }
    }
    return None;
}

"""Infer the struct type name of a comprehension loop variable from its collection.
For `for m in piece.raw_moves(self)`, returns 'Move' from the checked type of the
collection expression (`list[Move]`, or `list[Move | None]` via the struct member).
The checker owns this fact (Phase 0/1); the former AST call dissection +
method_ast_sigs MRO walk re-derived it and is gone."""
impl NaIRGenPass._infer_compr_elem_struct(compr: object) -> (str | None) {
    _coll_tk = self._type_key_of(compr.collection);
    if _coll_tk is not None
    and _coll_tk.startswith("list[")
    and _coll_tk.endswith("]") {
        _inner_tk = _coll_tk[5:-1];
        if _inner_tk in self.struct_types {
            return _inner_tk;
        }
        for part in _inner_tk.split("|") {
            if part in self.struct_types {
                return part;
            }
        }
    }
    return None;
}
# ─── Phase 7: String Methods and Builtins ─────────────────────
