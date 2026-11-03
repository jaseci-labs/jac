obj CompileRoute {
    def compile(
        program: JacProgram,
        file_path: str,
        use_str: (str | None),
        options: CompileOptions
    ) -> (uni.Module | None) abst;
}

glob _ROUTES: list[CompileRoute] = [];

def install_compile_route(route: CompileRoute);

def installed_compile_route -> (CompileRoute | None);
