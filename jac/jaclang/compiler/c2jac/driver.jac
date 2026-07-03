import ast as ast3;
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.helpers { read_file_with_encoding }
import from jaclang.compiler.c2jac.tags { Idiom, NodeTag, TagTable }
import from jaclang.compiler.c2jac.boundary { default_tier, default_mechanism }
import from jaclang.compiler.c2jac.mapper { CMapper }
import from jaclang.compiler.c2jac.enum_prepass { build_enum_map }
import from jaclang.compiler.c2jac.uni_builder { CUniBuilder }
import from jaclang.compiler.c2jac.splice { splice_directir }
import from jaclang.compiler.c2jac.comments { inject_tier_b_comments }

def transpile_c_file(
    filename: str,
    include_dirs: (list[str] | None) = None,
    defines: (list[str] | None) = None,
    undefines: (list[str] | None) = None,
    force_includes: (list[str] | None) = None,
    nostdinc: bool = False
) -> tuple[str, TagTable] {
    c_src = read_file_with_encoding(filename);
    if filename.endswith(".i") {
        return transpile_c_str(c_src, filename);
    }

    import from jaclang.compiler.c2jac.preprocess { preprocess_c }
    pre = preprocess_c(
        c_src,
        filename,
        include_dirs=include_dirs,
        defines=defines,
        undefines=undefines,
        force_includes=force_includes,
        nostdinc=nostdinc,
    );
    return transpile_c_str(pre, filename);
}

def transpile_c_str(c_src: str, filename: str) -> tuple[str, TagTable] {
    import from jaclang.vendor.pycparser { c_parser }
    parser = c_parser.CParser();
    try {
        file_ast = parser.parse(c_src, filename);
    } except Exception as e {
        if "Directive" in str(e) {
            raise ValueError(
                f"{filename}: transpile_c_str expects already-preprocessed C, but "
                f"the input still has #include/#define/#pragma/#if directives. "
                f"Use transpile_c_file (or the `jac c2jac` CLI), which preprocesses "
                f".c with pcpp automatically."
            ) from e;
        }
        raise;
    }
    return _transpile_ast(file_ast, c_src, filename);
}

def _transpile_ast(
    file_ast: object, c_src: str, filename: str
) -> tuple[str, TagTable] {
    tags = TagTable();
    _populate_default_tags(file_ast, tags);

    enum_verdicts = build_enum_map(file_ast, tags);

    mapper = CMapper(tags=tags);
    py_mod = mapper.conv(file_ast);
    ast3.fix_missing_locations(py_mod);

    orig_src = uni.Source(c_src, filename);
    uni_mod = PyastBuildPass(
        ir_in=uni.PythonModuleAst(py_mod, orig_src=orig_src), prog=JacProgram(),
    ).ir_out;

    builder = CUniBuilder(src=orig_src, tags=tags, enum_verdicts=enum_verdicts);
    splice_directir(uni_mod, mapper.slot_map, builder);
    uni_mod.has_synthesized_tokens = True;

    jac_str = uni_mod.unparse(requires_format=True);

    jac_str = inject_tier_b_comments(jac_str, tags, uni_mod);
    return (jac_str, tags);
}

def _populate_default_tags(nd: object, tags: TagTable) {
    tier = default_tier(nd);
    mech = default_mechanism(nd);
    coord = nd?.coord;
    line = coord.line if coord and coord.line else 0;
    nt = NodeTag(tier=tier, mechanism=mech, idiom=Idiom.NONE, reason="", c_line=line);
    tags.tag(nd, nt);
    for (_, child) in nd.children() {
        _populate_default_tags(child, tags);
    }
}
