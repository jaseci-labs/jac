obj _HostState {
    has sh: any = None,
        out1: str = "",
        out2: str = "";
}

def _emit(st: any, fd: int, text: str) {
    if fd == 2 {
        st.out2 = st.out2 + text;
    } else {
        st.out1 = st.out1 + text;
    }
    buf = st.out2 if fd == 2 else st.out1;
    idx = buf.lastIndexOf("\n");
    if idx >= 0 {
        head = buf.slice(0, idx);
        tail = buf.slice(idx + 1);
        if fd == 2 {
            console.error(head);
            st.out2 = tail;
        } else {
            console.log(head);
            st.out1 = tail;
        }
    }
}

def _flush_all(st: any) {
    if len(st.out1) > 0 {
        console.log(st.out1);
        st.out1 = "";
    }
    if len(st.out2) > 0 {
        console.error(st.out2);
        st.out2 = "";
    }
}

def _clock_gettime(st: any, clk: int, ts: int) -> int {
    dv = new(DataView, st.sh.mem.buffer);
    ms = Date.now() if clk == 0 else performance.now();
    sec = Math.floor(ms / 1000.0);
    nsec = Math.floor((ms - sec * 1000.0) * 1000000.0);
    dv.setBigInt64(ts, BigInt(sec), True);
    dv.setBigInt64(ts + 8, BigInt(nsec), True);
    return 0;
}

def:pub make_jac_host(sh: any) -> dict {
    st = _HostState(sh=sh);
    return {
        "write": lambda (fd: int, ptr: int, n: int) {
            bytes_view = new(Uint8Array, st.sh.mem.buffer, ptr, n);
            _emit(st, fd, new(TextDecoder).decode(bytes_view));
            return n;
        },
        "fflush": lambda (f: int) {
            _flush_all(st);
            return 0;
        },
        "exit": lambda (code: int) {
            _flush_all(st);
            raise Error("na wasm module called exit(" + String(code) + ")");
        },
        "abort": lambda {
            _flush_all(st);
            raise Error("na wasm module called abort()");
        },
        "getenv": lambda (p: int) { return 0; },
        "fopen": lambda (p: int, m: int) { return 0; },
        "fclose": lambda (f: int) { return -1; },
        "fread": lambda (b: int, sz: int, n: int, f: int) { return BigInt(0); },
        "fwrite": lambda (b: int, sz: int, n: int, f: int) { return BigInt(0); },
        "fgets": lambda (b: int, n: int, f: int) { return 0; },
        "ftell": lambda (f: int) { return BigInt(-1); },
        "fseek": lambda (f: int, o: int, w: int) { return -1; },
        "getdelim": lambda (lp: int, np: int, d: int, f: int) { return BigInt(-1); },
        "getpid": lambda { return 1; },
        "getcwd": lambda (b: int, n: int) { return 0; },
        "system": lambda (c: int) { return -1; },
        "chdir": lambda (p: int) { return -1; },
        "rmdir": lambda (p: int) { return -1; },
        "unlink": lambda (p: int) { return -1; },
        "mkdir": lambda (p: int, m: int) { return -1; },
        "rename": lambda (a: int, b: int) { return -1; },
        "realpath": lambda (p: int, r: int) { return 0; },
        "access": lambda (p: int, m: int) { return -1; },
        "stat": lambda (p: int, s: int) { return -1; },
        "clock_gettime": lambda (clk: int, ts: int) { return _clock_gettime(
            st, clk, ts
        ); },
        "nanosleep": lambda (req: int, rem: int) { return 0; }
    };
}

async def:pub instantiate_na_wasm(url: str, sh: any, extra_imports: any = None) -> any {
    imports = Object.assign({}, extra_imports or {});
    imports["jac_host1"] = make_jac_host(sh);
    res: any = await WebAssembly.instantiateStreaming(fetch(url), imports);
    inst: any = res.instance;
    sh.exports = inst.exports;
    sh.mem = inst.exports.memory;
    if inst.exports.__heap_base {
        sh.heap = inst.exports.__heap_base.value;
    }
    if inst.exports.__jac_glob_init {
        inst.exports.__jac_glob_init();
    }
    return inst;
}

glob _na_env_cfg: dict = {},
     _na_pending: dict = {};

def:pub set_na_env(module_stem: str, sh: any, extra_imports: any = None) {
    _na_env_cfg[module_stem] = [sh, extra_imports];
}

async def _na_instance(module_stem: str) -> any {
    if module_stem in _na_pending {
        return await _na_pending[module_stem];
    }
    cfg = _na_env_cfg.get(module_stem);
    sh: any = cfg[0] if cfg else {};
    extra: any = cfg[1] if cfg else None;
    p = instantiate_na_wasm(f"/static/{module_stem}.wasm", sh, extra);
    _na_pending[module_stem] = p;
    try {
        return await p;
    } except Exception as err {
        _na_pending.pop(module_stem, None);
        raise err;
    }
}

def _na_caller(module_stem: str, fn_name: str) -> any {
    async def _call(*args: any) -> any {
        inst = await _na_instance(module_stem);
        fn: any = inst.exports[fn_name];
        if not fn {
            raise Error(f"na module '{module_stem}' has no export '{fn_name}'");
        }
        return fn(*args);
    }
    return _call;
}

def:pub __na_bind(module_stem: str, names: list) -> any {
    out: any = {};
    for nm in names {
        out[nm] = _na_caller(module_stem, nm);
    }
    return out;
}
