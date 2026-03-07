"""Gap #44: Context manager __exit__ not checked, alias type not bound.

exit_with_stmt only checks for __enter__. Missing:
  1. __exit__ method validation
  2. Alias (as x) type binding to __enter__ return type
  3. Async context manager (__aenter__/__aexit__) not checked

Expected errors:
  1. Object with __enter__ but no __exit__ used in with
  2. as-variable should be str (from __enter__), assigned to int
  3. as-variable should be list[int] (from __enter__), assigned to str
  4. Multiple context managers, second has no __exit__
"""

obj ValidManager {
    def __enter__ -> str {
        return "resource";
    }

    def __exit__(exc_type: type, exc_val: Exception, exc_tb: object) -> bool {
        return False;
    }
}

obj EnterOnlyManager {
    def __enter__ -> int {
        return 42;
    }
    # Missing __exit__ — not a valid context manager
}

obj ExitOnlyManager {
    def __exit__(exc_type: type, exc_val: Exception, exc_tb: object) -> bool {
        return False;
    }
    # Missing __enter__ — not a valid context manager (already caught by existing check)
}

obj TypedManager {
    def __enter__ -> list[int] {
        return [1, 2, 3];
    }

    def __exit__(exc_type: type, exc_val: Exception, exc_tb: object) -> bool {
        return False;
    }
}

with entry {
    # Case 1: Object with __enter__ but no __exit__
    eo = EnterOnlyManager();
    with eo as val {              # Error: no __exit__ method
        print(val);
    }

    # Case 2: as-variable type should be bound to __enter__ return type
    vm = ValidManager();
    with vm as resource {
        # resource should be str (from __enter__ return type)
        bad1: int = resource;     # Error: str -> int (if alias binding works)
    }

    # Case 3: Typed manager — alias should get list[int] type
    tm = TypedManager();
    with tm as items {
        # items should be list[int] (from __enter__ return type)
        bad2: str = items;        # Error: list[int] -> str
    }

    # Case 4: Multiple context managers, one invalid
    with vm as r1, eo as r2 {    # Error: eo has no __exit__
        print(r1);
        print(r2);
    }

    # --- Cases that SHOULD be valid ---
    with vm as s {                # Ok: ValidManager has both __enter__ and __exit__
        good: str = s;            # Ok if alias binding works (str -> str)
    }
}
