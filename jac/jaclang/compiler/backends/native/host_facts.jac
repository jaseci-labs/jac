import json;

glob _HELD: dict[str, str] = {};

def host_native_fact(kind: str, key: str) -> str;

def target_fact(target: str) -> str;

def struct_layouts_fact(key: str) -> str;
