"""Each owned field value drops exactly once, at the same points in every gc mode."""

obj Res {
    has tag: int = 0;

    def drop {
        print(f"drop {self.tag}");
    }
}

obj Holder {
    has ref: own Res = Res();
}

def work {
    h: own Holder = Holder();
    h.ref = Res(tag=2);
    print("mid");
    print(h.ref.tag);
}

with entry {
    work();
    print("end");
}
