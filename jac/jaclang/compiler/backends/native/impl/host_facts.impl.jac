impl host_native_fact(kind: str, key: str) -> str {
    if kind == FACT_TARGET {
        return target_fact_text(key);
    }
    return kernel_native_fact(kind, key);
}
