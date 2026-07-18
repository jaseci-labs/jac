# Gate fixture for ELF static C-archive linking (#6978 Phase 0.1a): call the
# extern C leaf `jac_floor_magic` (defined by a merged archive member) and print
# its constant 0x1122334455667788 == 1234605616436508552. The import name is
# only an FFI declaration site; the symbol is satisfied statically by the member
# object passed to ElfLinker.link(archive_members=...), not a runtime dependency.
import from floorlib { def jac_floor_magic() -> i64;  }

with entry {
    print(jac_floor_magic());
}
