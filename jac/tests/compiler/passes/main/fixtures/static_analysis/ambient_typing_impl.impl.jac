impl Runner.run(cb: Callable[[], None]) -> Sequence[str] {
    cb();
    return ["ok"];
}

impl Runner.broken -> None {
    totally_undefined_thing;
}
