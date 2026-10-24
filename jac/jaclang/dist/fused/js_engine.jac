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
