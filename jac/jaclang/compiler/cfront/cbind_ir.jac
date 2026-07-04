import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }


obj FuncDesc {
    has name: str,
        params: list[tuple[str, str]],
        ret: str,
        variadic: bool = False;
}


obj StructDesc {
    has name: str,
        fields: list[tuple[str, str]];
}


obj ConstDesc {
    has name: str,
        value: int;
}


def _name(src: uni.Source, value: str) -> uni.Name {
    return uni.Name(
        orig_src=src,
        name=Tok.NAME,
        value=value,
        line=0,
        end_line=0,
        col_start=0,
        col_end=max(len(value), 1),
        pos_start=0,
        pos_end=max(len(value), 1)
    );
}


def _tok(src: uni.Source, kind: str, value: str) -> uni.Token {
    return uni.Token(
        orig_src=src,
        name=kind,
        value=value,
        line=0,
        end_line=0,
        col_start=0,
        col_end=max(len(value), 1),
        pos_start=0,
        pos_end=max(len(value), 1)
    );
}


def _type_tag(src: uni.Source, tname: str) -> uni.SubTag {
    ann = _name(src, tname);
    return uni.SubTag[uni.Expr](tag=ann, kid=[ann]);
}


def _ability(src: uni.Source, fd: FuncDesc) -> uni.Ability {
    name_node = _name(src, fd.name);
    pvars: list[uni.ParamVar] = [];
    for (pn, pt) in fd.params {
        pname = _name(src, pn);
        tt = _type_tag(src, pt);
        pvars.append(
            uni.ParamVar(
                name=pname, type_tag=tt, unpack=None, value=None, kid=[pname, tt]
            )
        );
    }
    varargs: uni.ParamVar | None = None;
    if fd.variadic {
        star = _tok(src, Tok.STAR_MUL, "*");
        rest = _name(src, "rest");
        rest_tt = _type_tag(src, "int");
        varargs = uni.ParamVar(
            name=rest,
            type_tag=rest_tt,
            unpack=star,
            value=None,
            kid=[star, rest, rest_tt]
        );
    }
    ret_ann = _name(src, fd.ret);
    sig_kids: list[uni.UniNode] = [*pvars];
    if varargs is not None {
        sig_kids.append(varargs);
    }
    sig_kids.append(ret_ann);
    sig = uni.FuncSignature(
        posonly_params=[],
        params=pvars,
        varargs=varargs,
        kwonlyargs=[],
        kwargs=None,
        return_type=ret_ann,
        kid=sig_kids
    );
    return uni.Ability(
        name_ref=name_node,
        is_async=False,
        is_static=False,
        is_classmethod=False,
        is_abstract=False,
        is_override=False,
        access=None,
        signature=sig,
        body=None,
        decorators=None,
        doc=None,
        kid=[name_node, sig]
    );
}


def _archetype(src: uni.Source, sd: StructDesc) -> uni.Archetype {
    fields: list[uni.ArchHas] = [];
    for (fn, ft) in sd.fields {
        fname = _name(src, fn);
        tt = _type_tag(src, ft);
        hv = uni.HasVar(
            name=fname, type_tag=tt, value=None, defer=False, kid=[fname, tt]
        );
        has_kw = _tok(src, Tok.KW_HAS, "has");
        semi = _tok(src, Tok.SEMI, ";");
        fields.append(
            uni.ArchHas(
                is_static=False,
                vars=[hv],
                is_frozen=False,
                access=None,
                doc=None,
                kid=[has_kw, hv, semi]
            )
        );
    }
    arch_type = _tok(src, Tok.KW_OBJECT, "obj");
    name_node = _name(src, sd.name);
    if fields {
        body_kids: list[uni.UniNode] = [*fields];
    } else {
        body_kids = [_tok(src, Tok.LBRACE, "{"), _tok(src, Tok.RBRACE, "}")];
    }
    return uni.Archetype(
        name=name_node,
        arch_type=arch_type,
        access=None,
        base_classes=[],
        body=fields,
        doc=None,
        decorators=None,
        kid=[arch_type, name_node, *body_kids]
    );
}


def _modpath(src: uni.Source, lib: str) -> uni.ModulePath {
    escaped = lib.replace("\\", "\\\\").replace("\"", "\\\"");
    lit = uni.String(
        orig_src=src,
        name=Tok.STRING.value,
        value=f"\"{escaped}\"",
        line=0,
        end_line=0,
        col_start=0,
        col_end=len(escaped) + 2,
        pos_start=0,
        pos_end=len(escaped) + 2
    );
    return uni.ModulePath(path=[lit], level=0, alias=None, kid=[lit]);
}


def _clib_import(src: uni.Source, lib: str, decls: list) -> uni.Import {
    modpath = _modpath(src, lib);
    imp_kw = _tok(src, Tok.KW_IMPORT, "import");
    from_kw = _tok(src, Tok.KW_FROM, "from");
    lbrace = _tok(src, Tok.LBRACE, "{");
    rbrace = _tok(src, Tok.RBRACE, "}");
    return uni.Import(
        from_loc=modpath,
        items=[],
        is_absorb=False,
        clib_decls=decls,
        kid=[imp_kw, from_kw, modpath, lbrace, *decls, rbrace]
    );
}


def _const_global(src: uni.Source, cd: ConstDesc) -> uni.GlobalVars {
    target = _name(src, cd.name);
    tt = _type_tag(src, "int");
    val = uni.Int(
        orig_src=src,
        name=Tok.INT,
        value=str(cd.value),
        line=0,
        end_line=0,
        col_start=0,
        col_end=len(str(cd.value)),
        pos_start=0,
        pos_end=len(str(cd.value))
    );
    assign = uni.Assignment(
        target=[target], value=val, type_tag=tt, mutable=True, kid=[target, tt, val]
    );
    return uni.GlobalVars(
        access=None, doc=None, assignments=[assign], is_frozen=False, kid=[assign]
    );
}


def build_binding_module(
    lib: str,
    funcs: list[FuncDesc],
    structs: list[StructDesc],
    consts: list[ConstDesc],
    mod_name: str = "bindings"
) -> uni.Module {
    src = uni.Source("", mod_path=f"<cbindgen:{lib}>");
    elements: list[uni.UniNode] = [];
    for sd in structs {
        elements.append(_clib_import(src, lib, [_archetype(src, sd)]));
    }
    for fd in funcs {
        elements.append(_clib_import(src, lib, [_ability(src, fd)]));
    }
    for cd in consts {
        elements.append(_const_global(src, cd));
    }
    if not elements {
        return uni.Module.make_stub(inject_src=src);
    }
    return uni.Module(
        name=mod_name, source=src, doc=None, body=elements, terminals=[], kid=elements
    );
}
