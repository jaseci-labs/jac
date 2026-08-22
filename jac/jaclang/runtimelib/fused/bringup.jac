import from .embed { Embed, open_tree }
import from .materialize { materialize }
import from .report { die }
import from _exec_native { executable_path }

def:pub open_runtime(exe_path: str) -> Embed {
    return open_tree(materialize(exe_path), exe_path);
}

def:pub engine_boot -> Embed {
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
