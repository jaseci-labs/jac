impl application_edges(
    entry_path: str, app_name: str, app_kind: str, project_root: str
) -> list[tuple[str, str]] {
    checked = kernel_module_facts(
        JacProgram(),
        [entry_path],
        CompileOptions(
            no_cgen=True,
            target_app=app_name,
            app_kind=app_kind,
            project_root=project_root
        ),
        closure=True
    );
    if checked.errors {
        raise ValueError(
            f"app '{app_name}' entry '{entry_path}' does not compile: "
                + diagnostic_text(checked.errors[0])
        );
    }
    return [(edge.consumer, edge.provider) for edge in checked.app_edges];
}
