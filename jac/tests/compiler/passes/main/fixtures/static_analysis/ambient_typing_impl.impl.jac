impl Runner.run(cb: Callable[[], None]) -> Sequence[str] {
    cb();
    return ["ok"];
}
