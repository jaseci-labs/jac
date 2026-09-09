impl precompile(
    source_dir: str,
    seal: bool = False,
    seal_compile: bool = False,
    seal_finalize: bool = False,
    debug_src: bool = False,
    jobs: str = "",
    app: str = ""
) -> int {
    import from jaclang.dist.precompile_bytecode { run_precompile }

    run_precompile(
        source_dir,
        seal=seal,
        seal_compile=seal_compile,
        finalize_only=seal_finalize,
        embed_src=debug_src,
        jobs_arg=jobs,
        app=app
    );
    return 0;
}
