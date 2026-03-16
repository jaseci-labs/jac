"""Test type[T] subscript member access.

When a parameter is typed as type[T], accessing class-level members (ClassVar)
should resolve to T's members, not the builtin type class's members.

This tests the bug where cls._jac_entry_funcs_ fails when cls: type[Archetype].
"""
import from typing { ClassVar }
import from collections { OrderedDict }

obj DSFunc {
    has name: str,
        trigger: type | None = None;
}

obj Archetype {
    has _jac_entry_funcs_: ClassVar[list[DSFunc]] = [];
    has _jac_exit_funcs_: ClassVar[list[DSFunc]] = [];
}

obj NodeArchetype(Archetype) {}

obj WalkerArchetype(Archetype) {}

# Test 1: Accessing ClassVar on type[T] parameter
def make_archetype(cls: type[Archetype]) -> type[Archetype] {
    # These should work - accessing ClassVar members on type[T]
    entries: OrderedDict[(str, DSFunc)] = OrderedDict(
        (fn.name, fn) for fn in cls._jac_entry_funcs_
    );
    exits: OrderedDict[(str, DSFunc)] = OrderedDict(
        (fn.name, fn) for fn in cls._jac_exit_funcs_
    );
    print('exits:', exits, 'entries:', entries);
    return cls;
}

# Test 2: Accessing ClassVar on type[Subclass] parameter
def process_walker(walker_cls: type[WalkerArchetype]) -> list[DSFunc] {
    # Should resolve _jac_entry_funcs_ from WalkerArchetype (inherited from Archetype)
    return walker_cls._jac_entry_funcs_;
}

# Test 3: Accessing ClassVar on type[T] with iteration
def count_entries(cls: type[Archetype]) -> int {
    count = 0;
    for func in cls._jac_entry_funcs_ {
        if func.trigger {
            count += 1;
            print('count:', count);
        }
    }
    return count;
}

# Test 4: Using type[T] in a generic context
def get_class_name(cls: type[Archetype]) -> str {
    # __name__ is a class attribute that should be accessible on type[T]
    return cls.__name__;
}

# Test 5: Assigning to ClassVar on type[T]
def update_entries(cls: type[Archetype], new_entries: list[DSFunc]) -> None {
    cls._jac_entry_funcs_ = new_entries;
}
