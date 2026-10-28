impl open_runtime(exe_path: str) -> Embed {
    return open_tree(materialize(exe_path), exe_path);
}

impl engine_boot -> Embed {
    exe = executable_path();
    if exe == "" {
        die("cannot resolve executable path");
    }
    emb = open_runtime(exe);
    if emb.init_interpreter([], False) >= 0 {
        die("interpreter initialization failed");
    }
    return emb;
}
