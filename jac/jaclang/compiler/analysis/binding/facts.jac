import from jaclang.compiler.ir.enums { CodeContext }

obj ImportEdge {
    has target: str,
        jac: bool,
        is_comptime: bool,
        context: CodeContext,
        top_level: bool,
        from_import: bool = False;
}
