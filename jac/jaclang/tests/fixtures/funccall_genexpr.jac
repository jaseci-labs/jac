def total(values: Any) {
    return sum(values);
}

with entry {
    result = total((x * x) for x in range(5));
    print(f"Result: {result}");
}
