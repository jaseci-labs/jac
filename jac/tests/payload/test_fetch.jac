"""Offline coverage of the fetch side: the llvm-slice range fetch (zip
central-directory parsing, member selection, run coalescing, crc + manifest
sha verification) against a synthetic zip served from memory, the bun zip
member lookup, the checksum-line parser, the platform tables, and the pins."""

import hashlib;
import io;
import json;
import os;
import shutil;
import tempfile;
import zipfile;

import from jaclang.payload.fetch {
    BUN_VERSION,
    HttpSource,
    bun_asset_name,
    fetch_llvm_slice,
    parse_central_directory,
    parse_eocd,
    pbs_platform,
    slice_wanted,
    unzip_member_by_suffix
}
import from jaclang.payload.fsutil { PayloadDie, find_sum_line }
import from jaclang.payload.pins {
    LlvmSlice,
    llvm_release,
    load_pins,
    pins,
    py_minor,
    py_ver
}
import from jaclang.runtimelib.client.bun_installer {
    BUN_VERSION as INSTALLER_BUN_VERSION
}

# zipfile's method constants are typed `Final` in typeshed, which the checker
# cannot assign from; spell them as the ints they are and pin them below.
glob ZIP_STORED: int = 0,
     ZIP_DEFLATED: int = 8;

"""Serves the synthetic zip + manifest from memory with HTTP range semantics."""
obj MemSource(HttpSource) {
    has blob: bytes = b"",
        manifest: bytes = b"",
        ranges: list[tuple[int, int]] = [];

    override def get(url: str) -> bytes {
        assert url.endswith("-manifest.json") , url;
        return self.manifest;
    }

    override def get_range(url: str, start: int, end: int) -> bytes {
        assert url.endswith("-dev.zip") , url;
        assert 0 <= start <= end < len(self.blob) , (start, end, len(self.blob));
        self.ranges.append((start, end));
        return self.blob[start:end + 1];
    }
}

def build_slice_zip -> tuple[bytes, dict[str, bytes]] {
    contents = {
        "lib/libLLVMCore.a": b"!<arch>\ncore" * 3000,
        "bin/clang": bytes(range(256)) * 400,
        "lib/libLLVMSupport.a": b"!<arch>\nsupport" * 2000,
        "lib/libLTO.dylib": b"\xcf\xfa\xed\xfelto" * 500,
        "lib/libclang.a": b"!<arch>\nclang" * 100,
        "include/llvm/ADT/ArrayRef.h": b"#pragma once\n// arrayref\n" * 40,
        "include/llvm-c/Core.h": b"#pragma once\n// core\n" * 40,
        "share/doc/README": b"docs\n" * 10
    };
    buf = io.BytesIO();
    with zipfile.ZipFile(buf, "w") as zf {
        for (name, data) in contents.items() {
            method = ZIP_STORED
                if name in ("lib/libLTO.dylib", "share/doc/README")
                else ZIP_DEFLATED;
            zf.writestr(name, data, compress_type=method);
        }
    }
    return (buf.getvalue(), contents);
}

def manifest_for(contents: dict[str, bytes], tamper: bool = False) -> bytes {
    libs = {};
    for (name, data) in contents.items() {
        if name.startswith("lib/libLLVM") {
            sha = hashlib.sha256(data).hexdigest();
            if tamper and name == "lib/libLLVMCore.a" {
                sha = "0" * 64;
            }
            libs[name.split("/")[-1]] = {"file": name, "sha256": sha};
        }
    }
    return json.dumps({"libs": libs}).encode("utf-8");
}

def slice_for(blob: bytes, manifest: bytes) -> LlvmSlice {
    return LlvmSlice(
        dirname="LLVM-test-slice",
        triple="x86_64-test",
        manifest_sha256=hashlib.sha256(manifest).hexdigest(),
        zip_size=len(blob),
        upstream=False
    );
}

test "zip method constants mirror zipfile" {
    assert ZIP_STORED == zipfile.ZIP_STORED;
    assert ZIP_DEFLATED == zipfile.ZIP_DEFLATED;
}

test "slice_wanted selects the LLVM archives, llvm headers, and (macOS) libLTO" {
    assert slice_wanted("lib/libLLVMCore.a", False);
    assert slice_wanted("lib/libLLVMSupport.a", True);
    assert slice_wanted("include/llvm/ADT/ArrayRef.h", False);
    assert slice_wanted("include/llvm-c/Core.h", False);
    assert not slice_wanted("include/clang/Basic/X.h", False);
    assert not slice_wanted("lib/libclang.a", False);
    assert not slice_wanted("lib/libLLVM.so", False);
    assert not slice_wanted("bin/clang", True);
    assert not slice_wanted("lib/libLTO.dylib", False);
    assert slice_wanted("lib/libLTO.dylib", True);
}

test "central directory parsing agrees with zipfile on a synthetic zip" {
    (blob, contents) = build_slice_zip();
    tail = blob[-min(len(blob), 65536):];
    (cd_size, cd_off) = parse_eocd(tail, "fetch-llvm");
    members = parse_central_directory(blob[cd_off:cd_off + cd_size]);
    with zipfile.ZipFile(io.BytesIO(blob)) as zf {
        infos = zf.infolist();
    }
    assert len(members) == len(infos) == len(contents);
    by_name = {m.name: m for m in members};
    for zi in infos {
        m = by_name[zi.filename];
        assert m.method == zi.compress_type;
        assert m.csize == zi.compress_size;
        assert m.crc == zi.CRC;
        assert m.lho == zi.header_offset;
    }
    try {
        parse_eocd(b"no zip here", "fetch-llvm");
        assert False , "expected a die";
    } except PayloadDie as e {
        assert str(e) == "fetch-llvm: no zip EOCD found";
    }
}

test "fetch_llvm_slice range-fetches and extracts only the wanted members" {
    (blob, contents) = build_slice_zip();
    manifest = manifest_for(contents);
    base = tempfile.mkdtemp(prefix="jac-payload-llvm-");
    try {
        src = MemSource(blob=blob, manifest=manifest, ranges=[]);
        fetch_llvm_slice(base, slice_for(blob, manifest), src, False);
        slice_root = os.path.join(base, "LLVM-test-slice");
        for name in (
            "lib/libLLVMCore.a",
            "lib/libLLVMSupport.a",
            "include/llvm/ADT/ArrayRef.h",
            "include/llvm-c/Core.h"
        ) {
            with open(os.path.join(slice_root, name), "rb") as f {
                assert f.read() == contents[name] , name;
            }
        }
        for name in (
            "bin/clang",
            "lib/libclang.a",
            "lib/libLTO.dylib",
            "share/doc/README"
        ) {
            assert not os.path.exists(os.path.join(slice_root, name)) , name;
        }
        # EOCD tail, central directory, then ONE coalesced run (every wanted
        # member sits within the 16 MiB gap of the next) -- three range GETs.
        assert len(src.ranges) == 3 , src.ranges;
        assert src.ranges[0] == (len(blob) - min(len(blob), 65536), len(blob) - 1);

        # macOS additionally wants libLTO.dylib (a stored member).
        base2 = os.path.join(base, "mac");
        fetch_llvm_slice(
            base2,
            slice_for(blob, manifest),
            MemSource(blob=blob, manifest=manifest, ranges=[]),
            True
        );
        with open(
            os.path.join(base2, "LLVM-test-slice", "lib/libLTO.dylib"), "rb"
        ) as f {
            assert f.read() == contents["lib/libLTO.dylib"];
        }
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
}

test "fetch_llvm_slice refuses a swapped manifest or a swapped archive" {
    (blob, contents) = build_slice_zip();
    manifest = manifest_for(contents);
    base = tempfile.mkdtemp(prefix="jac-payload-llvm-");
    try {
        rel = slice_for(blob, manifest);
        rel.manifest_sha256 = "f" * 64;
        try {
            fetch_llvm_slice(
                base, rel, MemSource(blob=blob, manifest=manifest, ranges=[]), False
            );
            assert False , "expected a die";
        } except PayloadDie as e {
            assert str(e).startswith("fetch-llvm: manifest checksum mismatch");
        }

        bad_manifest = manifest_for(contents, tamper=True);
        try {
            fetch_llvm_slice(
                base,
                slice_for(blob, bad_manifest),
                MemSource(blob=blob, manifest=bad_manifest, ranges=[]),
                False
            );
            assert False , "expected a die";
        } except PayloadDie as e {
            assert str(e) == "fetch-llvm: sha256 mismatch for lib/libLLVMCore.a";
        }
    } finally {
        shutil.rmtree(base, ignore_errors=True);
    }
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
    assert pbs_platform("macos-aarch64") == "aarch64-apple-darwin";
    assert pbs_platform("macos-x86_64") == "x86_64-apple-darwin";
    assert pbs_platform("linux-x86_64") == "x86_64-unknown-linux-gnu";
    assert pbs_platform("linux-aarch64") == "aarch64-unknown-linux-gnu";
    assert pbs_platform("windows-x86_64") is None;
    assert bun_asset_name("macos-aarch64") == "bun-darwin-aarch64";
    assert bun_asset_name("macos-x86_64") == "bun-darwin-x64";
    assert bun_asset_name("linux-x86_64") == "bun-linux-x64";
    assert bun_asset_name("linux-aarch64") == "bun-linux-aarch64";
    assert bun_asset_name("windows-x86_64") == "bun-windows-x64";
    assert bun_asset_name("freebsd-x86_64") is None;
}

test "pins.json carries the pbs + llvm pins and bun stays in lockstep" {
    p = pins();
    assert load_pins().pbs.tag == p.pbs.tag;
    assert p.pbs.tag == "20260610";
    assert p.pbs.python == "3.14.6";
    assert p.pbs.flavor == "pgo+lto-full";
    assert p.pbs.base
        == "https://github.com/astral-sh/python-build-standalone/releases/download";
    assert py_ver() == "3.14";
    assert py_minor("3.14.6") == "3.14";
    try {
        py_minor("3.14");
        assert False , "expected a die";
    } except PayloadDie { }

    assert p.llvm.version == "22.1.8";
    assert p.llvm.slice_base
        == "https://github.com/jaseci-labs/llvm-slice/releases/download";
    assert sorted(p.llvm.slices)
        == ["linux-aarch64", "linux-x86_64", "macos-aarch64", "macos-x86_64"];
    slices = p.llvm.slices;
    lx = slices["linux-x86_64"];
    assert llvm_release("linux-x86_64") is lx;
    assert lx.dirname == "LLVM-22.1.8-Linux-X64-libcxx";
    assert lx.triple == "x86_64-linux-libcxx";
    assert lx.zip_size == 667452266;
    assert not lx.upstream;
    la = slices["linux-aarch64"];
    assert la.dirname == "LLVM-22.1.8-Linux-ARM64-libcxx" and la.zip_size == 462054429;
    assert la.triple == "aarch64-linux-libcxx" and not la.upstream;
    ma = slices["macos-aarch64"];
    assert ma.dirname == "LLVM-22.1.8-macOS-ARM64"
        and ma.upstream
        and ma.zip_size == 743879473;
    assert ma.triple == "aarch64-apple-darwin";
    mx = slices["macos-x86_64"];
    assert mx.dirname == "LLVM-22.1.8-macOS-X64"
        and not mx.upstream
        and mx.zip_size == 49613317;
    assert mx.triple == "x86_64-apple-darwin";
    for rel in p.llvm.slices.values() {
        assert len(rel.manifest_sha256) == 64;
        assert rel.dirname.startswith("LLVM-22.1.8-");
    }
    assert llvm_release("windows-x86_64") is None;

    assert BUN_VERSION == INSTALLER_BUN_VERSION;
}
