impl mm_anon_flag -> int {
    return 32;
}


impl mm_sync_flag -> int {
    return 4;
}


impl mm_resize_requires_mremap -> bool {
    return False;
}


impl mm_dupfd_cloexec_cmd -> int {
    return 1030;
}
