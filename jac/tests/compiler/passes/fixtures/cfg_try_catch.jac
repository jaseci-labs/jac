def parse(s: str) -> int {
    y = 0;
    try {
        y = int(s);
        if y > 9 {
            y = 9;
        }
    } except ValueError {
        y = -1;
    }
    return y;
}

def check(s: str) {
    try {
        int(s);
        return;
    } except ValueError {
        print(s);
    }
}
