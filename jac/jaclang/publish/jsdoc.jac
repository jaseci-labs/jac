import from jaclang.jac0core.unitree { Module }

def jac_type_to_jsdoc(type_str: str, is_return: bool = False) -> str;

def jac_type_to_ts(type_str: str, is_return: bool = False) -> str;

def jsdoc_for_module(mod: Module) -> dict[str, str];

def inject_jsdoc(js: str, blocks: dict[str, str]) -> str;
