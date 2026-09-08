glob drops: int = 0;

obj Box {
    has value: int;

    def drop {
        drops += 1;
    }
}

def call_lambda -> int {
    box = Box(7);
    read = lambda (arg: Box) -> int {
        if arg.value > 0 {
            return arg.value;
        }
        return 0;
    };
    first = read(box);
    second = read(box);
    return first * 100 + second * 10 + drops;
}

def drop_count -> int {
    return drops;
}
