"""Test ClassVar type annotation support."""
import from typing { ClassVar }

obj DSFunc {
    has trigger: type | None = None;
}

obj Archetype {
    has _jac_entry_funcs_: ClassVar[list[DSFunc]] = [];
    has _jac_exit_funcs_: ClassVar[list[DSFunc]] = [];
}

obj NodeArchetype(Archetype) {}

obj WalkerArchetype(Archetype) {}

# Test: accessing ClassVar members and iterating over them
def execute_entries(
    warch: WalkerArchetype,
    current_loc: NodeArchetype
) -> bool {
    # ClassVar[list[DSFunc]] should unwrap to list[DSFunc]
    # and be iterable without errors
    for i in warch._jac_entry_funcs_ {
        if i.trigger {
            print(i.trigger);
        }
    }
    for i in current_loc._jac_entry_funcs_ {
        if not i.trigger {
            print(i.trigger);
        }
    }
    return True;
}
