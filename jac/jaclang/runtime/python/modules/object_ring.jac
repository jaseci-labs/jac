"""Circular storage shared by native Python queues and deques.

Slots contain owned CPython handles. Push/pop transfer ownership without calling
Python, so callers can publish complete mutations before releasing references.
Borrowing and replacement also leave ownership decisions to the caller.
"""
obj object_ring {
    has slots: list[u64] = [u64(0) for _ in range(8)],
        head: int = 0,
        count: int = 0;

    def resize(capacity: int) {
        slots = [u64(0) for _ in range(capacity)];
        for i in range(self.count) {
            slots[i] = self.borrow(i);
        }
        self.slots = slots;
        self.head = 0;
    }

    def borrow(index: int) -> u64 {
        return self.slots[(self.head + index) % len(self.slots)];
    }

    def exchange(index: int, value: u64) -> u64 {
        slot = (self.head + index) % len(self.slots);
        previous = self.slots[slot];
        self.slots[slot] = value;
        return previous;
    }

    def push(value: u64, left: bool = False) {
        if self.count == len(self.slots) {
            self.resize(len(self.slots) * 2);
        }
        if left {
            self.head = (self.head + len(self.slots) - 1) % len(self.slots);
            self.slots[self.head] = value;
        } else {
            self.slots[(self.head + self.count) % len(self.slots)] = value;
        }
        self.count += 1;
    }

    def pop(left: bool = False) -> u64 {
        index = self.head if left else (self.head + self.count - 1) % len(self.slots);
        value = self.slots[index];
        self.slots[index] = u64(0);
        if left {
            self.head = (self.head + 1) % len(self.slots);
        }
        self.count -= 1;
        if len(self.slots) > 8 and self.count < len(self.slots) // 4 {
            self.resize(len(self.slots) // 2);
        }
        return value;
    }
}
