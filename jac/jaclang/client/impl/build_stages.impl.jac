impl record_stages -> Iterator[list[tuple[str, float]]] {
    rows: list[tuple[str, float]] = [];
    token = _recording.set(rows);
    try {
        yield rows;
    } finally {
        _recording.reset(token);
    }
}

impl stage(done: str) -> Iterator[None] {
    rows = _recording.get();
    if rows is None {
        yield ;
        return;
    }
    began = time.monotonic();
    yield ;
    elapsed = time.monotonic() - began;
    rows.append((done, elapsed));
    if elapsed >= SHOWN_FROM_SECONDS {
        console.print(f"  ✔ {done} ({elapsed:.1f}s)");
    }
}
