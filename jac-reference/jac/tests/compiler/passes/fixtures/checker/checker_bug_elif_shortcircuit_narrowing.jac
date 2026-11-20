"""An elif with a short-circuit condition keeps the narrowing of the if guard."""

obj Base {}

obj Sub(Base) {
    has flag: bool = False;
}

def take(b: Base) -> None {
    print(b);
}

def plain_elif(x: (Base | None)) -> None {
    if not x {
        return;
    } elif isinstance(x, Sub) {
        return;
    }
    take(x);
}

def and_chained_elif(x: (Base | None)) -> None {
    if not x {
        return;
    } elif isinstance(x, Sub) and x.flag {
        return;
    }
    take(x);
}

def or_chained_elif(x: (Base | None), y: (Base | None)) -> None {
    if not x {
        return;
    } elif isinstance(x, Sub) or y is None {
        return;
    }
    take(x);
}

def nested_else_if(x: (Base | None)) -> None {
    if not x {
        return;
    } else {
        if isinstance(x, Sub) and x.flag {
            return;
        }
    }
    take(x);
}
