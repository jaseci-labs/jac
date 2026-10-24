import sys;


obj Inverse {
    has fn: Callable,
        args: list[any] = [],
        keys: list[str] = [];

    def run;
}


obj Fiber {
    has name: str,
        inject: list[str] = [],
        provide: list[str] = [],
        apply: Callable | None = None,
        active: bool = False,
        parent: str = "root";

    def satisfied(ctx: EffectContext) -> bool;
}


obj EffectContext {
    has store: dict[str, object] = {},
        registry: dict[str, Fiber] = {},
        frames: dict[str, list[Inverse]] = {},
        root_frame: list[Inverse] = [],
        current_fiber: str = "",
        verbose: bool = False;

    def has_key(key: str) -> bool;
    def get(key: str) -> object;
    def _log(msg: str);
    def set(key: str, value: object);
    def unset(key: str);
    def _record(inv: Inverse);
    def effect(
        fn: Callable,
        args: list[any],
        inverse: Callable,
        inv_args: list[any],
        keys: list[str] = []
    );

    def use(comp: Fiber) -> str;
    def unload(name: str) -> None;
    def swap(old_name: str, comp: Fiber) -> str;
    def _recover_frame(name: str);
    def _refresh;
    def _activate(name: str) -> None;
    def _notify(keys: list[str]) -> None;
    def dispose_all;
}

impl Inverse.run {
    self.fn(*self.args);
}


impl Fiber.satisfied(ctx: EffectContext) -> bool {
    for k in self.inject {
        if not ctx.has_key(k) {
            return False;
        }
    }
    return True;
}


impl EffectContext.has_key(key: str) -> bool {
    return key in self.store;
}

impl EffectContext.get(key: str) -> object {
    return self.store.get(key);
}

impl EffectContext._log(msg: str) {
    if self.verbose {
        sys.stderr.write("  [cordis] " + msg + "\n");
    }
}

impl EffectContext.set(key: str, value: object) {
    if key in self.store {
        raise ValueError("coeffect key already provided: " + key);
    }
    self.store[key] = value;
    inv = Inverse(fn=self.unset, args=[key], keys=[key]);
    self._record(inv);
    self._notify([key]);
}

impl EffectContext.unset(key: str) {
    self.store.pop(key, None);
    self._notify([key]);
}

impl EffectContext._record(inv: Inverse) {
    if self.current_fiber {
        frame: list[Inverse] | None = self.frames.get(self.current_fiber);
        if frame is None {
            frame = [];
            self.frames[self.current_fiber] = frame;
        }
        frame.append(inv);
    } else {
        self.root_frame.append(inv);
    }
}

impl EffectContext.effect(
    fn: Callable,
    args: list[any],
    inverse: Callable,
    inv_args: list[any],
    keys: list[str] = []
) {
    fn(*args);
    self._record(Inverse(fn=inverse, args=inv_args, keys=keys));
    if keys {
        self._notify(keys);
    }
}

impl EffectContext.use(comp: Fiber) -> str {
    if comp.name in self.registry {
        raise ValueError("fiber already registered: " + comp.name);
    }
    for k in comp.provide {
        for other_name in self.registry {
            other = self.registry[other_name];
            if other.active and k in other.provide {
                raise ValueError("provision conflict on " + k + ": " + other_name);
            }
        }
    }
    self.registry[comp.name] = comp;
    self._log("registered " + comp.name);
    self._refresh();
    return comp.name;
}

impl EffectContext.unload(name: str) -> None {
    fiber = self.registry.get(name);
    if fiber is None {
        return;
    }
    del self.registry[name];
    self._recover_frame(name);
    self._refresh();
    self._log("unloaded " + name);
}

impl EffectContext.swap(old_name: str, comp: Fiber) -> str {
    self.unload(old_name);
    return self.use(comp);
}

impl EffectContext._recover_frame(name: str) {
    frame: list[Inverse] = self.frames.pop(name, []);
    fiber = self.registry.get(name);
    while frame {
        inv: Inverse = frame.pop();
        self._log("  revert " + name + ": " + str(inv.keys));
        inv.run();
    }
    if fiber is not None {
        fiber.active = False;
    }
}

impl EffectContext._refresh {
    for _pass in range(32) {
        flipped = False;
        for name in list(self.registry.keys()) {
            fiber = self.registry[name];
            sat = fiber.satisfied(self);
            if sat and not fiber.active {
                self._activate(name);
                flipped = True;
            } elif fiber.active and not sat {
                self._recover_frame(name);
                flipped = True;
            }
        }
        if not flipped {
            break;
        }
    }
}

impl EffectContext._activate(name: str) -> None {
    fiber = self.registry.get(name);
    if fiber is None or fiber.apply is None {
        return;
    }
    prev = self.current_fiber;
    self.current_fiber = name;
    self.frames[name] = [];
    try {
        fiber.apply(self, fiber);
        fiber.active = True;
        self._log("activated " + name);
    } finally {
        self.current_fiber = prev;
    }
}

impl EffectContext._notify(keys: list[str]) -> None {
    return;
}

impl EffectContext.dispose_all {
    for name in list(self.registry.keys()) {
        self.unload(name);
    }
    while self.root_frame {
        inv: Inverse = self.root_frame.pop();
        inv.run();
    }
}
