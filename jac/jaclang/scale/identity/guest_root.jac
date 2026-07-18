import from uuid { uuid5, NAMESPACE_DNS, UUID }
import from jaclang.jac0core.constant { Constants as Con }

glob _GUEST_ROOT_NAMESPACE: UUID = uuid5(NAMESPACE_DNS, 'jaseci.scale.guest-root');

"""Resolve the stable deployment scope used to namespace the guest root."""
def resolve_project_scope -> str {
    import from jaclang.project.config { get_config }
    config = get_config();
    if config is not None and config.project.name {
        return config.project.name;
    }
    return 'jaseci';
}

"""Compute the deterministic guest root id for a deployment scope."""
def compute_guest_root_id(project_scope: str | None = None) -> str {
    scope = project_scope if project_scope else resolve_project_scope();
    project_namespace = uuid5(_GUEST_ROOT_NAMESPACE, scope);
    return uuid5(project_namespace, Con.GUEST.value).hex;
}
