"""Every control transfer runs the finalizers it exits, inside out."""

def returning -> int {
    try {
        try {
            return 7;
        } finally {
            print("inner");
        }
    } finally {
        print("outer");
    }
}

def looping {
    for i in range(3) {
        try {
            if i == 0 {
                continue;
            }
            break;
        } finally {
            print(i);
        }
    }
    try {
        for j in range(2) {
            break;
        }
        print("after loop");
    } finally {
        print("after try");
    }
}

with entry {
    print(returning());
    looping();
}
