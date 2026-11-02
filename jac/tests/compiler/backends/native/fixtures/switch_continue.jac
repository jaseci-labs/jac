"""A `continue` inside a switch moves the enclosing loop on."""

def run(limit: int) -> list[str] {
    log: list[str] = [];
    for i in range(limit) {
        try {
            switch i {
                case 0:
                    log.append("zero");
                    continue;
                case 1:
                    log.append("one");
                    break;
                default:
                    log.append("other");
            }
            log.append("after switch " + str(i));
        } finally {
            log.append("finally " + str(i));
        }
    }
    return log;
}

def nested(limit: int) -> list[str] {
    log: list[str] = [];
    for i in range(limit) {
        try {
            for j in range(2) {
                try {
                    switch j {
                        case 0:
                            continue;
                        default:
                            log.append("inner " + str(i) + str(j));
                    }
                } finally {
                    log.append("inner finally " + str(i) + str(j));
                }
            }
        } finally {
            log.append("outer finally " + str(i));
        }
    }
    return log;
}

def nested_switches(limit: int) -> list[str] {
    log: list[str] = [];
    for i in range(limit) {
        switch i % 2 {
            case 0:
                switch i {
                    case 0:
                        log.append("skip 0");
                        continue;
                    default:
                        log.append("even " + str(i));
                }
                log.append("after inner " + str(i));
            default:
                log.append("odd " + str(i));
        }
        log.append("end " + str(i));
    }
    return log;
}

def counted(limit: int) -> list[str] {
    log: list[str] = [];
    for i = 0 while i < limit with i += 1 {
        switch i {
            case 1:
                continue;
            default:
                log.append("counted " + str(i));
        }
        k = 0;
        while k < 3 {
            k += 1;
            if k == 2 {
                continue;
            }
            log.append("k " + str(k));
        }
    }
    return log;
}

def looping_case() -> list[str] {
    log: list[str] = [];
    n = 0;
    while n < 4 {
        n += 1;
        switch n {
            case 2:
                for j in range(3) {
                    if j == 1 {
                        continue;
                    }
                    log.append("j " + str(j));
                }
                log.append("two done");
                break;
            case 3:
                continue;
            default:
                log.append("n " + str(n));
        }
        log.append("tail " + str(n));
    }
    return log;
}

with entry {
    for line in run(3) {
        print(line);
    }
    for line in nested(2) {
        print(line);
    }
    for line in nested_switches(4) {
        print(line);
    }
    for line in counted(3) {
        print(line);
    }
    for line in looping_case() {
        print(line);
    }
}
