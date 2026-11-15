"""A `break` in a `finally` replaces the `continue` or `return` leaving through it."""

def overridden(limit: int) -> list[str] {
    log: list[str] = [];
    for i in range(limit) {
        switch i {
            case 1:
                try {
                    continue;
                } finally {
                    log.append("finally " + str(i));
                    break;
                }

            default:
                log.append("case " + str(i));

        }
        log.append("after " + str(i));
    }
    return log;
}

def overridden_outside(limit: int) -> list[str] {
    log: list[str] = [];
    for i in range(limit) {
        switch i % 2 {
            case 1:
                try {
                    switch i {
                        case 1:
                            continue;

                        default:
                            log.append("inner " + str(i));

                    }
                    log.append("after inner " + str(i));
                } finally {
                    break;
                }

            default:
                log.append("even " + str(i));

        }
        log.append("after " + str(i));
    }
    return log;
}

def returned(limit: int) -> list[str] {
    log: list[str] = [];
    for i in range(limit) {
        try {
            for j in range(2) {
                if i == 1 {
                    return ["returned"];
                }
                log.append("j " + str(i) + str(j));
            }
        } finally {
            if i == 1 {
                break;
            }
        }
    }
    log.append("broke");
    return log;
}

with entry {
    print(" ".join(overridden(3)));
    print(" ".join(overridden_outside(4)));
    print(" ".join(returned(3)));
}
