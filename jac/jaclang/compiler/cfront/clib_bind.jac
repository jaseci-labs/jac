import os;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext }
import from jaclang.jac0core.helpers { read_file_with_encoding }


def synthesize_clib_bindings(mod: uni.Module, importer_path: str) -> None {
    imports = [
        k
        for k in mod.get_all_sub_nodes(typ=uni.Import)
        if k.clib_header is not None
    ];
    if not imports {
        return;
    }
    import from jaclang.compiler.c2jac.bindgen {
        parse_header_source,
        collect_descs,
        BindReport
    }
    import from jaclang.compiler.cfront.cbind_ir {
        build_clib_decls,
        attach_synthesized_decls
    }
    base_dir = os.path.dirname(os.path.abspath(importer_path));
    for imp in imports {
        header_rel = imp.clib_header.lit_value;
        header_path = header_rel
            if os.path.isabs(header_rel)
            else os.path.join(base_dir, header_rel);
        allow = [i.name.value for i in imp.items] or None;
        c_src = read_file_with_encoding(header_path);
        (file_ast, macros) = parse_header_source(c_src, header_path);
        rep = BindReport();
        descs = collect_descs(file_ast, allow, None, macros, rep);
        decls = build_clib_decls(imp.loc.orig_src, descs.funcs, descs.structs);
        for dcl in decls {
            dcl.code_context = CodeContext.NATIVE;
        }
        attach_synthesized_decls(imp, decls);
    }
}
