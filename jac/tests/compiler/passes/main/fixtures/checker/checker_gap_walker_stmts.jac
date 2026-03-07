"""Gap #43: Walker visit/disengage/report have zero type validation.

No exit_visit_stmt, exit_disengage_stmt, or exit_report_stmt handlers
exist. The expressions in visit and report statements are never
type-evaluated. Visit targets should be validated as nodes.

Expected errors:
  1. visit with non-node target (visit 42)
  2. visit with string literal (not a node)
  3. visit with wrong function arg type
  4. report with type error in expression
  5. report with nonexistent method
"""

node Place {
    has name: str;
}

node City {
    has population: int;
}

def format_report(count: int) -> str {
    return f"Found {count} items";
}

def get_place(name: str) -> Place {
    return Place(name=name);
}

walker Explorer {
    has findings: list[str] = [];

    can explore with entry {
        # Case 1: Visit a non-node value
        visit 42;                          # Error: int is not a node

        # Case 2: Visit a string (not a node)
        visit "some_place";                # Error: str is not a node

        # Case 3: Visit with wrong function arg type in expression
        visit get_place(123);              # Error: int -> str param

        # Case 4: Report with type error in expression
        report format_report("not_int");   # Error: str -> int param

        # Case 5: Report with nonexistent method
        report self.nonexistent_method();  # Error: no such method
    }
}

walker SafeWalker {
    can walk with entry {
        # --- Cases that SHOULD be valid ---
        p = Place(name="test");
        visit p;                           # Ok: Place is a node
        report "found something";          # Ok: str expression
        report format_report(5);           # Ok: correct types
        disengage;                         # Ok: no expression
    }
}
