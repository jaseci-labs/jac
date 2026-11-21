impl plat_uname_ok -> bool {
    return uname(_PLAT_UTS) == 0;
}

impl _uts_str(offset: int) -> str {
    address = _PLAT_UTS + offset;
    length = strlen(address);
    copied = b"\x00" * int(length);
    memcpy(copied, address, length);
    return copied.decode();
}

impl plat_sysname -> str {
    return _uts_str(0);
}

impl plat_nodename -> str {
    return _uts_str(65);
}

impl plat_release -> str {
    return _uts_str(130);
}

impl plat_version -> str {
    return _uts_str(195);
}

impl plat_machine -> str {
    return _uts_str(260);
}

impl plat_uname_p -> str {
    stream = popen("uname -p", "r");
    if stream == 0 {
        return "";
    }
    buf = b"\x00" * 128;
    n = int(fread(buf, u64(1), u64(127), stream));
    pclose(stream);
    if n <= 0 {
        return "";
    }
    out = buf[0:n].decode().strip();
    if out == "unknown" {
        return "";
    }
    return out;
}

impl plat_libc_name -> str {
    return "glibc";
}

impl plat_libc_version -> str {
    return gnu_get_libc_version();
}

impl plat_arch_bits -> str {
    return "64bit";
}

impl plat_arch_linkage -> str {
    return "ELF";
}

impl plat_macos_release -> str {
    return "";
}
