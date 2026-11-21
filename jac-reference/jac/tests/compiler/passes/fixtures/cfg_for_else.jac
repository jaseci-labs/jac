def find(items: list, target: int) -> bool {
    for item in items {
        if item == target {
            return True;
        }
    } else {
        return False;
    }
}
