"""The SysV hash tables the ELF linker writes are the ones the dynamic linker
walks.

An executable's table has real buckets. The dynamic linker searches the
executable first for every symbol relocation of every loaded library, so a
single-bucket table made each of those lookups walk all of the executable's
dynamic symbols.

The hash itself is glibc's, in 32-bit arithmetic. Python ints kept a carry past
bit 31 that the loader's unsigned int drops, so a name like `hxxxxskz` hashed
to a different bucket than the one glibc searches, and a shared library's
export with that name could not be found."""

import ctypes;
import shutil;
import struct;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from unittest { SkipTest }
import from jaclang.compiler.backends.native.elf_linker { ElfLinker, _elf_hash }

glob DT_HASH: int = 4,
     DT_STRTAB: int = 5,
     DT_SYMTAB: int = 6;

"""glibc's _dl_elf_hash, written out independently of the linker."""
def _glibc_elf_hash(name: bytes) -> int {
    if not name {
        return 0;
    }
    h = name[0];
    for c in name[1:] {
        h = ((h << 4) + c) & 0xFFFFFFFF;
        h ^= (h & 0xF0000000) >> 24;
    }
    return h & 0x0FFFFFFF;
}

"""File offset of a virtual address, through the PT_LOAD segments."""
def _vaddr_to_off(loads: list[tuple[int, int, int]], vaddr: int) -> int {
    for (off, va, filesz) in loads {
        if va <= vaddr and vaddr < va + filesz {
            return off + vaddr - va;
        }
    }
    raise AssertionError(f"vaddr {hex(vaddr)} is not in a loaded segment");
}

"""(nbucket, buckets, chains, dynsym names) from an ELF64 executable's DT_HASH."""
def _read_hash(path: Path) -> tuple[int, list[int], list[int], list[bytes]] {
    data = path.read_bytes();
    (phoff, ) = struct.unpack_from("<Q", data, 32);
    (phentsize, phnum) = struct.unpack_from("<HH", data, 54);
    loads: list[tuple[int, int, int]] = [];
    dyn_off = -1;
    dyn_size = 0;
    for i in range(phnum) {
        (p_type, _flags, off, va, _pa, filesz, _memsz, _align) = struct.unpack_from(
            "<IIQQQQQQ", data, phoff + i * phentsize
        );
        if p_type == 1 {
            loads.append((off, va, filesz));
        } elif p_type == 2 {
            dyn_off = off;
            dyn_size = filesz;
        }
    }
    assert dyn_off >= 0 , "no PT_DYNAMIC";
    tags: dict[int, int] = {};
    for pos in range(dyn_off, dyn_off + dyn_size, 16) {
        (tag, val) = struct.unpack_from("<qQ", data, pos);
        if tag == 0 {
            break;
        }
        tags.setdefault(tag, val);
    }
    hash_off = _vaddr_to_off(loads, tags[DT_HASH]);
    (nbucket, nchain) = struct.unpack_from("<II", data, hash_off);
    buckets = list(struct.unpack_from(f"<{nbucket}I", data, hash_off + 8));
    chains = list(struct.unpack_from(f"<{nchain}I", data, hash_off + 8 + 4 * nbucket));
    str_off = _vaddr_to_off(loads, tags[DT_STRTAB]);
    sym_off = _vaddr_to_off(loads, tags[DT_SYMTAB]);
    names: list[bytes] = [];
    for i in range(nchain) {
        (st_name, ) = struct.unpack_from("<I", data, sym_off + 24 * i);
        end = data.index(b"\0", str_off + st_name);
        names.append(data[str_off + st_name:end]);
    }
    return (nbucket, buckets, chains, names);
}

test "an executable's dynamic symbols are hashed into buckets the loader can walk" {
    if sys.platform != "linux" or shutil.which("cc") is None {
        raise SkipTest("requires Linux and a C compiler");
    }
    with tempfile.TemporaryDirectory() as directory {
        temp_dir = Path(directory);
        source = temp_dir / "entry.c";
        obj_path = temp_dir / "entry.o";
        output = temp_dir / "prog";
        # Enough libc imports that one bucket would be one long chain;
        # -fno-builtin keeps each call a real import.
        source.write_text(
            "#include <string.h>\n#include <stdlib.h>\n"
            "extern void _exit(int);\n"
            "void _start(void) {\n"
            "    char p[32];\n"
            "    strcpy(p, \"hash\");\n"
            "    int ok = strlen(p) == 4 && strcmp(p, \"hash\") == 0\n"
            "        && memcmp(p, \"ha\", 2) == 0 && strchr(p, 's') == p + 2\n"
            "        && atoi(\"7\") == 7 && abs(-3) == 3;\n"
            "    memset(p, 0, sizeof p);\n"
            "    _exit(ok ? 0 : 1);\n"
            "}\n"
        );
        subprocess.run(
            [
                "cc",
                "-c",
                "-fPIC",
                "-fno-builtin",
                "-O0",
                str(source),
                "-o",
                str(obj_path)
            ],
            check=True
        );
        assert ElfLinker.link(
            objects=[obj_path.read_bytes()],
            output_path=str(output),
            needed_libs=["libc.so.6"]
        );
        subprocess.run([str(output)], check=True, timeout=10);
        (nbucket, buckets, chains, names) = _read_hash(output);
        assert len(names) > 8 , str(names);
        assert nbucket > 1 , f"{nbucket} bucket(s) for {len(names)} dynamic symbols";
        for (i, name) in enumerate(names) {
            if i == 0 {
                continue;
            }
            j = buckets[_glibc_elf_hash(name) % nbucket];
            while j != 0 and j != i {
                j = chains[j];
            }
            assert j == i , f"{str(name)} (dynsym {i}) is not in its hash chain";
        }
    }
}

"""A name whose hash carries past bit 31: `hxxxxsk` hashes to 0x0ffffffb,
so appending `z` overflows 32 bits."""
glob CARRY_NAME: str = "hxxxxskz";

test "the linker's hash is glibc's, including a carry past bit 31" {
    for name in ("", "a", "printf", "__libc_start_main", CARRY_NAME) {
        assert _elf_hash(name) == _glibc_elf_hash(name.encode()) , name;
    }
}

test "a shared library's exports are found by the dynamic linker" {
    if sys.platform != "linux" or shutil.which("cc") is None {
        raise SkipTest("requires Linux and a C compiler");
    }
    # Ten exports and no imports: 11 dynamic symbols in 5 buckets, where the
    # carried bit would move CARRY_NAME out of the bucket glibc searches.
    names = [CARRY_NAME] + [f"export_{i}" for i in range(1, 10)];
    with tempfile.TemporaryDirectory() as directory {
        temp_dir = Path(directory);
        source = temp_dir / "lib.c";
        obj_path = temp_dir / "lib.o";
        output = temp_dir / "libhash.so";
        source.write_text(
            "".join(
                f"int {name}(void) {{ return {i + 40}; }}\n"
                for (i, name) in enumerate(names)
            )
        );
        subprocess.run(
            ["cc", "-c", "-fPIC", "-O0", str(source), "-o", str(obj_path)], check=True
        );
        assert ElfLinker.link(
            objects=[obj_path.read_bytes()],
            output_path=str(output),
            shared=True,
            export_symbols=names,
            soname="libhash.so"
        );
        lib = ctypes.CDLL(str(output));
        for (i, name) in enumerate(names) {
            fn = getattr(lib, name);
            fn.restype = ctypes.c_int;
            assert fn() == i + 40 , name;
        }
    }
}
