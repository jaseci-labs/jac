"""A concrete implementation whose fields are inherited in another unit."""
import from abstract_slot_interface { SlotInterface }
obj SlotStorage(SlotInterface) {
    has values: list[int];

    def read -> int {
        return self.values[0];
    }
}
