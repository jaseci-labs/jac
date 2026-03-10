def quadrant(x: int, y: int) -> str {
    if x > 0 {
        if y > 0 {
            return "Q1";
        } else {
            return "Q4";
        }
    } else {
        return "left";
    }
}
