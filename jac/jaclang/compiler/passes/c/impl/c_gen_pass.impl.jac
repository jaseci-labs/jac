impl CGenPass.transform(ir_in: uni.Module) -> uni.Module {
    try {
        self.gen_module(ir_in);
    } except Exception as e {
        ir_in.gen.c_src = f"/* jac2c: C emission failed: {e} */\n";
        if self.strict_c {
            self.emit(
                DIAGNOSTICS["E9001"],
                node_override=ir_in,
                pass_name="CGenPass",
                details=str(e)
            );
        }
    }
    return ir_in;
}

impl CGenPass._unsupported(nd: uni.UniNode, code: str, **kw: object) {
    if self.strict_c {
        self.emit(DIAGNOSTICS[code], node_override=nd, **kw);
    }
}

impl CGenPass.is_ref_arch(arch: uni.Archetype) -> bool {
    return arch_is_ref(arch);
}

impl CGenPass.classify(mod: uni.Module) {
    next_id = C_FIRST_USER_TYPEID;
    for stmt in mod.body {
        if isinstance(stmt, uni.Archetype) and self.is_ref_arch(stmt) {
            name = stmt.name.value;
            self.type_ids[name] = next_id;
            next_id += 1;
        }
    }
    for stmt in mod.body {
        if isinstance(stmt, uni.Archetype) {
            self.index_arch(stmt);
        } elif isinstance(stmt, uni.Ability) and stmt.name_ref is not None {
            self.local_funcs[stmt.name_ref.sym_name] = True;
        }
    }
    self.classify_imports(mod);
}

impl CGenPass.classify_imports(mod: uni.Module) {
    import from jaclang.jac0core.program { JacProgram }
    for path in direct_import_paths(mod) {
        if path in self.seen_imports {
            continue;
        }
        self.seen_imports.append(path);
        sub = self.prog.find_module(path) if self.prog is not None else None;
        if sub is None {
            try {
                sub = JacProgram().compile(file_path=path);
            } except Exception {
                if self.strict_c {
                    raise;
                }
                continue;
            }
        }
        if sub not in self.imported_mods {
            self.imported_mods.append(sub);
        }
        self.index_imported(sub);
    }
}

impl CGenPass.index_imported(sub: uni.Module) {
    next_id = C_FIRST_USER_TYPEID + len(self.type_ids);
    for stmt in sub.body {
        if isinstance(stmt, uni.Archetype) and self.is_ref_arch(stmt) {
            name = stmt.name.value;
            if name in self.type_ids {
                continue;
            }
            self.type_ids[name] = next_id;
            next_id += 1;
            self.extern_types.append(name);
            self.index_arch(stmt);
        } elif isinstance(stmt, uni.Ability) and stmt.name_ref is not None {
            fname = stmt.name_ref.sym_name;
            if fname in self.local_funcs or fname in self.extern_func_defs {
                continue;
            }
            self.extern_funcs.append(fname);
            self.extern_func_defs[fname] = stmt;
        }
    }
}

impl CGenPass.index_arch(arch: uni.Archetype) {
    name = arch.name.value;
    self.arch_nodes[name] = arch;
    omap: dict[str, str] = {};
    dmap: dict[str, uni.Ability] = {};
    for member in (arch.body or []) {
        if isinstance(member, uni.Ability) and member.name_ref is not None {
            mname = member.name_ref.sym_name;
            omap[mname] = name;
            dmap[mname] = member;
        }
    }
    self.method_owners[name] = omap;
    self.method_defs[name] = dmap;
}

impl CGenPass.gen_module(mod: uni.Module) {
    self.classify(mod);
    self.tf = self.shared_type_facts
    or get_shared_type_facts([mod] + self.imported_mods, self.prog);
    if self.strict_c and not self.tf.ok {
        raise ValueError(
            "jac2c: semantic type facts unavailable -- refusing strict C emission"
        );
    }
    self.load_layout(mod);
    try {
        self.facts = get_ownership_facts(mod, self.prog);
    } except Exception {
        if self.strict_c {
            raise;
        }
        self.facts = None;
    }
    self.needs_rt = len(self.type_ids) > 0;
    self.arg_pre = [];
    self.arg_post = [];
    self.cur_pad = "";
    self.hoist_ok = False;
    structs: list[str] = [];
    vtables: list[str] = [];
    protos: list[str] = [];
    funcs: list[str] = [];
    for stmt in mod.body {
        if isinstance(stmt, uni.Archetype) {
            if stmt.name.value in self.type_ids {
                structs.append(self.gen_ref_struct(stmt));
                vt = self.gen_vtable(stmt);
                if vt {
                    vtables.append(vt);
                }
                protos.extend(self.ref_protos(stmt));
                funcs.extend(self.gen_ref_defs(stmt));
            } else {
                structs.append(self.gen_struct(stmt));
            }
        } elif isinstance(stmt, uni.Ability) {
            protos.append(self.func_head(stmt) + ";");
            funcs.append(self.gen_func(stmt));
        }
    }
    parts: list[str] = ["/* Generated from Jac by `jac jac2c`. */"];
    if self.needs_rt {
        parts.append("#include \"jacrt.h\"");
    }
    parts.extend(
        [
            e
            for e in self.extern_decls()
            if e
        ]
    );
    parts.extend(
        [
            s
            for s in structs
            if s
        ]
    );
    parts.extend(
        [
            p
            for p in protos
            if p
        ]
    );
    parts.extend(
        [
            v
            for v in vtables
            if v
        ]
    );
    parts.extend(
        [
            f
            for f in funcs
            if f
        ]
    );
    mod.gen.c_src = "\n\n".join(parts) + "\n";
}

impl CGenPass.extern_decls -> list[str] {
    out: list[str] = [];
    for tname in self.extern_types {
        arch = self.arch_nodes.get(tname);
        if arch is None {
            continue;
        }
        out.append(self.gen_ref_struct(arch));
        out.append("extern " + self.ctor_head(arch) + ";");
        for ab in self.method_list(arch) {
            if ab.name_ref is not None and ab.name_ref.sym_name == "init" {
                continue;
            }
            out.append("extern " + self.method_head(arch, ab) + ";");
        }
    }
    for fname in self.extern_funcs {
        ab = self.extern_func_defs.get(fname);
        if ab is None {
            continue;
        }
        out.append("extern " + self.func_head(ab) + ";");
    }
    return out;
}

impl CGenPass.load_layout(mod: uni.Module) {
    if self.shared_layout is not None {
        self.layout = self.shared_layout;
    } else {
        try {
            self.layout = get_layout_registry(mod, self.prog);
        } except Exception {
            if self.strict_c {
                raise;
            }
            self.layout = None;
        }
    }
    if self.layout is None {
        return;
    }

    for cname in self.type_ids.keys() {
        lay = self.layout.get_layout(cname);
        if lay is not None {
            if cname not in self.tf.field_types {
                self.tf.field_types[cname] = {};
            }
            for fi in lay.fields {
                self.tf.field_types[cname][fi.name] = fi.type_tag;
            }
        }
    }
}

impl CGenPass.has_vtable(name: str) -> bool {
    if self.layout is None {
        return False;
    }
    lay = self.layout.get_layout(name);
    return lay is not None and lay.has_vtable;
}

impl CGenPass.mro_of(name: str) -> list[str] {
    if self.layout is not None {
        lay = self.layout.get_layout(name);
        if lay is not None and lay.mro {
            return lay.mro;
        }
    }
    return [name];
}

impl CGenPass.resolve_override(cls: str, m: str) -> str {
    for c in self.mro_of(cls) {
        if c in self.method_defs and m in self.method_defs[c] {
            return c;
        }
    }
    return cls;
}

impl CGenPass.resolve_introducer(cls: str, m: str) -> str {
    found = cls;
    for c in self.mro_of(cls) {
        if c in self.method_defs and m in self.method_defs[c] {
            found = c;
        }
    }
    return found;
}

impl CGenPass.layout_fields(name: str) -> list {
    if self.layout is not None {
        lay = self.layout.get_layout(name);
        if lay is not None {
            return lay.fields;
        }
    }
    return [];
}

impl CGenPass.c_type(jac_ty: str) -> str {
    if jac_ty in self.type_ids {
        return f"struct {jac_ty} *";
    }
    if jac_ty in C_PRIM_TYPES {
        return C_PRIM_TYPES[jac_ty];
    }
    return f"struct {jac_ty}";
}

impl CGenPass.type_name(type_tag: object) -> str {
    return type_tag_name(type_tag);
}

impl CGenPass.ret_type_name(ret: object) -> str {
    return sig_ret_name(ret);
}

impl CGenPass.gen_struct(arch: uni.Archetype) -> str {
    name = arch.name.value;
    lines: list[str] = [f"struct {name} " + "{"];
    for member in (arch.body or []) {
        if isinstance(member, uni.ArchHas) {
            for hv in member.vars {
                cty = self.c_type(self.type_name(hv.type_tag));
                lines.append(f"    {cty} {hv.name.value};");
            }
        }
    }
    lines.append("};");
    return "\n".join(lines);
}

impl CGenPass.field_list(arch: uni.Archetype) -> list[uni.HasVar] {
    out: list[uni.HasVar] = [];
    for member in (arch.body or []) {
        if isinstance(member, uni.ArchHas) {
            for hv in member.vars {
                out.append(hv);
            }
        }
    }
    return out;
}

impl CGenPass.method_list(arch: uni.Archetype) -> list[uni.Ability] {
    out: list[uni.Ability] = [];
    for member in (arch.body or []) {
        if isinstance(member, uni.Ability) {
            out.append(member);
        }
    }
    return out;
}

impl CGenPass.find_init(arch: uni.Archetype) -> object {
    for cname in self.mro_of(arch.name.value) {
        if cname in self.method_defs and "init" in self.method_defs[cname] {
            return self.method_defs[cname]["init"];
        }
    }
    return None;
}

impl CGenPass.gen_ref_struct(arch: uni.Archetype) -> str {
    name = arch.name.value;
    lines: list[str] = [f"struct {name} " + "{"];
    if self.has_vtable(name) {
        lines.append("    void **__vtable;");
    }
    lfields = self.layout_fields(name);
    if lfields {
        for fi in lfields {
            cty = self.c_type(fi.type_tag);
            lines.append(f"    {cty} {fi.name};");
        }
    } else {
        for hv in self.field_list(arch) {
            cty = self.c_type(self.type_name(hv.type_tag));
            lines.append(f"    {cty} {hv.name.value};");
        }
    }
    lines.append("};");
    return "\n".join(lines);
}

impl CGenPass.gen_vtable(arch: uni.Archetype) -> str {
    name = arch.name.value;
    if not self.has_vtable(name) {
        return "";
    }
    if self.layout is None {
        return "";
    }
    lay = self.layout.get_layout(name);

    slots: list[str] = [];
    for ms in lay.methods {
        while len(slots) <= ms.index {
            slots.append("(void *)0");
        }
        if ms.name == "init" {
            slots[ms.index] = "(void *)0";
        } else {
            owner = self.resolve_override(name, ms.name);
            slots[ms.index] = f"(void *){owner}__{ms.name}";
        }
    }
    entries: list[str] = [f"(void *)\"{name}\""] + slots;
    body = ",\n    ".join(entries);
    return f"static void *{name}__vtable[] = " + "{\n    " + body + "\n};";
}

impl CGenPass.ctor_head(arch: uni.Archetype) -> str {
    name = arch.name.value;
    init = self.find_init(arch);
    params: list[str] = [];
    if isinstance(init, uni.Ability)
    and isinstance(init.signature, uni.FuncSignature)
    and init.signature.params {
        for p in init.signature.params {
            pty = self.c_type(self.type_name(p.type_tag));
            params.append(f"{pty} {p.name.value}");
        }
    }
    ptxt = ", ".join(params) if params else "void";
    return f"struct {name} *{name}__new({ptxt})";
}

impl CGenPass.method_head(arch: uni.Archetype, ab: uni.Ability) -> str {
    cname = arch.name.value;
    mname = ab.name_ref.sym_name if ab.name_ref is not None else "";
    sig = ab.signature;
    ret = self.c_type(
        self.ret_type_name(
            sig.return_type if isinstance(sig, uni.FuncSignature) else None
        )
    );
    params: list[str] = [f"struct {cname} *self"];
    if isinstance(sig, uni.FuncSignature) and sig.params {
        for p in sig.params {
            pty = self.c_type(self.type_name(p.type_tag));
            params.append(f"{pty} {p.name.value}");
        }
    }
    return f"{ret} {cname}__{mname}(" + ", ".join(params) + ")";
}

impl CGenPass.ref_protos(arch: uni.Archetype) -> list[str] {
    name = arch.name.value;
    out: list[str] = [f"static void {name}__dtor(void *self);"];
    out.append(self.ctor_head(arch) + ";");
    for ab in self.method_list(arch) {
        if ab.name_ref is not None and ab.name_ref.sym_name == "init" {
            continue;
        }
        out.append(self.method_head(arch, ab) + ";");
    }
    return out;
}

impl CGenPass.gen_ref_defs(arch: uni.Archetype) -> list[str] {
    out: list[str] = [self.gen_dtor(arch), self.gen_ctor(arch)];
    for ab in self.method_list(arch) {
        if ab.name_ref is not None and ab.name_ref.sym_name == "init" {
            continue;
        }
        out.append(self.gen_method(arch, ab));
    }
    return out;
}

impl CGenPass.gen_dtor(arch: uni.Archetype) -> str {
    name = arch.name.value;
    lines: list[str] = [f"static void {name}__dtor(void *self) " + "{"];
    body: list[str] = [];
    for (fname, fty) in self.all_fields(arch) {
        if fty in self.type_ids {
            body.append(f"    jac_rc_release(((struct {name} *)self)->{fname});");
        }
    }
    if body {
        lines.extend(body);
    } else {
        lines.append("    (void)self;");
    }
    lines.append("}");
    return "\n".join(lines);
}

impl CGenPass.all_fields(arch: uni.Archetype) -> list {
    name = arch.name.value;
    lfields = self.layout_fields(name);
    if lfields {
        out: list = [];
        for fi in lfields {
            out.append((fi.name, fi.type_tag));
        }
        return out;
    }
    out2: list = [];
    for hv in self.field_list(arch) {
        out2.append((hv.name.value, self.type_name(hv.type_tag)));
    }
    return out2;
}

impl CGenPass.gen_ctor(arch: uni.Archetype) -> str {
    name = arch.name.value;
    tid = self.type_ids[name];
    self.enter_method(name);
    lines: list[str] = [self.ctor_head(arch) + " {"];
    lines.append(
        f"    struct {name} *self = (struct {name} *)jac_rc_alloc("
        f"sizeof(struct {name}), {tid}, {name}__dtor);"
    );
    if self.has_vtable(name) {
        lines.append(f"    self->__vtable = {name}__vtable;");
    }

    for (fname, dexpr) in self.field_defaults(arch) {
        lines.append(f"    self->{fname} = " + self.gen_expr(dexpr) + ";");
    }
    init = self.find_init(arch);
    if isinstance(init, uni.Ability) {
        self.local_types = ScopeTypes.for_ability(init.signature, name);
        body = self.gen_block(init.body, 1);
        if body {
            lines.append(body);
        }
    }
    lines.append("    return self;");
    lines.append("}");
    return "\n".join(lines);
}

impl CGenPass.field_defaults(arch: uni.Archetype) -> list {
    out: list = [];
    for cname in reversed(self.mro_of(arch.name.value)) {
        anode = self.arch_nodes.get(cname);
        if anode is None {
            continue;
        }
        for hv in self.field_list(anode) {
            if hv.value is not None {
                out.append((hv.name.value, hv.value));
            }
        }
    }
    return out;
}

impl CGenPass.gen_method(arch: uni.Archetype, ab: uni.Ability) -> str {
    cname = arch.name.value;
    self.enter_method(cname);

    sig = ab.signature;
    self.cur_ret_cty = self.c_type(
        self.ret_type_name(
            sig.return_type if isinstance(sig, uni.FuncSignature) else None
        )
    );
    self.local_types = ScopeTypes.for_ability(sig, cname);
    body = self.gen_block(ab.body, 1);
    return self.method_head(arch, ab) + " {\n" + body + "\n}";
}

impl CGenPass.enter_method(cls: str) {
    self.local_types = {};
    self.owned_locals = [];
    self.cur_class = cls;
    self.local_types["self"] = cls;
}

impl CGenPass.func_head(ab: uni.Ability) -> str {
    name = ab.name_ref.sym_name if ab.name_ref is not None else "";
    sig = ab.signature;
    ret = self.c_type(
        self.ret_type_name(
            sig.return_type if isinstance(sig, uni.FuncSignature) else None
        )
    );
    params: list[str] = [];
    if isinstance(sig, uni.FuncSignature) and sig.params {
        for p in sig.params {
            pty = self.c_type(self.type_name(p.type_tag));
            params.append(f"{pty} {p.name.value}");
        }
    }
    ptxt = ", ".join(params) if params else "void";
    return f"{ret} {name}({ptxt})";
}

impl CGenPass.gen_func(ab: uni.Ability) -> str {
    self.owned_locals = [];
    self.cur_class = "";
    sig = ab.signature;
    self.cur_ret_cty = self.c_type(
        self.ret_type_name(
            sig.return_type if isinstance(sig, uni.FuncSignature) else None
        )
    );
    self.local_types = ScopeTypes.for_ability(sig, "");
    body = self.gen_block(ab.body, 1);
    return self.func_head(ab) + " {\n" + body + "\n}";
}

impl CGenPass.gen_block(stmts: object, ind: int) -> str {
    out: list[str] = [];
    stmt_list = list(stmts or []);
    for (i, st) in enumerate(stmt_list) {
        rendered = self.gen_stmt(st, ind, i == len(stmt_list) - 1);
        if rendered {
            out.append(rendered);
        }
    }
    return "\n".join(out);
}

impl CGenPass.scope_release_lines(pad: str, skip_name: str) -> list[str] {
    out: list[str] = [];
    for v in self.owned_locals {
        if v != skip_name {
            out.append(pad + f"jac_rc_release({v});");
        }
    }
    return out;
}

impl CGenPass.ref_field_store(st: uni.Assignment, pad: str) -> (str | None) {
    if st.type_tag is not None or st.aug_op is not None or st.value is None {
        return None;
    }
    tgt = st.target[0];
    if not isinstance(tgt, uni.AtomTrailer) or not tgt.is_attr {
        return None;
    }
    recv_ty = self.expr_type_name(tgt.target);
    if recv_ty not in self.type_ids {
        return None;
    }
    fname = self.attr_name(tgt.right);
    if recv_ty not in self.tf.field_types
    or fname not in self.tf.field_types[recv_ty] {
        return None;
    }
    fty = self.tf.field_types[recv_ty][fname];
    if fty not in self.type_ids {
        return None;
    }
    recv = self.gen_expr(tgt.target);
    lhs = f"{recv}->{fname}";
    val = self.gen_expr(st.value);
    self.tmp_ctr += 1;
    tmp = f"_jf{self.tmp_ctr}";
    cty = self.c_type(fty);

    moves = self.facts is not None and self.facts.is_owned(st.value);
    lines: list[str] = [pad + "{", pad + f"    {cty} {tmp} = {val};"];
    if not moves {
        lines.append(pad + f"    jac_rc_retain({tmp});");
    }
    lines.append(pad + f"    jac_rc_release({lhs});");
    lines.append(pad + f"    {lhs} = {tmp};");
    lines.append(pad + "}");
    return "\n".join(lines);
}

impl CGenPass.ref_local_copy(st: uni.Assignment, pad: str) -> (str | None) {
    if st.aug_op is not None or st.value is None {
        return None;
    }
    tgt = st.target[0];
    if not isinstance(tgt, uni.Name) or tgt.value in self.local_types {
        return None;
    }
    if st.type_tag is not None {
        ty = self.type_name(st.type_tag);
    } else {
        ty = self.expr_type_name(st.value);
    }
    if ty not in self.type_ids {
        return None;
    }

    if self.facts is not None and self.facts.is_owned(st.value) {
        return None;
    }
    name = tgt.value;
    self.local_types[name] = ty;
    self.owned_locals.append(name);
    cty = self.c_type(ty);
    val = self.gen_expr(st.value);
    if isinstance(st.value, uni.Name)
    and st.value.value in self.owned_locals
    and self.facts is not None
    and self.facts.is_last_use(st.value) {
        self.owned_locals.remove(st.value.value);
        return pad + f"{cty} {name} = {val};";
    }
    return pad + f"{cty} {name} = {val};\n" + pad + f"jac_rc_retain({name});";
}

impl CGenPass.gen_stmt(st: object, ind: int, is_last: bool) -> str {
    pad = "    " * ind;
    outer_pre = self.arg_pre;
    outer_post = self.arg_post;
    outer_pad = self.cur_pad;
    outer_hoist = self.hoist_ok;
    self.arg_pre = [];
    self.arg_post = [];
    self.cur_pad = pad;
    self.hoist_ok = isinstance(st, (uni.Assignment, uni.ExprStmt, uni.ReturnStmt));
    body = self.render_stmt(st, ind, is_last);
    pre = self.arg_pre;
    post = self.arg_post;
    self.arg_pre = outer_pre;
    self.arg_post = outer_post;
    self.cur_pad = outer_pad;
    self.hoist_ok = outer_hoist;
    if not pre and not post {
        return body;
    }
    lines: list[str] = [];
    lines.extend(pre);
    lines.append(body);
    lines.extend(post);
    return "\n".join(lines);
}

impl CGenPass.render_stmt(st: object, ind: int, is_last: bool) -> str {
    pad = "    " * ind;
    if isinstance(st, uni.ReturnStmt) {
        pops = self.exc_pop_lines(pad);
        if st.expr is None {
            lines = pops + self.scope_release_lines(pad, "");
            lines.append(pad + "return;");
            return "\n".join(lines);
        }
        skip_name = "";
        if isinstance(st.expr, uni.Name) and st.expr.value in self.owned_locals {
            skip_name = st.expr.value;
        }
        releases = self.scope_release_lines(pad, skip_name);
        val = self.gen_expr(st.expr);

        argcleanup = self.arg_post;
        self.arg_post = [];
        if not releases and not pops and not argcleanup {
            return pad + "return " + val + ";";
        }

        self.tmp_ctr += 1;
        tmp = f"_ret{self.tmp_ctr}";
        lines = [pad + f"{self.cur_ret_cty} {tmp} = {val};"];
        lines.extend(pops);
        lines.extend(argcleanup);
        lines.extend(releases);
        lines.append(pad + f"return {tmp};");
        return "\n".join(lines);
    }
    if isinstance(st, uni.TryStmt) {
        return self.gen_try(st, ind);
    }
    if isinstance(st, uni.RaiseStmt) {
        return self.gen_raise(st, ind);
    }
    if isinstance(st, uni.Assignment) {
        fld = self.ref_field_store(st, pad);
        if fld is not None {
            return fld;
        }
        loc = self.ref_local_copy(st, pad);
        if loc is not None {
            if is_last {
                cleanup = self.scope_release_lines(pad, "");
                if cleanup {
                    return loc + "\n" + "\n".join(cleanup);
                }
            }
            return loc;
        }
        rendered = pad + self.gen_assign(st) + ";";
        if is_last {
            cleanup = self.scope_release_lines(pad, "");
            if cleanup {
                return rendered + "\n" + "\n".join(cleanup);
            }
        }
        return rendered;
    }
    if isinstance(st, uni.IfStmt) {
        return self.gen_if(st, ind);
    }
    if isinstance(st, uni.WhileStmt) {
        head = pad + "while (" + self.gen_expr(st.condition) + ") {\n";
        return head + self.gen_block(st.body, ind + 1) + "\n" + pad + "}";
    }
    if isinstance(st, uni.IterForStmt) {
        return self.gen_for(st, ind);
    }
    if isinstance(st, uni.ExprStmt) {
        rendered = pad + self.gen_expr(st.expr) + ";";
        if is_last {
            cleanup = self.scope_release_lines(pad, "");
            if cleanup {
                return rendered + "\n" + "\n".join(cleanup);
            }
        }
        return rendered;
    }
    self._unsupported(st, "E4301", stype=type(st).__name__);
    return pad + f"/* jac2c: unsupported statement {type(st).__name__} */";
}

impl CGenPass.gen_for(st: uni.IterForStmt, ind: int) -> str {
    pad = "    " * ind;

    iter_a = st.iter;
    tgt_node = iter_a.target[0];
    tgt = self.gen_expr(tgt_node);
    if iter_a.type_tag is not None {
        ty = self.type_name(iter_a.type_tag);
    } else {
        ty = self.expr_type_name(iter_a.value) or "int";
    }
    if isinstance(tgt_node, uni.Name) {
        self.local_types[tgt_node.value] = ty;
    }
    init = f"{self.c_type(ty)} {tgt} = " + self.gen_expr(iter_a.value);
    step = self.gen_assign(st.count_by);
    cond = self.gen_expr(st.condition);
    head = pad + f"for ({init}; {cond}; {step}) " + "{\n";
    return head + self.gen_block(st.body, ind + 1) + "\n" + pad + "}";
}

impl CGenPass.gen_if(st: uni.IfStmt, ind: int) -> str {
    pad = "    " * ind;
    head = pad + "if (" + self.gen_expr(st.condition) + ") {\n";
    s = head + self.gen_block(st.body, ind + 1) + "\n" + pad + "}";
    eb = st.else_body;
    if eb is None {
        return s;
    }
    if isinstance(eb, uni.ElseIf) {
        return s + " else " + self.gen_if(eb, ind).strip();
    }
    if isinstance(eb, uni.ElseStmt) {
        inner = self.gen_block(eb.body, ind + 1);
        return s + " else {\n" + inner + "\n" + pad + "}";
    }
    return s;
}

impl CGenPass.exc_pop_lines(pad: str) -> list[str] {
    out: list[str] = [];
    i = len(self.exc_frames) - 1;
    while i >= 0 {
        out.append(pad + "jac_exc_pop();");
        i -= 1;
    }
    return out;
}

impl CGenPass.exc_type_name(e: object) -> str {
    if isinstance(e, uni.AtomUnit) {
        return self.exc_type_name(e.value);
    }
    if isinstance(e, uni.Name) {
        return e.value;
    }
    if isinstance(e, uni.FuncCall) {
        return self.exc_type_name(e.target);
    }
    if isinstance(e, uni.AtomTrailer) and e.is_attr {
        return self.attr_name(e.right);
    }
    return "";
}

impl CGenPass.exc_match_cond(et: str, cname: str) -> str {
    if cname == "" or cname == "Exception" or cname == "BaseException" {
        return "1";
    }
    ids: list[int] = [JAC_TYPE_REGISTRY.exception_type_id(cname)];
    for d in JAC_TYPE_REGISTRY.exception_descendants(cname) {
        ids.append(JAC_TYPE_REGISTRY.exception_type_id(d));
    }
    clauses: list[str] = [];
    for i in ids {
        clauses.append(f"{et} == {i}");
    }
    return " || ".join(clauses);
}

impl CGenPass.gen_raise(st: uni.RaiseStmt, ind: int) -> str {
    self.needs_rt = True;
    pad = "    " * ind;
    cause = st.cause;
    if cause is None {
        return pad + "jac_exc_throw((int64_t)jac_exc_current_type(), jac_exc_current_payload());";
    }
    cname = self.exc_type_name(cause);
    tid = JAC_TYPE_REGISTRY.exception_type_id(cname);
    payload = "(void *)0";
    if isinstance(cause, uni.FuncCall) and cause.params {
        for p in cause.params {
            if isinstance(p, uni.Expr) {
                payload = "(void *)" + self.gen_expr(p);
                break;
            }
        }
    }
    return pad + f"jac_exc_throw({tid}, {payload});";
}

impl CGenPass.gen_try(st: uni.TryStmt, ind: int) -> str {
    self.needs_rt = True;
    pad = "    " * ind;
    self.exc_ctr += 1;
    n = self.exc_ctr;
    fr = f"_ef{n}";
    handled = f"_eh{n}";
    et = f"_et{n}";
    lines: list[str] = [pad + "{"];
    lines.append(pad + f"    jac_exc_frame {fr};");
    lines.append(pad + f"    int {handled} = 0;");
    lines.append(pad + f"    if (setjmp({fr}.env) == 0) " + "{");
    lines.append(pad + f"        jac_exc_push(&{fr});");
    self.exc_frames.append(fr);
    body = self.gen_block(st.body, ind + 2);
    self.exc_frames.pop();
    if body {
        lines.append(body);
    }
    lines.append(pad + "        jac_exc_pop();");
    lines.append(pad + f"        {handled} = 1;");
    lines.append(pad + "    } else {");
    lines.append(pad + f"        int {et} = (int)jac_exc_current_type();");
    first = True;
    for exc in (st.excepts or []) {
        cname = self.exc_type_name(exc.ex_type);
        cond = self.exc_match_cond(et, cname);
        kw = "if" if first else "else if";
        first = False;
        lines.append(pad + f"        {kw} ({cond}) " + "{");
        if exc.name is not None {
            bind = exc.name.value;
            lines.append(
                pad + f"            void *{bind} = jac_exc_current_payload();"
            );
            lines.append(pad + f"            (void){bind};");
        }
        lines.append(pad + "            jac_exc_clear();");
        hbody = self.gen_block(exc.body, ind + 3);
        if hbody {
            lines.append(hbody);
        }
        lines.append(pad + f"            {handled} = 1;");
        lines.append(pad + "        }");
    }
    lines.append(pad + "    }");
    if st.finally_body is not None {
        fbody = self.gen_block(st.finally_body.body, ind + 1);
        if fbody {
            lines.append(fbody);
        }
    }
    lines.append(
        pad + f"    if (!{handled}) " + "{ " + "jac_exc_throw((int64_t)jac_exc_current_type(), jac_exc_current_payload()); }"
    );
    lines.append(pad + "}");
    return "\n".join(lines);
}

impl CGenPass.gen_assign(a: uni.Assignment) -> str {
    tgt_node = a.target[0];
    tgt = self.gen_expr(tgt_node);
    if a.type_tag is not None {
        tyname = self.type_name(a.type_tag);
        cty = self.c_type(tyname);
        if isinstance(tgt_node, uni.Name) {
            self.local_types[tgt_node.value] = tyname;
            if tyname in self.type_ids {
                self.owned_locals.append(tgt_node.value);
            }
        }
        if a.value is not None {
            return f"{cty} {tgt} = " + self.gen_expr(a.value);
        }
        return f"{cty} {tgt}";
    }
    if a.aug_op is not None {
        return f"{tgt} {a.aug_op.value} " + self.gen_expr(a.value);
    }

    if isinstance(tgt_node, uni.Name) and tgt_node.value not in self.local_types {
        inferred = self.expr_type_name(a.value);
        if inferred {
            cty = self.c_type(inferred);
            self.local_types[tgt_node.value] = inferred;
            if inferred in self.type_ids {
                self.owned_locals.append(tgt_node.value);
            }
            return f"{cty} {tgt} = " + self.gen_expr(a.value);
        }
    }
    return f"{tgt} = " + self.gen_expr(a.value);
}

impl CGenPass.expr_type_name(e: object) -> str {
    return self.tf.type_of(e, self.local_types);
}

impl CGenPass.c_op(op_val: str) -> str {
    if op_val in C_OP_MAP {
        return C_OP_MAP[op_val];
    }
    return op_val;
}

impl CGenPass.gen_compare_clause(left: object, op_val: str, right: object) -> str {
    if (op_val == "==" or op_val == "!=")
    and (self.expr_type_name(left) == "str" or self.expr_type_name(right) == "str") {
        self.needs_rt = True;
        eq = "jac_str_eq(" + self.gen_expr(left) + ", " + self.gen_expr(right) + ")";
        if op_val == "!=" {
            return f"(!{eq})";
        }
        return f"({eq})";
    }
    cop = self.c_op(op_val);
    return "(" + self.gen_expr(left) + f" {cop} " + self.gen_expr(right) + ")";
}

impl CGenPass.gen_expr(e: object) -> str {
    if isinstance(e, uni.AtomUnit) {
        return self.gen_expr(e.value);
    }
    if isinstance(e, uni.Bool) {
        return "1" if e.value == "True" else "0";
    }
    if isinstance(e, uni.Name) {
        return e.value;
    }
    if isinstance(e, (uni.Int, uni.Float)) {
        return e.value;
    }
    if isinstance(e, uni.String) {
        return e.value;
    }
    if isinstance(e, uni.MultiString) {
        pieces: list[str] = [];
        for s in e.strings {
            if isinstance(s, uni.String) {
                pieces.append(s.value);
            } else {
                self._unsupported(s, "E4302", etype=type(s).__name__);
                return f"/* jac2c: unsupported expr {type(s).__name__} */";
            }
        }
        return " ".join(pieces);
    }
    if isinstance(e, uni.BinaryExpr) {
        if e.op.value == "+"
        and (
            self.expr_type_name(e.left) == "str"
            or self.expr_type_name(e.right) == "str"
        ) {
            self.needs_rt = True;
            return "jac_str_concat(" + self.gen_expr(e.left) + ", " + self.gen_expr(
                e.right
            ) + ")";
        }
        op = self.c_op(e.op.value);
        return "(" + self.gen_expr(e.left) + f" {op} " + self.gen_expr(e.right) + ")";
    }
    if isinstance(e, uni.CompareExpr) {
        clauses: list[str] = [];
        prev = e.left;
        for (op, right) in zip(e.ops, e.rights) {
            clauses.append(self.gen_compare_clause(prev, op.value, right));
            prev = right;
        }
        if len(clauses) == 1 {
            return clauses[0];
        }
        return "(" + " && ".join(clauses) + ")";
    }
    if isinstance(e, uni.UnaryExpr) {
        return self.c_op(e.op.value) + self.gen_expr(e.operand);
    }
    if isinstance(e, uni.AtomTrailer) {
        if e.is_attr {
            recv_ty = self.expr_type_name(e.target);
            sep = "->" if recv_ty in self.type_ids else ".";
            return self.gen_expr(e.target) + sep + self.attr_name(e.right);
        }
        return self.gen_expr(e.target) + "[" + self.gen_expr(e.right) + "]";
    }
    if isinstance(e, uni.FuncCall) {
        return self.gen_call(e);
    }
    self._unsupported(e, "E4302", etype=type(e).__name__);
    return f"/* jac2c: unsupported expr {type(e).__name__} */";
}

impl CGenPass.gen_call(e: uni.FuncCall) -> str {
    tgt = e.target;

    if isinstance(tgt, uni.Name) and tgt.value in self.type_ids {
        args = self.gen_args(e, tgt.value);
        return f"{tgt.value}__new(" + ", ".join(args) + ")";
    }

    if isinstance(tgt, uni.Name)
    and tgt.value == "len"
    and e.params
    and len(e.params) == 1
    and self.expr_type_name(e.params[0]) == "str" {
        self.needs_rt = True;
        return "jac_str_len(" + self.gen_expr(e.params[0]) + ")";
    }

    if isinstance(tgt, uni.AtomTrailer) and tgt.is_attr {
        recv_ty = self.expr_type_name(tgt.target);
        mname = self.attr_name(tgt.right);
        if recv_ty in self.type_ids and mname != "init" {
            recv = self.gen_expr(tgt.target);
            args = self.gen_args(e, recv_ty + "." + mname);
            slot = None;
            if self.layout is not None {
                slot = self.layout.get_method_slot(recv_ty, mname);
            }
            if self.has_vtable(recv_ty) and slot is not None {
                return self.virtual_call(recv_ty, mname, recv, slot, args);
            }
            owner = self.resolve_override(recv_ty, mname);
            selfarg = recv;
            if owner != recv_ty {
                selfarg = f"(struct {owner} *){recv}";
            }
            call_args = [selfarg] + args;
            return f"{owner}__{mname}(" + ", ".join(call_args) + ")";
        }
    }
    args = self.gen_args(e, "");
    return self.gen_expr(tgt) + "(" + ", ".join(args) + ")";
}

impl CGenPass.gen_args(e: uni.FuncCall, callee_key: str) -> list {
    args: list[str] = [];
    idx = 0;
    for p in (e.params or []) {
        if isinstance(p, uni.Expr) {
            args.append(self.emit_arg(p, callee_key, idx));
            idx += 1;
        }
    }
    return args;
}

impl CGenPass.emit_arg(p: uni.Expr, callee_key: str, idx: int) -> str {
    argstr = self.gen_expr(p);
    ty = self.expr_type_name(p);
    if ty not in self.type_ids or self.facts is None or not self.hoist_ok {
        return argstr;
    }
    owned = self.facts.is_owned(p);
    consumed = callee_key != "" and self.facts.is_consumed(callee_key, idx);
    cty = self.c_type(ty);
    if consumed {
        if owned {
            return argstr;
        }
        self.tmp_ctr += 1;
        tmp = f"_arg{self.tmp_ctr}";
        self.arg_pre.append(self.cur_pad + f"{cty} {tmp} = {argstr};");
        self.arg_pre.append(self.cur_pad + f"jac_rc_retain({tmp});");
        return tmp;
    }
    if owned {
        self.tmp_ctr += 1;
        tmp = f"_arg{self.tmp_ctr}";
        self.arg_pre.append(self.cur_pad + f"{cty} {tmp} = {argstr};");
        self.arg_post.append(self.cur_pad + f"jac_rc_release({tmp});");
        return tmp;
    }
    return argstr;
}

impl CGenPass.virtual_call(
    recv_ty: str, mname: str, recv: str, slot: int, args: list
) -> str {
    intro = self.resolve_introducer(recv_ty, mname);
    ab = self.method_defs[intro][mname];
    sig = ab.signature;
    ret = self.c_type(
        self.ret_type_name(
            sig.return_type if isinstance(sig, uni.FuncSignature) else None
        )
    );
    ptypes: list[str] = [f"struct {intro} *"];
    if isinstance(sig, uni.FuncSignature) and sig.params {
        for p in sig.params {
            ptypes.append(self.c_type(self.type_name(p.type_tag)));
        }
    }
    fnty = f"{ret} (*)(" + ", ".join(ptypes) + ")";
    call_args = [f"(struct {intro} *){recv}"] + args;
    return (
        f"(({fnty})jac_vtable_slot({recv}->__vtable, {slot}))(" + ", ".join(
            call_args
        ) + ")"
    );
}

impl CGenPass.attr_name(nd: object) -> str {
    if isinstance(nd, uni.Name) {
        return nd.value;
    }
    return self.gen_expr(nd);
}

impl import_path(mp: uni.ModulePath) -> (str | None) {
    try {
        return mp.resolve_relative_path();
    } except (OSError, ValueError, AttributeError) {
        return None;
    }
}

impl direct_import_paths(mod: uni.Module) -> list[str] {
    out: list[str] = [];
    for stmt in mod.body {
        if not isinstance(stmt, uni.Import) {
            continue;
        }
        for mp in stmt.kid {
            if not isinstance(mp, uni.ModulePath) {
                continue;
            }
            path = import_path(mp);
            if path is None or not path.endswith(".jac") {
                continue;
            }
            if path not in out {
                out.append(path);
            }
        }
    }
    return out;
}

impl discover_import_graph(
    main_path: str, main_mod: uni.Module, prog: any, strict_c: bool = False
) -> list[tuple[str, uni.Module]] {
    import from jaclang.jac0core.program { JacProgram }
    seen: dict[str, uni.Module] = {main_path: main_mod};
    order: list[str] = [main_path];
    queue: list[uni.Module] = [main_mod];
    while queue {
        cur = queue.pop(0);
        for path in direct_import_paths(cur) {
            if path in seen {
                continue;
            }
            sub = prog.find_module(path) if prog is not None else None;
            if sub is None {
                try {
                    sub = JacProgram().compile(file_path=path);
                } except Exception {
                    if strict_c {
                        raise;
                    }
                    continue;
                }
            }
            seen[path] = sub;
            order.append(path);
            queue.append(sub);
        }
    }
    return [(p, seen[p]) for p in order];
}

impl emit_translation_units(
    main_path: str, main_mod: uni.Module, prog: any
) -> list[tuple[str, str]] {
    graph = discover_import_graph(main_path, main_mod, prog, strict_c=True);
    mods = [m for (_, m) in graph];
    reg = get_shared_layout_registry(mods, prog);
    reg_tf = get_shared_type_facts(mods, prog);
    out: list[tuple[str, str]] = [];
    for (path, m) in graph {
        CGenPass(
            ir_in=m,
            prog=prog,
            shared_layout=reg,
            shared_type_facts=reg_tf,
            strict_c=True
        );
        out.append((path, m.gen.c_src or ""));
    }
    return out;
}
