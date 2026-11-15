obj CatalogResolver {
    def resolve_module(path: str) -> (Module | None) abst;
    def resolve_shared(
        module_path: str, dotted: str, class_name: str
    ) -> (ClassDetailsShared | None) abst;
}
