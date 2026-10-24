import os;

import from _dl_native { dlopen, dlsym, dl_error, RTLD_NOW, RTLD_GLOBAL }

import from c {
    def readlink(path: str, buf: bytes, bufsiz: int) -> int;  obj EngineApi {
        has jac_main: Callable[[i32, int], i32] = 0;
    }
}

def:pub is_node_name(argv0: str) -> bool;

def link_target(path: str) -> str;

def:pub engine_dir(rt: str, argv0: str, exe_path: str) -> str;

def:pub run_node(rt: str, argv: list[str], exe_path: str) -> int;

impl is_node_name(argv0: str) -> bool {
    return os.path.basename(argv0) == "node";
}

impl link_target(path: str) -> str {
    buf = b"\x00" * 4096;
    n = readlink(path, buf, 4095);
    if n <= 0 {
        return "";
    }
    return buf[0:n].decode();
}

impl engine_dir(rt: str, argv0: str, exe_path: str) -> str {
    candidates: list[str] = [];
    if "/" in argv0 {
        candidates.append(argv0);
    } else {
        for d in os.environ.get("PATH", "").split(":") {
            if d and link_target(d + "/node") == exe_path {
                candidates.append(d + "/node");
            }
        }
    }
    for link in candidates {
        js = os.path.dirname(os.path.dirname(link));
        if os.path.isfile(js + "/libjs_engine.so") {
            return js;
        }
    }
    return rt + "/js";
}

impl run_node(rt: str, argv: list[str], exe_path: str) -> int {
    export_ca_bundle(rt);
    js = engine_dir(rt, argv[0], exe_path);
    node_link = js + "/bin/node";
    os.environ["PATH"] = js + "/bin:" + os.environ.get("PATH", "");
    lib = js + "/libjs_engine.so";
    handle = dlopen(lib, i32(RTLD_NOW | RTLD_GLOBAL));
    if handle == 0 {
        die(f"cannot load the JavaScript engine {lib}: {dl_error()}");
    }
    main_fn = dlsym(handle, "jac_main");
    if main_fn == 0 {
        die(f"{lib} has no jac_main entry");
    }
    api = EngineApi(jac_main=main_fn);
    args = CStrArray([node_link] + argv[1:]);
    return int(api.jac_main(i32(args.count), args.ptrs));
}
