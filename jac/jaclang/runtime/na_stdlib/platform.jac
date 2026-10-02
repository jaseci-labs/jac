import from _platform_native {
    plat_uname_ok,
    plat_sysname,
    plat_nodename,
    plat_release,
    plat_version,
    plat_machine,
    plat_uname_p,
    plat_libc_name,
    plat_libc_version,
    plat_arch_bits,
    plat_arch_linkage,
    plat_macos_release
}

glob _PY_VERSION: str = "3.14.6";

obj _UnameCache {
    has done: bool = False,
        pdone: bool = False,
        udone: bool = False,
        ldone: bool = False,
        system: str = "",
        `node: str = "",
        release: str = "",
        version: str = "",
        machine: str = "",
        processor: str = "",
        libc_n: str = "",
        libc_v: str = "",
        pdone_f: bool = False,
        pdone_t: bool = False,
        pfull: str = "",
        pterse: str = "",
        ures: uname_result = uname_result(
            system="", `node="", release="", version="", machine="", processor=""
        );
}

glob _UC: _UnameCache = _UnameCache();

obj:pub uname_result {
    has system: str,
        `node: str,
        release: str,
        version: str,
        machine: str,
        processor: str;
}

def _load_uname {
    if not _UC.done {
        if plat_uname_ok() {
            _UC.system = plat_sysname();
            _UC.node = plat_nodename();
            _UC.release = plat_release();
            _UC.version = plat_version();
            _UC.machine = plat_machine();
        }
        _UC.done = True;
    }
}

def _processor -> str {
    if not _UC.pdone {
        _UC.processor = plat_uname_p();
        _UC.pdone = True;
    }
    return _UC.processor;
}

def:pub uname -> uname_result {
    if not _UC.udone {
        _load_uname();
        _UC.ures.system = _UC.system;
        _UC.ures.`node = _UC.node;
        _UC.ures.release = _UC.release;
        _UC.ures.version = _UC.version;
        _UC.ures.machine = _UC.machine;
        _UC.ures.processor = _processor();
        _UC.udone = True;
    }
    return _UC.ures;
}

def:pub system -> str {
    _load_uname();
    return _UC.system;
}

def:pub `node -> str {
    _load_uname();
    return _UC.node;
}

def:pub release -> str {
    _load_uname();
    return _UC.release;
}

def:pub version -> str {
    _load_uname();
    return _UC.version;
}

def:pub machine -> str {
    _load_uname();
    return _UC.machine;
}

def:pub processor -> str {
    return _processor();
}

def:pub architecture(
    executable: str = "", bits: str = "", linkage: str = ""
) -> tuple[(str, str)] {
    b: str = bits;
    if b == "" {
        b = plat_arch_bits();
    }
    l: str = linkage;
    if l == "" {
        l = plat_arch_linkage();
    }
    return (b, l);
}

def:pub libc_ver -> tuple[(str, str)] {
    if not _UC.ldone {
        _UC.libc_n = plat_libc_name();
        _UC.libc_v = plat_libc_version();
        _UC.ldone = True;
    }
    return (_UC.libc_n, _UC.libc_v);
}

def:pub python_version -> str {
    return _PY_VERSION;
}

def:pub python_version_tuple -> tuple[(str, str, str)] {
    major: str = _PY_VERSION[0:_PY_VERSION.find(".")];
    rest: str = _PY_VERSION[_PY_VERSION.find(".") + 1:];
    minor: str = rest[0:rest.find(".")];
    patch: str = rest[rest.find(".") + 1:];
    return (major, minor, patch);
}

def _platform_join(args: list[str]) -> str {
    parts: list[str] = [];
    for a in args {
        t: str = a.strip();
        if t != "" {
            parts.append(t);
        }
    }
    p: str = "-".join(parts);
    dirty: bool = (
        " " in p
        or "/" in p
        or "\\" in p
        or ":" in p
        or ";" in p
        or "\"" in p
        or "(" in p
        or ")" in p
        or "unknown" in p
        or "--" in p
        or (len(p) > 0 and p[len(p) - 1] == "-")
    );
    if not dirty {
        return p;
    }
    p = p.replace(" ", "_");
    p = p.replace("/", "-");
    p = p.replace("\\", "-");
    p = p.replace(":", "-");
    p = p.replace(";", "-");
    p = p.replace("\"", "-");
    p = p.replace("(", "-");
    p = p.replace(")", "-");
    p = p.replace("unknown", "");
    while "--" in p {
        p = p.replace("--", "-");
    }
    while len(p) > 0 and p[len(p) - 1] == "-" {
        p = p[0:len(p) - 1];
    }
    return p;
}

def:pub platform(aliased: bool = False, terse: bool = False) -> str {
    if terse {
        if _UC.pdone_t {
            return _UC.pterse;
        }
    } elif _UC.pdone_f {
        return _UC.pfull;
    }
    u = uname();
    system: str = u.system;
    release: str = u.release;
    machine: str = u.machine;
    processor: str = u.processor;
    if machine == processor {
        processor = "";
    }
    if system == "Darwin" {
        mac = plat_macos_release();
        if mac != "" {
            system = "macOS";
            release = mac;
        }
    }
    result: str = "";
    if system == "Linux" {
        lv = libc_ver();
        result = _platform_join(
            [system, release, machine, processor, "with", lv[0] + lv[1]]
        );
    } elif terse {
        result = _platform_join([system, release]);
    } else {
        (bits, linkage) = architecture();
        result = _platform_join([system, release, machine, processor, bits, linkage]);
    }
    if terse {
        _UC.pterse = result;
        _UC.pdone_t = True;
    } else {
        _UC.pfull = result;
        _UC.pdone_f = True;
    }
    return result;
}
