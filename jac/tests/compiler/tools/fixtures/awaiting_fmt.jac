"""Awaiting-clause formatting: the clause survives the round trip to source."""
def run {
    try {
        print("body");
    } awaiting {
        print("waiting");
    } except Exception {
        print("failed");
    }
}

def bare {
    try {
        print("body");
    } awaiting {
        print("waiting");
    }
}

def with_else {
    try {
        print("body");
    } awaiting {
        print("waiting");
    } except Exception as e {
        print(e);
    } else {
        print("ok");
    }
}
