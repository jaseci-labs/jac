"""Implementation of JIR class methods."""
import struct;
import sys;
import zlib;

# --- JirHeader methods ---
impl JirHeader.to_bytes -> bytes {
    return struct.pack(
        HEADER_FMT,
        self.magic,
        self.format_version,
        self.python_version,
        self.jaclang_version_hash,
        self.source_content_hash,
        self.node_count,
        self.symbol_count,
        self.string_pool_size,
        self.flags
    );
}

impl JirHeader.is_compatible -> bool {
    expected_py = (sys.version_info.major << 8) | sys.version_info.minor;
    if self.python_version != expected_py {
        return False;
    }
    import from importlib.metadata { version as pkg_version }
    try {
        jac_ver = pkg_version('jaclang');
    } except Exception {
        jac_ver = "0.0.0";
    }
    expected_jac = zlib.crc32(jac_ver.encode()) & 0xFFFFFFFF;
    if self.jaclang_version_hash != expected_jac {
        return False;
    }
    return True;
}
