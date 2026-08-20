import from jaclang.jac0core.unitree {
    Ability,
    ArchHas,
    Archetype,
    Assignment,
    AstSymbolNode,
    AtomTrailer,
    BinaryExpr,
    BuiltinType,
    Enum,
    FuncCall,
    FuncSignature,
    HasVar,
    IndexSlice,
    Module,
    ModuleItem,
    Name,
    TupleVal,
    UnaryExpr,
    UniNode
}
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.const_fold { fold_const }
import from jaclang.jac0core.constant { OwnershipKind, Tokens as Tok }
import from jaclang.jac0core.diagnostics { E5030, W5031, W5032 }

glob LAYOUT_COMPATIBLE_PRIMITIVES: set[str] = {
         "int",
         "float",
         "bool",
         "str",
         "bytes",
         "i8",
         "u8",
         "i16",
         "u16",
         "i32",
         "u32",
         "i64",
         "u64",
         "f32",
         "f64",

     },
     VTABLE_HEADER_SLOTS: int = 1;

glob LAYOUT_COMPATIBLE_SCALARS: set[str] = LAYOUT_COMPATIBLE_PRIMITIVES | {"type"};

obj FieldInfo {
    has name: str,
        index: int,
        type_tag: str,
        type_node: (UniNode | None) = None,
        default_expr: (UniNode | None) = None,
        owner: str = "",
        is_func_ptr: bool = False,
        decl_node: (UniNode | None) = None;
}

obj MethodSlot {
    has name: str,
        index: int,
        owner: str,
        signature: (UniNode | None) = None;
}

obj ArchetypeLayout {
    has name: str,
        arch_type: str,
        decl_mod: str = "",
        aid: str = "",
        parents: list[str] = [],
        mro: list[str] = [],
        fields: list[FieldInfo] = [],
        field_index: dict[str, int] = {},
        methods: list[MethodSlot] = [],
        method_index: dict[str, int] = {},
        has_vtable: bool = False,
        vtable_by_dispatch: bool = False,
        parent_field_start: dict[str, int] = {},
        is_osp: bool = False,
        is_acyclic: bool = False,
        vtable_ptr_slot: (int | None) = None,
        type_tag_slot: (int | None) = None,
        reports_slot: (int | None) = None;
}

obj EnumMemberLayout {
    has name: str,
        ordinal: int,
        int_value: int = 0,
        str_value: (str | None) = None;
}

obj EnumLayout {
    has name: str,
        underlying: str = "i64",
        is_string_enum: bool = False,
        is_class_form: bool = False,
        all_values_known: bool = True,
        members: list[EnumMemberLayout] = [];
}

glob ACCESSOR_SLOT_SUFFIX: dict[str, str] = {
         "property": "__get__",
         "setter": "__set__",
         "deleter": "__del__"
     };

def accessor_slot_name(field_name: str, acc: Ability) -> (str | None) {
    suffix = ACCESSOR_SLOT_SUFFIX.get(acc.accessor_kind);
    return None if suffix is None else f"{field_name}.{suffix}";
}

def archetype_accessors(arch: Archetype) -> list[tuple[(str, HasVar, Ability)]] {
    out: list[tuple[(str, HasVar, Ability)]] = [];
    for var in arch.get_has_vars() {
        if not var.accessors {
            continue;
        }
        fname = var.name.value if var.name else "field";
        for acc in var.accessors {
            slot = accessor_slot_name(fname, acc);
            if slot is not None {
                out.append((slot, var, acc, ));
            }
        }
    }
    return out;
}

def class_model(prog: any) -> LayoutRegistry {
    """The program's single class model, created on first use.

    Layouts used to live on `module.gen.layout_registry`, one partial model
    per module, merged into each other by aliasing shared layout objects.
    "The layout of class X" then had one answer per module that asked. There
    is now one model per program and one answer.
    """;
    if prog is None {
        return LayoutRegistry();
    }
    model = prog?.class_model;
    if model is None {
        model = LayoutRegistry();
        prog.class_model = model;
    }
    return model;
}

def get_layout_registry(module: Module, prog: any = None) -> LayoutRegistry {
    """The program's class model, with `module`'s archetypes guaranteed in it.

    "Has this module been laid out" is asked of the MODEL, not of
    `module.gen.layout_registry`. Module IR is cached across JacProgram
    instances, so that field outlives the program that set it: a second
    program would find it already populated, skip the pass, and be handed a
    model belonging to a program that no longer owns the compile -- while its
    own `prog.class_model` stayed empty. Two models in play is the exact
    failure the per-module registries had.

    `module.gen.layout_registry` is still assigned, because consumers read it
    directly, but it is a pointer to the shared model rather than a cache key.
    """;
    model = class_model(prog);
    if prog is None {
        reg = module.gen.layout_registry;
        if reg is not None {
            return reg;
        }
    }
    import os;
    path = module.loc.mod_path if module.loc else None;
    key = os.path.realpath(path) if path else "";
    if key and key in model.modules_done {
        return model;
    }

    import from jaclang.jac0core.compiler { run_pass }
    run_pass(LayoutPass, module, prog);
    return module.gen.layout_registry or model;
}


def layout_slot_count(lay: ArchetypeLayout) -> int {
    top = 0;
    for slot in [lay.vtable_ptr_slot, lay.type_tag_slot, lay.reports_slot] {
        if slot is not None and (slot + 1) > top {
            top = slot + 1;
        }
    }
    for finfo in lay.fields {
        if (finfo.index + 1) > top {
            top = finfo.index + 1;
        }
    }
    return top;
}

def arch_decl_module(arch: Archetype) -> str {
    """The realpath of the module that DECLARES this archetype.

    Half of an archetype's identity. Read off the declaration itself rather
    than off a use site, so it does not depend on who is asking or on which
    module happens to be compiling.
    """;
    import os;
    mod = arch.find_parent_of_type(Module);
    path = mod.loc.mod_path if (mod is not None and mod.loc) else None;
    return os.path.realpath(path) if path else "";
}

def archetype_id(arch: Archetype) -> str {
    """`<declaring module realpath>::<name>` -- an archetype's identity.

    A bare name is not an identity: two modules may each declare `Config`,
    and a model spanning the import closure holds both. Keying on the bare
    name made that a collision resolved by import-walk order; keying here
    makes them two entries that cannot be confused.
    """;
    name = arch.name.value if arch.name else "unknown";
    return f"{arch_decl_module(arch)}::{name}";
}

def base_expr_name(base_expr: UniNode) -> (str | None) {
    """The bare name a base expression spells, or None.""";
    if isinstance(base_expr, Name) {
        return base_expr.value;
    }
    if isinstance(base_expr, AstSymbolNode) {
        return base_expr.sym_name;
    }
    return None;
}

def sibling_archetype(arch: Archetype, name: str) -> (Archetype | None) {
    """An archetype of `name` declared in the SAME module as `arch`.

    The symbol a base expression carries is the identity-exact answer, but it
    is not always bound -- a module compiled as somebody's dependency can
    reach layout with its base expressions unresolved, and then a class loses
    the fields it inherits and every method that touches one demotes.

    Falling back to the name within the declaring module is safe where a
    fully bare-name lookup is not: one module cannot declare the same
    archetype name twice, so there is nothing here to confuse. It never
    reaches outside that module, which is where bare names stop being
    identities.
    """;
    mod = arch.find_parent_of_type(Module);
    if mod is None {
        return None;
    }
    for nd in mod.get_all_sub_nodes(Archetype) {
        if nd is not arch and nd.name and nd.name.value == name {
            return nd;
        }
    }
    return None;
}

def base_declaration(base_expr: UniNode) -> (Archetype | None) {
    """The archetype a base expression names, through the symbol it carries.

    Identity comes from the symbol the expression already resolved to, so an
    imported base names the archetype that actually declares it. Matching a
    base expression against a bare-name map of the current module -- the old
    path -- silently dropped a base declared elsewhere and silently accepted
    an unrelated class that happened to share the name.
    """;
    decl: (UniNode | None) = base_expr?.sym?.decl;
    if decl is None {
        return None;
    }
    if isinstance(decl, Archetype) {
        return decl;
    }
    return decl.find_parent_of_type(Archetype);
}

def class_type_decl(cls: any) -> (Archetype | None) {
    """The Archetype a ClassType was built from, or None.

    The type system already resolved this through the symbol table, so it is
    the authoritative answer to "which declaration is this" -- the question
    bare-name lookup could only guess at.
    """;
    shared = cls.shared if cls is not None else None;
    decl = shared.symbol_table if shared is not None else None;
    return decl if isinstance(decl, Archetype) else None;
}


def is_enum_class_type(t: any) -> bool {
    try {
        import from jaclang.compiler.type_system.types { ClassType as _ClassType }
    } except ImportError {
        return False;
    }
    return isinstance(t, _ClassType)
        and t._shared is not None
        and t.shared.is_enum_class;
}

def enum_decl_of(t: any) -> (Enum | Archetype | None) {
    if not is_enum_class_type(t) {
        return None;
    }
    _scope = t.shared.symbol_table;
    if isinstance(_scope, Enum) {
        return _scope;
    }
    return _scope if class_form_enum_scalar(t) is not None else None;
}

def enum_value_type_of(t: any) -> (any | None) {
    return t.shared.enum_value_type if is_enum_class_type(t) else None;
}

def class_form_enum_scalar(t: any) -> (str | None) {
    if not is_enum_class_type(t) {
        return None;
    }
    if not isinstance(t.shared.symbol_table, Archetype) {
        return None;
    }
    _vt = t.shared.enum_value_type;
    if _vt is None or not (_vt?.shared) {
        return None;
    }
    _vname = _vt.shared.class_name;
    return _vname if _vname in ("str", "int") else None;
}

def class_form_enum_decls(module: Module) -> list[Archetype] {
    out: list[Archetype] = [];
    for nd in module.get_all_sub_nodes(Archetype) {
        if nd.name is None {
            continue;
        }
        if class_form_enum_scalar(nd.name.type) is not None {
            out.append(nd);
        }
    }
    return out;
}

def enum_member_literal(value_expr: (UniNode | None)) -> (str | int | None) {
    (folded, val) = fold_const(value_expr);
    if not folded or isinstance(val, bool) or not isinstance(val, (str, int)) {
        return None;
    }
    return val;
}

def is_enum_auto(value_expr: (UniNode | None)) -> bool {
    if not isinstance(value_expr, FuncCall) or value_expr.params {
        return False;
    }
    _target = value_expr.target;
    if not isinstance(_target, Name) {
        return False;
    }
    _sym = _target.sym;
    _decl = _sym.decl if _sym is not None else None;
    if _decl is None {
        return False;
    }
    _item = _decl.find_parent_of_type(ModuleItem);
    if _item is not None and _item.name is not None {
        _from = _item.from_parent.from_loc;
        return (
            _from is not None
            and _from.dot_path_str == "enum"
            and _item.name.value == "auto"
        );
    }
    _mod = _decl.find_parent_of_type(Module);
    return _mod is not None and _mod.name == "enum" and _sym.sym_name == "auto";
}

def resolve_enum_member_values(
    raw_members: list[tuple[(str, (UniNode | None))]]
) -> list[(str | int | None)] {
    out: list[(str | int | None)] = [];
    _max: (int | None) = None;
    _blocked = False;
    for member in raw_members {
        _vnode = member[1];
        if is_enum_auto(_vnode) {
            if _blocked {
                out.append(None);
                continue;
            }
            _next = 1 if _max is None else _max + 1;
            _max = _next;
            out.append(_next);
            continue;
        }
        _lit = enum_member_literal(_vnode);
        if isinstance(_lit, int) {
            _max = _lit if (_max is None or _lit > _max) else _max;
        } else {
            _blocked = True;
        }
        out.append(_lit);
    }
    return out;
}

def class_form_enum_members(scope: any) -> list[tuple[(str, (UniNode | None))]] {
    out: list[tuple[(str, (UniNode | None))]] = [];
    if scope is None or not (scope?.names_in_scope) {
        return out;
    }
    _placed: list[tuple[(int, int, str)]] = [];
    _values: dict[str, UniNode] = {};
    for mname in scope.names_in_scope {
        _sym = scope.names_in_scope.get(mname);
        _decl = _sym.decl if _sym is not None else None;
        _asn = _decl.parent if (_decl is not None) else None;
        if not isinstance(_asn, Assignment) or _asn.value is None {
            continue;
        }
        _placed.append((_asn.loc.first_line, _asn.loc.col_start, mname));
        _values[mname] = _asn.value;
    }
    _placed.sort();
    for entry in _placed {
        out.append((entry[2], _values[entry[2]]));
    }
    return out;
}

def class_form_enum_literal(t: any, member: str) -> (str | int | None) {
    _members = class_form_enum_members(t.shared.symbol_table);
    _values = resolve_enum_member_values(_members);
    for (_idx, _member) in enumerate(_members) {
        if _member[0] == member {
            return _values[_idx];
        }
    }
    return None;
}

def class_form_enum_member(t: any) -> (tuple[(str, (str | int), str)] | None) {
    try {
        import from jaclang.compiler.type_system.types {
            EnumMemberType as _EnumMemberType
        }
    } except ImportError {
        return None;
    }
    if not isinstance(t, _EnumMemberType) or t.enum_class is None {
        return None;
    }
    _scalar = class_form_enum_scalar(t.enum_class);
    if _scalar is None or t.member_info is None {
        return None;
    }
    _name = t.member_info.member_name;
    _lit = class_form_enum_literal(t.enum_class, _name);
    if _scalar == "str" and isinstance(_lit, str) {
        return (_scalar, _lit, _name);
    }
    if _scalar == "int" and isinstance(_lit, int) and not isinstance(_lit, bool) {
        return (_scalar, _lit, _name);
    }
    return None;
}

obj LayoutRegistry {
    has layouts: dict[str, ArchetypeLayout] = {},
        modules_done: set[str] = set(),
        name_index: dict[str, list[str]] = {},
        mro_order: dict[str, list[str]] = {},
        class_parents: dict[str, list[str]] = {},
        topo_order: list[str] = [],
        collisions: dict[str, list[str]] = {},
        enums: dict[str, EnumLayout] = {},
        frozen: bool = False;

    def get_layout(name: str) -> (ArchetypeLayout | None);
    def resolve_id(name: str) -> (str | None);
    def register(lay: ArchetypeLayout) -> None;
    def freeze -> None;
    def get_enum_layout(name: str) -> (EnumLayout | None);
    def resolve_method_owner(arch_name: str, method_name: str) -> (str | None);
    def get_mro(name: str) -> list[str];
    def get_topo_order -> list[str];
    def is_primary_ancestor(child: str, ancestor: str) -> bool;
}

obj LayoutPass(Transform) {
    has ir_in: Module,
        cancel_token: any = None,
        registry: LayoutRegistry postinit,
        isinstance_targets: set[str] postinit,
        _building: set[str] postinit,
        _base_aids: set[str] postinit,
        _closure_archs: dict[str, Archetype] postinit,
        _registered: list[str] postinit;

    def postinit -> None;
    def transform(ir_in: Module) -> Module;
    def _collect_archetypes(module: Module) -> dict[str, Archetype];
    def _collect_isinstance_targets(module: Module) -> None;
    def _mark_module_done(module: Module) -> None;
    def _class_type_of(arch: Archetype) -> any;
    def _lays_out(arch: Archetype) -> bool;
    def _base_archetypes(arch: Archetype) -> list[Archetype];
    def _discover_closure(arch_map: dict[str, Archetype]) -> None;
    def _ancestor_archetypes(arch: Archetype) -> list[Archetype];
    def _ensure_layout(arch: Archetype) -> (str | None);
    def _build_layout(
        arch: Archetype, aid: str, ancestors: list[ArchetypeLayout]
    ) -> ArchetypeLayout;

    def _build_enum_layouts(module: Module) -> None;
    def _compute_acyclicity -> None;
    def _acyclic_walk(aid: str, state: dict[str, int]) -> int;
    def _expand_type_keys(key: str) -> (list[str] | None);
    def _split_top_level(s: str, sep: str) -> list[str];
    def _build_vtable_layout(aid: str) -> None;
    def _validate_obj_fields(arch: Archetype, arch_map: dict[str, Archetype]) -> None;
    def _is_layout_compatible_type(
        type_node: (UniNode | None), arch_map: dict[str, Archetype]
    ) -> bool;
}
