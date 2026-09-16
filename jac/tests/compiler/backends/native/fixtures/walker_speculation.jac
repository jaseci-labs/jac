node Work {
    has value: int,
        result: int = 0,
        values: list[int] = [],
        lookup: dict[int, int] = {};
}

def compute(seed: int) -> int {
    value = seed;
    for i in range(20000) {
        value = (value * 31 + i) % 1000003;
    }
    return value;
}

walker WorkWalker {
    has shared: int = 0;

    can step with Work entry {
        here.result = compute(here.value);
        here.values.append(here.value);
        alias = here.values;
        alias.append(here.result);
        here.lookup[here.value] = here.result;
        report here.values;
        alias[0] += 10;
        visit [-->] else {
            report here.lookup[here.value];
        }
    }

    can dependent with Work entry {
        self.shared += here.value;
        report self.shared;
    }

    can leave with Work exit {
        report -here.value;
    }
}

walker FallbackWalker {
    has count: int = 0;

    can step with Work entry {
        self.count += 1;
        report self.count;
        if here.value == 2 {
            print("external", self.count);
            visit : 0 : [-->];
        } else {
            visit [-->];
        }
    }
}

obj Payload {
    has value: int;
}

node Allocation {
    has value: int,
        payload: Payload = Payload(0);
}

walker Allocator {
    can step with Allocation entry {
        fresh = Payload(here.value);
        report fresh;
        here.payload = fresh;
        fresh.value += 1;
        visit [-->];
    }
}

walker Divisor {
    has divisor: int = 0;

    can prepare with Work entry {
        self.divisor = 2;
    }

    can consume with Work entry {
        report 10 // self.divisor;
    }
}

walker Waiter {
    has ready: bool = False;

    can prepare with Work entry {
        self.ready = True;
    }

    can consume with Work entry {
        while not self.ready {}
        report 6;
    }
}

walker Failure {
    has count: int = 0;

    can first with Work entry {
        self.count += 1;
        report self.count;
    }

    can fail with Work entry {
        self.count += 1;
        report self.count;
        raise ValueError("expected");
    }

    can cancelled with Work entry {
        self.count += 100;
    }
}

with entry {
    a = Work(1);
    b = Work(2);
    c = Work(3);
    d = Work(4);
    a ++> b;
    a ++> c;
    b ++> d;
    visitor = WorkWalker();
    a spawn visitor;
    reports: list[any] = [];
    reports = visitor.reports;
    print(len(reports));
    first_report: list[int] = reports[0];
    assert first_report is a.values;
    print(first_report[0], first_report[1]);
    for i in [1, 3, 5, 6, 8, 9, 10, 11, 12, 13] {
        reported: int = reports[i];
        print(reported);
    }
    print(a.values, b.values, c.values, d.values);
    print(visitor.shared);
    fallback = FallbackWalker();
    a spawn fallback;
    fallback_reports: list[any] = [];
    fallback_reports = fallback.reports;
    for value in fallback_reports {
        reported_value: int = value;
        print(reported_value);
    }
    divisor = Divisor();
    a spawn divisor;
    quotient: int = divisor.reports[0];
    assert quotient == 5;
    waiter = Waiter();
    a spawn waiter;
    waited: int = waiter.reports[0];
    assert waited == 6;
    failure = Failure();
    try {
        a spawn failure;
        assert False;
    } except ValueError {
        assert failure.count == 2;
        assert len(failure.reports) == 2;
        prefix_first: int = failure.reports[0];
        prefix_second: int = failure.reports[1];
        assert prefix_first == 1 and prefix_second == 2;
        print("caught", failure.count);
    }
    allocation_root = Allocation(7);
    allocation_left = Allocation(8);
    allocation_right = Allocation(9);
    allocation_root ++> allocation_left;
    allocation_root ++> allocation_right;
    allocation_left ++> Allocation(10);
    allocation_right ++> Allocation(11);
    allocator = Allocator();
    allocation_root spawn allocator;
    allocated: list[any] = [];
    allocated = allocator.reports;
    assert len(allocated) == 5;
    saved: Payload = allocated[1];
    assert saved is allocation_left.payload;
    assert saved.value == 9;
    saved.value += 10;
    assert allocation_left.payload.value == 19;
    print(saved.value, allocation_right.payload.value);
}
