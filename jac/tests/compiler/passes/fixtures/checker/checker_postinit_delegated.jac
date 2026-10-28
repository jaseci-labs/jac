obj Delegated {
    has seed: int = 1,
        total: int postinit,
        label: str postinit;

    def postinit;
    def _setup;
    def _name;
}

impl Delegated.postinit {
    self._setup();
}

impl Delegated._setup {
    self.total = self.seed * 2;
    self._name();
}

impl Delegated._name {
    self.label = "ready";
}

obj Shallow {
    has count: int postinit;

    def postinit;
    def _noop;
}

impl Shallow.postinit {
    self._noop();
}

impl Shallow._noop {}
