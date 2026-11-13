glob U64_MAX_TEXT: str = "18446744073709551615";

obj WasmValueContract {
    has type_name: str,
        mode: str,
        kind: str,
        bits: int = 0,
        signed: bool = False,
        is_float: bool = False,
        minimum: str = "",
        maximum: str = "",
        name: str = "";

    def to_dict -> dict[str, any];
}

obj WasmFunctionContract {
    has params: list[WasmValueContract],
        result: WasmValueContract;

    def to_dict -> dict[str, any];
}

def _ownership_mode(ownership: OwnershipKind) -> str;

def value_contract(
    expr: (Expr | None),
    ownership: OwnershipKind = OwnershipKind.NONE,
    host: bool = False
) -> WasmValueContract;

def function_contract(decl: Ability, host: bool = False) -> WasmFunctionContract;

def host_contracts(
    module: (Module | None), program: JacProgram
) -> dict[str, WasmFunctionContract];

def host_contract_dicts(
    module: (Module | None), program: JacProgram
) -> dict[str, dict[str, any]];

def _host_type(name: str) -> str;

def _host_export(export: Expr | KWPair, program: JacProgram) -> (Ability | None);

def check_host_call(call: FuncCall, program: JacProgram) -> None;
