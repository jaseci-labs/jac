walker AppContextPass(CompilerPass) {
    static has contract: PassContract = PassContract();

    can run_walk with Module entry {
        self.prog.stamp_app_facts(here);
        self.prog.stamp_access_check_facts(here);
    }
}

walker AbsorbImportsPass(CompilerPass) {
    static has contract: PassContract = PassContract();

    can run_walk with Module entry {
        self.prog.resolve_absorb_imports(here);
    }
}

walker BoundaryFactsPass(CompilerPass) {
    static has contract: PassContract = PassContract();

    can run_walk with Module entry {
        self.prog.stamp_boundary_facts(here);
    }
}

walker NativeImportFactsPass(CompilerPass) {
    static has contract: PassContract = PassContract();

    can run_walk with Module entry {
        self.prog.stamp_native_import_facts(here);
    }
}
