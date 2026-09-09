"""A `lin` binding is an own binding that must be consumed; codegen treats it
exactly like `own`, so the close-then-drop sequence is identical in every
memory mode (#8984 rule 7)."""

obj Handle {
    has id: int = 0;

    def drop { print("drop " + str(self.id)); }
}

def close(h: own Handle) -> None {
    print("close " + str(h.id));
}

def open_one(id: int) -> own Handle {
    h: lin Handle = Handle(id=id);
    return h;
}

def run -> int {
    h: lin Handle = open_one(7);
    print("using " + str(h.id));
    close(h);
    return 1;
}

with entry { print(run()); print("done"); }
