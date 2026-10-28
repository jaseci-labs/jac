impl stdlib_intercepted(module_name: str, func_name: str) -> bool {
    return (module_name == "os" and func_name in NATIVE_OS_FUNCS)
        or (module_name == "random" and func_name in NATIVE_RANDOM_FUNCS)
        or (module_name == "struct" and func_name in NATIVE_STRUCT_FUNCS);
}
