"""Multi-statement lambda used as a `has` field default on an obj archetype.

Obj/node `has` defaults lower through ``field(factory=...)``. The multi-statement
lambda helper hoists to the enclosing function-or-module scope (never the class
body, which would trip Python private-name mangling), and the field uses a plain
factory so the default is rebuilt per instance.
"""

obj Formatter {
    has fmt: type = lambda (s: str) -> str {
        up = s.upper();
        up + "!"
    };

    def apply(msg: str) -> str {
        return self.fmt(msg);
    }
}

node Shouter {
    has fmt: type = lambda (s: str) -> str {
        up = s.upper();
        up + "!"
    };
}

with entry {
    f = Formatter();
    print(f.apply("hi"));
    n = Shouter();
    print(n.fmt("bye"));
}
