import from c { def uname(buf: int) -> i32;  }
import from c { def strlen(pointer: int) -> u64;  }
import from c { def memcpy(target: bytes, source: int, length: u64) -> int;  }
import from c { def malloc(size: int) -> int;  }
import from c { def popen(cmd: str, mode: str) -> int;  }
import from c { def pclose(stream: int) -> i32;  }
import from c { def fread(buffer: bytes, size: u64, count: u64, stream: int) -> u64;  }
import from c { def gnu_get_libc_version -> str;  }

glob _PLAT_UTS: int = malloc(512);

def:pub plat_uname_ok -> bool;

def _uts_str(offset: int) -> str;

def:pub plat_sysname -> str;

def:pub plat_nodename -> str;

def:pub plat_release -> str;

def:pub plat_version -> str;

def:pub plat_machine -> str;

def:pub plat_uname_p -> str;

def:pub plat_libc_name -> str;

def:pub plat_libc_version -> str;

def:pub plat_arch_bits -> str;

def:pub plat_arch_linkage -> str;

def:pub plat_macos_release -> str;

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
