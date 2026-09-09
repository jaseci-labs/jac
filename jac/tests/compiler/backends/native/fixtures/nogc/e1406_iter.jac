"""Must-fail under --memory nogc: iter() retains a raw collection reference (E1406)."""

glob data = [1, 2, 3],
     it = iter(data);

with entry {
    print(next(it));
}
