impl deep_merge(base: dict[str, any], override_dict: dict[str, any]) -> dict[str, any] {
    result = base.copy();
    for (key, value) in override_dict.items() {
        if (
            (key in result)
            and isinstance(result[key], dict)
            and isinstance(value, dict)
        ) {
            result[key] = deep_merge(result[key], value);
        } else {
            result[key] = value;
        }
    }
    return result;
}
