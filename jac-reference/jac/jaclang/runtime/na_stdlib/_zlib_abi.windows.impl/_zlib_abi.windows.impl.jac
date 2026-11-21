impl zs_load_total(addr: int) -> int {
    return int(__mem_load_i32(addr)) & 4294967295;
}
