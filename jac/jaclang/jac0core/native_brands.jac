glob DRIVER_ORIGIN: str = "driver:JacCompiler",
     _BRAND_STATE: dict[str, any] = {"bound": False, "origin": ""},
     _BRAND_ORIGINS: list[str] = [];

def native_brands_bound -> bool {
    return bool(_BRAND_STATE["bound"]);
}

def native_brand_origin -> str {
    return str(_BRAND_STATE["origin"]);
}

def native_brand_origins -> list[str] {
    return list(_BRAND_ORIGINS);
}

def reset_native_brands {
    _BRAND_STATE["bound"] = False;
    _BRAND_STATE["origin"] = "";
    _BRAND_ORIGINS.clear();
    import from jaclang.jac0core.parser.frontend { _NATIVE_PARSE_MEMO }
    _NATIVE_PARSE_MEMO.clear();
}

def ensure_native_brands_bound(origin: str = "") -> any {
    who = origin or "<unnamed>";
    _BRAND_ORIGINS.append(who);
    if not _BRAND_STATE["origin"] {
        _BRAND_STATE["origin"] = who;
    }
    import from jaclang.jac0core.parser.frontend { _bind_native_parser_once }
    parser = _bind_native_parser_once();
    if parser is not None {
        _BRAND_STATE["bound"] = True;
    }
    return parser;
}

def native_parser(origin: str = "") -> any {
    return ensure_native_brands_bound(origin);
}
