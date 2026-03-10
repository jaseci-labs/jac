"""Gap #50: postinit method not validated against by-postinit field declarations.

When an obj declares fields with 'by postinit', the type checker should
verify that the postinit method actually assigns to ALL such fields with
compatible types. The semantic analysis pass already checks that a postinit
method EXISTS, but the type checker should go further:

  A) All 'by postinit' fields must be assigned in the postinit body
  B) Assigned values must be compatible with the declared field types

Currently, the type checker does not inspect postinit bodies to verify
these constraints, allowing missing assignments and type mismatches to
slip through to runtime.

Expected errors:
  1. Incomplete: self.z never assigned in postinit     (missing assignment)
  2. WrongType: self.value = "wrong"                   (str to int field)
  3. WrongType: self.label = 42                        (int to str field)

No errors expected for:
  - Complete: all by-postinit fields correctly assigned
"""

# --- Correct: all by-postinit fields assigned with correct types ---
obj Complete {
    has a: int = 5,
        b: int by postinit,
        c: str by postinit;

    def postinit -> None;
}

impl Complete.postinit {
    self.b = self.a * 2;        # Ok: int assigned to int field
    self.c = "hello";           # Ok: str assigned to str field
}

# --- Missing: postinit doesn't assign to all by-postinit fields ---
obj Incomplete {
    has x: int = 1,
        y: int by postinit,
        z: str by postinit;

    def postinit -> None;
}

impl Incomplete.postinit {
    self.y = self.x + 10;      # Ok: int assigned to int field
    # Missing: self.z is never assigned — Error!
}

# --- Wrong types: postinit assigns incompatible types ---
obj WrongType {
    has value: int by postinit,
        label: str by postinit;

    def postinit -> None;
}

impl WrongType.postinit {
    self.value = "wrong";       # Error: str assigned to int field
    self.label = 42;            # Error: int assigned to str field
}

with entry {
    c = Complete(a=10);
    print(c.b, c.c);           # Ok: properly initialized

    i = Incomplete(x=5);
    print(i.y, i.z);           # Runtime crash: z never assigned

    w = WrongType();
    print(w.value, w.label);   # Wrong types at runtime
}
