"""Programs the native tier ran and answered differently from the Python tier.

Each case here was found by the tier census (`tests/tier_census.jac`): an
ordinary program, not written for the native tier, that lowered, ran to the
end and printed something else. A refusal is loud; these were not."""
import from pathlib { Path }
import from tests.support { assert_native_identity }

def fixture(name: str) -> str {
    return str(Path(__file__).resolve().parent / "fixtures" / name);
}

"""A `switch` falls through: once a case matches, every later case runs until
a `break`, the default included, and a default that is reached before any
match runs too. The native lowering ran one case and left, skipped a case
with no body, and dropped a case that names several values."""
test "a switch falls through to the next case until a break" {
    out = assert_native_identity(
        fixture("switch_fallthrough.jac"), profiles=["rc", "managed"]
    );
    assert "banana ['banana-or-orange', 'grape']" in out , out;
    assert "kiwi ['kiwi-or-lime', 'default:kiwi']" in out , out;
    assert "3 many nine" in out , out;
    assert "5109" in out , out;
}

"""`(a, b) = pair` inside a function, where `a` and `b` are module globals,
assigns the globals, as `a = x` does. The native lowering bound two locals
and the globals kept their old values."""
test "a tuple assignment to module globals writes the globals" {
    out = assert_native_identity(
        fixture("unpack_into_globals.jac"), profiles=["rc", "managed"]
    );
    assert "World Hello 1" in out , out;
    assert "y1 y2 3" in out , out;
    assert "['p', 'q'] q lr" in out , out;
}

"""`3 == 3.0` and `True == 1` hold whatever the static types are. Two untyped
values were equal on the native tier only when they were the same kind of
number, so `x as int as float == 3.0` was false for `x: any = 3`."""
test "untyped numbers of different kinds compare by value" {
    out = assert_native_identity(
        fixture("any_number_equality.jac"), profiles=["rc", "managed"]
    );
    assert "True True True True True" in out , out;
    assert "False False False False True" in out , out;
    assert "True True True False" in out , out;
}

"""An archetype is a dataclass on the Python tier, so printing one writes
`Name(field=value, ...)`. The native tier wrote `<Name object at 0x...>`,
which is different text and a different one every run."""
test "an object without its own repr prints its fields" {
    out = assert_native_identity(
        fixture("default_object_text.jac"), profiles=["rc", "managed"]
    );
    assert "Named(x=1, y=2.0, label=\"it's\", tags=['a', 'b'])" in out , out;
    assert "Holder(inner=Point(x=3, y=1.5), maybe=None, flag=True)" in out , out;
    assert "Link(name='a', nxt=Link(name='b', nxt=None))" in out , out;
    assert "Bag(counts={'x': 1}, seen={1}, pair=(1, 'a'), anything='q', ratio=0.1)"
        in out , out;
    assert "Tour(depth=2) Road(km=9)" in out , out;
}

"""The text follows the object, not the type it is held as: a subclass
instance held as its base prints the subclass's name and fields, or runs the
subclass's own `__repr__`."""
test "default object text follows the runtime class" {
    out = assert_native_identity(
        fixture("default_object_text_subclass.jac"), profiles=["rc", "managed"]
    );
    assert "Shape(sides=0) Square(sides=4, width=2) Named<q>" in out , out;
    assert "[Square(sides=4, width=2), Shape(sides=0), Named<q>]" in out , out;
}

"""An ability triggered by `Root` runs at the root node only. The native
tier has no root node of its own and read the name as "any location", so
`with Root | Stop entry` ran at every node, and twice at a `Stop`. An
ability whose trigger names a base and its subclass does run twice at the
subclass, on both tiers."""
test "a Root trigger does not match every node" {
    out = assert_native_identity(
        fixture("union_trigger_abilities.jac"), profiles=["rc", "managed"]
    );
    assert "['ab', 'a'] ['ab'] ['root-or-c']" in out , out;
    assert "['either', 'either', 'leaving', 'leaving'] ['either', 'leaving']"
        in out , out;
}

"""Two graph forms were accepted by the native tier and did nothing: a
statement naming `root` was dropped whole, and a connect with a list as an
operand connected to the list object. A walker then stopped early and the
program printed less than the Python tier, with no error. What is still not
lowered (`root` as a value, and a list on both sides of a connect) is
refused by name."""
test "graph forms the native tier cannot lower are refused, not dropped" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from tests.support { native_force_opts }
    options = native_force_opts();
    options.skip_native_engine = True;
    options.no_ir_cache = True;
    program = JacProgram();
    program.compile(file_path=fixture("graph_forms_not_lowered.jac"), options=options);
    refusals = [str(e) for e in program.errors_had];
    assert any("expression 'root'" in r for r in refusals) , refusals;
    assert any("connect operand 'root'" in r for r in refusals) , refusals;
    assert any("connect operand 'list'" in r for r in refusals) , refusals;
}

"""A function that cannot be lowered is left to the Python tier and every
native caller of it is refused. A walker's ability has no caller in the
source: the graph engine runs it. So a walker with an ability that could not
be lowered compiled, and the program stopped on the stub when the engine
reached it. The module is now refused when that happens."""
test "a walker ability that cannot be lowered refuses the module" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from tests.support { native_force_opts }
    options = native_force_opts();
    options.skip_native_engine = True;
    options.no_ir_cache = True;
    program = JacProgram();
    program.compile(file_path=fixture("ability_not_lowered.jac"), options=options);
    refusals = [str(e) for e in program.errors_had];
    assert any("event ability" in r and "look" in r for r in refusals) , refusals;
}

"""`print(f())` writes `None` when `f` returns nothing. The native tier
refused the program instead, which made this the most common reason a
program was not native in the first census."""
test "printing the result of a call that returns nothing writes None" {
    out = assert_native_identity(
        fixture("print_none_result.jac"), profiles=["rc", "managed"]
    );
    assert "a None b None" in out , out;
    assert "None 1 2" in out , out;
}

"""`hub ++> [a, b]` connects `hub` to each node, and `[a, b] ++> sink` each
node to `sink`, with a fresh edge per connection."""
test "a connect with a list of nodes on one side connects each node" {
    out = assert_native_identity(
        fixture("connect_through_list.jac"), profiles=["rc", "managed"]
    );
    assert "fan out [1, 2, 3]" in out , out;
    assert "fan in [5, 9] [6, 9]" in out , out;
    assert "typed [10, 11, 12]" in out , out;
    assert "single and empty [20, 21]" in out , out;
}

"""An object reached again while its own text is being written prints as
`...`, as a dataclass does on the Python tier, so a tree with parent links
or two objects that hold each other still print and still terminate."""
test "default object text stops at an object it is already writing" {
    out = assert_native_identity(
        fixture("default_object_text_cycle.jac"), profiles=["rc", "managed"]
    );
    assert "Tree(name='top', parent=None, kids=[Tree(name='kid', parent=..., kids=[])])"
        in out , out;
    assert "Pair(left=Pair(left=..., label='b'), label='a')" in out , out;
}

"""The native tier has no root node. A plain `root ++> node` in a module
that only follows edges forward is an anchor nothing native can observe, so
it is accepted and the rest of the statement still happens: `root ++> a ++>
b` used to drop the whole statement and leave `a` and `b` unconnected. A
root connect that names an edge, or sits beside a backward traversal, would
be missed, and is refused."""
test "a connect from root keeps the rest of the chain" {
    out = assert_native_identity(
        fixture("connect_from_root.jac"), profiles=["rc", "managed"]
    );
    assert "chain [1, 2, 3]" in out , out;
    assert "reversed [4, 5]" in out , out;
}

"""An integer and a float are equal when they are the same number, not when
they round to the same float. `9007199254740993 == 9007199254740992.0` is
false, and so is `9223372036854775807 == 9223372036854775808.0`; comparing
both sides as floats made each of them true."""
test "untyped numbers compare exactly past the range a float holds" {
    out = assert_native_identity(
        fixture("any_number_equality_wide.jac"), profiles=["rc", "managed"]
    );
    assert "False True" in out , out;
    assert "True True False False" in out , out;
}

"""`(a, b) = (b, a)` on two module globals reads both before it writes
either. Releasing the value a global held as soon as it was overwritten freed
an object the second assignment was still about to store."""
test "swapping two module globals that hold objects keeps both" {
    out = assert_native_identity(
        fixture("unpack_swaps_object_globals.jac"), profiles=["rc", "managed"]
    );
    assert out == "R L 2\nL R 2\nR L 2\n" , out;
}

"""`sinks <++ src` yields `sinks` and `hub <++ feeders` yields `hub`: the
side the edges arrive at, as written, whichever side is the list."""
test "a connect written toward its source yields the destination" {
    out = assert_native_identity(
        fixture("connect_reverse_result.jac"), profiles=["rc", "managed"]
    );
    assert "reverse list dest 2" in out , out;
    assert "reverse node dest 10" in out , out;
    assert "[1, 2, 3]" in out , out;
}

"""Only an edge that leaves root is an anchor nothing native can observe.
One that arrives at root, or runs both ways, gives the node an outgoing edge
a forward traversal would follow, so it is refused like any other use of
root."""
test "a connect that puts an edge into root is refused" {
    import from jaclang.compiler.driver.program { JacProgram }
    import from tests.support { native_force_opts }
    options = native_force_opts();
    options.skip_native_engine = True;
    options.no_ir_cache = True;
    program = JacProgram();
    program.compile(file_path=fixture("connect_into_root.jac"), options=options);
    refusals = [
        str(e)
        for e in program.errors_had
        if "connect operand 'root'" in str(e)
    ];
    assert len(refusals) == 4 , [str(e) for e in program.errors_had];
}

"""A `continue` inside a switch belongs to the loop around the switch. The
native tier jumped to that loop without running the `finally` blocks it left
on the way. The Python tier runs a switch as a loop of its own and restarted
it, so the same program never finished there."""
test "a continue inside a switch moves the enclosing loop on" {
    out = assert_native_identity(
        fixture("switch_continue.jac"), profiles=["rc", "managed"]
    );
    assert "zero\nfinally 0\none\nafter switch 1\nfinally 1\n" in out , out;
    assert "inner finally 00\ninner 01\ninner finally 01\nouter finally 0\n"
        in out , out;
    assert "skip 0\nodd 1\nend 1\neven 2\nafter inner 2\n" in out , out;
    assert "counted 0\nk 1\nk 3\ncounted 2\n" in out , out;
    assert "two done\ntail 2\nn 4\ntail 4\n" in out , out;
}

"""The objects being written out are tracked without a limit. With room for
64, a chain of 80 objects that closes on itself past the 64th was followed
round the cycle until the stack ran out."""
test "default object text nests past any fixed depth and still stops at a cycle" {
    out = assert_native_identity(
        fixture("default_object_text_deep.jac"), profiles=["rc", "managed"]
    );
    assert "1754 80 0\n1753 80 1\n" in out , out;
    assert "True 1754" in out , out;
}

"""A field whose own text raises ends the write of the object holding it.
The object is no longer being written, so printing it again writes it in
full rather than `...`."""
test "an error raised while an object is written out leaves it printable" {
    out = assert_native_identity(
        fixture("default_object_text_raise.jac"), profiles=["rc", "managed"]
    );
    assert out
        == (
            "Holder(name='h', inner=calm)\n"
            "refused: not now\n"
            "Holder(name='h', inner=calm)\n"
            "Holder(name='h', inner=calm)\n"
        ) , out;
}

"""Each thread tracks the objects it is writing out on its own. Sharing one
record let a `flow for` body see another thread's objects as its own and
print `...` for an object it had not met."""
test "threads writing out cyclic objects do not see each other's progress" {
    out = assert_native_identity(
        fixture("default_object_text_threads.jac"), profiles=["rc", "managed"]
    );
    assert "Pair(label=7, other=Pair(label=107, other=...))\nwrong 0\n" in out , out;
}
