obj PersistenceConfig {
    has namespace: str = "main";

    def module_facts(module: str) -> tuple[str, str];
}

def parse_persistence(raw: any, project_name: str) -> PersistenceConfig;
