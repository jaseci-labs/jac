import from c { def uname(buf: int) -> i32;  }
import from c { def strlen(pointer: int) -> u64;  }
import from c { def memcpy(target: bytes, source: int, length: u64) -> int;  }
import from c { def malloc(size: int) -> int;  }
import from c { def popen(cmd: str, mode: str) -> int;  }
import from c { def pclose(stream: int) -> i32;  }
import from c { def fread(buffer: bytes, size: u64, count: u64, stream: int) -> u64;  }

glob _PLAT_UTS: int = malloc(1280);

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
