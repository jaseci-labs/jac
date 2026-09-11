import struct;
import os;
import from jaclang.compiler.backends.native.linker_common {
    _align,
    _append_to_blob,
    _resolve_seg_vaddr
}

obj CoffSection {
    has name: str,
        characteristics: int,
        data: bytes,
        vsize: int;
}

obj CoffReloc {
    has offset: int,
        sym_idx: int,
        rtype: int,
        target_sec: int;
}

obj CoffSymbol {
    has name: str,
        value: int,
        sec_num: int,
        storage_class: int,
        weak_tag: int = -1,
        typ: int = 0;
}

obj PeLinker {
    has obj_data: bytes,
        symbols: list[CoffSymbol | None],
        sections: list[CoffSection],
        relocations: list[CoffReloc],
        needed_libs: list[str],
        symbol_lib_map: dict[str, str] = {},
        shared: bool = False,
        export_symbols: list[str] = [],
        init_funcs: list[str] = [],
        soname: str = "";

    static def link(
        obj_bytes: bytes,
        output_path: str,
        needed_libs: list[str] = ["msvcrt.dll"],
        symbol_lib_map: dict[str, str] = {},
        shared: bool = False,
        export_symbols: list[str] = [],
        init_funcs: list[str] = [],
        soname: str = ""
    ) -> bool;

    def parse_object -> bool;
    def build_executable -> bytes;
    def build_shared_object -> bytes;
}

glob IMAGE_FILE_MACHINE_AMD64 = 0x8664;

glob SCN_CNT_CODE = 0x20,
     SCN_CNT_INITIALIZED_DATA = 0x40,
     SCN_CNT_UNINITIALIZED_DATA = 0x80,
     SCN_LNK_REMOVE = 0x800,
     SCN_MEM_EXECUTE = 0x20000000,
     SCN_MEM_READ = 0x40000000,
     SCN_MEM_WRITE = 0x80000000;

glob REL_ADDR64 = 1,
     REL_ADDR32 = 2,
     REL_ADDR32NB = 3,
     REL_REL32 = 4,
     REL_REL32_5 = 9;

glob SYM_CLASS_EXTERNAL = 2,
     SYM_CLASS_WEAK_EXTERNAL = 105;

glob IMAGE_BASE = 0x140000000,
     SECT_ALIGN = 0x1000,
     FILE_ALIGN = 0x200;

glob IMAGE_FILE_DLL = 0x2000,
     DLL_IMAGE_BASE = 0x180000000,
     IMAGE_REL_BASED_ABSOLUTE = 0,
     IMAGE_REL_BASED_HIGHLOW = 3,
     IMAGE_REL_BASED_DIR64 = 10,
     IMAGE_DLLCHAR_DYNAMIC_BASE = 0x40,
     IMAGE_DLLCHAR_NX_COMPAT = 0x100;

glob WIN_ALIAS = {"malloc_usable_size": "_msize", "snprintf": "_snprintf"};
