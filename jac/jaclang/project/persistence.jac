obj PersistenceConfig {
    has namespace: str = "main";

    def module_facts(module: str) -> tuple[str, str] {
        return (self.namespace, module);
    }
}

def parse_persistence(raw: any, project_name: str) -> PersistenceConfig {
    if (not isinstance(raw, dict) or set(raw) - {'namespace'}) {
        raise ValueError('[persistence] accepts only namespace');
    }
    namespace = raw.get('namespace', project_name.strip() or 'main');
    if not isinstance(namespace, str) or not namespace.strip() {
        raise ValueError('[persistence] namespace must be a nonempty string');
    }
    return PersistenceConfig(namespace=namespace);
}
