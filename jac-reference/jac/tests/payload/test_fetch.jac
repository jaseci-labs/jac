"""Offline coverage of the fetch side: the bun zip member lookup, the
checksum-line parser, the platform tables, and the pins."""

import io;
import zipfile;

import from jaclang.dist.payload.fetch {
    BUN_VERSION,
    bun_asset_name,
    unzip_member_by_suffix
}
import from jaclang.dist.payload.fsutil { PayloadDie, find_sum_line }
import from jaclang.dist.payload.pins { load_pins, pins, py_minor, py_ver }
import from jaclang.client.js_runtime { BUN_VERSION as INSTALLER_BUN_VERSION }

# zipfile's method constants are typed `Final` in typeshed, which the checker
# cannot assign from; spell them as the ints they are and pin them below.
glob ZIP_STORED: int = 0,
     ZIP_DEFLATED: int = 8;

test "zip method constants mirror zipfile" {
    assert ZIP_STORED == zipfile.ZIP_STORED;
    assert ZIP_DEFLATED == zipfile.ZIP_DEFLATED;
}

test "unzip_member_by_suffix finds bun inside its release zip" {
    buf = io.BytesIO();
    with zipfile.ZipFile(buf, "w") as zf {
        zf.writestr("bun-linux-x64/README.md", b"readme", compress_type=ZIP_DEFLATED);
        zf.writestr(
            "bun-linux-x64/bun", b"\x7fELF bun" * 1000, compress_type=ZIP_DEFLATED
        );
    }
    blob = buf.getvalue();
    assert unzip_member_by_suffix(blob, "/bun") == b"\x7fELF bun" * 1000;
    try {
        unzip_member_by_suffix(blob, "/bun.exe");
        assert False , "expected a die";
    } except PayloadDie as e {
        assert str(e) == "fetch-bun: no member ending in '/bun.exe' found in zip";
    }
    try {
        unzip_member_by_suffix(b"short", "/bun");
        assert False , "expected a die";
    } except PayloadDie as e {
        assert str(e) == "fetch-bun: zip too small";
    }
}

test "find_sum_line reads `<hex>  <filename>` lines" {
    sums = "abc123  cpython-a.tar.zst\n"
    "def456 *bun-linux-x64.zip\r\n"
    "\n"
    "bad-line\n"
    "777\tother.zip\n";
    assert find_sum_line(sums, "cpython-a.tar.zst") == "abc123";
    assert find_sum_line(sums, "other.zip") == "777";
    assert find_sum_line(sums, "missing") is None;
    assert find_sum_line(sums, "*bun-linux-x64.zip") == "def456";
}

test "platform tables match the Zig tool" {
    assert bun_asset_name("macos-aarch64") == "bun-darwin-aarch64";
    assert bun_asset_name("macos-x86_64") == "bun-darwin-x64";
    assert bun_asset_name("linux-x86_64") == "bun-linux-x64";
    assert bun_asset_name("linux-aarch64") == "bun-linux-aarch64";
    assert bun_asset_name("windows-x86_64") == "bun-windows-x64";
    assert bun_asset_name("freebsd-x86_64") is None;
}

test "source pins agree with the payload" {
    p = pins();
    assert load_pins().python == p.python;
    assert p.python == "3.14.6";
    assert py_ver() == "3.14";
    assert py_minor("3.14.6") == "3.14";
    try {
        py_minor("3.14");
        assert False , "expected a die";
    } except PayloadDie {}

    assert BUN_VERSION == INSTALLER_BUN_VERSION;
}
