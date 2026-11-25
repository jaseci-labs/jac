glob _TARGETS: dict[str, tuple[str, str]] = {},
     _CODEC_TABLES: list[tuple[bytes, bytes]] = [],
     _PRIMITIVE_METHODS: dict[str, set[str]] = {},
     _SEALED_RUNTIME: list[bool] = [];

def target_layout(target: str) -> tuple[str, str];

def struct_layouts_of(
    data_layout: str, counts: dict[str, int], probe_ir: str
) -> dict[str, tuple[list[int], int]];

def codec_tables -> tuple[bytes, bytes];

def canonical_codec_name(encoding: str) -> str;

def primitive_method_names(type_name: str) -> set[str];

def sealed_runtime_active -> bool;

def import_search_dirs -> list[str];

def package_store_dir -> str;
