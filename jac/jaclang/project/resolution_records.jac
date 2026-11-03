obj PythonModuleSite {
    has origin: str = "",
        namespace_dirs: list[str] = [];
}

obj PythonProbe {
    has origin: str = "",
        package_dir: str = "",
        namespace_dir: str = "";
}

obj JacVirtualModule {
    has name: str,
        path: str = "",
        exports: list[str] = [];
}

obj NpmExport {
    has path: str = "",
        targets: list[NpmExport] = [],
        conditions: list[tuple[str, NpmExport]] = [],
        subpaths: list[tuple[str, NpmExport]] = [];
}

obj NpmPackageJson {
    has module: str = "",
        main: str = "",
        types: str = "",
        typings: str = "",
        exports: (NpmExport | None) = None;
}
