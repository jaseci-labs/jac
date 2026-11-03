impl json_map(value: any) -> dict[str, any] {
    out: dict[str, any] = {};
    if isinstance(value, dict) {
        for (key, item) in value.items() {
            out[str(key)] = item;
        }
    }
    return out;
}

impl json_maps(value: any) -> list[dict[str, any]] {
    return [json_map(item) for item in json_list(value)];
}

impl json_list(value: any) -> list[any] {
    if isinstance(value, list) {
        items: list[any] = value;
        return items;
    }
    return [];
}

impl json_str_list(value: any) -> list[str] {
    return [str(item) for item in json_list(value)];
}

impl json_str_map(value: any) -> dict[str, str] {
    return {key: str(item) for (key, item) in json_map(value).items()};
}

impl json_opt_str(value: any) -> (str | None) {
    return value if isinstance(value, str) else None;
}

impl json_opt_str_list(value: any) -> (list[str | None] | None) {
    if value is None {
        return None;
    }
    return [json_opt_str(item) for item in json_list(value)];
}
