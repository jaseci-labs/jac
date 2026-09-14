"""The dispatcher knows the interface, independently of its implementations."""
import from abstract_slot_interface { SlotInterface }
def dispatch_read(value: SlotInterface) -> int {
    return value.read();
}
