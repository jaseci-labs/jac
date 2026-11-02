walker AppContextPass(CompilerPass) {
    can run_walk with Module entry;
}

walker AbsorbImportsPass(CompilerPass) {
    can run_walk with Module entry;
}

walker BoundaryFactsPass(CompilerPass) {
    can run_walk with Module entry;
}

walker NativeImportFactsPass(CompilerPass) {
    can run_walk with Module entry;
}
