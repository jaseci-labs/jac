import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.frontend.helpers { read_file_with_encoding }

test "builtin extensions preserve the original stub source" {
    program = JacProgram();
    program._get_compiler().stub_catalog_disabled = True;
    evaluator = program.get_type_evaluator();
    dict_type = evaluator.prefetch.dict_class;
    assert dict_type is not None;
    source = dict_type.shared.symbol_table.loc.orig_src;
    assert source.code == read_file_with_encoding(source.file_path);
    list_type = evaluator.prefetch.list_class;
    assert list_type is not None;
    assert list_type.lookup_member_symbol("chunks") is not None;
}

test "chunk signatures preserve list element types" {
    program = JacProgram();
    program.compile(
        file_path="chunk_types.jac",
        use_str="def split(xs: list[str]) -> list[list[str]] { return xs.chunks(2); }",
        options=CompileOptions(
            no_cgen=True, no_ir_cache=True, force_target_program=True
        )
    );
    assert not program.errors_had , str(program.errors_had);
}

test "chunk signatures reject an invalid chunk size" {
    program = JacProgram();
    program.compile(
        file_path="chunk_size.jac",
        use_str="def split(xs: list[int]) -> list[list[int]] { return xs.chunks(\"bad\"); }",
        options=CompileOptions(
            no_cgen=True, no_ir_cache=True, force_target_program=True
        )
    );
    assert any("Cannot assign" in str(error) for error in program.errors_had);
}
