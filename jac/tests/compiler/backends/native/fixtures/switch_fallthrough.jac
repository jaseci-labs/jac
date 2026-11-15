def classify(fruit: str) -> list[str] {
    seen: list[str] = [];
    switch fruit {
        case "apple":
            seen.append("apple");
            break;

        case "banana":

        case "orange":
            seen.append("banana-or-orange");

        case "grape":
            seen.append("grape");
            break;

        case "kiwi" | "lime":
            seen.append("kiwi-or-lime");

        default:
            seen.append("default:" + fruit);

    }
    return seen;
}

def bucket(n: int) -> str {
    out = "";
    switch n {
        case 1:
            out += "one ";

        case 2:
            out += "two ";
            break;

        default:
            out += "many ";

        case 9:
            out += "nine ";

    }
    return out;
}

def in_loop(limit: int) -> int {
    total = 0;
    for i in range(limit) {
        switch i {
            case 1:
                break;

            case 3:
                total += 100;

            default:
                total += i;

        }
        total += 1000;
    }
    return total;
}

with entry {
    for fruit in ["apple", "banana", "orange", "grape", "kiwi", "lime", "mango"] {
        print(fruit, classify(fruit));
    }
    for n in [1, 2, 3, 9] {
        print(n, bucket(n));
    }
    print(in_loop(5));
}
