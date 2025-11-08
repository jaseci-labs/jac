walker Adder {
    can do with `root entry;
}

node node_a {
    has x: int = 0,
        y: int = 0;

    can add with Adder entry;
}

impl Adder.do {
    here ++> node_a();
    visit [-->];
}

impl node_a.add {
    self.x = 550;
    self.y = 450;
    print(int(self.x) + int(self.y));
}

with entry {
    # spawn will iniiate the walker Adder from root node
    Adder() spawn root;
}
