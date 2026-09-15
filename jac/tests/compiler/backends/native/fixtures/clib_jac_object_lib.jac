"""An imported Jac object appears in a C ABI signature before layout emission."""
glob imported_drops: int = 0;
obj ImportedPacket {
    has value: i64;

    def drop {
        imported_drops += 1;
    }
}

import from c { def echo_imported_packet(value: ImportedPacket) -> ImportedPacket;  }

def:pub retain_imported_packet(value: ImportedPacket) -> ImportedPacket {
    return value;
}
def imported_roundtrip -> i64 {
    original = ImportedPacket(17);
    returned = echo_imported_packet(original);
    return returned.value;
}

def imported_drop_count -> int {
    return imported_drops;
}
