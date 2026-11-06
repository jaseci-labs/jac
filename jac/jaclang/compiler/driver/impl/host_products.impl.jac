impl bytecode_passes(request: ProductRequest) -> PassSchedule {
    return [JcirBytecodeGenPass];
}

impl native_object_passes(request: ProductRequest) -> PassSchedule {
    return [NativeCompilePass];
}

impl format_passes(request: ProductRequest) -> PassSchedule {
    return [CommentAttachPass, DocIRGenPass, JacFormatPass];
}

impl format_lintfix_passes(request: ProductRequest) -> PassSchedule {
    return [CommentAttachPass, JacAutoLintPass, DocIRGenPass, JacFormatPass];
}

impl python_ast_passes(request: ProductRequest) -> PassSchedule {
    return [PyastBuildPass];
}

impl grammar_passes(request: ProductRequest) -> PassSchedule {
    return [GrammarExtractPass];
}

impl cfg_dot_passes(request: ProductRequest) -> PassSchedule {
    return [CoalesceBBPass];
}

impl normalize_passes(request: ProductRequest) -> PassSchedule {
    return [NormalizePass];
}

impl unparse_passes(request: ProductRequest) -> PassSchedule {
    return [UnparsePass];
}

impl doc_passes(request: ProductRequest) -> PassSchedule {
    return [DocIRGenPass];
}

impl format_text_passes(request: ProductRequest) -> PassSchedule {
    return [JacFormatPass];
}

impl register_host_products {
    register_product(
        CompilationProduct.BYTECODE,
        ProductSpec(needs=[CompilationProduct.PY_IR], passes=bytecode_passes)
    );
    register_product(
        CompilationProduct.NATIVE_OBJECT,
        ProductSpec(
            needs=[CompilationProduct.NATIVE_LOWER],
            passes=native_object_passes,
            drop=drop_native_object
        )
    );
    register_product(CompilationProduct.FORMAT, ProductSpec(passes=format_passes));
    register_product(
        CompilationProduct.FORMAT_LINTFIX, ProductSpec(passes=format_lintfix_passes)
    );
    register_product(
        CompilationProduct.PYTHON_AST, ProductSpec(passes=python_ast_passes, tool=True)
    );
    register_product(
        CompilationProduct.GRAMMAR, ProductSpec(passes=grammar_passes, tool=True)
    );
    register_product(
        CompilationProduct.CFG_DOT, ProductSpec(passes=cfg_dot_passes, tool=True)
    );
    register_product(
        CompilationProduct.NORMALIZE, ProductSpec(passes=normalize_passes, tool=True)
    );
    register_product(
        CompilationProduct.UNPARSE, ProductSpec(passes=unparse_passes, tool=True)
    );
    register_product(CompilationProduct.DOC, ProductSpec(passes=doc_passes, tool=True));
    register_product(
        CompilationProduct.FORMAT_TEXT,
        ProductSpec(passes=format_text_passes, tool=True)
    );
}
