import asyncio;

node AsyncValue {
    has v: int;
}

walker Accumulate {
    has total: int = 0;

    async can add with AsyncValue entry {
        await asyncio.sleep(0);
        self.total += here.v;
        visit [-->];
    }
}

walker Derived(Accumulate) {}
walker Fails {
    async can fail with Root entry {
        await asyncio.sleep(0);
        raise ValueError("ability failed");
    }
}

async def concurrent {
    a = Accumulate();
    b = Derived();
    await asyncio.gather(a spawn AsyncValue(v=2), b spawn AsyncValue(v=3));
    assert a.total == 2;
    assert b.total == 3;
}

with entry {
    a = AsyncValue(v=1);
    a ++> AsyncValue(v=4);
    w = Accumulate();
    w spawn a;
    assert w.total == 5;
    d = Derived();
    root spawn d;
    d spawn AsyncValue(v=6);
    assert d.total == 6;
    try {
        Fails() spawn root;
        assert False;
    } except ValueError as e {
        assert str(e) == "ability failed";
    }
    pending: any = concurrent();
    asyncio.run(pending);
    print("async abilities completed");
}
