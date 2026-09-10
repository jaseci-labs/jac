impl TypeEvaluator.get_type_of_context_binding(
    item: ExprAsItem, is_async: bool = False
) -> TypeBase {
    context_type = self.get_type_of_expression(item.expr);
    if isinstance(context_type, UnknownType) {
        return context_type;
    }
    enter_type = self.get_type_of_magic_method_call(
        context_type, "__aenter__" if is_async else "__enter__", [], item.expr
    );
    if enter_type is None {
        return context_type;
    }
    return self._unwrap_awaitable_type(enter_type, item.expr)
        if is_async
        else enter_type;
}
