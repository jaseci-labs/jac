import from c { def uname(buf: int) -> i32;  }
import from c { def strdup(s: int) -> str;  }
import from c { def malloc(size: int) -> int;  }
import from c { def popen(cmd: str, mode: str) -> int;  }
import from c { def pclose(stream: int) -> i32;  }
import from c { def fread(buffer: bytes, size: u64, count: u64, stream: int) -> u64;  }

glob _PLAT_UTS: int = malloc(1280);

def:pub plat_uname_ok -> bool {
    return uname(_PLAT_UTS) == 0;
}

def:pub plat_sysname -> str {
    return strdup(_PLAT_UTS + 0);
}

def:pub plat_nodename -> str {
    return strdup(_PLAT_UTS + 256);
}

def:pub plat_release -> str {
    return strdup(_PLAT_UTS + 512);
}

def:pub plat_version -> str {
    return strdup(_PLAT_UTS + 768);
}

def:pub plat_machine -> str {
    return strdup(_PLAT_UTS + 1024);
}

def:pub plat_uname_p -> str {
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

def:pub plat_libc_name -> str {
    return "";
}

def:pub plat_libc_version -> str {
    return "";
}

def:pub plat_arch_bits -> str {
    return "64bit";
}

def:pub plat_arch_linkage -> str {
    return "";
}

def:pub plat_macos_release -> str {
    stream = popen("sw_vers -productVersion", "r");
    if stream == 0 {
        return "";
    }
    buf = b"\x00" * 64;
    n = int(fread(buf, u64(1), u64(63), stream));
    pclose(stream);
    if n <= 0 {
        return "";
    }
    return buf[0:n].decode().strip();
}
