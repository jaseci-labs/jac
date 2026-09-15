"""Local and imported Jac objects retain typed ownership across C callbacks."""
import from .clib_jac_object_lib {
    imported_roundtrip,
    imported_drop_count,
    retain_imported_packet
}
glob local_drops: int = 0;
obj LocalPacket {
    has value: i64;

    def drop {
        local_drops += 1;
    }
}

import from c { def echo_local_packet(value: LocalPacket) -> LocalPacket;  }

def:pub retain_local_packet(value: LocalPacket) -> LocalPacket {
    return value;
}
def local_roundtrip -> i64 {
    original = LocalPacket(25);
    returned = echo_local_packet(original);
    return returned.value;
}

def:pub roundtrip -> i64 {
    return local_roundtrip() + imported_roundtrip();
}
def:pub drop_count -> int {
    return local_drops + imported_drop_count();
}
