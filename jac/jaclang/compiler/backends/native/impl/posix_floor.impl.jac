impl posix_floor_ir(osarch: str) -> str {
    text = {
        "linux-x86_64": POSIX_FLOOR_IR_LINUX_X86_64,
        "linux-aarch64": POSIX_FLOOR_IR_LINUX_AARCH64,
        "macos-aarch64": POSIX_FLOOR_IR_MACOS_AARCH64,
        "macos-x86_64": POSIX_FLOOR_IR_MACOS_X86_64
    }.get(
        osarch, ""
    );
    return f"; --- POSIX floor ({osarch}) ---\n{text}" if text else "";
}
