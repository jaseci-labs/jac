import logging;
import from uuid { uuid5, NAMESPACE_DNS, UUID }
import from jaclang.jac0core.constant { Constants as Con }

glob _GUEST_ROOT_NAMESPACE: UUID = uuid5(NAMESPACE_DNS, 'jaseci.scale.guest-root'),
     _DEFAULT_SCOPE: str = 'jaseci',
     _scope_fallback_warned: list = [False],
     logger = logging.getLogger(__name__);

def resolve_project_scope -> str {
    import from jaclang.project.config { get_config }
    config = get_config();
    if config is not None and config.project.name {
        return config.project.name;
    }
    if not _scope_fallback_warned[0] {
        _scope_fallback_warned[0] = True;
        logger.warning(
            "Guest root scope falling back to '%s' because [project] name is "
            "unset in jac.toml; distinct projects sharing one backend would "
            "then share the same anonymous guest graph.",
            _DEFAULT_SCOPE
        );
    }
    return _DEFAULT_SCOPE;
}

def compute_guest_root_id(project_scope: str | None = None) -> str {
    scope = project_scope or resolve_project_scope();
    project_namespace = uuid5(_GUEST_ROOT_NAMESPACE, scope);
    return uuid5(project_namespace, Con.GUEST.value).hex;
}
