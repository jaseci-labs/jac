impl PyastGenPass.exit_archetype(self: PyastGenPass, nd: uni.Archetype) -> None {
    inner: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None = None;
    if isinstance(nd.body, uni.ImplDef) {
        inner = nd.body.body if not isinstance(nd.body.body, uni.Expr) else None;
    } elif not isinstance(nd.body, uni.Expr) {
        inner = nd.body;
    }
    body: list[ast3.AST] = self.resolve_stmt_block(inner, doc=nd.doc);
    if (not body and not isinstance(nd.body, uni.Expr)) {
        self.log_error('Archetype has no body. Perhaps an impl must be imported.', nd);
        body = [self.sync(ast3.Pass(), nd)];
    }
    if nd.is_async {
        body.insert(
            0,
            self.sync(
                ast3.Assign(
                    targets=[
                        self.sync(ast3.Name(id='__jac_async__', ctx=ast3.Store()))
                    ],
                    value=self.sync(ast3.Constant(value=nd.is_async))
                )
            )
        );
    }
    decorators = [cast(ast3.expr, i.gen.py_ast[0]) for i in nd.decorators]
    if nd.decorators
    else [];
    if (sem_decorator := self._get_sem_decorator(nd)) {
        decorators.append(sem_decorator);
    }
    base_classes = [cast(ast3.expr, i.gen.py_ast[0]) for i in nd.base_classes];
    if (nd.arch_type.name != Tok.KW_CLASS) {
        base_classes.append(self.jaclib_obj(nd.arch_type.value.capitalize()));
    }
    type_param_asts: list[ast3.type_param] = [];
    if nd.type_params {
        for tp in nd.type_params {
            if tp.gen.py_ast {
                type_param_asts.append(cast(ast3.type_param, tp.gen.py_ast[0]));
            }
        }
    }
    class_def = self.sync(
        ast3.ClassDef(
            name=nd.name.sym_name,
            bases=[cast(ast3.expr, i) for i in base_classes],
            keywords=[],
            body=[cast(ast3.stmt, i) for i in body],
            decorator_list=[cast(ast3.expr, i) for i in decorators],
            type_params=type_param_asts
        )
    );
    nd.gen.py_ast = [class_def];
}
