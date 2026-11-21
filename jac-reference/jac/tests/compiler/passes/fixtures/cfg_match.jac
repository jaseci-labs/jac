def classify(x: int) -> str {
    match x {
        case 0:
            return "zero";
        case 1:
            return "one";
        case _:
            return "other";
    }
}
