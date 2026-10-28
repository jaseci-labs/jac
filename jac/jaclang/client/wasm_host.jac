obj _HostState {
    has sh: any = None,
        out1: str = "",
        out2: str = "";
}

def _emit(st: _HostState, fd: int, text: str);

def _flush_all(st: _HostState);

def _clock_gettime(st: _HostState, clk: int, ts: int) -> int;

def:pub make_jac_host(sh: any) -> dict[str, any];

async def:pub instantiate_na_wasm(url: str, sh: any, extra_imports: any = None) -> any;

glob _na_env_cfg: dict[str, list[any]] = {},
     _na_pending: dict[str, any] = {},
     _na_contracts: dict[str, any] = {},
     _na_exports: any = new(globalThis.WeakMap as any);

def _host_callback(host: any, name: str, contract: any) -> any;

def:pub bind_na_host(native_export: any, host: any);

async def:pub release_na_module(native_export: any);

async def _na_instance(module_stem: str) -> any;

glob _na_handles: any = new(globalThis.WeakMap as any);

def _handle_live(handle: any) -> bool;

def _na_argument(value: any, contract: any, module_stem: str, inst: any) -> any;

def _na_result(
    value: any, contract: any, module_stem: str, inst: any, parents: list[any]
) -> any;

def _na_caller(module_stem: str, fn_name: str, contract: any) -> any;

def:pub __na_bind(module_stem: str, contract_json: str) -> any;
