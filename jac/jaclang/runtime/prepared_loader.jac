import importlib;
import importlib.util;
import os;
import from importlib.abc { Loader, MetaPathFinder }
import from importlib.machinery { ModuleSpec }
import from types { ModuleType }
import type from jaclang.runtime.prepared { PreparedApplication }

obj PreparedAliasLoader(Loader) {
    has target: str;

    def create_module(spec: ModuleSpec) -> ModuleType {
        return importlib.import_module(self.target);
    }

    def exec_module(module: ModuleType) {}
}

obj PreparedLoader(Loader) {
    has application: PreparedApplication;

    def create_module(spec: ModuleSpec) -> ModuleType | None {
        return None;
    }

    def exec_module(module: ModuleType) {
        import from jaclang.runtime.prepared { execute_module }
        execute_module(module, self.application);
    }
}

obj PreparedFinder(MetaPathFinder) {
    def find_spec(
        fullname: str, path: list[str] | None = None, target: ModuleType | None = None
    ) -> ModuleSpec | None {
        import from jaclang.runtime.prepared {
            _applications,
            application_namespace,
            entry_alias,
            qualified_module
        }
        if not any(
            fullname == application_namespace(application)
                or fullname.startswith(application_namespace(application) + '.')
            for application in _applications.values()
        ) {
            return None;
        }
        alias = entry_alias(fullname);
        if alias is not None {
            return importlib.util.spec_from_loader(
                fullname, PreparedAliasLoader(alias[0]), origin=alias[1]
            );
        }
        for application in _applications.values() {
            namespace = application_namespace(application);
            if fullname != namespace and not fullname.startswith(namespace + '.') {
                continue;
            }
            for source in application.code {
                if qualified_module(source, application) == fullname {
                    package = os.path.basename(source).startswith('__init__.');
                    return importlib.util.spec_from_file_location(
                        fullname,
                        source,
                        loader=PreparedLoader(application),
                        submodule_search_locations=[os.path.dirname(source)]
                            if package
                            else None
                    );
                }
            }
            relative = fullname[len(namespace):].lstrip('.');
            directory = os.path.join(application.root, *relative.split('.'));
            if any(
                source.startswith(directory + os.sep) for source in application.code
            ) {
                spec = ModuleSpec(fullname, loader=None, is_package=True);
                spec.submodule_search_locations = [directory];
                return spec;
            }
        }
        return None;
    }
}
