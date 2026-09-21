"""Project declarations for durable graph identity, independent of deployment."""

class PersistenceAccessError(ValueError) {}

obj PersistenceDomain {
    has name: str,
        owner: str,
        apps: list[str],
        modules: list[str];
}

obj PersistenceConfig {
    has namespace: str = "main",
        domains: dict[str, PersistenceDomain] = {};

    def module_facts(module: str, app: str) -> tuple[str, ...] {
        for domain in self.domains.values() {
            if module in domain.modules {
                if app not in domain.apps {
                    raise PersistenceAccessError(
                        f"App '{app}' imports persistence module '{module}' in "
                        f"domain '{domain.name}' without being a declared participant"
                    );
                }
                return (self.namespace, app, 'domain:' + domain.name, module, domain.owner);
            }
        }
        return (self.namespace, app, 'app:' + app, module, app);
    }
}

def parse_persistence(raw: any, project_name: str, apps: list[str]) -> PersistenceConfig {
    if (not isinstance(raw, dict) or set(raw) - {'namespace', 'domains'}) {
        raise ValueError('[persistence] accepts only namespace and domains');
    }
    namespace = raw.get('namespace', project_name or 'main');
    if not isinstance(namespace, str) or not namespace.strip() {
        raise ValueError('[persistence] namespace must be a nonempty string');
    }
    config = PersistenceConfig(namespace=namespace);
    domains = raw.get('domains', {});
    if not isinstance(domains, dict) {
        raise ValueError('[persistence.domains] must be a table');
    }
    claimed: dict[str, str] = {};
    for (name, table) in domains.items() {
        if (not isinstance(table, dict) or set(table) != {'owner', 'apps', 'modules'}) {
            raise ValueError(f'[persistence.domains.{name}] requires owner, apps and modules');
        }
        owner = table['owner'];
        members = table['apps'];
        modules = table['modules'];
        if not isinstance(owner, str) or owner not in apps {
            raise ValueError(f"Persistence domain '{name}' has unknown owner '{owner}'");
        }
        if not isinstance(members, list) or not members or any(
            not isinstance(member, str) or member not in apps for member in members
        ) or owner not in members or len(set(members)) != len(members) {
            raise ValueError(f"Persistence domain '{name}' apps must name unique declared apps including its owner");
        }
        if not isinstance(modules, list) or not modules {
            raise ValueError(f"Persistence domain '{name}' modules must be a nonempty list");
        }
        for module in modules {
            if not isinstance(module, str) or not all(
                part.isidentifier() for part in module.split('.')
            ) {
                raise ValueError(f"Persistence domain '{name}' requires exact dotted module names");
            }
            if module in claimed {
                raise ValueError(f"Persistence module '{module}' is already declared in '{claimed[module]}'");
            }
            claimed[module] = name;
        }
        config.domains[name] = PersistenceDomain(name, owner, members, modules);
    }
    return config;
}
