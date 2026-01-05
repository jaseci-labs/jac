"""Test walrus operator type checking."""

glob result1 = (z := 20) + 10;  # OK: z is int, result is int
glob result2: int = result1;  # OK
glob result3: str = result1;  # Error: cannot assign int to str
glob result4: str = z;

node MyNode {}
node AnotherNode {}

with entry {
    print(result4);  # Should print 20

    if (x := 10) > 5 {
        y: int = x;  # OK: x is int
        y = "hello";  # Error: cannot assign str to int
    }

    # Walrus with node
    if n := MyNode() {
        m: MyNode = n;  # OK: n is MyNode
        p: AnotherNode = n;  # Error: cannot assign MyNode to AnotherNode
    }
    root ++> (a := MyNode());  # OK: a is MyNode
    a = AnotherNode();  # Error: cannot assign AnotherNode to MyNode
}
