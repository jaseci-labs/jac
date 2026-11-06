impl assert_abi -> int {
    return strlen("abi");
}

impl plat_scratch -> int {
    return calloc(1, 16);
}
