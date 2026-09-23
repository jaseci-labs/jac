import type from jaclang.compiler.frontend.unitree { Module }
import type from jaclang.compiler.types.types { ClassDetailsShared }

obj CatalogResolver {
    def resolve_module(path: str) -> (Module | None) {
        return None;
    }

    def resolve_shared(
        module_path: str, dotted: str, class_name: str
    ) -> (ClassDetailsShared | None) {
        return None;
    }
}
