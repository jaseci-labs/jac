import json;

def pair_sum -> int {
    (left, right) = json.loads("[2, 3]");
    return left + right;
}

def too_few -> int {
    (left, right) = json.loads("[2]");
    return left + right;
}

def too_many -> int {
    (left, right) = json.loads("[2, 3, 4]");
    return left + right;
}

def consume_extra -> int {
    items = iter(json.loads("[1, 2, 3, 4]"));
    try {
        (left, right) = items;
    } except ValueError {
        return next(items);
    }
    return 0;
}
