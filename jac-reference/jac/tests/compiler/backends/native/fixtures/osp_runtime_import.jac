import from jaclang.runtime.osp_kernel { osp_skip_rest }

node Item {}

walker Inspect {
    has count: int = 0;

    can first with Item entry {
        self.count += 1;
        osp_skip_rest();
    }

    can second with Item entry {
        self.count += 100;
    }
}

def probe -> int {
    item = Item();
    visitor = Inspect();
    item spawn visitor;
    return visitor.count;
}

with entry {
    assert probe() == 1;
}
