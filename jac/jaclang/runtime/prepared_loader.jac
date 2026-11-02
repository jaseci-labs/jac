import importlib;
import importlib.util;
import os;
import from importlib.abc { Loader, MetaPathFinder }
import from importlib.machinery { ModuleSpec }
import from types { ModuleType }

obj PreparedAliasLoader(Loader) {
    has target: str;

    def create_module(spec: ModuleSpec) -> ModuleType;
    def exec_module(module: ModuleType);
}

obj PreparedLoader(Loader) {
    has application: PreparedApplication;

    def create_module(spec: ModuleSpec) -> ModuleType | None;
    def exec_module(module: ModuleType);
}

obj PreparedFinder(MetaPathFinder) {
    def find_spec(
        fullname: str, path: list[str] | None = None, target: ModuleType | None = None
    ) -> ModuleSpec | None;
}
