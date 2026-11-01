glob _HELD: dict[str, str] = {};

def host_native_fact(kind: str, key: str) -> str;

def compute_fact(kind: str, key: str) -> str;

def codec_tables_fact -> str;

def primitive_methods_fact(type_name: str) -> str;
