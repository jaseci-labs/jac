"""Isolated test: just exit_archetype — the suspected killer function."""

import ast as ast3;
import from typing { cast, Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.lexer { Tok }

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
    # ==============================
    # decorators (NO comprehension)
    # ==============================
    decorators: list[ast3.expr] = [];

    if nd.decorators {
        for i in nd.decorators {
            decorators.append(cast(ast3.expr, i.gen.py_ast[0]));
        }
    }

    if (sem_decorator := self._get_sem_decorator(nd)) {
        decorators.append(sem_decorator);
    }


    # ==============================
    # base_classes (NO comprehension)
    # ==============================
    base_classes: list[ast3.expr] = [];

    for i in nd.base_classes {
        base_classes.append(cast(ast3.expr, i.gen.py_ast[0]));
    }

    if (nd.arch_type.name != Tok.KW_CLASS) {
        base_classes.append(self.jaclib_obj(nd.arch_type.value.capitalize()));
    }


    # ==============================
    # type_param_asts (already loop)
    # ==============================
    type_param_asts: list[ast3.type_param] = [];

    if nd.type_params {
        for tp in nd.type_params {
            if tp.gen.py_ast {
                type_param_asts.append(cast(ast3.type_param, tp.gen.py_ast[0]));
            }
        }
    }


    # ==============================
    # bases (NO comprehension)
    # ==============================
    bases_tmp: list[ast3.expr] = [];
    for i in base_classes {
        bases_tmp.append(cast(ast3.expr, i));
    }


    # ==============================
    # body cast (NO comprehension)
    # ==============================
    body_tmp: list[ast3.stmt] = [];
    for i in body {
        body_tmp.append(cast(ast3.stmt, i));
    }


    # ==============================
    # decorator_list (NO comprehension)
    # ==============================
    decorator_tmp: list[ast3.expr] = [];
    for i in decorators {
        decorator_tmp.append(cast(ast3.expr, i));
    }


    class_def = self.sync(
        ast3.ClassDef(
            name=nd.name.sym_name,
            bases=bases_tmp,
            keywords=[],
            body=body_tmp,
            decorator_list=decorator_tmp,
            type_params=type_param_asts
        )
    );

    nd.gen.py_ast = [class_def];
}
