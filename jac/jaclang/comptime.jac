import sys;
import platform as _platform;

import from enum { Enum as _PyEnum }
import from typing { get_type_hints as _get_type_hints }
import from importlib { import_module as _import_module }

enum Codespace {
    SERVER = "server",
    CLIENT = "client",
    NATIVE = "native",
    with entry {
        has is_server: bool { getter; }

        has is_client: bool { getter; }

        has is_native: bool { getter; }
    }
}

impl Codespace.is_server.getter -> bool {
    return self.value == "server";
}

impl Codespace.is_client.getter -> bool {
    return self.value == "client";
}

impl Codespace.is_native.getter -> bool {
    return self.value == "native";
}

obj TargetInfo {
    has os: str,
        arch: str;
}

obj FieldInfo {
    has name: str,
        `type: any = None,
        has_default: bool = False,
        `default: any = None,
        semstr: (str | None) = None;
}

obj LazyRef {
    has module: str,
        qualname: str;

    has resolved: any { getter; }

    def __call__(*args: any, **kwargs: any) -> any;
    def __getattr__(name: str) -> any;
    def __repr__ -> str;
}

impl LazyRef.resolved.getter -> any {
    cur: any = _import_module(self.module);
    for part in self.qualname.split(".") {
        cur = getattr(cur, part);
    }
    return cur;
}

def _host_os -> str;

glob codespace: Codespace = Codespace.SERVER,
     target: TargetInfo = TargetInfo(os=_host_os(), arch=_platform.machine());

def __ct_ref(module: str, qualname: str) -> any;

def __ct_lazy(module: str, qualname: str) -> LazyRef;

def typeof(x: any) -> type;

def name(t: any) -> str;

def module_of(t: any) -> str;

def is_subtype(t: type, u: type) -> bool;

def _semstr_of(target: any) -> (str | None);

def semstr(t: any, field: str = "") -> (str | None);

def fields(t: type) -> list[FieldInfo];

def has_field(t: type, field: str) -> bool;

def get_field(target: any, field: str) -> any;

def set_field(target: any, field: str, value: any);

def members(e: type) -> list[any];

def set_fuel(n: int) -> None;

def embed_file(path: str) -> str;

def embed_bytes(path: str) -> bytes;

def _scalar_size_align(t: any) -> (tuple[int, int] | None);

def _size_align(t: any) -> tuple[int, int];

def sizeof(t: any) -> int;

def alignof(t: any) -> int;

def record(cls: type, **fields: any) -> any;

glob _SPECIALIZED: dict[tuple[object, ...], type] = {};

def specialize(cls: type, **ct: any) -> type;

def _ct_sort_key(item: tuple[str, any]) -> str;
