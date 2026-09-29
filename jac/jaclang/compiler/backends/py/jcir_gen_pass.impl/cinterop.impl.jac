import json;
import from jaclang.compiler.frontend.constant { OwnershipKind, is_borrow_kind }

impl JcirGenPass._clib_block_desc(imp: Import) -> dict[str, any] {
    import from jaclang.compiler.c_interop {
        c_type_spec,
        is_foreign_struct_archetype,
        is_opaque_c_archetype
    }
    lib: dict[str, any] = {};
    if imp.from_loc is not None and imp.from_loc.path {
        names: list[str] = [];
        for part in imp.from_loc.path {
            if isinstance(part, String) {
                raw = part.value;
                if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "\"'" {
                    raw = raw[1:-1];
                }
                lib = {"path": raw};
            } elif isinstance(part, Name) {
                names.append(part.value);
            }
        }
        if names and not lib {
            lib = {"names": names, "level": imp.from_loc.level};
        }
    }
    structs: list[dict[str, any]] = [];
    opaque: list[str] = [];
    functions: list[dict[str, any]] = [];
    for decl in imp.clib_decls or [] {
        if isinstance(decl, Archetype) and is_opaque_c_archetype(decl) {
            opaque.append(decl.name.value);
        } elif isinstance(decl, Archetype) and is_foreign_struct_archetype(decl) {
            fields: list[list[any]] = [];
            for hv in decl.get_has_vars() {
                tag = hv.type_tag.tag if hv.type_tag else None;
                fields.append([hv.name.sym_name, c_type_spec(hv.type, tag)]);
            }
            structs.append({"name": decl.name.value, "fields": fields});
        } elif isinstance(decl, Ability)
            and isinstance(decl.signature, FuncSignature) {
            params: list[list[any]] = [];
            for p in decl.signature.get_parameters() {
                if p.is_vararg or p.is_kwargs {
                    continue;
                }
                tag = p.type_tag.tag if p.type_tag else None;
                spec = c_type_spec(p.type, tag);
                if p.type_tag is not None and is_borrow_kind(p.type_tag.ownership) {
                    spec = [
                        "ref",
                        p.type_tag.ownership == OwnershipKind.MUT_BORROW,
                        spec
                    ];
                }
                params.append([p.name.value, spec]);
            }
            ret_expr = decl.signature.return_type;
            ret_spec: list[any] = ["void"];
            if ret_expr is not None {
                import from jaclang.compiler.types.types { FunctionType }
                fn_type = decl.name_spec.type;
                ret_type = fn_type.return_type
                    if isinstance(fn_type, FunctionType)
                    else None;
                ret_spec = c_type_spec(ret_type, ret_expr);
            }
            functions.append(
                {
                    "name": decl.name_ref.sym_name if decl.name_ref else "",
                    "params": params,
                    "ret": ret_spec,
                    "variadic": decl.signature.varargs is not None
                }
            );
        }
    }
    return {"lib": lib, "structs": structs, "opaque": opaque, "functions": functions};
}

impl JcirGenPass._gen_clib_binding(imp: Import) -> list[CgNode] {
    desc = self._clib_block_desc(imp);
    holder = f"_jac_clib_{self._c_temp_count}";
    self._c_temp_count += 1;
    store = self.nod('Store', [], []);
    out: list[CgNode] = [
        self.nod(
            'Assign',
            ['targets', 'value'],
            [
                [self.nod('Name', ['id', 'ctx'], [holder, store])],
                self.call_node(
                    self.builtin_name('_jac_clib_bind'),
                    [
                        self.call_node(self.name_load('globals'), [], []),
                        self.const_of(json.dumps(desc, separators=(",", ":")))
                    ],
                    []
                )
            ],
            jac_node=imp
        )
    ];
    declared: list[str] = [];
    for key in ["opaque", "structs", "functions"] {
        entries: list[any] = desc[key];
        for item in entries {
            if isinstance(item, str) {
                declared.append(item);
            } else {
                named: dict[str, any] = item;
                declared.append(str(named["name"]));
            }
        }
    }
    for name in declared {
        out.append(
            self.nod(
                'Assign',
                ['targets', 'value'],
                [
                    [
                        self.nod(
                            'Name', ['id', 'ctx'], [name, self.nod('Store', [], [])]
                        )
                    ],
                    self.nod(
                        'Subscript',
                        ['value', 'slice', 'ctx'],
                        [
                            self.name_load(holder),
                            self.const_of(name),
                            self.nod('Load', [], [])
                        ]
                    )
                ]
            )
        );
    }
    return out;
}

impl JcirGenPass._c_temp_name(role: str) -> str {
    name = f"_jac_c{role}{self._c_temp_count}";
    self._c_temp_count += 1;
    return name;
}

impl JcirGenPass._c_named(name: str, value: CgNode) -> CgNode {
    return self.nod(
        'NamedExpr',
        ['target', 'value'],
        [self.nod('Name', ['id', 'ctx'], [name, self.nod('Store', [], [])]), value]
    );
}

impl JcirGenPass._c_interop_call_rewrite(nd: FuncCall) -> None {
    import from jaclang.compiler.c_interop { c_type_spec, is_builtin_pin_call }
    outs = self.outs(nd);
    call = outs[0] if outs else None;
    if is_builtin_pin_call(nd) {
        pinned: (Expr | None) = None;
        for param in (nd.params or []) {
            if not isinstance(param, KWPair) {
                pinned = param;
                break;
            }
        }
        if pinned is not None and isinstance(call, CgNode) and call.cls == 'Call' {
            spec = c_type_spec(pinned.type, None);
            call.items('args').append(self.const_of(json.dumps(spec)));
        }
        return;
    }
    if nd.call_kind != "clib" or not isinstance(nd.callee_decl, Ability) {
        return;
    }
    sig = nd.callee_decl.signature;
    if not isinstance(sig, FuncSignature) {
        return;
    }
    borrowed_at: list[int] = [];
    borrowed_spec: list[list[any]] = [];
    position = 0;
    for p in sig.get_parameters() {
        if p.is_vararg or p.is_kwargs {
            continue;
        }
        index = position;
        position += 1;
        type_tag = p.type_tag;
        if type_tag is None or not is_borrow_kind(type_tag.ownership) {
            continue;
        }
        spec = c_type_spec(p.type, type_tag.tag);
        inner: list[any] = spec;
        if spec[0] == "opt" {
            inner = spec[1];
        }
        if inner[0] == "s" or inner[0] == "ptr" {
            borrowed_at.append(index);
            borrowed_spec.append(inner);
        }
    }
    if not borrowed_at {
        return;
    }
    params: list[Expr | KWPair] = list(nd.params or []);
    if not isinstance(call, CgNode) or call.cls != 'Call' {
        return;
    }
    call_args = call.items('args');
    for param in params {
        if isinstance(param, KWPair) {
            return;
        }
    }
    if len(call_args) != len(params) {
        return;
    }
    pre: list[CgNode] = [];
    post: list[CgNode] = [];
    scope = self.call_node(self.name_load('globals'), [], []);
    for slot_index in range(len(borrowed_at)) {
        i = borrowed_at[slot_index];
        if i >= len(params) {
            continue;
        }
        spec_const = self.const_of(json.dumps(borrowed_spec[slot_index]));
        place = self._place_parts(params[i]);
        if place is None {
            call_args[i] = self.call_node(
                self.builtin_name('_jac_c_cell'), [spec_const, call_args[i], scope], []
            );
            continue;
        }
        cell = self._c_temp_name("cell");
        readback = self.call_node(
            self.nod(
                'Attribute',
                ['value', 'attr', 'ctx'],
                [self.name_load(cell), 'get', self.nod('Load', [], [])]
            ),
            [],
            []
        );
        initial: CgNode;
        if place.kind == 'name' {
            initial = self.name_load(place.name);
            post.append(self._c_named(place.name, readback));
        } else {
            target = place.target;
            key = place.key;
            assert target is not None and key is not None , "attribute and item places carry a target and a key";
            holder = self._c_temp_name("own");
            pre.append(self._c_named(holder, target));
            if place.kind == 'attr' {
                initial = self.nod(
                    'Attribute',
                    ['value', 'attr', 'ctx'],
                    [self.name_load(holder), key.get('value'), self.nod('Load', [], [])]
                );
            } else {
                slot = self._c_temp_name("key");
                pre.append(self._c_named(slot, key));
                initial = self.nod(
                    'Subscript',
                    ['value', 'slice', 'ctx'],
                    [
                        self.name_load(holder),
                        self.name_load(slot),
                        self.nod('Load', [], [])
                    ]
                );
                key = self.name_load(slot);
            }
            helper = '_jac_replace_attr'
                if place.kind == 'attr'
                else '_jac_replace_item';
            post.append(
                self.call_node(
                    self.builtin_name(helper),
                    [self.name_load(holder), key, readback],
                    []
                )
            );
        }
        call_args[i] = self._c_named(
            cell,
            self.call_node(
                self.builtin_name('_jac_c_cell'), [spec_const, initial, scope], []
            )
        );
    }
    elements: list[CgNode] = [];
    elements.extend(pre);
    elements.append(call);
    elements.extend(post);
    sequence = self.nod('Tuple', ['elts', 'ctx'], [elements, self.nod('Load', [], [])]);
    self.set_out(
        nd,
        [
            self.nod(
                'Subscript',
                ['value', 'slice', 'ctx'],
                [sequence, self.const_of(len(pre)), self.nod('Load', [], [])],
                jac_node=nd
            )
        ]
    );
}

impl JcirGenPass._c_copy_rewrite(nd: AtomTrailer) -> None {
    import from jaclang.compiler.c_interop { foreign_read_copies }
    if not foreign_read_copies(nd) {
        return;
    }
    got = self.outs(nd);
    if not got or not isinstance(got[0], CgNode) {
        return;
    }
    self.set_out(
        nd,
        [self.call_node(self.builtin_name('_jac_c_copy'), [got[0]], [], jac_node=nd)]
    );
}
