"""A `continue` reaches the loop it belongs to and no other.

A switch that holds a loop does not pass on a `continue` that loop took, and a
switch that runs while a `continue` is on its way out does not lose it."""

def outer_keeps_going(limit: int) -> list[str] {
    log: list[str] = [];
    for i in range(limit) {
        switch i % 2 {
            case 0:
                for j in range(2) {
                    switch j {
                        case 1:
                            continue;
                        default:
                            log.append("inner " + str(i) + str(j));
                    }
                    log.append("inner tail " + str(i) + str(j));
                }
                log.append("after inner loop " + str(i));
                break;
            default:
                log.append("odd " + str(i));
        }
        log.append("after outer switch " + str(i));
    }
    return log;
}

def in_finally(limit: int) -> list[str] {
    log: list[str] = [];
    for i in range(limit) {
        switch i {
            case 0:
                try {
                    log.append("zero");
                    continue;
                } finally {
                    for k in range(2) {
                        switch k {
                            case 0:
                                continue;
                            default:
                                log.append("cleanup " + str(i));
                        }
                        log.append("cleanup tail " + str(k));
                    }
                }
            default:
                log.append("other " + str(i));
        }
        log.append("tail " + str(i));
    }
    return log;
}

with entry {
    for line in outer_keeps_going(3) {
        print(line);
    }
    for line in in_finally(2) {
        print(line);
    }
}
