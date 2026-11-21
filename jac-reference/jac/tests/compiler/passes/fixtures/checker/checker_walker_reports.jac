"""Walker .reports attribute should be visible on all walker types."""

node Task {
    has title: str;
    has done: bool = False;
}

walker ListTasks {
    has reports: list[list[Task]] = [];

    can collect with Root entry {
        report [-->][?:Task];
    }
}

walker UntypedWalker {
    can work with Root entry {
        report "hello";
    }
}

with entry {
    # Typed walker — .reports should resolve to list[list[Task]]
    result1 = root spawn ListTasks();
    tasks = result1.reports[0] if result1.reports else [];

    # Untyped walker — .reports should resolve to list[Any] (inherited from Walker)
    result2 = root spawn UntypedWalker();
    data = result2.reports[0] if result2.reports else None;
}
