"""Test fixture: a match case body requires at least one statement."""

def pick(x: int) -> int {
    match x {
        case 1: ;
        case 2: ;;
        case _: return x;
    }
    return 0;
}
