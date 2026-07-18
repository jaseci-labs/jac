"""Silently-dropped positional arguments (issue #7320 Cluster 2, the
silent-kwarg family): range() step, str.find() start, pow() modulus.

Each compiled clean and ran with the extra argument ignored, so loops
walked every index, find searched from 0, and pow returned the full
power instead of the modular result.
"""

def:pub range_step_sum -> int {
    acc = 0;
    for i in range(0, 10, 3) {
        acc = acc * 10 + i;
    }
    down = 0;
    for j in range(5, 0, -2) {
        down = down * 10 + j;
    }
    return acc * 1000 + down;
}

def:pub find_with_start -> int {
    s = "abcabc";
    a = s.find("b", 2);
    b = s.find("b");
    c = s.find("z", 1);
    return a * 100 + b * 10 + (1 if c == -1 else 0);
}

def:pub pow_with_mod -> int {
    return pow(3, 4, 5) * 1000 + pow(2, 10, 1000);
}

def:pub range_zero_step_raises -> int {
    acc = 0;
    try {
        for i in range(1, 5, 0) {
            acc += 1;
            if acc > 3 {
                return 999;
            }
        }
    } except Exception {
        return 1;
    }
    return 0;
}

def:pub pow_zero_mod_raises -> int {
    try {
        x = pow(3, 4, 0);
        return 0;
    } except Exception {
        return 1;
    }
}

with entry {
    range_step_sum();
}
