"""Base archetype definitions."""
import from typing { ClassVar, Any }

obj DSFunc {
    has trigger: type | None = None;
}

obj Archetype {
    with entry {
        _jac_entry_funcs_: ClassVar[list[DSFunc]] = [];
        
        _jac_exit_funcs_: ClassVar[list[DSFunc]] = [];
    }

    def __init_subclass__(cls: Any, **kwargs: object) -> None;
}
obj NodeArchetype(Archetype) {
}

obj EdgeArchetype(Archetype) {
}

obj WalkerArchetype(Archetype) {
}

# Test 5: Combined test like runtime.jac
def execute_entries(
    warch: WalkerArchetype,
    current_loc: NodeArchetype | EdgeArchetype
) -> bool {
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