def fail_value {
    raise ValueError("value");
}

def fail_missing {
    raise FileNotFoundError("missing");
}

def fail_type {
    raise TypeError("type");
}

with entry {
    for kind in [0, 1] {
        matched = False;
        try {
            if kind == 0 {
                fail_value();
            } else {
                fail_missing();
            }
        } except (OSError, ValueError) as error {
            matched = True;
            assert str(error) == ("value" if kind == 0 else "missing");
        }
        assert matched;
    }
    selected = 0;
    try {
        fail_value();
    } except (ValueError, OSError) {
        selected = 1;
    } except ValueError {
        selected = 2;
    }
    assert selected == 1;
    propagated = False;
    finalized = 0;
    try {
        try {
            fail_type();
        } except (ValueError, OSError) {
            assert False;
        } finally {
            finalized += 1;
        }
    } except TypeError {
        propagated = True;
    }
    assert propagated and finalized == 1;
    propagated = False;
    try {
        try {
            fail_value();
        } except () {
            assert False;
        }
    } except ValueError {
        propagated = True;
    }
    assert propagated;
    matched = False;
    try {
        fail_type();
    } except (OSError, Exception) {
        matched = True;
    }
    assert matched;
    propagated = False;
    try {
        try {
            fail_value();
        } except (OSError, ValueError) {
            raise;
        }
    } except Exception {
        propagated = True;
    }
    assert propagated;
    print("tuple handlers pass");
}
