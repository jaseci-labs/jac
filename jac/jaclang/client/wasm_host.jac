obj _HostState {
    has sh: any = None,
        out1: str = "",
        out2: str = "";
}

def _emit(st: _HostState, fd: int, text: str) {
    if fd == 2 {
        st.out2 = st.out2 + text;
    } else {
        st.out1 = st.out1 + text;
    }
    buf = st.out2 if fd == 2 else st.out1;
    idx = buf.rfind("\n");
    if idx >= 0 {
        head = buf[:idx];
        tail = buf[idx + 1:];
        if fd == 2 {
            console.error(head);
            st.out2 = tail;
        } else {
            console.log(head);
            st.out1 = tail;
        }
    }
}

def _flush_all(st: _HostState) {
    if len(st.out1) > 0 {
        console.log(st.out1);
        st.out1 = "";
    }
    if len(st.out2) > 0 {
        console.error(st.out2);
        st.out2 = "";
    }
}

def _clock_gettime(st: _HostState, clk: int, ts: int) -> int {
    dv = new(DataView, st.sh.mem.buffer);
    ms = Date.now() if clk == 0 else performance.now();
    sec = Math.floor(ms / 1000.0);
    nsec = Math.floor((ms - sec * 1000.0) * 1000000.0);
    dv.setBigInt64(ts, globalThis.BigInt(sec), True);
    dv.setBigInt64(ts + 8, globalThis.BigInt(nsec), True);
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
        "fread": lambda (b: int, sz: int, n: int, f: int) { return globalThis.BigInt(
            0
        ); },
        "fwrite": lambda (b: int, sz: int, n: int, f: int) { return globalThis.BigInt(
            0
        ); },
        "fgets": lambda (b: int, n: int, f: int) { return 0; },
        "ftell": lambda (f: int) { return globalThis.BigInt(-1); },
        "fseek": lambda (f: int, o: int, w: int) { return -1; },
        "getdelim": lambda (lp: int, np: int, d: int, f: int) { return globalThis.BigInt(
            -1
        ); },
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
    inst.__jac_owned_handles = 0;
    inst.__jac_live = True;
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
     _na_pending: dict = {},
     _na_contracts: dict = {},
     _na_exports: any = new(globalThis.WeakMap as any);

def _host_callback(host: any, name: str, contract: any) -> any {
    def callback(*args: any) -> any {
        values: list = [];
        for i in range(len(args)) {
            value = args[i];
            c = contract.params[i];
            if c.kind == "cstring" {
                memory_bytes = new(Uint8Array, host.mem.buffer);
                end = value;
                while end < memory_bytes.length and memory_bytes[end] != 0 {
                    end += 1;
                }
                value = new(TextDecoder).decode(memory_bytes.subarray(value, end));
            } elif c.type == "bool" {
                value = bool(value);
            } elif c.numeric == "int" and c.bits == 64 {
                value = globalThis.Number(value);
                if not Number.isSafeInteger(value) {
                    raise Error("Host integer exceeds exact range");
                }
            }
            values.append(value);
        }
        result = host[name].apply(host, values);
        if contract.result.numeric == "int" and contract.result.bits == 64 {
            return globalThis.BigInt(result);
        }
        if contract.result.type == "bool" {
            return 1 if result else 0;
        }
        return result;
    }
    return callback;
}

def:pub bind_na_host(native_export: any, host: any) {
    module = _na_exports.get(native_export);
    if not module {
        raise Error("Host binding requires a generated native export");
    }
    if module in _na_pending {
        raise Error("Bind the native host before instantiation");
    }
    env: any = {};
    required = _na_contracts[module].imports;
    for name in Object.keys(required) {
        if not host[name] or host[name].length != required[name].params.length {
            raise Error("Host import signature mismatch: " + name);
        }
        env[name] = _host_callback(host, name, required[name]);
    }
    _na_env_cfg[module] = [host, {"env": env}];
}

async def:pub release_na_module(native_export: any) {
    module = _na_exports.get(native_export);
    if not module {
        raise Error("Module release requires a generated native export");
    }
    if module in _na_pending {
        inst = await _na_pending[module];
        if inst.__jac_owned_handles != 0 {
            raise Error("Native module still has live owned handles");
        }
        inst.__jac_live = False;
        _na_pending.pop(module, None);
    }
    _na_env_cfg.pop(module, None);
}

async def _na_instance(module_stem: str) -> any {
    if module_stem in _na_pending {
        return await _na_pending[module_stem];
    }
    cfg = _na_env_cfg.get(module_stem);
    if not cfg and len(Object.keys(_na_contracts[module_stem].imports)) > 0 {
        raise Error("Native module requires a checked host binding: " + module_stem);
    }
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

glob _na_handles: any = new(globalThis.WeakMap as any);

def _handle_live(handle: any) -> bool {
    if not handle or not handle.live or not handle.instance.__jac_live {
        return False;
    }
    for parent in handle.parents {
        if not _handle_live(parent) {
            return False;
        }
    }
    return True;
}

def _na_argument(value: any, contract: any, module_stem: str, inst: any) -> any {
    if contract.kind == "handle" {
        handle = _na_handles.get(value);
        if not _handle_live(handle)
            or handle.module != module_stem
            or handle.instance != inst
            or handle.type != contract.type {
            raise Error(
                "Invalid, consumed, or foreign native handle for " + contract.type
            );
        }
        if contract.mode == "borrow_mut"
            and not handle.owned
            and handle.mode != "borrow_mut" {
            raise Error("Cannot mutably borrow a shared native handle");
        }
        return handle.pointer;
    }
    if contract.numeric == "int" and contract.bits == 64 {
        if typeof(value) != "bigint" and not Number.isSafeInteger(value) {
            raise Error("Native integer arguments must be exact integers");
        }
        integer: any = globalThis.BigInt(value);
        minimum: any = globalThis.BigInt(contract.minimum);
        maximum: any = globalThis.BigInt(contract.maximum);
        if integer < minimum or integer > maximum {
            raise Error("Native integer argument is out of range");
        }
        return integer;
    }
    if contract.type == "bool" {
        if typeof(value) != "boolean" {
            raise Error("Native bool argument requires a boolean");
        }
        return 1 if value else 0;
    }
    if contract.numeric == "int"
        and (
            not Number.isSafeInteger(value)
            or value < Number(contract.minimum)
            or value > Number(contract.maximum)
        ) {
        raise Error("Native integer argument is out of range");
    }
    if contract.numeric == "float" and typeof(value) != "number" {
        raise Error("Native floating point argument requires a number");
    }
    return value;
}

def _na_result(
    value: any, contract: any, module_stem: str, inst: any, parents: list
) -> any {
    if contract.kind == "handle" {
        token: any = Object.freeze({});
        if contract.mode == "own" {
            inst.__jac_owned_handles += 1;
        }
        _na_handles.set(
            token,
            {
                "pointer": value,
                "type": contract.type,
                "module": module_stem,
                "instance": inst,
                "live": True,
                "owned": contract.mode == "own",
                "mode": contract.mode,
                "parents": [] if contract.mode == "own" else parents
            }
        );
        return token;
    }
    if contract.type == "None" {
        return None;
    }
    if contract.type == "bool" {
        return bool(value);
    }
    if contract.type == "int" {
        result = globalThis.Number(value);
        if not Number.isSafeInteger(result) {
            raise Error("Native integer exceeds JavaScript's exact integer range");
        }
        return result;
    }
    return value;
}

def _na_caller(module_stem: str, fn_name: str, contract: any) -> any {
    async def _call(*args: any) -> any {
        inst = await _na_instance(module_stem);
        fn: any = inst.exports[fn_name];
        if not fn {
            raise Error(f"na module '{module_stem}' has no export '{fn_name}'");
        }
        if len(args) != len(contract.params) {
            raise Error("Native argument count mismatch for " + fn_name);
        }
        values: list = [];
        handles: list = [];
        for i in range(len(args)) {
            parameter = contract.params[i];
            values.append(_na_argument(args[i], parameter, module_stem, inst));
            if parameter.kind == "handle" {
                handle = _na_handles.get(args[i]);
                if parameter.mode == "own" and not handle.owned {
                    raise Error("Cannot consume a borrowed native handle");
                }
                for previous in handles {
                    if previous.handle.pointer == handle.pointer
                        and (parameter.mode != "borrow" or previous.mode != "borrow") {
                        raise Error("Aliased native handles require shared borrows");
                    }
                }
                handles.append({"handle": handle, "mode": parameter.mode});
            }
        }
        for i in range(len(args)) {
            if contract.params[i].kind == "handle"
                and contract.params[i].mode == "own" {
                handle = _na_handles.get(args[i]);
                handle.live = False;
                inst.__jac_owned_handles -= 1;
            }
        }
        return _na_result(
            fn(*values), contract.result, module_stem, inst, [h.handle for h in handles]
        );
    }
    return _call;
}

def:pub __na_bind(module_stem: str, contract_json: str) -> any {
    metadata: any = JSON.parse(contract_json);
    _na_contracts[module_stem] = metadata;
    contracts = metadata.exports;
    out: any = {};
    for name in Object.keys(contracts) {
        out[name] = _na_caller(module_stem, name, contracts[name]);
        _na_exports.set(out[name], module_stem);
    }
    return out;
}
