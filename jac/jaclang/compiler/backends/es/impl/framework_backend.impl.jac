impl FrameworkBackend.runtime_module -> str {
    return "@jac/runtime";
}

impl FrameworkBackend.lower_view_expr(expr: es.Expression) -> es.Expression {
    return expr;
}

impl FrameworkBackend._get_setter_name(var_name: str) -> str {
    import from jaclang.compiler.frontend.constant { client_state_setter_name }
    return client_state_setter_name(var_name);
}

impl FrameworkBackend.jsx_factory_name -> str {
    return "__jacJsx";
}

impl FrameworkBackend.vite_aliases -> dict[str, str] {
    return {};
}
