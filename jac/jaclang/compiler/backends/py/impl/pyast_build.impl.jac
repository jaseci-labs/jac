impl wide_integer(value: CgWideInt) -> PyObj {
    digits: list[int] = [];
    acc = 0;
    held = 0;
    for byte in value.magnitude {
        acc = acc | (byte << held);
        held += 8;
        while held >= INT_DIGIT_BITS {
            digits.append(acc & INT_DIGIT_MASK);
            acc = acc >> INT_DIGIT_BITS;
            held -= INT_DIGIT_BITS;
        }
    }
    if held > 0 {
        digits.append(acc & INT_DIGIT_MASK);
    }
    return integer_from_digits(digits, value.negative);
}

impl build_module_ast(root: CgNode, mod_path: str) -> Module {
    return PyAstBuilder(mod_path=mod_path).build_module(root);
}

impl PyAstBuilder.fail(cg: (CgNode | None), message: str) -> PyAstBuildError {
    if cg is None {
        return PyAstBuildError(f"{self.mod_path}: {message}");
    }
    return PyAstBuildError(
        f"{self.mod_path}:{cg.l1}:{cg.c1}: codegen recipe {cg.cls}: {message}"
    );
}

impl PyAstBuilder.build_module(root: CgNode) -> Module {
    if root.cls != "Module" {
        raise self.fail(root, "the module recipe's root must be Module");
    }
    return Module(
        body=self.stmts_at(root, "body"),
        type_ignores=self.type_ignores_at(root, "type_ignores")
    );
}

impl PyAstBuilder.node_of(item: any) -> ast_node {
    if isinstance(item, CgNode) {
        return self.node(item);
    }
    if isinstance(item, ast_node) {
        return item;
    }
    if isinstance(item, CgSplice) {
        raise self.fail(
            None, "a splice reached a field slot; splices belong in statement lists"
        );
    }
    raise self.fail(
        None,
        f"a {type(item).__name__} value reached a node slot; only recipe nodes "
        "lower to AST nodes"
    );
}

impl PyAstBuilder.node(cg: CgNode) -> ast_node {
    category = RECIPE_CATEGORIES.get(cg.cls);
    if category is None {
        raise self.fail(cg, "no JacPython AST class has this name");
    }
    if category == RECIPE_STMT {
        return self.stmt_node(cg);
    }
    if category == RECIPE_EXPR {
        return self.expr_node(cg);
    }
    if category == RECIPE_OPERATOR {
        return self.operator_node(cg);
    }
    if category == RECIPE_PATTERN {
        return self.pattern_node(cg);
    }
    if category == RECIPE_MODULE {
        return self.build_module(cg);
    }
    return self.part_node(cg);
}

impl PyAstBuilder.stmt_node(cg: CgNode) -> stmt {
    cls = cg.cls;
    if cls == "Expr" {
        return Expr(
            value=self.expr_at(cg, "value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Assign" {
        return Assign(
            targets=self.exprs_at(cg, "targets"),
            value=self.expr_at(cg, "value"),
            type_comment=self.opt_text_at(cg, "type_comment"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Return" {
        return Return(
            value=self.opt_expr_at(cg, "value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "If" {
        return If(
            `test=self.expr_at(cg, "test"),
            body=self.stmts_at(cg, "body"),
            orelse=self.stmts_at(cg, "orelse"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "FunctionDef" {
        return FunctionDef(
            name=self.text_at(cg, "name"),
            args=self.arguments_at(cg, "args"),
            body=self.stmts_at(cg, "body"),
            decorator_list=self.exprs_at(cg, "decorator_list"),
            returns=self.opt_expr_at(cg, "returns"),
            type_comment=self.opt_text_at(cg, "type_comment"),
            type_params=self.type_params_at(cg, "type_params"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "AsyncFunctionDef" {
        return AsyncFunctionDef(
            name=self.text_at(cg, "name"),
            args=self.arguments_at(cg, "args"),
            body=self.stmts_at(cg, "body"),
            decorator_list=self.exprs_at(cg, "decorator_list"),
            returns=self.opt_expr_at(cg, "returns"),
            type_comment=self.opt_text_at(cg, "type_comment"),
            type_params=self.type_params_at(cg, "type_params"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "ClassDef" {
        return ClassDef(
            name=self.text_at(cg, "name"),
            bases=self.exprs_at(cg, "bases"),
            keywords=self.keywords_at(cg, "keywords"),
            body=self.stmts_at(cg, "body"),
            decorator_list=self.exprs_at(cg, "decorator_list"),
            type_params=self.type_params_at(cg, "type_params"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "ImportFrom" {
        return ImportFrom(
            module=self.opt_text_at(cg, "module"),
            names=self.aliases_at(cg, "names"),
            level=self.opt_number_at(cg, "level"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Import" {
        return Import(
            names=self.aliases_at(cg, "names"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "AnnAssign" {
        return AnnAssign(
            target=self.expr_at(cg, "target"),
            annotation=self.expr_at(cg, "annotation"),
            value=self.opt_expr_at(cg, "value"),
            simple=self.number_at(cg, "simple"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "AugAssign" {
        return AugAssign(
            target=self.expr_at(cg, "target"),
            op=self.operator_at(cg, "op"),
            value=self.expr_at(cg, "value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "For" {
        return For(
            target=self.expr_at(cg, "target"),
            iter=self.expr_at(cg, "iter"),
            body=self.stmts_at(cg, "body"),
            orelse=self.stmts_at(cg, "orelse"),
            type_comment=self.opt_text_at(cg, "type_comment"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "AsyncFor" {
        return AsyncFor(
            target=self.expr_at(cg, "target"),
            iter=self.expr_at(cg, "iter"),
            body=self.stmts_at(cg, "body"),
            orelse=self.stmts_at(cg, "orelse"),
            type_comment=self.opt_text_at(cg, "type_comment"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "While" {
        return While(
            `test=self.expr_at(cg, "test"),
            body=self.stmts_at(cg, "body"),
            orelse=self.stmts_at(cg, "orelse"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "With" {
        return With(
            items=self.withitems_at(cg, "items"),
            body=self.stmts_at(cg, "body"),
            type_comment=self.opt_text_at(cg, "type_comment"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "AsyncWith" {
        return AsyncWith(
            items=self.withitems_at(cg, "items"),
            body=self.stmts_at(cg, "body"),
            type_comment=self.opt_text_at(cg, "type_comment"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Try" {
        return Try(
            body=self.stmts_at(cg, "body"),
            handlers=self.handlers_at(cg, "handlers"),
            orelse=self.stmts_at(cg, "orelse"),
            finalbody=self.stmts_at(cg, "finalbody"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "TryStar" {
        return TryStar(
            body=self.stmts_at(cg, "body"),
            handlers=self.handlers_at(cg, "handlers"),
            orelse=self.stmts_at(cg, "orelse"),
            finalbody=self.stmts_at(cg, "finalbody"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Raise" {
        return Raise(
            exc=self.opt_expr_at(cg, "exc"),
            cause=self.opt_expr_at(cg, "cause"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Assert" {
        return Assert(
            `test=self.expr_at(cg, "test"),
            msg=self.opt_expr_at(cg, "msg"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Delete" {
        return Delete(
            targets=self.exprs_at(cg, "targets"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "TypeAlias" {
        return TypeAlias(
            name=self.expr_at(cg, "name"),
            type_params=self.type_params_at(cg, "type_params"),
            value=self.expr_at(cg, "value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Match" {
        return Match(
            subject=self.expr_at(cg, "subject"),
            cases=self.cases_at(cg, "cases"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Global" {
        return Global(
            names=self.texts_at(cg, "names"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Nonlocal" {
        return Nonlocal(
            names=self.texts_at(cg, "names"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Pass" {
        return Pass(
            lineno=cg.l1, col_offset=cg.c1, end_lineno=cg.l2, end_col_offset=cg.c2
        );
    }
    if cls == "Break" {
        return Break(
            lineno=cg.l1, col_offset=cg.c1, end_lineno=cg.l2, end_col_offset=cg.c2
        );
    }
    if cls == "Continue" {
        return Continue(
            lineno=cg.l1, col_offset=cg.c1, end_lineno=cg.l2, end_col_offset=cg.c2
        );
    }
    raise self.fail(cg, "is not a statement class");
}

impl PyAstBuilder.expr_node(cg: CgNode) -> expr {
    cls = cg.cls;
    if cls == "Name" {
        return Name(
            id=self.text_at(cg, "id"),
            ctx=self.ctx_at(cg),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Constant" {
        return Constant(
            value=self.constant(cg, self.required(cg, "value")),
            kind=self.opt_text_at(cg, "kind"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Attribute" {
        return Attribute(
            value=self.expr_at(cg, "value"),
            attr=self.text_at(cg, "attr"),
            ctx=self.ctx_at(cg),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Call" {
        return Call(
            func=self.expr_at(cg, "func"),
            args=self.exprs_at(cg, "args"),
            keywords=self.keywords_at(cg, "keywords"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Subscript" {
        return Subscript(
            value=self.expr_at(cg, "value"),
            slice=self.expr_at(cg, "slice"),
            ctx=self.ctx_at(cg),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "BinOp" {
        return BinOp(
            left=self.expr_at(cg, "left"),
            op=self.operator_at(cg, "op"),
            right=self.expr_at(cg, "right"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Compare" {
        return Compare(
            left=self.expr_at(cg, "left"),
            ops=self.cmpops_at(cg, "ops"),
            comparators=self.exprs_at(cg, "comparators"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "BoolOp" {
        return BoolOp(
            op=self.boolop_at(cg, "op"),
            values=self.exprs_at(cg, "values"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "UnaryOp" {
        return UnaryOp(
            op=self.unaryop_at(cg, "op"),
            operand=self.expr_at(cg, "operand"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Tuple" {
        return Tuple(
            elts=self.exprs_at(cg, "elts"),
            ctx=self.ctx_at(cg),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "List" {
        return List(
            elts=self.exprs_at(cg, "elts"),
            ctx=self.ctx_at(cg),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Dict" {
        return Dict(
            keys=self.opt_exprs_at(cg, "keys"),
            values=self.exprs_at(cg, "values"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Set" {
        return Set(
            elts=self.exprs_at(cg, "elts"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Lambda" {
        return Lambda(
            args=self.arguments_at(cg, "args"),
            body=self.expr_at(cg, "body"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "IfExp" {
        return IfExp(
            `test=self.expr_at(cg, "test"),
            body=self.expr_at(cg, "body"),
            orelse=self.expr_at(cg, "orelse"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "NamedExpr" {
        return NamedExpr(
            target=self.expr_at(cg, "target"),
            value=self.expr_at(cg, "value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Starred" {
        return Starred(
            value=self.expr_at(cg, "value"),
            ctx=self.ctx_at(cg),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Slice" {
        return Slice(
            lower=self.opt_expr_at(cg, "lower"),
            upper=self.opt_expr_at(cg, "upper"),
            step=self.opt_expr_at(cg, "step"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "JoinedStr" {
        return JoinedStr(
            values=self.exprs_at(cg, "values"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "FormattedValue" {
        return FormattedValue(
            value=self.expr_at(cg, "value"),
            conversion=self.number_at(cg, "conversion"),
            format_spec=self.opt_expr_at(cg, "format_spec"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "TemplateStr" {
        return TemplateStr(
            values=self.exprs_at(cg, "values"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Interpolation" {
        return Interpolation(
            value=self.expr_at(cg, "value"),
            str=self.constant(cg, self.required(cg, "str")),
            conversion=self.number_at(cg, "conversion"),
            format_spec=self.opt_expr_at(cg, "format_spec"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "ListComp" {
        return ListComp(
            elt=self.expr_at(cg, "elt"),
            generators=self.generators_at(cg, "generators"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "SetComp" {
        return SetComp(
            elt=self.expr_at(cg, "elt"),
            generators=self.generators_at(cg, "generators"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "GeneratorExp" {
        return GeneratorExp(
            elt=self.expr_at(cg, "elt"),
            generators=self.generators_at(cg, "generators"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "DictComp" {
        return DictComp(
            key=self.expr_at(cg, "key"),
            value=self.expr_at(cg, "value"),
            generators=self.generators_at(cg, "generators"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Await" {
        return Await(
            value=self.expr_at(cg, "value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "Yield" {
        return Yield(
            value=self.opt_expr_at(cg, "value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "YieldFrom" {
        return YieldFrom(
            value=self.expr_at(cg, "value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    raise self.fail(cg, "is not an expression class");
}

impl PyAstBuilder.pattern_node(cg: CgNode) -> pattern {
    cls = cg.cls;
    if cls == "MatchValue" {
        return MatchValue(
            value=self.expr_at(cg, "value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "MatchAs" {
        return MatchAs(
            pattern=self.opt_pattern_at(cg, "pattern"),
            name=self.opt_text_at(cg, "name"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "MatchOr" {
        return MatchOr(
            patterns=self.patterns_at(cg, "patterns"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "MatchSequence" {
        return MatchSequence(
            patterns=self.patterns_at(cg, "patterns"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "MatchMapping" {
        return MatchMapping(
            keys=self.exprs_at(cg, "keys"),
            patterns=self.patterns_at(cg, "patterns"),
            rest=self.opt_text_at(cg, "rest"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "MatchClass" {
        return MatchClass(
            cls=self.expr_at(cg, "cls"),
            patterns=self.patterns_at(cg, "patterns"),
            kwd_attrs=self.texts_at(cg, "kwd_attrs"),
            kwd_patterns=self.patterns_at(cg, "kwd_patterns"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "MatchSingleton" {
        return MatchSingleton(
            value=self.constant(cg, self.required(cg, "value")),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "MatchStar" {
        return MatchStar(
            name=self.opt_text_at(cg, "name"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    raise self.fail(cg, "is not a pattern class");
}

impl PyAstBuilder.operator_node(cg: CgNode) -> ast_node {
    cls = cg.cls;
    if cls == "Load" {
        return Load();
    }
    if cls == "Store" {
        return Store();
    }
    if cls == "Del" {
        return Del();
    }
    if cls == "And" {
        return And();
    }
    if cls == "Or" {
        return Or();
    }
    if cls == "Add" {
        return Add();
    }
    if cls == "Sub" {
        return Sub();
    }
    if cls == "Mult" {
        return Mult();
    }
    if cls == "MatMult" {
        return MatMult();
    }
    if cls == "Div" {
        return Div();
    }
    if cls == "Mod" {
        return Mod();
    }
    if cls == "Pow" {
        return Pow();
    }
    if cls == "LShift" {
        return LShift();
    }
    if cls == "RShift" {
        return RShift();
    }
    if cls == "BitOr" {
        return BitOr();
    }
    if cls == "BitXor" {
        return BitXor();
    }
    if cls == "BitAnd" {
        return BitAnd();
    }
    if cls == "FloorDiv" {
        return FloorDiv();
    }
    if cls == "Invert" {
        return Invert();
    }
    if cls == "Not" {
        return Not();
    }
    if cls == "UAdd" {
        return UAdd();
    }
    if cls == "USub" {
        return USub();
    }
    if cls == "Eq" {
        return Eq();
    }
    if cls == "NotEq" {
        return NotEq();
    }
    if cls == "Lt" {
        return Lt();
    }
    if cls == "LtE" {
        return LtE();
    }
    if cls == "Gt" {
        return Gt();
    }
    if cls == "GtE" {
        return GtE();
    }
    if cls == "Is" {
        return Is();
    }
    if cls == "IsNot" {
        return IsNot();
    }
    if cls == "In" {
        return In();
    }
    if cls == "NotIn" {
        return NotIn();
    }
    raise self.fail(cg, "is not an operator or context class");
}

impl PyAstBuilder.part_node(cg: CgNode) -> ast_node {
    cls = cg.cls;
    if cls == "keyword" {
        return keyword(
            arg=self.opt_text_at(cg, "arg"),
            value=self.expr_at(cg, "value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "arg" {
        return arg(
            arg=self.text_at(cg, "arg"),
            annotation=self.opt_expr_at(cg, "annotation"),
            type_comment=self.opt_text_at(cg, "type_comment"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "arguments" {
        return arguments(
            posonlyargs=self.args_at(cg, "posonlyargs"),
            args=self.args_at(cg, "args"),
            vararg=self.opt_arg_at(cg, "vararg"),
            kwonlyargs=self.args_at(cg, "kwonlyargs"),
            kw_defaults=self.opt_exprs_at(cg, "kw_defaults"),
            kwarg=self.opt_arg_at(cg, "kwarg"),
            defaults=self.exprs_at(cg, "defaults")
        );
    }
    if cls == "alias" {
        return alias(
            name=self.text_at(cg, "name"),
            asname=self.opt_text_at(cg, "asname"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "comprehension" {
        return comprehension(
            target=self.expr_at(cg, "target"),
            iter=self.expr_at(cg, "iter"),
            ifs=self.exprs_at(cg, "ifs"),
            is_async=self.number_at(cg, "is_async")
        );
    }
    if cls == "ExceptHandler" {
        return ExceptHandler(
            type=self.opt_expr_at(cg, "type"),
            name=self.opt_text_at(cg, "name"),
            body=self.stmts_at(cg, "body"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "withitem" {
        return withitem(
            context_expr=self.expr_at(cg, "context_expr"),
            optional_vars=self.opt_expr_at(cg, "optional_vars")
        );
    }
    if cls == "match_case" {
        return match_case(
            pattern=self.pattern_of(self.required(cg, "pattern")),
            guard=self.opt_expr_at(cg, "guard"),
            body=self.stmts_at(cg, "body")
        );
    }
    if cls == "TypeVar" {
        return TypeVar(
            name=self.text_at(cg, "name"),
            bound=self.opt_expr_at(cg, "bound"),
            default_value=self.opt_expr_at(cg, "default_value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "ParamSpec" {
        return ParamSpec(
            name=self.text_at(cg, "name"),
            default_value=self.opt_expr_at(cg, "default_value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "TypeVarTuple" {
        return TypeVarTuple(
            name=self.text_at(cg, "name"),
            default_value=self.opt_expr_at(cg, "default_value"),
            lineno=cg.l1,
            col_offset=cg.c1,
            end_lineno=cg.l2,
            end_col_offset=cg.c2
        );
    }
    if cls == "TypeIgnore" {
        return TypeIgnore(lineno=self.number_at(cg, "lineno"), tag=self.text_at(cg, "tag"));
    }
    raise self.fail(cg, "has no lowering into JacPython's AST");
}

impl PyAstBuilder.required(cg: CgNode, key: str) -> any {
    if not cg.hasf(key) {
        raise self.fail(cg, f"lacks its required field {key}");
    }
    return cg.get(key);
}

impl PyAstBuilder.optional(cg: CgNode, key: str) -> any {
    if not cg.hasf(key) {
        return None;
    }
    return cg.get(key);
}

impl PyAstBuilder.sequence(cg: CgNode, key: str) -> list[any] {
    if not cg.hasf(key) {
        return [];
    }
    raw = cg.get(key);
    if not isinstance(raw, list) {
        raise self.fail(cg, f"field {key} holds a {type(raw).__name__}, not a list");
    }
    out: list[any] = [];
    for item in raw {
        if isinstance(item, CgSplice) {
            out.extend(self.splice(item));
        } else {
            out.append(item);
        }
    }
    return out;
}

impl PyAstBuilder.splice(item: CgSplice) -> list[stmt] {
    try {
        parsed = parse_file(item.src, self.mod_path);
    } except syntax_failure as err {
        raise self.fail(
            None, f"a generated Python splice does not parse: {err.msg}\n{item.src}"
        );
    }
    if parsed is None {
        raise self.fail(None, f"a generated Python splice does not parse:\n{item.src}");
    }
    return parsed.body;
}

impl PyAstBuilder.constant(cg: CgNode, value: any) -> PyObj {
    if value is None {
        return py_none();
    }
    if isinstance(value, CgEllipsis) {
        return PyEllipsis(t="ellipsis");
    }
    if isinstance(value, CgWideInt) {
        return wide_integer(value);
    }
    if isinstance(value, bool) {
        return PyBool(t="bool", val=value);
    }
    if isinstance(value, int) {
        return PyInt(t="int", val=value);
    }
    if isinstance(value, float) {
        return PyFloat(t="float", val=value);
    }
    if isinstance(value, str) {
        return PyStr(t="str", val=value);
    }
    if isinstance(value, bytes) {
        return PyBytes(t="bytes", val=list(value));
    }
    raise self.fail(
        cg,
        f"a {type(value).__name__} constant is outside the recipe's constant "
        "domain (None, an ellipsis marker, a wide integer, bool, int, float, str "
        "and bytes)"
    );
}

impl PyAstBuilder.stmt_of(item: any) -> stmt {
    built = self.node_of(item);
    if not isinstance(built, stmt) {
        raise self.fail(
            item if isinstance(item, CgNode) else None,
            "a statement slot holds a node that is not a statement"
        );
    }
    return built;
}

impl PyAstBuilder.expr_of(item: any) -> expr {
    built = self.node_of(item);
    if not isinstance(built, expr) {
        raise self.fail(
            item if isinstance(item, CgNode) else None,
            "an expression slot holds a node that is not an expression"
        );
    }
    return built;
}

impl PyAstBuilder.pattern_of(item: any) -> pattern {
    built = self.node_of(item);
    if not isinstance(built, pattern) {
        raise self.fail(
            item if isinstance(item, CgNode) else None,
            "a pattern slot holds a node that is not a pattern"
        );
    }
    return built;
}

impl PyAstBuilder.expr_at(cg: CgNode, key: str) -> expr {
    return self.expr_of(self.required(cg, key));
}

impl PyAstBuilder.opt_expr_at(cg: CgNode, key: str) -> (expr | None) {
    value = self.optional(cg, key);
    if value is None {
        return None;
    }
    return self.expr_of(value);
}

impl PyAstBuilder.exprs_at(cg: CgNode, key: str) -> list[expr] {
    return [self.expr_of(item) for item in self.sequence(cg, key)];
}

impl PyAstBuilder.opt_exprs_at(cg: CgNode, key: str) -> list[(expr | None)] {
    out: list[(expr | None)] = [];
    for item in self.sequence(cg, key) {
        if item is None {
            out.append(None);
        } else {
            out.append(self.expr_of(item));
        }
    }
    return out;
}

impl PyAstBuilder.stmts_at(cg: CgNode, key: str) -> list[stmt] {
    return [self.stmt_of(item) for item in self.sequence(cg, key)];
}

impl PyAstBuilder.patterns_at(cg: CgNode, key: str) -> list[pattern] {
    return [self.pattern_of(item) for item in self.sequence(cg, key)];
}

impl PyAstBuilder.opt_pattern_at(cg: CgNode, key: str) -> (pattern | None) {
    value = self.optional(cg, key);
    if value is None {
        return None;
    }
    return self.pattern_of(value);
}

impl PyAstBuilder.text_at(cg: CgNode, key: str) -> str {
    value = self.required(cg, key);
    if not isinstance(value, str) {
        raise self.fail(cg, f"field {key} holds a {type(value).__name__}, not a str");
    }
    return value;
}

impl PyAstBuilder.opt_text_at(cg: CgNode, key: str) -> (str | None) {
    value = self.optional(cg, key);
    if value is None {
        return None;
    }
    if not isinstance(value, str) {
        raise self.fail(cg, f"field {key} holds a {type(value).__name__}, not a str");
    }
    return value;
}

impl PyAstBuilder.texts_at(cg: CgNode, key: str) -> list[str] {
    out: list[str] = [];
    for item in self.sequence(cg, key) {
        if not isinstance(item, str) {
            raise self.fail(
                cg, f"field {key} holds a {type(item).__name__}, not a str"
            );
        }
        out.append(item);
    }
    return out;
}

impl PyAstBuilder.number_at(cg: CgNode, key: str) -> int {
    value = self.required(cg, key);
    if isinstance(value, bool) {
        return 1 if value else 0;
    }
    if not isinstance(value, int) {
        raise self.fail(cg, f"field {key} holds a {type(value).__name__}, not an int");
    }
    return value;
}

impl PyAstBuilder.opt_number_at(cg: CgNode, key: str) -> (int | None) {
    if self.optional(cg, key) is None {
        return None;
    }
    return self.number_at(cg, key);
}

impl PyAstBuilder.ctx_at(cg: CgNode) -> expr_context {
    value = self.optional(cg, "ctx");
    if value is None {
        return Load();
    }
    built = self.node_of(value);
    if not isinstance(built, expr_context) {
        raise self.fail(cg, "field ctx is not Load, Store or Del");
    }
    return built;
}

impl PyAstBuilder.arguments_at(cg: CgNode, key: str) -> arguments {
    built = self.node_of(self.required(cg, key));
    if not isinstance(built, arguments) {
        raise self.fail(cg, f"field {key} is not an arguments node");
    }
    return built;
}

impl PyAstBuilder.opt_arg_at(cg: CgNode, key: str) -> (arg | None) {
    value = self.optional(cg, key);
    if value is None {
        return None;
    }
    built = self.node_of(value);
    if not isinstance(built, arg) {
        raise self.fail(cg, f"field {key} is not an arg node");
    }
    return built;
}

impl PyAstBuilder.args_at(cg: CgNode, key: str) -> list[arg] {
    out: list[arg] = [];
    for item in self.sequence(cg, key) {
        built = self.node_of(item);
        if not isinstance(built, arg) {
            raise self.fail(cg, f"field {key} holds a node that is not an arg");
        }
        out.append(built);
    }
    return out;
}

impl PyAstBuilder.keywords_at(cg: CgNode, key: str) -> list[keyword] {
    out: list[keyword] = [];
    for item in self.sequence(cg, key) {
        built = self.node_of(item);
        if not isinstance(built, keyword) {
            raise self.fail(cg, f"field {key} holds a node that is not a keyword");
        }
        out.append(built);
    }
    return out;
}

impl PyAstBuilder.aliases_at(cg: CgNode, key: str) -> list[alias] {
    out: list[alias] = [];
    for item in self.sequence(cg, key) {
        built = self.node_of(item);
        if not isinstance(built, alias) {
            raise self.fail(cg, f"field {key} holds a node that is not an alias");
        }
        out.append(built);
    }
    return out;
}

impl PyAstBuilder.withitems_at(cg: CgNode, key: str) -> list[withitem] {
    out: list[withitem] = [];
    for item in self.sequence(cg, key) {
        built = self.node_of(item);
        if not isinstance(built, withitem) {
            raise self.fail(cg, f"field {key} holds a node that is not a withitem");
        }
        out.append(built);
    }
    return out;
}

impl PyAstBuilder.handlers_at(cg: CgNode, key: str) -> list[excepthandler] {
    out: list[excepthandler] = [];
    for item in self.sequence(cg, key) {
        built = self.node_of(item);
        if not isinstance(built, excepthandler) {
            raise self.fail(
                cg, f"field {key} holds a node that is not an except handler"
            );
        }
        out.append(built);
    }
    return out;
}

impl PyAstBuilder.cases_at(cg: CgNode, key: str) -> list[match_case] {
    out: list[match_case] = [];
    for item in self.sequence(cg, key) {
        built = self.node_of(item);
        if not isinstance(built, match_case) {
            raise self.fail(cg, f"field {key} holds a node that is not a match_case");
        }
        out.append(built);
    }
    return out;
}

impl PyAstBuilder.generators_at(cg: CgNode, key: str) -> list[comprehension] {
    out: list[comprehension] = [];
    for item in self.sequence(cg, key) {
        built = self.node_of(item);
        if not isinstance(built, comprehension) {
            raise self.fail(
                cg, f"field {key} holds a node that is not a comprehension"
            );
        }
        out.append(built);
    }
    return out;
}

impl PyAstBuilder.type_params_at(cg: CgNode, key: str) -> list[type_param] {
    out: list[type_param] = [];
    for item in self.sequence(cg, key) {
        built = self.node_of(item);
        if not isinstance(built, type_param) {
            raise self.fail(cg, f"field {key} holds a node that is not a type param");
        }
        out.append(built);
    }
    return out;
}

impl PyAstBuilder.type_ignores_at(cg: CgNode, key: str) -> list[type_ignore] {
    out: list[type_ignore] = [];
    for item in self.sequence(cg, key) {
        built = self.node_of(item);
        if not isinstance(built, type_ignore) {
            raise self.fail(cg, f"field {key} holds a node that is not a type ignore");
        }
        out.append(built);
    }
    return out;
}

impl PyAstBuilder.operator_at(cg: CgNode, key: str) -> operator {
    built = self.node_of(self.required(cg, key));
    if not isinstance(built, operator) {
        raise self.fail(cg, f"field {key} is not a binary operator");
    }
    return built;
}

impl PyAstBuilder.unaryop_at(cg: CgNode, key: str) -> unaryop {
    built = self.node_of(self.required(cg, key));
    if not isinstance(built, unaryop) {
        raise self.fail(cg, f"field {key} is not a unary operator");
    }
    return built;
}

impl PyAstBuilder.boolop_at(cg: CgNode, key: str) -> boolop {
    built = self.node_of(self.required(cg, key));
    if not isinstance(built, boolop) {
        raise self.fail(cg, f"field {key} is not a boolean operator");
    }
    return built;
}

impl PyAstBuilder.cmpops_at(cg: CgNode, key: str) -> list[cmpop] {
    out: list[cmpop] = [];
    for item in self.sequence(cg, key) {
        built = self.node_of(item);
        if not isinstance(built, cmpop) {
            raise self.fail(cg, f"field {key} holds a node that is not a comparison");
        }
        out.append(built);
    }
    return out;
}
