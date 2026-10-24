glob _STRUCT_LAYOUTS: dict[str, tuple[list[int], int]] = {};

def layout_identity(llt: ir.Type, memo: dict[str, str]) -> str;

def struct_layouts(module: ir.Module) -> dict[str, tuple[list[int], int]];

def scalar_layout(
    llt: (ir.Type | None)
) -> tuple[int, int, list[tuple[int, bool, int]]];

def classify_struct_sysv(
    size: int, align: int, scalars: list[tuple[int, bool, int]]
) -> dict[str, any];

def classify_struct_aapcs(
    size: int, align: int, scalars: list[tuple[int, bool, int]]
) -> dict[str, any];

def classify_struct_win64(
    size: int, align: int, scalars: list[tuple[int, bool, int]]
) -> dict[str, any];

def classify_struct(
    size: int, align: int, scalars: list[tuple[int, bool, int]], triple: str
) -> dict[str, any];

def classify_foreign_fn(
    structs: dict[str, list[tuple[str, str | None]]],
    params: list[tuple[(str | None), (str | None)]],
    ret_tname: (str | None),
    triple: str,
    force: bool = False
) -> (dict[str, any] | None);
