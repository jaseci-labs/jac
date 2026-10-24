import hashlib;
import json;
import os;

def native_unit_ref(path: str) -> str;

def resolve_native_unit_ref(ref: str, anchor: str = "") -> str;

def _json_dict(raw: any) -> dict[str, any];

def _json_list(raw: any) -> list[any];

def _json_str_list(raw: any) -> list[str];

def _json_opt_str(raw: any) -> (str | None);

def _json_opt_str_list(raw: any) -> (list[str | None] | None);

def _enum_members_json(members: list[tuple[str, any, int]]) -> list[any];

def _tuple_layout_to_dict(t: (NativeTupleLayout | None)) -> (dict[str, any] | None);

def _func_layout_to_dict(f: NativeFuncLayout) -> dict[str, any];

def native_layout_to_dict(layout: NativeModuleLayout) -> dict[str, any];

def _tuple_layout_from_dict(raw: any) -> (NativeTupleLayout | None);

def _func_layout_from_dict(raw: any) -> NativeFuncLayout;

def _field_info_from_dict(raw: any) -> NativeFieldInfo;

def native_layout_from_dict(raw: any) -> NativeModuleLayout;

glob NIFACE_FORMAT: int = 5,
     NIFACE_HASH_LEN: int = 64,
     EXPORT_FUNCTION: str = "function",
     EXPORT_METHOD: str = "method",
     EXPORT_GLOBAL: str = "global",
     EXPORT_STATIC: str = "static",
     EXPORT_VTABLE: str = "vtable",
     EXPORT_TEST: str = "test";

obj NativeExport {
    has name: str,
        symbol: str,
        kind: str,
        is_pub: bool = False,
        param_types: list[str] = [],
        param_names: list[str] = [],
        param_defaults: list[str] = [],
        ret_type: str = "",
        ownership: list[str] = [];

    def to_dict -> dict[str, any];
    static def from_dict(d: dict[str, any]) -> NativeExport;
}

obj NativeValueSchema {
    has code: str,
        class_name: str = "",
        element: (NativeValueSchema | None) = None,
        data_offset: int = 0,
        key_offset: int = 0,
        order_offset: int = 0;

    def to_dict -> dict[str, any];
    static def from_dict(d: dict[str, any]) -> NativeValueSchema;
}

obj NativeFieldSlot {
    has index: int,
        offset: int,
        code: str,
        aux: str = "",
        schema: (NativeValueSchema | None) = None;

    def to_dict -> dict[str, any];
    static def from_dict(d: dict[str, any]) -> NativeFieldSlot;
}

obj NativeClassLayout {
    has name: str,
        size: int = 0,
        tag: int = 0,
        tag_offset: int = -1,
        fields: dict[str, NativeFieldSlot] = {},
        bases: list[str] = [],
        vtable: list[str] = [],
        is_node: bool = False;

    def to_dict -> dict[str, any];
    static def from_dict(d: dict[str, any]) -> NativeClassLayout;
}

def _fields_digest(fields: dict[str, any]) -> str;

obj NativeIface {
    has format: int = NIFACE_FORMAT,
        module: str = "",
        prefix: str = "",
        exports: dict[str, NativeExport] = {},
        classes: dict[str, NativeClassLayout] = {},
        enums: dict[str, list[str]] = {},
        init_symbol: str = "",
        entry_symbol: str = "",
        demoted: list[str] = [],
        clib_paths: list[str] = [],
        python_imports: list[str] = [],
        clib_symbol_lib: dict[str, str] = {},
        layout: (NativeModuleLayout | None) = None,
        deps: list[str] = [],
        coverage: dict[str, any] = {},
        headerless: bool = False,
        runtime_globals: list[str] = [],
        init_reads: list[str] = [];

    def digest_fields -> dict[str, any];
    def digest -> str;
    def to_dict -> dict[str, any];
    def _with_references(fields: dict[str, any]) -> dict[str, any];
    def resolve_deps(anchor: str);
    def to_bytes -> bytes;
    static def from_dict(d: dict[str, any]) -> (NativeIface | None);
    static def from_bytes(raw: (bytes | None)) -> (NativeIface | None);
    static def verified_digest(raw: (bytes | None)) -> (str | None);
    static def read_digest(raw: (bytes | None)) -> (str | None);
    def pub_symbols -> list[str];
    def symbol_of(name: str) -> (str | None);
    def is_demoted(name: str) -> bool;
    def classes_json -> dict[str, any];
}

def _rekey_class_refs(value: any, keys: dict[str, str]) -> any;

def merge_class_layouts(ifaces: list[NativeIface]) -> dict[str, any];

def layout_digest(classes: dict[str, any]) -> str;
