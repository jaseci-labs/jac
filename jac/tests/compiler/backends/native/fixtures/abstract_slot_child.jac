"""Direct inherited field access and interface dispatch must share one layout."""
import from abstract_slot_interface { SlotInterface }
import from abstract_slot_storage { SlotStorage }
obj SlotLeaf(SlotStorage) {
    has extra: int = 7;
}

def run_abstract_slots -> int {
    leaf = SlotLeaf(values=[5]);
    interface: SlotInterface = leaf;
    if not isinstance(interface, SlotLeaf) {
        return -1;
    }
    return leaf.values[0] + interface.read() + leaf.extra;
}
