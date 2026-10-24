walker AppContextPass(CompilerPass) {
    static has contract: PassContract = PassContract();

    can run_walk with Module entry;
}

walker AbsorbImportsPass(CompilerPass) {
    static has contract: PassContract = PassContract();

    can run_walk with Module entry;
}

walker BoundaryFactsPass(CompilerPass) {
    static has contract: PassContract = PassContract();

    can run_walk with Module entry;
}

walker NativeImportFactsPass(CompilerPass) {
    static has contract: PassContract = PassContract();

    can run_walk with Module entry;
}
