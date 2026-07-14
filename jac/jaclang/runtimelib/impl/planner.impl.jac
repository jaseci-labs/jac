impl execute_path(mem: any, path: any, slc: (slice | None) = None) -> list[any] {
    import from jaclang.runtimelib.resolver { resolve_path_anchors }
    return resolve_path_anchors(mem, path, slc);
}
