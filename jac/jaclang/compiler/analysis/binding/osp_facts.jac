import from jaclang.runtime.object_model { field }

obj OspSlot {
    has owner: str,
        kind: str,
        ability: str,
        is_entry: bool,
        has_body: bool,
        trigger_names: list[str] = field(default_factory=`list);
}


obj OspModel {
    has arch_kind: dict[(str, str)] = field(default_factory=`dict),
        tags: dict[(str, int)] = field(default_factory=`dict),
        order: list[str] = field(default_factory=`list),
        order_index: dict[(str, int)] = field(default_factory=`dict),
        isa: dict[(str, list[str])] = field(default_factory=`dict),
        slots: list[OspSlot] = field(default_factory=`list),
        collisions: list[tuple[str, str]] = field(default_factory=`list),
        uses_construct: bool = False;

    def has_event_ability -> bool {
        return len(self.slots) > 0;
    }

    def local_slots -> list[OspSlot] {
        return [
            s
            for s in self.slots
            if s.has_body
        ];
    }

    def has_local_ability -> bool {
        return len(self.local_slots()) > 0;
    }

    def local_index(name: str) -> int {
        return self.order_index.get(name, -1);
    }

    def trigger_tags(slot: OspSlot) -> list[int] {
        if not slot.trigger_names {
            return [-1];
        }
        out: list[int] = [];
        for _n in slot.trigger_names {
            out.append(self.tags.get(_n, -1));
        }
        return out;
    }

    def entry_slots(owner: str) -> list[OspSlot] {
        return [
            s
            for s in self.slots
            if (s.owner == owner) and s.is_entry
        ];
    }

    def exit_slots(owner: str) -> list[OspSlot] {
        return [
            s
            for s in self.slots
            if (s.owner == owner) and (not s.is_entry)
        ];
    }
}
